import Foundation

/// Domain rules shared by the app (normalizing user input) and the content filter (matching flows).
enum DomainMatcher {
    /// Turns user input like "https://www.Reddit.com/r/swift" into "reddit.com".
    static func normalize(_ input: String) -> String? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = value.range(of: "://") {
            value = String(value[range.upperBound...])
        }
        if let end = value.firstIndex(where: { "/?#:".contains($0) }) {
            value = String(value[..<end])
        }
        if value.hasPrefix("www.") {
            value = String(value.dropFirst(4))
        }
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !value.isEmpty, value.contains("."), !value.contains(" ") else { return nil }
        return value
    }

    /// True when `host` is a blocked domain or any subdomain of one.
    static func isBlocked(host: String, blockedDomains: Set<String>) -> Bool {
        var candidate = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        while !candidate.isEmpty {
            if blockedDomains.contains(candidate) { return true }
            guard let dot = candidate.firstIndex(of: ".") else { return false }
            candidate = String(candidate[candidate.index(after: dot)...])
        }
        return false
    }
}

/// Encodes the blocklist into `NEFilterProviderConfiguration.vendorConfiguration`.
///
/// The filter runs as a root system extension, so it can't read the user's defaults;
/// the provider configuration is the channel the system hands to it.
enum FilterVendorConfiguration {
    static let blockedDomainsKey = "blockedDomains"

    static func make(blockedDomains: Set<String>) -> [String: Any] {
        [blockedDomainsKey: blockedDomains.sorted()]
    }

    static func blockedDomains(from vendorConfiguration: [String: Any]?) -> Set<String> {
        let domains = vendorConfiguration?[blockedDomainsKey] as? [String] ?? []
        return Set(domains.map { $0.lowercased() })
    }
}
