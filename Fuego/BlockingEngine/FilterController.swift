import AppKit
import Combine
import Foundation
import NetworkExtension
import SystemExtensions
import os

/// Installs the content filter system extension and keeps its configuration in sync.
@MainActor
final class FilterController: ObservableObject {
    enum Status: Equatable {
        case checking
        /// The extension isn't installed or the filter isn't configured yet.
        case needsSetup
        /// macOS is waiting for the user to allow the extension in System Settings.
        case awaitingApproval
        /// Installed and configured, but switched off in System Settings.
        case disabled
        case ready
        case failed(String)

        var label: String {
            switch self {
            case .checking: return "checking…"
            case .needsSetup: return "not set up"
            case .awaitingApproval: return "waiting for approval"
            case .disabled: return "turned off in system settings"
            case .ready: return "ready"
            case .failed(let message): return message
            }
        }
    }

    static let extensionIdentifier = "dev.getfuego.FuegoFocus.FuegoContentFilter"

    @Published private(set) var status: Status = .checking

    private let logger = Logger(subsystem: "dev.getfuego.FuegoFocus", category: "filter")
    private var pendingActivation: SystemExtensionRequest?
    private var configurationObserver: NSObjectProtocol?

    init() {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .NEFilterConfigurationDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refreshStatus() }
        }
    }

    // MARK: - Setup

    /// Called at launch. Updates the extension if it was installed by an older build,
    /// without prompting anyone who hasn't set it up yet.
    func start() async {
        if await isExtensionInstalled() {
            logger.info("Extension installed; checking for an update")
            do {
                try await activateExtension()
            } catch {
                logger.error("Extension update failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        await refreshStatus()
        logger.info("Filter status: \(self.status.label, privacy: .public)")
    }

    /// Installs the system extension and the filter configuration, prompting the user as needed.
    func setUp() async throws {
        do {
            try await activateExtension()
            try await saveConfiguration(policy: .off, enable: true)
            await refreshStatus()
        } catch {
            logger.error("Setup failed: \(error.localizedDescription, privacy: .public)")
            let message = Self.describe(error)
            status = .failed(message)
            throw SetupError(message: "website blocking setup failed: \(message)")
        }
    }

    /// Hands a new policy to the filter. Requires setup to have completed.
    func apply(_ policy: FilterPolicy) async throws {
        try await saveConfiguration(policy: policy, enable: true)
        await refreshStatus()
    }

    func refreshStatus() async {
        if pendingActivation != nil {
            status = .awaitingApproval
            return
        }
        let manager = NEFilterManager.shared()
        do {
            try await manager.loadFromPreferences()
        } catch {
            status = .failed(Self.describe(error))
            return
        }
        if manager.providerConfiguration == nil {
            status = .needsSetup
        } else if !manager.isEnabled {
            status = .disabled
        } else if await isExtensionInstalled() {
            status = .ready
        } else {
            status = .needsSetup
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private func saveConfiguration(policy: FilterPolicy, enable: Bool) async throws {
        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()

        let configuration = manager.providerConfiguration ?? NEFilterProviderConfiguration()
        configuration.filterSockets = true
        configuration.filterPackets = false
        configuration.filterDataProviderBundleIdentifier = Self.extensionIdentifier
        configuration.vendorConfiguration = policy.vendorConfiguration

        manager.providerConfiguration = configuration
        manager.localizedDescription = "Fuego"
        if enable {
            manager.isEnabled = true
        }
        try await manager.saveToPreferences()
        logger.info("Saved filter configuration: \(policy.blockedDomains.count) domains")
    }

    private func activateExtension() async throws {
        if let pendingActivation {
            status = .awaitingApproval
            try await pendingActivation.wait()
            return
        }
        logger.info("Requesting extension activation")
        let request = SystemExtensionRequest.activation(
            identifier: Self.extensionIdentifier,
            onNeedsApproval: { [weak self] in
                self?.logger.info("Extension is waiting for user approval")
                self?.status = .awaitingApproval
                self?.openSystemSettings()
            })
        pendingActivation = request
        defer { pendingActivation = nil }
        try await request.wait()
        logger.info("Extension activated")
    }

    private func isExtensionInstalled() async -> Bool {
        let properties = (try? await SystemExtensionRequest.properties(identifier: Self.extensionIdentifier)) ?? []
        return properties.contains { $0.isEnabled && !$0.isAwaitingUserApproval && !$0.isUninstalling }
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == OSSystemExtensionErrorDomain,
            nsError.code == OSSystemExtensionError.unsupportedParentBundleLocation.rawValue
        {
            return "move Fuego to /Applications first"
        }
        if nsError.domain == NEFilterErrorDomain,
            nsError.code == NEFilterManagerError.configurationPermissionDenied.rawValue
        {
            return "filter permission was denied"
        }
        return error.localizedDescription.lowercased()
    }
}

struct SetupError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - OSSystemExtensionRequest wrapper

/// Bridges the delegate-based system extension API to async/await.
@MainActor
private final class SystemExtensionRequest: NSObject, OSSystemExtensionRequestDelegate {
    private let request: OSSystemExtensionRequest
    private let onNeedsApproval: () -> Void
    private var result: Result<[OSSystemExtensionProperties], Error>?
    private var waiters: [CheckedContinuation<[OSSystemExtensionProperties], Error>] = []

    private init(request: OSSystemExtensionRequest, onNeedsApproval: @escaping () -> Void) {
        self.request = request
        self.onNeedsApproval = onNeedsApproval
        super.init()
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    static func activation(identifier: String, onNeedsApproval: @escaping () -> Void) -> SystemExtensionRequest {
        SystemExtensionRequest(
            request: .activationRequest(forExtensionWithIdentifier: identifier, queue: .main),
            onNeedsApproval: onNeedsApproval)
    }

    static func properties(identifier: String) async throws -> [OSSystemExtensionProperties] {
        let request = SystemExtensionRequest(
            request: .propertiesRequest(forExtensionWithIdentifier: identifier, queue: .main),
            onNeedsApproval: {})
        return try await request.waitForProperties()
    }

    func wait() async throws {
        _ = try await waitForProperties()
    }

    private func waitForProperties() async throws -> [OSSystemExtensionProperties] {
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { waiters.append($0) }
    }

    private func finish(_ result: Result<[OSSystemExtensionProperties], Error>) {
        guard self.result == nil else { return }
        self.result = result
        waiters.forEach { $0.resume(with: result) }
        waiters.removeAll()
    }

    // The requests are created with `queue: .main`, so these callbacks arrive on the main thread.

    nonisolated func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        Logger(subsystem: "dev.getfuego.FuegoFocus", category: "filter").info(
            "Replacing extension \(existing.bundleShortVersion, privacy: .public) (\(existing.bundleVersion, privacy: .public)) with \(ext.bundleShortVersion, privacy: .public) (\(ext.bundleVersion, privacy: .public))"
        )
        return .replace
    }

    nonisolated func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        MainActor.assumeIsolated { onNeedsApproval() }
    }

    nonisolated func request(
        _ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result
    ) {
        MainActor.assumeIsolated { finish(.success([])) }
    }

    nonisolated func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        MainActor.assumeIsolated { finish(.failure(error)) }
    }

    nonisolated func request(
        _ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]
    ) {
        MainActor.assumeIsolated { finish(.success(properties)) }
    }
}
