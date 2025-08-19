import Foundation
import Combine
import Logging
import AppKit

/// Manages application settings and preferences
@MainActor
class SettingsManager: ObservableObject {
    private let logger = Logger(label: "com.fuego.settings")
    private let persistence: PersistenceManager
    
    @Published var settings: FuegoSettings
    
    init(persistence: PersistenceManager = PersistenceManager()) {
        self.persistence = persistence
        self.settings = persistence.fetchSettings()
        
        setupHotkeys()
        logger.info("Settings manager initialized")
    }
    
    // MARK: - Settings Management
    
    func saveSettings(_ newSettings: FuegoSettings) {
        let oldSettings = settings
        settings = newSettings
        
        do {
            try persistence.saveSettings(newSettings)
            logger.info("Settings saved")
            
            // Handle setting changes that require immediate action
            handleSettingsChanges(from: oldSettings, to: newSettings)
            
        } catch {
            logger.error("Failed to save settings: \(error)")
            // Revert settings on failure
            settings = oldSettings
        }
    }
    
    func resetToDefaults() {
        let defaultSettings = FuegoSettings()
        saveSettings(defaultSettings)
        logger.info("Settings reset to defaults")
    }
    
    // MARK: - Individual Setting Updates
    
    func updateLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        saveSettings(settings)
        
