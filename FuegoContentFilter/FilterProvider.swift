import Foundation
import NetworkExtension
import os.log

/// Drops connections to blocked domains while a focus session is running.
///
/// The app enables this filter only during a session and passes the blocklist through
/// `filterConfiguration.vendorConfiguration`.
final class FilterProvider: NEFilterDataProvider {
    private let logger = OSLog(subsystem: "dev.getfuego.FuegoFocus", category: "FilterProvider")
    private let lock = NSLock()
    private var blockedDomains: Set<String> = []
    private var configurationObservation: NSKeyValueObservation?

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        reloadBlocklist()
        configurationObservation = observe(\.filterConfiguration, options: [.new]) { provider, _ in
            provider.reloadBlocklist()
        }

        // Inspect every outbound TCP/UDP flow; the verdict is made per flow in handleNewFlow.
        let rule = NEFilterRule(networkRule: NENetworkRule(
            remoteNetworkEndpoint: nil, remotePrefix: 0, localNetworkEndpoint: nil, localPrefix: 0,
            protocol: .any, direction: .outbound), action: .filterData)
        let settings = NEFilterSettings(rules: [rule], defaultAction: .allow)
        apply(settings) { error in
            if let error {
                os_log("Failed to apply filter settings: %{public}@", log: self.logger, type: .error, error.localizedDescription)
            }
            completionHandler(error)
        }
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("Stopping content filter, reason: %d", log: logger, type: .info, reason.rawValue)
        configurationObservation = nil
        completionHandler()
    }

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        guard let host = hostname(of: flow) else { return .allow() }

        lock.lock()
        let blocked = DomainMatcher.isBlocked(host: host, blockedDomains: blockedDomains)
        lock.unlock()

        if blocked {
            os_log("Blocking flow to %{private}@", log: logger, type: .info, host)
            return .drop()
        }
        return .allow()
    }

    private func reloadBlocklist() {
        let domains = FilterVendorConfiguration.blockedDomains(from: filterConfiguration.vendorConfiguration)
        lock.lock()
        blockedDomains = domains
        lock.unlock()
        os_log("Loaded %d blocked domains", log: logger, type: .info, domains.count)
    }

    private func hostname(of flow: NEFilterFlow) -> String? {
        if let host = flow.url?.host, !host.isEmpty {
            return host
        }
        if let socketFlow = flow as? NEFilterSocketFlow,
            let host = socketFlow.remoteHostname, !host.isEmpty
        {
            return host
        }
        return nil
    }
}
