import Combine
import Foundation
import Logging

/// Simplified settings manager for basic functionality
@MainActor
class SettingsManager: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.settings")
    private let persistence: PersistenceManager
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "FuegoSettings"

    @Published var settings: FuegoSettings

    init() {
        self.persistence = PersistenceManager()
        self.settings = FuegoSettings()  // Initialize with defaults first
        self.settings = loadSettings()  // Then load actual settings

        logger.info("Settings manager initialized")
    }

    // MARK: - Settings Management

    func loadSettings() -> FuegoSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            logger.info("No saved settings found, using defaults")
            return FuegoSettings()
        }

        do {
            let savedSettings = try JSONDecoder().decode(FuegoSettings.self, from: data)
            logger.info("Settings loaded successfully")
            return savedSettings
        } catch {
            logger.error("Failed to decode settings: \(error)")
            return FuegoSettings()
        }
    }

    func saveSettings(_ newSettings: FuegoSettings) throws {
        do {
            let data = try JSONEncoder().encode(newSettings)
            userDefaults.set(data, forKey: settingsKey)
            settings = newSettings
            logger.info("Settings saved successfully")
        } catch {
            logger.error("Failed to save settings: \(error)")
            throw error
        }
    }

    func resetToDefaults() {
        let defaultSettings = FuegoSettings()
        do {
            try saveSettings(defaultSettings)
            logger.info("Settings reset to defaults")
        } catch {
            logger.error("Failed to reset settings: \(error)")
        }
    }
}
