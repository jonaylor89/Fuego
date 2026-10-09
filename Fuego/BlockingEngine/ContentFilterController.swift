import AppKit
import Combine
import Foundation
import Logging
import NetworkExtension
import SystemExtensions

enum FilterStatus: Equatable {
    case unknown
    case notInstalled
    case awaitingApproval
    case ready
    case filtering
    case error(String)

    var label: String {
        switch self {
        case .unknown: return "checking…"
        case .notInstalled: return "not set up"
        case .awaitingApproval: return "needs approval"
        case .ready: return "ready"
        case .filtering: return "blocking"
        case .error: return "error"
        }
    }

    var needsSetup: Bool {
        switch self {
        case .notInstalled, .awaitingApproval, .error: return true
        case .unknown, .ready, .filtering: return false
        }
    }
}

/// Controls the content filter used for website blocking.
@MainActor
protocol ContentFilterControlling: AnyObject {
    var status: FilterStatus { get }
    var statusPublisher: AnyPublisher<FilterStatus, Never> { get }

    /// Installs the system extension (prompting the user if needed) and registers the filter.
    func install() async throws
    func startFiltering(blockedDomains: Set<String>) async throws
    func stopFiltering() async throws
    func refreshStatus() async
}

/// Installs `FuegoContentFilter` as a system extension and drives it via `NEFilterManager`.
@MainActor
final class ContentFilterController: NSObject, ContentFilterControlling {
    static let extensionBundleIdentifier = "dev.getfuego.FuegoFocus.FuegoContentFilter"

    private let logger = Logger(label: "dev.getfuego.contentfilter")
    private let manager = NEFilterManager.shared()
    private var activationContinuation: CheckedContinuation<Void, Error>?

    @Published private(set) var status: FilterStatus = .unknown
    var statusPublisher: AnyPublisher<FilterStatus, Never> { $status.eraseToAnyPublisher() }

    func install() async throws {
        do {
            try await activateSystemExtension()
            try await manager.loadFromPreferences()
            configureIfNeeded()
            try await manager.saveToPreferences()
            await refreshStatus()
        } catch {
            logger.error("Content filter install failed: \(error.localizedDescription)")
            status = .error(error.localizedDescription)
            throw error
        }
    }

    func startFiltering(blockedDomains: Set<String>) async throws {
        try await manager.loadFromPreferences()
        if manager.providerConfiguration == nil {
            try await install()
        }
        configureIfNeeded()
        manager.providerConfiguration?.vendorConfiguration =
            FilterVendorConfiguration.make(blockedDomains: blockedDomains)
        manager.isEnabled = true
        try await manager.saveToPreferences()
        await refreshStatus()
    }

    func stopFiltering() async throws {
        try await manager.loadFromPreferences()
        guard manager.providerConfiguration != nil, manager.isEnabled else {
            await refreshStatus()
            return
        }
        manager.isEnabled = false
        try await manager.saveToPreferences()
        await refreshStatus()
    }

    func refreshStatus() async {
        do {
            try await manager.loadFromPreferences()
            if manager.providerConfiguration == nil {
                status = .notInstalled
            } else {
                status = manager.isEnabled ? .filtering : .ready
            }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func configureIfNeeded() {
        guard manager.providerConfiguration == nil else { return }
        let configuration = NEFilterProviderConfiguration()
        configuration.filterSockets = true
        configuration.filterPackets = false
        configuration.filterDataProviderBundleIdentifier = Self.extensionBundleIdentifier
        manager.providerConfiguration = configuration
        manager.localizedDescription = "Fuego"
        manager.isEnabled = false
    }

    private func activateSystemExtension() async throws {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: Self.extensionBundleIdentifier, queue: .main)
        request.delegate = self
        try await withCheckedThrowingContinuation { continuation in
            activationContinuation = continuation
            OSSystemExtensionManager.shared.submitRequest(request)
        }
    }

    private func finishActivation(_ result: Result<Void, Error>) {
        activationContinuation?.resume(with: result)
        activationContinuation = nil
    }
}

extension ContentFilterController: OSSystemExtensionRequestDelegate {
    nonisolated func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    nonisolated func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        MainActor.assumeIsolated {
            logger.info("System extension is waiting for user approval")
            status = .awaitingApproval
            openSystemSettings()
        }
    }

    nonisolated func request(
        _ request: OSSystemExtensionRequest,
        didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        MainActor.assumeIsolated {
            logger.info("System extension activation finished: \(result.rawValue)")
            finishActivation(.success(()))
        }
    }

    nonisolated func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            finishActivation(.failure(error))
        }
    }
}
