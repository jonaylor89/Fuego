import Combine
import Foundation
import Logging
import ServiceManagement

/// Central coordination hub for all Fuego functionality
@MainActor
class FuegoCore: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.core")

    // Core managers
    let sessionManager: SessionManager
    let blockingEngine: BlockingEngine
    let timerEngine: TimerEngine
    let settingsManager: SettingsManager

    // Published state
    @Published var currentSession: Session?
    @Published var isPaused: Bool = false
    @Published var timerState: TimerState = .idle
    @Published var settings: FuegoSettings
    @Published var filterStatus: FilterController.Status = .checking
    /// The most recent failure, shown in the popover until the next action succeeds.
    @Published var lastError: String?

    var filter: FilterController { blockingEngine.filter }

    init() {
        self.settingsManager = SettingsManager()
        self.blockingEngine = BlockingEngine()
        self.timerEngine = TimerEngine()
        self.sessionManager = SessionManager(persistence: PersistenceManager())
        self.settings = settingsManager.settings

        setupBindings()
        logger.info("Fuego Core initialized")
    }

    private func setupBindings() {
        sessionManager.$currentSession.assign(to: &$currentSession)
        sessionManager.$isPaused.assign(to: &$isPaused)
        timerEngine.$state.assign(to: &$timerState)
        blockingEngine.filter.$status.assign(to: &$filterStatus)

        timerEngine.onTimerComplete = { [weak self] in
            Task { await self?.endSession() }
        }
    }

    /// Called once at launch.
    func start() async {
        await filter.start()
        // Clear blocking left over from a session that ended with a crash
        if filterStatus == .ready {
            await blockingEngine.unblock()
        }
    }

    // MARK: - Session Control

    func startSession() async {
        guard currentSession == nil else { return }
        logger.info("Starting focus session")
        let duration = settings.timerDuration
        await run {
            try await blockingEngine.block(
                websites: settings.blockedWebsites,
                applications: settings.blockedApplications,
                until: Date().addingTimeInterval(duration))
            _ = try await sessionManager.startSession()
            timerEngine.start(duration: duration)
        }
    }

    func pauseSession() async {
        guard currentSession != nil, !isPaused else { return }
        logger.info("Pausing session")
        await run {
            try await sessionManager.pauseSession()
            timerEngine.pause()
            await blockingEngine.unblock()
        }
    }

    func resumeSession() async {
        guard currentSession != nil, isPaused else { return }
        logger.info("Resuming session")
        await run {
            try await blockingEngine.block(
                websites: settings.blockedWebsites,
                applications: settings.blockedApplications,
                until: Date().addingTimeInterval(timerState.remainingTime))
            try await sessionManager.resumeSession()
            timerEngine.resume()
        }
    }

    func endSession() async {
        guard currentSession != nil else { return }
        logger.info("Ending session")
        timerEngine.stop()
        await blockingEngine.unblock()
        await run {
            try await sessionManager.endSession()
        }
    }

    // MARK: - Settings Management

    func updateSettings(_ newSettings: FuegoSettings) async {
        await run {
            try settingsManager.saveSettings(newSettings)
            if newSettings.launchAtLogin != settings.launchAtLogin {
                try updateLaunchAtLogin(newSettings.launchAtLogin)
            }
            settings = newSettings

            // Apply new lists right away during an active session
            if currentSession != nil, !isPaused {
                try await blockingEngine.block(
                    websites: settings.blockedWebsites,
                    applications: settings.blockedApplications,
                    until: Date().addingTimeInterval(timerState.remainingTime))
            }
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    // MARK: - Website Blocking Setup

    func setUpWebsiteBlocking() async {
        await run {
            try await filter.setUp()
        }
    }

    // MARK: - Lifecycle

    func shutdown() async {
        logger.info("Shutting down Fuego Core")
        if currentSession != nil {
            await endSession()
        }
    }

    /// Runs an action, recording any failure in `lastError` for the UI.
    private func run(_ action: () async throws -> Void) async {
        do {
            try await action()
            lastError = nil
        } catch {
            logger.error("\(error)")
            lastError = error.localizedDescription
        }
    }
}
