import Foundation
import Network
import NetworkExtension
import os

/// Content filter that drops connections to blocked domains during a focus session.
///
/// The blocklist arrives in `filterConfiguration.vendorConfiguration` (see `FilterPolicy`);
/// the system updates that property whenever the app saves a new configuration.
final class FilterProvider: NEFilterDataProvider {
    private let logger = Logger(subsystem: "dev.getfuego.FuegoFocus.FuegoContentFilter", category: "filter")
    private let state = OSAllocatedUnfairLock(initialState: (policy: FilterPolicy.off, loadedAt: Date.distantPast))
    private var configurationObservation: NSKeyValueObservation?

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        reloadPolicy()
        configurationObservation = observe(\.filterConfiguration, options: [.new]) { provider, _ in
            provider.reloadPolicy()
        }

        // Send every flow to handleNewFlow; it decides cheaply and allows most of them.
        let settings = NEFilterSettings(rules: [], defaultAction: .filterData)
        apply(settings) { [logger] error in
            if let error {
                logger.error("Failed to apply filter settings: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("Filter started")
            }
            completionHandler(error)
        }
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Filter stopped, reason \(reason.rawValue)")
        configurationObservation = nil
        completionHandler()
    }

    @discardableResult
    private func reloadPolicy() -> FilterPolicy {
        let newPolicy = FilterPolicy(vendorConfiguration: filterConfiguration.vendorConfiguration)
        let oldPolicy = state.withLock { state in
            defer { state = (newPolicy, Date()) }
            return state.policy
        }
        if newPolicy != oldPolicy {
            logger.info(
                "Policy updated: \(newPolicy.blockedDomains.count) domains, until \(newPolicy.blockUntil?.description ?? "off", privacy: .public)"
            )
        }
        return newPolicy
    }

    /// The configuration observer doesn't fire for updates that land while the filter is
    /// starting, so re-read the configuration every couple of seconds as well.
    private var currentPolicy: FilterPolicy {
        let (policy, loadedAt) = state.withLock { $0 }
        return Date().timeIntervalSince(loadedAt) > 2 ? reloadPolicy() : policy
    }

    // MARK: - Flow handling

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let policy = currentPolicy
        guard policy.isActive(), let socketFlow = flow as? NEFilterSocketFlow else {
            return .allow()
        }

        if let host = hostname(of: socketFlow) {
            if policy.blocks(host: host) {
                logger.info("Blocked \(host, privacy: .public)")
                return .drop()
            }
            return .allow()
        }

        // The app connected by IP address, as Chrome and Firefox do. Read the hostname
        // from the first outbound bytes instead.
        switch socketFlow.socketProtocol {
        case IPPROTO_TCP:
            return .filterDataVerdict(
                withFilterInbound: false, peekInboundBytes: 0,
                filterOutbound: true, peekOutboundBytes: HostSniffer.maxPeekBytes)
        case IPPROTO_UDP where remotePort(of: socketFlow) == 443:
            // QUIC encrypts its handshake, so there's no hostname to read. Dropping it makes
            // browsers fall back to TCP, where the TLS hostname is visible.
            return .drop()
        default:
            return .allow()
        }
    }

    override func handleOutboundData(
        from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data
    ) -> NEFilterDataVerdict {
        switch HostSniffer.sniff(readBytes) {
        case .host(let host):
            if currentPolicy.blocks(host: host) {
                logger.info("Blocked \(host, privacy: .public) (from handshake)")
                return .drop()
            }
            return .allow()
        case .needBytes(let count) where count > readBytes.count:
            return NEFilterDataVerdict(passBytes: 0, peekBytes: count)
        case .needBytes, .unknown:
            return .allow()
        }
    }

    override func handleInboundData(
        from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data
    ) -> NEFilterDataVerdict {
        .allow()
    }

    // MARK: - Helpers

    private func hostname(of flow: NEFilterSocketFlow) -> String? {
        if let host = flow.remoteHostname, !host.isEmpty, IPv4Address(host) == nil, IPv6Address(host) == nil {
            return host
        }
        if let host = flow.url?.host, !host.isEmpty {
            return host
        }
        return nil
    }

    private func remotePort(of flow: NEFilterSocketFlow) -> UInt16? {
        if case .hostPort(_, let port) = flow.remoteFlowEndpoint {
            return port.rawValue
        }
        return nil
    }
}
