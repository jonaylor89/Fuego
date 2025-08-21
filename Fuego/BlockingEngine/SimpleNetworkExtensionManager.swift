import AppKit
import Combine
import Foundation
import NetworkExtension
import os.log

/// Simplified Network Extension Manager that works with extensions in PlugIns location
class SimpleNetworkExtensionManager: NSObject, ObservableObject {
    private let logger = OSLog(
        subsystem: "dev.getfuego.FuegoFocus", category: "SimpleNetworkExtension")

    @Published var isExtensionEnabled = false
    @Published var extensionStatus: String = "Not Configured"
    @Published var statusMessage: String = "Extension not configured"
    @Published var isConfiguring: Bool = false

    // Network Extension Bundle Identifier
    private let extensionBundleIdentifier = "dev.getfuego.FuegoFocus.FuegoContentFilter"
    private let sharedStorage = SharedBlocklist()

    override init() {
        super.init()
        os_log("SimpleNetworkExtensionManager initialized", log: logger, type: .info)

        // Check initial status
        Task {
            await updateStatus()
        }
    }

    // MARK: - Public Interface

    /// Setup and activate the Network Extension
    func setupNetworkExtension() async throws {
        os_log("🚀 Setting up Network Extension", log: logger, type: .info)

        guard !isConfiguring else {
            os_log("Extension configuration already in progress", log: logger, type: .default)
            return
        }

        isConfiguring = true
        statusMessage = "Configuring extension..."

        defer {
            DispatchQueue.main.async {
                self.isConfiguring = false
            }
        }

        do {
            let manager = NEFilterManager.shared()

            // Load existing preferences
            os_log("Loading existing preferences...", log: logger, type: .info)
            try await manager.loadFromPreferences()

            // Create or update configuration
            if manager.providerConfiguration == nil {
                os_log("Creating new Network Extension configuration", log: logger, type: .info)

                let configuration = NEFilterProviderConfiguration()
                configuration.username = "Fuego User"
                configuration.organization = "Fuego Focus App"
                configuration.filterSockets = true
                configuration.filterPackets = false
                configuration.filterDataProviderBundleIdentifier = extensionBundleIdentifier
                configuration.vendorConfiguration = [:]

                manager.providerConfiguration = configuration
                manager.localizedDescription = "Fuego Content Filter"

                os_log(
                    "Created configuration with bundle ID: %{public}@", log: logger, type: .info,
                    extensionBundleIdentifier)
            } else {
                os_log("Using existing configuration", log: logger, type: .info)
            }

            // Enable the extension
            manager.isEnabled = true

            // Save configuration
            os_log("Saving Network Extension configuration...", log: logger, type: .info)
            try await manager.saveToPreferences()

            // Update status
            await updateStatus()

            os_log("✅ Network Extension setup completed successfully", log: logger, type: .info)

        } catch {
            os_log(
                "❌ Failed to setup Network Extension: %{public}@", log: logger, type: .error,
                error.localizedDescription)

            DispatchQueue.main.async {
                self.extensionStatus = "Error"
                self.statusMessage = "Setup failed: \(error.localizedDescription)"
            }

            throw error
        }
    }

    /// Enable the Network Extension
    func enableExtension() async throws {
        os_log("Enabling Network Extension", log: logger, type: .info)

        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()

        guard manager.providerConfiguration != nil else {
            throw NetworkExtensionError.extensionNotAvailable
        }

        manager.isEnabled = true
        try await manager.saveToPreferences()

        // Update shared storage
        sharedStorage.isFilteringEnabled = true

        await updateStatus()

        os_log("✅ Network Extension enabled", log: logger, type: .info)
    }

    /// Disable the Network Extension
    func disableExtension() async throws {
        os_log("Disabling Network Extension", log: logger, type: .info)

        let manager = NEFilterManager.shared()
        try await manager.loadFromPreferences()

        manager.isEnabled = false
        try await manager.saveToPreferences()

        // Update shared storage
        sharedStorage.isFilteringEnabled = false

        await updateStatus()

        os_log("✅ Network Extension disabled", log: logger, type: .info)
    }

