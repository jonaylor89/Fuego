import AppKit
import Combine
import Foundation
import Logging
import NetworkExtension

// MARK: - Extension Manager for Main App

/// Manages the Network Extension from the main app
@MainActor
class NetworkExtensionManager: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.blocking.extensionmanager")
    private let sharedStorage = SharedBlocklist()

    @Published var isExtensionEnabled = false
    @Published var extensionStatus: String = "Unknown"

    func setupExtension() async throws {
        logger.info("Setting up network extension")

        let manager = NEFilterManager.shared()

        try await manager.loadFromPreferences()

        if manager.providerConfiguration == nil {
            // Create new configuration
            let configuration = NEFilterProviderConfiguration()
            configuration.username = "Fuego User"
            configuration.organization = "Fuego Focus App"
            configuration.filterSockets = true
            configuration.filterPackets = false  // Only filter at socket level
            configuration.vendorConfiguration = [:]

            manager.providerConfiguration = configuration
            manager.localizedDescription = "Fuego Content Filter"
            manager.isEnabled = true

            try await manager.saveToPreferences()
            logger.info("Network extension configuration saved")

            // Wait a moment for the system to process the configuration
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }

        await updateStatus()
    }

    func enableExtension() async throws {
        logger.info("Enabling network extension")

        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()

        if manager.providerConfiguration == nil {
            throw NetworkExtensionError.extensionNotAvailable
        }

        manager.isEnabled = true
        try await manager.saveToPreferences()

        // Update shared storage
        let currentDomains = sharedStorage.blockedDomains
        sharedStorage.updateBlocklist(currentDomains, enabled: true)

        await updateStatus()

        // Log configuration details for debugging
        logger.info(
            "Extension enabled - Bundle ID: \(manager.providerConfiguration?.filterDataProviderBundleIdentifier ?? "Unknown")"
        )
    }

    func disableExtension() async throws {
        logger.info("Disabling network extension")

        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()

        manager.isEnabled = false
        try await manager.saveToPreferences()

        // Update shared storage
        sharedStorage.isFilteringEnabled = false

        await updateStatus()
    }

    func updateBlocklist(_ domains: Set<String>) {
        logger.info("Updating blocklist with \(domains.count) domains")
        sharedStorage.updateBlocklist(domains, enabled: isExtensionEnabled)
    }

    func updateStatus() async {
        let manager = NEFilterManager.shared()

        do {
            try await manager.loadFromPreferences()
            isExtensionEnabled = manager.isEnabled

            if manager.providerConfiguration == nil {
                extensionStatus = "Not Configured"
            } else if manager.isEnabled {
                extensionStatus = "Active"
            } else {
                extensionStatus = "Disabled"
            }
        } catch {
            extensionStatus = "Error: \(error.localizedDescription)"
            logger.error("Failed to update extension status: \(error)")
        }
    }

    func requestPermissions() async throws {
        logger.info("Requesting network extension permissions")

        do {
            // This will trigger the system dialog for Network Extension permissions
            try await setupExtension()
            try await enableExtension()

            // Force a status update
            await updateStatus()

            logger.info("Network extension setup completed successfully")
        } catch {
            logger.error("Failed to set up network extension: \(error)")
            throw error
        }
    }
}

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

/// Enhanced blocking engine that uses Network Extension for robust content filtering
@MainActor
class NetworkExtensionBlockingEngine: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.blocking.networkextension")

    @Published var isActive: Bool = false
    @Published var currentBlockedWebsites: Set<String> = []
    @Published var extensionStatus: String = "Unknown"

    private var networkExtensionManager: NetworkExtensionManager
    private var appBlockingManager: AppBlockingManager

    init() {
        self.networkExtensionManager = NetworkExtensionManager()
        self.appBlockingManager = AppBlockingManager()

        // Observe extension status changes
        networkExtensionManager.$extensionStatus
            .assign(to: &$extensionStatus)

        networkExtensionManager.$isExtensionEnabled
            .assign(to: &$isActive)

        logger.info("Network Extension blocking engine initialized")
    }

    // MARK: - Public Interface

    /// Apply blocking rules using Network Extension
    func applyRules(_ blockedWebsites: Set<String>, _ blockedApplications: Set<String>) async throws
    {
        logger.info("Applying blocking rules via Network Extension")

        do {
            // Always check status first
            await networkExtensionManager.updateStatus()

            // Ensure Network Extension is set up and enabled
            if !networkExtensionManager.isExtensionEnabled {
                logger.info("Extension not enabled, requesting permissions")
                try await networkExtensionManager.requestPermissions()
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
        try await networkExtensionManager.requestPermissions()
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
                    Fuego needs to set up a Network Extension for website blocking.

                    After clicking "Open Settings":
                    1. Go to System Settings → General → Login Items & Extensions
                    2. Look for "Network Extensions" section
                    3. Enable "Fuego Content Filter" if it appears
                    4. Return to Fuego and try again

                    Note: The extension may take a moment to appear in System Settings.
                    """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Open System Settings to Login Items & Extensions
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
        switch extensionStatus {
        case "Active":
            return isActive ? "🟢 Network blocking active" : "🟡 Extension enabled, filtering paused"
        case "Disabled":
            return "🔴 Network extension disabled"
        case "Not Configured":
            return "⚪ Extension not configured"
        default:
            return "⚪ \(extensionStatus)"
        }
    }

    /// Get detailed status information for debugging
    var detailedStatus: [String: Any] {
        return [
            "extensionEnabled": networkExtensionManager.isExtensionEnabled,
            "filteringActive": isActive,
            "blockedDomainsCount": currentBlockedWebsites.count,
            "extensionStatus": extensionStatus,
        ]
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
