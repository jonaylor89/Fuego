import AppKit
import Combine
import Foundation
import Logging
import NetworkExtension

// MARK: - Shared Storage Helper

/// Shared storage mechanism for communicating blocklist between main app and extension
class SharedBlocklist {
    private let logger = Logger(label: "dev.getfuego.blocking.sharedblocklist")
    private let userDefaults = UserDefaults(suiteName: "group.dev.getfuego.FuegoFocus")

    // MARK: - Storage Keys
    private enum StorageKeys {
        static let blockedDomains = "blockedDomains"
        static let isFilteringEnabled = "isFilteringEnabled"
        static let lastUpdated = "lastUpdated"
    }

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
            logger.info("Updated blocked domains: \(newValue.count) domains")
        }
    }

    var isFilteringEnabled: Bool {
        get {
            return userDefaults?.bool(forKey: StorageKeys.isFilteringEnabled) ?? false
        }
        set {
            userDefaults?.set(newValue, forKey: StorageKeys.isFilteringEnabled)
            userDefaults?.set(Date(), forKey: StorageKeys.lastUpdated)
            logger.info("Filtering enabled: \(newValue)")
        }
    }

    // MARK: - Public Methods

    func updateBlocklist(_ domains: Set<String>, enabled: Bool) {
        blockedDomains = domains
        isFilteringEnabled = enabled
        logger.info("Updated blocklist with \(domains.count) domains, enabled: \(enabled)")
    }
}

/// Enhanced blocking engine that uses System Extension + Network Extension for robust content filtering
@MainActor
class NetworkExtensionBlockingEngine: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.blocking.networkextension")

    @Published var isActive: Bool = false
    @Published var currentBlockedWebsites: Set<String> = []
    @Published var extensionStatus: String = "Unknown"

    private var networkExtensionManager: SimpleNetworkExtensionManager
    private var appBlockingManager: AppBlockingManager
    private let sharedStorage = SharedBlocklist()

    init() {
        self.networkExtensionManager = SimpleNetworkExtensionManager()
        self.appBlockingManager = AppBlockingManager()

        // Observe network extension status changes
        networkExtensionManager.$statusMessage
            .assign(to: &$extensionStatus)

        networkExtensionManager.$isExtensionEnabled
            .assign(to: &$isActive)

        logger.info("Network Extension blocking engine initialized with simplified approach")
    }

    // MARK: - Public Interface

    /// Apply blocking rules using Network Extension
    func applyRules(_ blockedWebsites: Set<String>, _ blockedApplications: Set<String>) async throws
    {
        logger.info("Applying blocking rules via Network Extension")

        do {
            // Check network extension status first
            await networkExtensionManager.updateStatus()

            // Ensure Network Extension is configured
            if networkExtensionManager.extensionStatus == "Not Configured" {
                logger.info("Network Extension not configured, setting up")
                try await networkExtensionManager.setupNetworkExtension()
            }

            // Update the blocklist in shared storage
            networkExtensionManager.updateBlocklist(blockedWebsites)
            currentBlockedWebsites = blockedWebsites

            // Apply app blocking (still using traditional method)
            try await appBlockingManager.applyRules(blockedApplications)

            isActive = true
            logger.info("Network Extension blocking rules applied successfully")

        } catch {
            logger.error("Failed to apply Network Extension blocking rules: \(error)")

            // Show user-friendly error message
            await showPermissionErrorIfNeeded(error)
            throw error
        }
    }

    /// Disable all blocking
    func disable() async {
        logger.info("Disabling Network Extension blocking")

        do {
            // Disable the Network Extension
            try await networkExtensionManager.disableExtension()

            // Disable app blocking
            await appBlockingManager.disableBlocking()

            isActive = false
            currentBlockedWebsites.removeAll()
            logger.info("Network Extension blocking disabled")

        } catch {
            logger.error("Failed to disable Network Extension: \(error)")
        }
    }

    /// Clean up when app terminates
    func cleanup() async {
        logger.info("Cleaning up Network Extension blocking engine")
        await disable()
    }

    /// Check if the Network Extension is properly configured
    func checkExtensionStatus() async {
        await networkExtensionManager.updateStatus()
    }

    /// Request initial setup of Network Extension
    func requestInitialSetup() async throws {
        logger.info("Requesting initial Network Extension setup")
        try await networkExtensionManager.setupWithUserGuidance()
    }

    /// Get the network extension manager for UI binding
    var networkExtension: SimpleNetworkExtensionManager {
        return networkExtensionManager
    }

    // MARK: - Private Methods

    private func showPermissionErrorIfNeeded(_ error: Error) async {
        // Check if this is a permission-related error
        if let nsError = error as NSError? {
            if nsError.domain == NEVPNErrorDomain
                || nsError.code == NEVPNError.configurationInvalid.rawValue
            {
                let alert = NSAlert()
                alert.messageText = "Network Extension Setup Required"
                alert.informativeText = """
                    Fuego needs to configure a Network Extension for website blocking.

                    Steps:
                    1. Click "Setup Network Extension" in the app
                    2. Enable the extension in System Settings → General → Login Items & Extensions → Network Extensions
                    3. Look for "Fuego Content Filter" and enable it
                    4. Return to Fuego to start filtering

                    The network extension provides robust content filtering.
                    """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Open System Settings to Network Extensions
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
                    {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}

// MARK: - Network Extension Status Extension

extension NetworkExtensionBlockingEngine {

    /// Get a user-friendly description of the current status
    var statusDescription: String {
        return networkExtensionManager.statusDescription
    }

    /// Get detailed status information for debugging
    var detailedStatus: [String: Any] {
        var status = networkExtensionManager.detailedStatus
        status["filteringActive"] = isActive
        status["blockedDomainsCount"] = currentBlockedWebsites.count
        return status
    }
}

// MARK: - Error Types

enum NetworkExtensionError: LocalizedError {
    case extensionNotAvailable
    case permissionDenied
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .extensionNotAvailable:
            return "Network Extension framework is not available"
        case .permissionDenied:
            return "Permission denied to configure Network Extension"
        case .configurationFailed:
            return "Failed to configure Network Extension"
        }
    }
}