    /// Update the blocklist for filtering
    func updateBlocklist(_ domains: Set<String>) {
        os_log("Updating blocklist with %d domains", log: logger, type: .info, domains.count)

        sharedStorage.updateBlocklist(domains, enabled: isExtensionEnabled)
    }

    /// Check and update the current status of the Network Extension
    @MainActor
    func updateStatus() async {
        os_log("Updating Network Extension status...", log: logger, type: .info)

        do {
            let manager = NEFilterManager.shared()
            try await manager.loadFromPreferences()

            isExtensionEnabled = manager.isEnabled

            if manager.providerConfiguration == nil {
                extensionStatus = "Not Configured"
                statusMessage = "Extension needs configuration"
                os_log("Status: Not Configured", log: logger, type: .info)
            } else if manager.isEnabled {
                extensionStatus = "Active"
                statusMessage = "Extension is active and filtering"
                os_log("Status: Active", log: logger, type: .info)

                if let bundleId = manager.providerConfiguration?.filterDataProviderBundleIdentifier
                {
                    os_log("Bundle ID: %{public}@", log: logger, type: .info, bundleId)
                }
            } else {
                extensionStatus = "Disabled"
                statusMessage = "Extension is configured but disabled"
                os_log("Status: Disabled", log: logger, type: .info)
            }

        } catch {
            extensionStatus = "Error"
            statusMessage = "Error: \(error.localizedDescription)"
            os_log(
                "Failed to update status: %{public}@", log: logger, type: .error,
                error.localizedDescription)
        }
    }

    /// Complete setup with user guidance
    func setupWithUserGuidance() async throws {
        os_log(
            "=== Starting Network Extension setup with user guidance ===", log: logger, type: .info)

        do {
            // Step 1: Setup the extension
            try await setupNetworkExtension()

            // Step 2: Show user guidance
            await showSetupGuidance()

            os_log("=== Setup process completed ===", log: logger, type: .info)

        } catch {
            os_log(
                "=== Setup failed: %{public}@ ===", log: logger, type: .error,
                error.localizedDescription)
            await showErrorGuidance(error)
            throw error
        }
    }

    // MARK: - Private Helper Methods

    @MainActor
    private func showSetupGuidance() {
        let alert = NSAlert()
        alert.messageText = "Network Extension Setup Complete"
        alert.informativeText = """
            Fuego has configured the Network Extension for content filtering.

            To enable the extension:
            1. Go to System Settings → General → Login Items & Extensions
            2. Find "Network Extensions" section
            3. Enable "Fuego Content Filter"
            4. Return to Fuego to start filtering

            The extension may take a moment to appear in System Settings.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemSettings()
        }
    }

    @MainActor
    private func showErrorGuidance(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Network Extension Setup Failed"
        alert.informativeText = """
            Error: \(error.localizedDescription)

            Common solutions:
            • Make sure Fuego has necessary permissions
            • Try restarting the app
            • Check System Settings → Privacy & Security for approval requests
            • Restart your Mac if the issue persists

            The app will continue to work with basic website blocking.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            openSystemSettings()
        }
    }

    private func openSystemSettings() {
        // Try to open Network Extensions settings directly
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            // Fallback to Privacy & Security
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Status Properties

    var statusDescription: String {
        switch extensionStatus {
        case "Active":
            return "🟢 Network filtering active"
        case "Disabled":
            return "🟡 Extension configured, needs enabling"
        case "Not Configured":
            return "⚪ Extension needs setup"
        case "Error":
            return "❌ Extension error"
        default:
            return "⚪ \(extensionStatus)"
        }
    }

    var detailedStatus: [String: Any] {
        return [
            "extensionEnabled": isExtensionEnabled,
            "extensionStatus": extensionStatus,
            "statusMessage": statusMessage,
            "isConfiguring": isConfiguring,
            "bundleIdentifier": extensionBundleIdentifier,
        ]
    }
}
