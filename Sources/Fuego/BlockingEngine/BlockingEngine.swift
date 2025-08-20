import Foundation
import NetworkExtension
import Combine
import Logging
import AppKit

/// Manages website and application blocking functionality
@MainActor
class BlockingEngine: ObservableObject {
    private let logger = Logger(label: "com.fuego.blocking")
    
    @Published var isActive: Bool = false
    @Published var currentBlockedWebsites: Set<String> = []
    
    private var filterManager: NEFilterManager?
    private var hostsFileManager: HostsFileManager
    private var appBlockingManager: AppBlockingManager
    
    init() {
        self.hostsFileManager = HostsFileManager()
        self.appBlockingManager = AppBlockingManager()
        setupNetworkExtension()
    }
    
    // MARK: - Public Interface
    
    /// Apply blocking rules to start filtering
    func applyRules(_ blockedWebsites: Set<String>, _ blockedApplications: Set<String>) async throws {
        logger.info("Applying blocking rules")
        
        // Apply website blocking
        try await applyWebsiteBlocking(blockedWebsites)
        
        // Apply app blocking
        try await appBlockingManager.applyRules(blockedApplications)
        
        isActive = true
        logger.info("Blocking rules applied successfully")
    }
    
    /// Disable all blocking
    func disable() async {
        logger.info("Disabling blocking")
        
        await hostsFileManager.restoreHostsFile()
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
            // Use hosts file for simple domain blocking
            try await hostsFileManager.blockDomains(Array(blockedWebsites))
        }
    }
    
    // Network extension filtering removed for simplicity
}

// MARK: - Hosts File Management

class HostsFileManager {
    private let logger = Logger(label: "com.fuego.hosts")
    private let hostsPath = "/etc/hosts"
    private let backupPath = "/tmp/fuego_hosts_backup"
    private let fuegoMarker = "# Fuego Focus App"
    
    func blockDomains(_ domains: [String]) async throws {
        logger.info("Blocking domains via hosts file: \(domains)")
        
        // Backup original hosts file
        try await backupHostsFile()
        
        // Read current hosts content
        let currentContent = try String(contentsOfFile: hostsPath)
        
        // Remove any existing Fuego entries
        let cleanedContent = removeExistingFuegoEntries(from: currentContent)
        
        // Add new blocking entries
        var newContent = cleanedContent
        newContent += "\n\(fuegoMarker) - START\n"
        
        for domain in domains {
            newContent += "0.0.0.0 \(domain)\n"
            newContent += "0.0.0.0 www.\(domain)\n"
        }
        
        newContent += "\(fuegoMarker) - END\n"
        
        // Write updated hosts file (requires admin privileges)
        try await writeHostsFile(content: newContent)
        
        logger.info("Successfully blocked \(domains.count) domains")
    }
    
    func restoreHostsFile() async {
        do {
            if FileManager.default.fileExists(atPath: backupPath) {
                let backupContent = try String(contentsOfFile: backupPath)
                try await writeHostsFile(content: backupContent)
                try FileManager.default.removeItem(atPath: backupPath)
                logger.info("Hosts file restored from backup")
            } else {
                // Remove only Fuego entries
                let currentContent = try String(contentsOfFile: hostsPath)
                let cleanedContent = removeExistingFuegoEntries(from: currentContent)
                try await writeHostsFile(content: cleanedContent)
                logger.info("Fuego entries removed from hosts file")
            }
        } catch {
            logger.error("Failed to restore hosts file: \(error)")
        }
    }
    
    private func backupHostsFile() async throws {
        let content = try String(contentsOfFile: hostsPath)
        try content.write(toFile: backupPath, atomically: true, encoding: .utf8)
    }
    
    private func writeHostsFile(content: String) async throws {
        // This requires admin privileges - would need to use AuthorizationServices
        // or have the user run the app with sudo (not recommended for production)
        try content.write(toFile: hostsPath, atomically: true, encoding: .utf8)
    }
    
    private func removeExistingFuegoEntries(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var filteredLines: [String] = []
        var inFuegoSection = false
        
        for line in lines {
            if line.contains("\(fuegoMarker) - START") {
                inFuegoSection = true
                continue
            }
            
            if line.contains("\(fuegoMarker) - END") {
                inFuegoSection = false
                continue
            }
            
            if !inFuegoSection {
                filteredLines.append(line)
            }
        }
        
        return filteredLines.joined(separator: "\n")
    }
}

// MARK: - App Blocking Management

class AppBlockingManager {
    private let logger = Logger(label: "com.fuego.appblocking")
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
            
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               let bundleIdentifier = app.bundleIdentifier {
                
                if self.monitoredApps.contains(bundleIdentifier) {
                    self.logger.info("Terminating blocked app: \(bundleIdentifier)")
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
            if let bundleIdentifier = app.bundleIdentifier,
               blockedApps.contains(bundleIdentifier) {
                logger.info("Terminating running blocked app: \(bundleIdentifier)")
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