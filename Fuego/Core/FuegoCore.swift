import Combine
import Foundation
import Logging

/// Central coordination hub for all Fuego functionality
@MainActor
final class FuegoCore: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.core")

    let sessionManager: SessionManager
    let blockingEngine: BlockingEngine
    let timerEngine: TimerEngine
    let settingsManager: SettingsManager

    @Published private(set) var currentSession: Session?
    @Published private(set) var isBlocked = false
    @Published private(set) var timerState: TimerState = .idle
    @Published private(set) var settings: FuegoSettings
    @Published private(set) var filterStatus: FilterStatus = .unknown
    @Published var lastError: String?

    init(
        blockingEngine: BlockingEngine,
        settingsManager: SettingsManager? = nil,
        timerEngine: TimerEngine? = nil
    ) {
        let settingsManager = settingsManager ?? SettingsManager()
        self.blockingEngine = blockingEngine
        self.settingsManager = settingsManager
        self.timerEngine = timerEngine ?? TimerEngine()
        self.sessionManager = SessionManager(persistence: PersistenceManager())
        self.settings = settingsManager.settings

        sessionManager.$currentSession.assign(to: &$currentSession)
        blockingEngine.$isActive.assign(to: &$isBlocked)
        self.timerEngine.$state.assign(to: &$timerState)
        blockingEngine.filter.statusPublisher.assign(to: &$filterStatus)

        self.timerEngine.onTimerComplete = { [weak self] in
            Task { try? await self?.endSession() }
        }

        logger.info("Fuego Core initialized")
    }

    // MARK: - Session Control

    func startSession() async throws {
        logger.info("Starting focus session")
        lastError = nil
        _ = try await sessionManager.startSession()
        timerEngine.start(duration: settings.timerDuration)

        do {
            try await blockingEngine.apply(
                websites: settings.blockedWebsites, apps: settings.blockedApplications)
        } catch {
            lastError = "website blocking unavailable: \(error.localizedDescription)"
            throw error
        }
    }

    func pauseSession() async throws {
        guard currentSession != nil else { return }
        logger.info("Pausing session")
        try await sessionManager.pauseSession()
        timerEngine.pause()
        await blockingEngine.disable()
    }

    func resumeSession() async throws {
        guard currentSession != nil else { return }
        logger.info("Resuming session")
        try await sessionManager.resumeSession()
        timerEngine.resume()
        try await blockingEngine.apply(
            websites: settings.blockedWebsites, apps: settings.blockedApplications)
    }

    func endSession() async throws {
        guard currentSession != nil else { return }
        logger.info("Ending session")
        try await sessionManager.endSession()
        timerEngine.stop()
        await blockingEngine.disable()
    }

    // MARK: - Settings Management

    func updateSettings(_ newSettings: FuegoSettings) async throws {
        try settingsManager.saveSettings(newSettings)
        settings = newSettings

        if currentSession != nil, !sessionManager.isPaused {
            try await blockingEngine.apply(
                websites: settings.blockedWebsites, apps: settings.blockedApplications)
        }
    }

    // MARK: - Website Blocking Setup

    func installContentFilter() async {
        do {
            try await blockingEngine.filter.install()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshFilterStatus() async {
        await blockingEngine.filter.refreshStatus()
    }

    // MARK: - Lifecycle

    func shutdown() async {
        logger.info("Shutting down Fuego Core")
        try? await endSession()
        await blockingEngine.disable()
    }
}
