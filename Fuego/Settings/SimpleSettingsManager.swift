import Combine
import Foundation
import Logging
import ServiceManagement

/// Persists `FuegoSettings` and applies the launch-at-login preference.
@MainActor
final class SettingsManager: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.settings")
    private let userDefaults: UserDefaults
    private let applyLaunchAtLogin: (Bool) -> Void
    private let settingsKey = "FuegoSettings"

    @Published private(set) var settings = FuegoSettings()

    init(
        userDefaults: UserDefaults = .standard,
        applyLaunchAtLogin: @escaping (Bool) -> Void = SettingsManager.setLaunchAtLogin
    ) {
        self.userDefaults = userDefaults
        self.applyLaunchAtLogin = applyLaunchAtLogin
        self.settings = loadSettings()
    }

    func loadSettings() -> FuegoSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            return FuegoSettings()
        }
        do {
            return try JSONDecoder().decode(FuegoSettings.self, from: data)
        } catch {
            logger.error("Failed to decode settings: \(error)")
            return FuegoSettings()
        }
    }

    func saveSettings(_ newSettings: FuegoSettings) throws {
        let data = try JSONEncoder().encode(newSettings)
        userDefaults.set(data, forKey: settingsKey)
        if newSettings.launchAtLogin != settings.launchAtLogin {
            applyLaunchAtLogin(newSettings.launchAtLogin)
        }
        settings = newSettings
    }

    nonisolated static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger(label: "dev.getfuego.settings").error(
                "Failed to update launch at login: \(error.localizedDescription)")
        }
    }
}
