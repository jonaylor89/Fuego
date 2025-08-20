import AppKit
import Combine
import Foundation
import Logging
import NetworkExtension
import Security

/// Manages website and application blocking functionality
@MainActor
class BlockingEngine: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.blocking")

    @Published var isActive: Bool = false
    @Published var currentBlockedWebsites: Set<String> = []

    private var filterManager: NEFilterManager?
    private var localServer: LocalBlockingServer
    private var appBlockingManager: AppBlockingManager

    init() {
        self.localServer = LocalBlockingServer()
        self.appBlockingManager = AppBlockingManager()
        setupNetworkExtension()
    }

    // MARK: - Public Interface

    /// Apply blocking rules to start filtering
    func applyRules(_ blockedWebsites: Set<String>, _ blockedApplications: Set<String>) async throws
    {
        logger.info("Applying blocking rules")

        do {
            // Apply website blocking
            try await applyWebsiteBlocking(blockedWebsites)

            // Apply app blocking
            try await appBlockingManager.applyRules(blockedApplications)

            isActive = true
            logger.info("Blocking rules applied successfully")
        } catch {
            logger.error("Failed to apply blocking rules: \(error)")

            // Show user-friendly error message if permission denied
            if error is BlockingError || (error as NSError).code == 513 {
                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = "Administrator Access Required"
                    alert.informativeText =
                        "Fuego needs administrator access to block websites by modifying the hosts file. Please enter your password when prompted."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }

            throw error
        }
    }

    /// Disable all blocking
    func disable() async {
        logger.info("Disabling blocking")

        localServer.stop()
        await appBlockingManager.disableBlocking()

        if let filterManager = filterManager {
            filterManager.removeFromPreferences { error in
                if let error = error {
                    self.logger.error("Failed to remove filter: \(error)")
                }
            }
        }

        isActive = false
        logger.info("Blocking disabled")
    }

    /// Clean up hosts file when app terminates
    func cleanup() async {
        logger.info("Cleaning up blocking engine")
        localServer.stop()
        await restoreHostsFileOnExit()
    }

    private func restoreHostsFileOnExit() async {
        let backupPath = "/tmp/fuego_hosts_backup"

        guard FileManager.default.fileExists(atPath: backupPath) else {
            logger.info("No hosts backup found, nothing to restore")
            return
        }

        do {
            let script = """
                do shell script "cp '\(backupPath)' /etc/hosts" without altering line endings
                """

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]

            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                try FileManager.default.removeItem(atPath: backupPath)
                logger.info("Hosts file restored on app exit")
            }
        } catch {
            logger.error("Failed to restore hosts file on exit: \(error)")
        }
    }

    /// Check if a URL should be blocked
    func shouldBlockURL(_ url: URL) -> Bool {
        guard isActive else { return false }

        let host = url.host?.lowercased() ?? ""

        // Check blocked websites
        return currentBlockedWebsites.contains(host)
    }

    // MARK: - Private Methods

    private func setupNetworkExtension() {
        NEFilterManager.shared().loadFromPreferences { error in
            if let error = error {
                self.logger.error("Failed to load filter preferences: \(error)")
            } else {
                self.filterManager = NEFilterManager.shared()
            }
        }
    }

    private func applyWebsiteBlocking(_ blockedWebsites: Set<String>) async throws {
        currentBlockedWebsites = blockedWebsites

        if !blockedWebsites.isEmpty {
            // Start local server to serve stoic quotes
            try await localServer.start()

            // Set up one-time hosts file redirect to localhost (requires admin once)
            try await setupInitialHostsRedirect(for: Array(blockedWebsites))
        }
    }

    private func setupInitialHostsRedirect(for domains: [String]) async throws {
        // Only modify hosts file once per app session, not every focus session
        let hostsPath = "/etc/hosts"
        let backupPath = "/tmp/fuego_hosts_backup"

        // Check if we already have our entries
        let currentContent = try String(contentsOfFile: hostsPath)
        if currentContent.contains("# Fuego Focus App") {
            logger.info("Hosts file already configured for Fuego")
            return
        }

        // Backup original hosts file
        try currentContent.write(toFile: backupPath, atomically: true, encoding: .utf8)

        // Add entries to redirect to localhost:8080
        var newContent = currentContent
        newContent += "\n# Fuego Focus App - START\n"

        for domain in domains {
            newContent += "127.0.0.1 \(domain)\n"
            newContent += "127.0.0.1 www.\(domain)\n"
        }

        newContent += "# Fuego Focus App - END\n"

        // Write with admin privileges (one-time setup)
        try await writeHostsFileOneTime(content: newContent)
        logger.info("Hosts file configured to redirect \(domains.count) domains to local server")
    }

    private func writeHostsFileOneTime(content: String) async throws {
        let tempPath = "/tmp/fuego_new_hosts"
        try content.write(toFile: tempPath, atomically: true, encoding: .utf8)

        let script = """
            do shell script "cp '\(tempPath)' /etc/hosts" with administrator privileges
            """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        try task.run()
        task.waitUntilExit()

        try? FileManager.default.removeItem(atPath: tempPath)

        if task.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("Failed to write hosts file: \(error)")
            throw BlockingError.hostsFileWriteError
        }
    }

    // Network extension filtering removed for simplicity
}

// MARK: - App Blocking Management

class AppBlockingManager {
    private let logger = Logger(label: "dev.getfuego.appblocking")
    private var monitoredApps: Set<String> = []
    private var isBlocking = false

    func applyRules(_ blockedApplications: Set<String>) async throws {
        logger.info("Applying app blocking rules")

        monitoredApps = blockedApplications
        isBlocking = true

        // Start monitoring running applications
        startAppMonitoring()

        // Kill currently running blocked apps
        await terminateBlockedApps(blockedApplications)
    }

    func disableBlocking() async {
        logger.info("Disabling app blocking")
        isBlocking = false
        monitoredApps.removeAll()
        stopAppMonitoring()
    }

    private func startAppMonitoring() {
        // Monitor for app launches using NSWorkspace notifications
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, self.isBlocking else { return }

            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
                let appName = app.localizedName
            {

                if self.monitoredApps.contains(appName) {
                    self.logger.info("Terminating blocked app: \(appName)")
                    app.terminate()
                }
            }
        }
    }

    private func stopAppMonitoring() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
    }

    private func terminateBlockedApps(_ blockedApps: Set<String>) async {
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            if let appName = app.localizedName,
                blockedApps.contains(appName)
            {
                logger.info("Terminating running blocked app: \(appName)")
                app.terminate()
            }
        }
    }
}

// MARK: - Error Types

enum BlockingError: LocalizedError {
    case networkExtensionNotAvailable
    case insufficientPrivileges
    case hostsFileWriteError

    var errorDescription: String? {
        switch self {
        case .networkExtensionNotAvailable:
            return "Network Extension is not available"
        case .insufficientPrivileges:
            return "Insufficient privileges to modify system files"
        case .hostsFileWriteError:
            return "Failed to write to hosts file"
        }
    }
}
