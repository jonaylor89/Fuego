import Foundation

/// What the content filter should block, and until when.
///
/// The app hands this to the filter through `NEFilterProviderConfiguration.vendorConfiguration`.
/// The filter is a system extension running as root, so it can't read the user's
/// app group container — the filter configuration is the channel the system delivers to it.
struct FilterPolicy: Equatable {
    var blockedDomains: Set<String>
    /// Blocking lapses on its own after this date, so a crashed app never leaves sites blocked forever.
    var blockUntil: Date?

    static let off = FilterPolicy(blockedDomains: [], blockUntil: nil)

    func isActive(at now: Date = Date()) -> Bool {
        guard let blockUntil, !blockedDomains.isEmpty else { return false }
        return now < blockUntil
    }

    /// True when `host` is a blocked domain or one of its subdomains.
    func blocks(host: String) -> Bool {
        var host = host.lowercased()
        if host.hasSuffix(".") { host.removeLast() }
        guard !host.isEmpty else { return false }
        return blockedDomains.contains { domain in
            host == domain || host.hasSuffix("." + domain)
        }
    }

    // MARK: - Vendor configuration encoding

    private enum Key {
        static let blockedDomains = "blockedDomains"
        static let blockUntil = "blockUntil"
    }

    var vendorConfiguration: [String: Any] {
        var configuration: [String: Any] = [Key.blockedDomains: blockedDomains.sorted()]
        if let blockUntil {
            configuration[Key.blockUntil] = blockUntil.timeIntervalSince1970
        }
        return configuration
    }

    init(blockedDomains: Set<String>, blockUntil: Date?) {
        self.blockedDomains = blockedDomains
        self.blockUntil = blockUntil
    }

    init(vendorConfiguration: [String: Any]?) {
        let domains = vendorConfiguration?[Key.blockedDomains] as? [String] ?? []
        self.blockedDomains = Set(domains.compactMap(FilterPolicy.normalizedDomain))
        if let timestamp = vendorConfiguration?[Key.blockUntil] as? Double {
            self.blockUntil = Date(timeIntervalSince1970: timestamp)
        } else {
            self.blockUntil = nil
        }
    }

    // MARK: - Domain normalization

    /// Turns user input like `https://www.Reddit.com/r/all` into `reddit.com`.
    /// Returns nil when the input isn't a plausible domain name.
    static func normalizedDomain(_ input: String) -> String? {
        var domain = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let schemeEnd = domain.range(of: "://") {
            domain = String(domain[schemeEnd.upperBound...])
        }
        if let pathStart = domain.firstIndex(where: { "/?#".contains($0) }) {
            domain = String(domain[..<pathStart])
        }
        if let portStart = domain.firstIndex(of: ":") {
            domain = String(domain[..<portStart])
        }
        if domain.hasSuffix(".") { domain.removeLast() }
        if domain.hasPrefix("www.") { domain.removeFirst(4) }

        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        guard labels.count >= 2,
            labels.allSatisfy({ !$0.isEmpty && $0.count <= 63 && $0.allSatisfy(allowed.contains) })
        else {
            return nil
        }
        return domain
    }
}
