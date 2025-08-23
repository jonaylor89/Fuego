import Foundation
import Network
import NetworkExtension
import os.log

/// Shared storage mechanism for communicating blocklist between main app and extension
class SharedBlocklist {
    private let logger = OSLog(subsystem: "dev.getfuego.FuegoFocus", category: "SharedBlocklist")
    private let userDefaults = UserDefaults(suiteName: "group.dev.getfuego.FuegoFocus")

    // MARK: - Storage Keys
    private enum StorageKeys {
        static let blockedDomains = "blockedDomains"
        static let isFilteringEnabled = "isFilteringEnabled"
        static let lastUpdated = "lastUpdated"
    }

    init() {}

    // MARK: - Public Properties

    var blockedDomains: Set<String> {
        get {
            guard let data = userDefaults?.data(forKey: StorageKeys.blockedDomains),
                let domains = try? JSONDecoder().decode(Set<String>.self, from: data)
            else {
                return []
            }
            return domains
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            userDefaults?.set(data, forKey: StorageKeys.blockedDomains)
            userDefaults?.set(Date(), forKey: StorageKeys.lastUpdated)
            os_log("Updated blocked domains: %d domains", log: logger, type: .info, newValue.count)
        }
    }

    var isFilteringEnabled: Bool {
        get {
            return userDefaults?.bool(forKey: StorageKeys.isFilteringEnabled) ?? false
        }
        set {
            userDefaults?.set(newValue, forKey: StorageKeys.isFilteringEnabled)
            userDefaults?.set(Date(), forKey: StorageKeys.lastUpdated)
            os_log("Filtering enabled: %{public}@", log: logger, type: .info, String(newValue))
        }
    }

    // MARK: - Public Methods

    func loadBlocklist() {
        os_log("Loading blocklist from shared storage", log: logger, type: .info)
        let domains = blockedDomains
        let enabled = isFilteringEnabled
        os_log(
            "Loaded %d blocked domains, filtering enabled: %{public}@", log: logger, type: .info,
            domains.count, String(enabled))
    }

    func updateBlocklist(_ domains: Set<String>, enabled: Bool) {
        blockedDomains = domains
        isFilteringEnabled = enabled
        os_log(
            "Updated blocklist with %d domains, enabled: %{public}@", log: logger, type: .info,
            domains.count, String(enabled))
    }

    func startMonitoring(onChange: @escaping () -> Void) {
        os_log("Started monitoring shared preferences for changes", log: logger, type: .info)
        // Simplified monitoring for Network Extension
        // Real file monitoring would be more complex in this context
    }

    func stopMonitoring() {
        os_log("Stopped monitoring shared preferences", log: logger, type: .info)
        // Cleanup monitoring resources
    }
}

/// Content Filter Provider that intercepts network requests and blocks based on domain
class FilterProvider: NEFilterDataProvider {
    private let logger = OSLog(subsystem: "dev.getfuego.FuegoFocus", category: "FilterProvider")
    private var sharedStorage: SharedBlocklist

    override init() {
        self.sharedStorage = SharedBlocklist()
        super.init()
        os_log("FilterProvider initialized", log: logger, type: .info)
    }

    // MARK: - NEFilterDataProvider Override Methods

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting content filter", log: logger, type: .info)

        // Load initial blocklist from shared storage
        sharedStorage.loadBlocklist()

        // Log initial state
        let domains = sharedStorage.blockedDomains
        let enabled = sharedStorage.isFilteringEnabled
        os_log("Initial state - Domains: %d, Filtering enabled: %{public}@", log: logger, type: .info, domains.count, String(enabled))

        if enabled {
            os_log("Blocked domains: %{public}@", log: logger, type: .info, domains.joined(separator: ", "))
        }

        // Set up monitoring for blocklist changes via Darwin notifications
        setupBlocklistChangeMonitoring()