        // Configure launch at login
        configureLaunchAtLogin(enabled)
    }
    
    func updateGlobalHotkey(_ hotkey: String?, for action: HotkeyAction) {
        switch action {
        case .toggleSession:
            settings.globalHotkeys.toggleSession = hotkey
        case .instantWork:
            settings.globalHotkeys.instantWork = hotkey
        case .showDashboard:
            settings.globalHotkeys.showDashboard = hotkey
        }
        
        saveSettings(settings)
        setupHotkeys()
    }
    
    func updateNotificationSettings(_ notifications: NotificationSettings) {
        settings.notifications = notifications
        saveSettings(settings)
    }
    
    func updateSecuritySettings(_ security: SecuritySettings) {
        settings.security = security
        saveSettings(settings)
    }
    
    func updateAppearanceSettings(_ appearance: AppearanceSettings) {
        settings.appearance = appearance
        saveSettings(settings)
    }
    
    // MARK: - Security
    
    func setPassword(_ password: String) {
        settings.security.passwordProtected = true
        settings.security.passwordHash = hashPassword(password)
        saveSettings(settings)
        logger.info("Password protection enabled")
    }
    
    func removePassword() {
        settings.security.passwordProtected = false
        settings.security.passwordHash = nil
        settings.security.lockedModeEnabled = false
        settings.security.requirePasswordToQuit = false
        saveSettings(settings)
        logger.info("Password protection disabled")
    }
    
    func verifyPassword(_ password: String) -> Bool {
        guard settings.security.passwordProtected,
              let storedHash = settings.security.passwordHash else {
            return true // No password set
        }
        
        return hashPassword(password) == storedHash
    }
    
    private func hashPassword(_ password: String) -> String {
        // In production, use proper cryptographic hashing (e.g., bcrypt, Argon2)
        // This is a simple implementation for demonstration
        guard let data = password.data(using: .utf8) else { return "" }
        return data.base64EncodedString()
    }
    
    // MARK: - Launch at Login
    
    private func configureLaunchAtLogin(_ enabled: Bool) {
        // Implementation would use ServiceManagement framework
        // This is a simplified version
        
        if enabled {
            // Add to login items
            logger.info("Adding app to login items")
        } else {
            // Remove from login items
            logger.info("Removing app from login items")
        }
    }
    
    // MARK: - Global Hotkeys
    
    private func setupHotkeys() {
        // Implementation would use Carbon or other hotkey frameworks
        // This is a placeholder for the actual hotkey registration
        
        if let toggleHotkey = settings.globalHotkeys.toggleSession {
            registerHotkey(toggleHotkey, action: .toggleSession)
        }
        
        if let instantWorkHotkey = settings.globalHotkeys.instantWork {
            registerHotkey(instantWorkHotkey, action: .instantWork)
        }
        
        if let showDashboardHotkey = settings.globalHotkeys.showDashboard {
            registerHotkey(showDashboardHotkey, action: .showDashboard)
        }
    }
    
    private func registerHotkey(_ hotkey: String, action: HotkeyAction) {
        // Parse hotkey string and register with system
        logger.info("Registering hotkey: \(hotkey) for action: \(action)")
        
        // Implementation would:
        // 1. Parse the hotkey string (e.g., "⌃⌥F" -> Ctrl+Option+F)
        // 2. Register with system hotkey API
        // 3. Set up callback to handle hotkey press
    }
    
    private func unregisterAllHotkeys() {
        // Implementation would unregister all currently registered hotkeys
        logger.info("Unregistering all hotkeys")
    }
    
    // MARK: - Settings Change Handling
    
    private func handleSettingsChanges(from oldSettings: FuegoSettings, to newSettings: FuegoSettings) {
        // Handle launch at login changes
        if oldSettings.launchAtLogin != newSettings.launchAtLogin {
            configureLaunchAtLogin(newSettings.launchAtLogin)
        }
        
        // Handle hotkey changes
        if oldSettings.globalHotkeys != newSettings.globalHotkeys {
            setupHotkeys()
        }
        
        // Handle appearance changes
        if oldSettings.appearance.theme != newSettings.appearance.theme {
            applyTheme(newSettings.appearance.theme)
        }
        
        if oldSettings.appearance.menuBarIcon != newSettings.appearance.menuBarIcon {
            updateMenuBarIcon(newSettings.appearance.menuBarIcon)
        }
    }
    
    private func applyTheme(_ theme: AppTheme) {
        // Implementation would apply the selected theme
        logger.info("Applying theme: \(theme)")
        
        switch theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil // Use system appearance
        }
    }
    
    private func updateMenuBarIcon(_ icon: MenuBarIcon) {
        // Implementation would update the menu bar icon
        logger.info("Updating menu bar icon: \(icon)")
        
        // This would typically involve:
        // 1. Getting reference to the status item
        // 2. Updating the button image
        // 3. Refreshing the menu bar display
    }
    
    // MARK: - Validation
    
    func validateSettings(_ settings: FuegoSettings) -> [SettingsValidationError] {
        var errors: [SettingsValidationError] = []
        
        // Validate hotkeys don't conflict
        let hotkeys = [
            settings.globalHotkeys.toggleSession,
            settings.globalHotkeys.instantWork,
            settings.globalHotkeys.showDashboard
        ].compactMap { $0 }
        
        if Set(hotkeys).count != hotkeys.count {
            errors.append(.duplicateHotkeys)
        }
        
        // Validate password requirements
        if settings.security.lockedModeEnabled && !settings.security.passwordProtected {
            errors.append(.lockedModeRequiresPassword)
        }
        
        return errors
    }
    
    // MARK: - Import/Export
    
    func exportSettings() -> Data? {
        do {
            return try JSONEncoder().encode(settings)
        } catch {
            logger.error("Failed to export settings: \(error)")
            return nil
        }
    }
    
    func importSettings(from data: Data) throws {
        let importedSettings = try JSONDecoder().decode(FuegoSettings.self, from: data)
        
        // Validate imported settings
        let validationErrors = validateSettings(importedSettings)
        guard validationErrors.isEmpty else {
            throw SettingsError.invalidSettings(validationErrors)
        }
        
        saveSettings(importedSettings)
        logger.info("Settings imported successfully")
    }
}

// MARK: - Supporting Types

enum HotkeyAction: String, CaseIterable {
    case toggleSession = "toggle_session"
    case instantWork = "instant_work"
    case showDashboard = "show_dashboard"
}

enum SettingsValidationError {
    case duplicateHotkeys
    case lockedModeRequiresPassword
    case invalidHotkeyFormat(String)
}

enum SettingsError: LocalizedError {
    case invalidSettings([SettingsValidationError])
    case persistenceError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidSettings(let errors):
            return "Invalid settings: \(errors)"
        case .persistenceError(let error):
            return "Settings persistence error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Extensions

extension GlobalHotkeys: Equatable {
    static func == (lhs: GlobalHotkeys, rhs: GlobalHotkeys) -> Bool {
        return lhs.toggleSession == rhs.toggleSession &&
               lhs.instantWork == rhs.instantWork &&
               lhs.showDashboard == rhs.showDashboard
    }
}