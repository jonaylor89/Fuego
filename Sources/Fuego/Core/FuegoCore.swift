import Foundation
import Combine
import Logging

/// Central coordination hub for all Fuego functionality
@MainActor
class FuegoCore: ObservableObject {
    static let shared = FuegoCore()
    
    private let logger = Logger(label: "com.fuego.core")
    
    // Core managers
    let sessionManager: SessionManager
    let blockingEngine: BlockingEngine
    let timerEngine: TimerEngine
    let settingsManager: SettingsManager
    let persistenceManager: PersistenceManager
    
    // Published state
    @Published var currentSession: Session?
    @Published var isBlocked: Bool = false
    @Published var timerState: TimerState = .idle
    @Published var settings: FuegoSettings = FuegoSettings()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize managers
        self.persistenceManager = PersistenceManager()
        self.settingsManager = SettingsManager()
        self.blockingEngine = BlockingEngine()
        self.timerEngine = TimerEngine()
        self.sessionManager = SessionManager(persistence: persistenceManager)
        
        // Load settings
        loadSettings()
        
        setupBindings()
        logger.info("Fuego Core initialized")
    }
    
    private func setupBindings() {
        // Session state changes
        sessionManager.$currentSession
            .assign(to: &$currentSession)
        
        // Blocking state changes
        blockingEngine.$isActive
            .assign(to: &$isBlocked)
        
        // Timer state changes
        timerEngine.$state
            .assign(to: &$timerState)
    }
    
    private func loadSettings() {
        settings = settingsManager.loadSettings()
    }
    
    // MARK: - Session Control
    
    func startSession() async throws {
        logger.info("Starting focus session")
        
        // Start session
        _ = try await sessionManager.startSession()
        
        // Apply blocking rules from settings
        try await blockingEngine.applyRules(settings.blockedWebsites, settings.blockedApplications)
        
        // Start timer
        try await timerEngine.start(duration: settings.timerDuration)
    }
    
    func pauseSession() async throws {
        guard currentSession != nil else { return }
        
        logger.info("Pausing session")
        try await sessionManager.pauseSession()
        await blockingEngine.disable()
        timerEngine.pause()
    }
    
    func resumeSession() async throws {
        guard currentSession != nil else { return }
        
        logger.info("Resuming session")
        try await sessionManager.resumeSession()
        try await blockingEngine.applyRules(settings.blockedWebsites, settings.blockedApplications)
        timerEngine.resume()
    }
    
    func endSession() async throws {
        guard currentSession != nil else { return }
        
        logger.info("Ending session")
        try await sessionManager.endSession()
        await blockingEngine.disable()
        timerEngine.stop()
    }
    
    // MARK: - Quick Actions
    
    func toggleSession() async throws {
        if currentSession != nil {
            if sessionManager.isPaused {
                try await resumeSession()
            } else {
                try await pauseSession()
            }
        } else {
            try await startSession()
        }
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: FuegoSettings) async throws {
        settings = newSettings
        try settingsManager.saveSettings(newSettings)
        
        // If session is active, update blocking rules
        if currentSession != nil, !sessionManager.isPaused {
            try await blockingEngine.applyRules(settings.blockedWebsites, settings.blockedApplications)
        }
    }
    
    // MARK: - Lifecycle
    
    func shutdown() {
        logger.info("Shutting down Fuego Core")
        
        Task {
            if currentSession != nil {
                try? await endSession()
            }
            await blockingEngine.disable()
        }
        
        cancellables.removeAll()
    }
}