        completionHandler(nil)
    }

    private func setupBlocklistChangeMonitoring() {
        // Use Darwin notifications to listen for changes from main app
        let notificationName = "dev.getfuego.blocklist.updated" as CFString
        let center = CFNotificationCenterGetDarwinNotifyCenter()

        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())

        CFNotificationCenterAddObserver(
            center,
            observer,
            { (center, observer, name, object, userInfo) in
                guard let observer = observer else { return }
                let provider = Unmanaged<FilterProvider>.fromOpaque(observer).takeUnretainedValue()
                provider.reloadBlocklist()
            },
            notificationName,
            nil,
            .deliverImmediately
        )

        os_log("Darwin notification observer registered for blocklist changes", log: logger, type: .info)
    }

    private func reloadBlocklist() {
        os_log("Reloading blocklist from shared storage", log: logger, type: .info)

        sharedStorage.loadBlocklist()
        let domains = sharedStorage.blockedDomains
        let enabled = sharedStorage.isFilteringEnabled

        os_log("Blocklist reloaded - Domains: %d, Filtering enabled: %{public}@", log: logger, type: .info, domains.count, String(enabled))

        if enabled {
            os_log("Updated blocked domains: %{public}@", log: logger, type: .info, domains.joined(separator: ", "))
        }
    }

    override func stopFilter(
        with reason: NEProviderStopReason, completionHandler: @escaping () -> Void
    ) {
        os_log("Stopping content filter, reason: %d", log: logger, type: .info, reason.rawValue)
        sharedStorage.stopMonitoring()
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard sharedStorage.isFilteringEnabled else {
            // Filtering is disabled, allow all traffic
            return .allow()
        }

        // Extract domain from the flow
        let domain = extractDomain(from: flow)

        if shouldBlockDomain(domain) {
            os_log("Blocking request to: %{public}@", log: logger, type: .info, domain)

            // Drop the connection for blocked domains
            // This is the most reliable approach for NEFilterDataProvider
            return .drop()
        }

        // Allow the request
        return .allow()
    }

    override func handleInboundData(
        from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data
    ) -> NEFilterDataVerdict {
        // Since we're dropping connections in handleNewFlow, this shouldn't be called
        // for blocked domains, but we'll keep it as a safety check
        return .allow()
    }

    override func handleOutboundData(
        from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data
    ) -> NEFilterDataVerdict {
        return .allow()
    }

    // MARK: - Domain Filtering Logic

    private func extractDomain(from flow: NEFilterFlow) -> String {
        // Try to extract hostname from NEFilterSocketFlow
        if let socketFlow = flow as? NEFilterSocketFlow {
            // Try to get remote hostname directly if available
            if let remoteHostname = socketFlow.remoteHostname, !remoteHostname.isEmpty {
                os_log("Extracted hostname from remoteHostname: %{public}@", log: logger, type: .debug, remoteHostname)
                return remoteHostname
            }

            // Try to extract from URL (for browser flows)
            if let url = socketFlow.url {
                if let host = url.host, !host.isEmpty {
                    os_log("Extracted hostname from URL: %{public}@", log: logger, type: .debug, host)
                    return host
                }
            }

            // Fallback: Parse from flow description
            let flowDescription = String(describing: socketFlow)
            os_log("Flow description: %{public}@", log: logger, type: .debug, flowDescription)

            // Look for hostname patterns in the description
            if let range = flowDescription.range(of: "hostname: ") {
                let hostnamePart = String(flowDescription[range.upperBound...])
                if let endRange = hostnamePart.range(of: " ") {
                    let hostname = String(hostnamePart[..<endRange.lowerBound])
                    os_log("Extracted hostname from description (method 1): %{public}@", log: logger, type: .debug, hostname)
                    return hostname
                } else if let endRange = hostnamePart.range(of: "}") {
                    let hostname = String(hostnamePart[..<endRange.lowerBound])
                    os_log("Extracted hostname from description (method 2): %{public}@", log: logger, type: .debug, hostname)
                    return hostname
                }
            }

            // Alternative pattern matching for different flow descriptions
            if let range = flowDescription.range(of: "remoteEndpoint: ") {
                let endpointPart = String(flowDescription[range.upperBound...])
                if let colonRange = endpointPart.range(of: ":") {
                    let hostname = String(endpointPart[..<colonRange.lowerBound])
                    // Filter out IP addresses and empty strings
                    if !hostname.isEmpty && !hostname.contains("[") && !isIPAddress(hostname) {
                        os_log("Extracted hostname from remoteEndpoint: %{public}@", log: logger, type: .debug, hostname)
                        return hostname
                    }
                }
            }
        }

        os_log("Could not extract hostname from flow", log: logger, type: .debug)
        return ""
    }

    private func isIPAddress(_ string: String) -> Bool {
        // Simple check for IPv4 addresses
        let components = string.components(separatedBy: ".")
        return components.count == 4
            && components.allSatisfy { component in
                guard let number = Int(component) else { return false }
                return number >= 0 && number <= 255
            }
    }

    private func shouldBlockDomain(_ domain: String) -> Bool {
        guard !domain.isEmpty else { return false }

        let cleanDomain = domain.lowercased()

        return sharedStorage.blockedDomains.contains { blockedDomain in
            let cleanBlockedDomain = blockedDomain.lowercased()

            // Exact match
            if cleanDomain == cleanBlockedDomain {
                return true
            }

            // Subdomain match (e.g., mail.example.com matches example.com)
            if cleanDomain.hasSuffix(".\(cleanBlockedDomain)") {
                return true
            }

            // www variant (e.g., www.example.com matches example.com)
            if cleanDomain == "www.\(cleanBlockedDomain)" {
                return true
            }

            return false
        }
    }

    // MARK: - Redirect Response Creation

    private func createRedirectResponse(for domain: String) -> Data? {
        let stoicQuotes = [
            "You have power over your mind - not outside events. Realize this, and you will find strength. — Marcus Aurelius",
            "The impediment to action advances action. What stands in the way becomes the way. — Marcus Aurelius",
            "It's not what happens to you, but how you react to it that matters. — Epictetus",
            "Waste no more time arguing what a good person should be. Be one. — Marcus Aurelius",
            "The best revenge is not to be like your enemy. — Marcus Aurelius",
        ]

        let randomQuote = stoicQuotes.randomElement() ?? "Focus on what matters."

        let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Focus Time - \(domain)</title>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    * { margin: 0; padding: 0; box-sizing: border-box; }
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segue UI', system-ui, sans-serif;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        min-height: 100vh;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        line-height: 1.6;
                        color: white;
                    }
                    .container {
                        text-align: center;
                        max-width: 600px;
                        padding: 40px 20px;
                        background: rgba(255,255,255,0.1);
                        backdrop-filter: blur(10px);
                        border-radius: 20px;
                        border: 1px solid rgba(255,255,255,0.2);
                    }
                    .flame {
                        font-size: 64px;
                        margin-bottom: 20px;
                        filter: drop-shadow(0 4px 8px rgba(0,0,0,0.3));
                    }
                    h1 {
                        font-size: 28px;
                        font-weight: 300;
                        margin-bottom: 20px;
                        letter-spacing: 2px;
                    }
                    .domain {
                        font-size: 14px;
                        opacity: 0.8;
                        margin-bottom: 30px;
                        font-family: 'SF Mono', Monaco, monospace;
                    }
                    .quote {
                        font-size: 20px;
                        font-style: italic;
                        line-height: 1.8;
                        margin: 40px 0;
                        opacity: 0.95;
                    }
                    .subtitle {
                        font-size: 16px;
                        opacity: 0.7;
                        margin-top: 30px;
                    }
                    .breathe {
                        animation: breathe 4s ease-in-out infinite;
                    }
                    @keyframes breathe {
                        0%, 100% { transform: scale(1); }
                        50% { transform: scale(1.05); }
                    }
                </style>
            </head>
            <body>
                <div class="container breathe">
                    <div class="flame">🔥</div>
                    <h1>FOCUS TIME</h1>
                    <div class="domain">\(domain)</div>
                    <div class="quote">"\(randomQuote)"</div>
                    <div class="subtitle">Return when your mind is clear</div>
                </div>
            </body>
            </html>
            """

        let response = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html; charset=utf-8\r
            Content-Length: \(html.utf8.count)\r
            Connection: close\r
            \r
            \(html)
            """

        return response.data(using: .utf8)
    }
}
