import CoreData
import Foundation
import Logging

/// Simplified persistence manager for basic session storage
@MainActor
class PersistenceManager: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.persistence")
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "FuegoSettings"

    // For now, just use in-memory storage
    // In a real app, this would use Core Data or another persistence solution
    private var sessions: [Session] = []

    init() {
        logger.info("Persistence manager initialized")
    }

    // MARK: - Session Management

    func saveSession(_ session: Session) throws {
        logger.info("Saving session: \(session.id)")
        sessions.append(session)
    }

    func updateSession(_ session: Session) throws {
        logger.info("Updating session: \(session.id)")

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }

    func fetchSessions(limit: Int? = nil) -> [Session] {
        let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }

        if let limit = limit {
            return Array(sortedSessions.prefix(limit))
        }

        return sortedSessions
    }

    // MARK: - Settings Management

    func saveSettings(_ settings: FuegoSettings) throws {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsKey)
            logger.info("Settings saved to UserDefaults")
        } catch {
            logger.error("Failed to save settings: \(error)")
            throw error
        }
    }

    func fetchSettings() -> FuegoSettings {
        guard let data = userDefaults.data(forKey: settingsKey) else {
            logger.info("No saved settings found, returning defaults")
            return FuegoSettings()
        }

        do {
            let settings = try JSONDecoder().decode(FuegoSettings.self, from: data)
            logger.info("Settings loaded from UserDefaults")
            return settings
        } catch {
            logger.error("Failed to decode settings: \(error)")
            return FuegoSettings()
        }
    }
}
