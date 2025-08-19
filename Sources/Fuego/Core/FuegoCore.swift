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
    let scheduleManager: ScheduleManager
    let profileManager: ProfileManager
    let persistenceManager: PersistenceManager
    let automationEngine: AutomationEngine
    let settingsManager: SettingsManager
    
    // Published state
    @Published var currentSession: Session?
    @Published var activeProfile: Profile
    @Published var isBlocked: Bool = false
    @Published var timerState: TimerState = .idle
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize managers
        self.persistenceManager = PersistenceManager()
        self.settingsManager = SettingsManager(persistence: persistenceManager)
        self.profileManager = ProfileManager(persistence: persistenceManager)
        self.blockingEngine = BlockingEngine()
        self.timerEngine = TimerEngine()
        self.scheduleManager = ScheduleManager()
        self.sessionManager = SessionManager(persistence: persistenceManager)
        self.automationEngine = AutomationEngine()
        
        // Load or create default profile
        self.activeProfile = profileManager.loadActiveProfile() ?? profileManager.createDefaultProfile()
        
        setupBindings()
        scheduleManager.setFuegoCore(self)
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
        
        // Profile changes
        profileManager.$activeProfile
            .compactMap { $0 }
            .assign(to: &$activeProfile)
    }
    
    // MARK: - Session Control
    
    func startSession(with profile: Profile? = nil) async throws {
        let sessionProfile = profile ?? activeProfile
        logger.info("Starting session with profile: \(sessionProfile.name)")
        
        // Update active profile if different
        if let profile = profile {
            try await profileManager.setActiveProfile(profile)
        }
        
        // Start session
        let session = try await sessionManager.startSession(with: sessionProfile)
        
        // Apply blocking rules
        try await blockingEngine.applyRules(sessionProfile.blockingRules)
        
        // Start timer if configured
        if sessionProfile.timerConfig.isEnabled {
            try await timerEngine.start(with: sessionProfile.timerConfig)
        }
        
        // Trigger automation hooks
        await automationEngine.executeHooks(for: .sessionStart, session: session)
    }
    
    func pauseSession() async throws {
        guard let session = currentSession else { return }
        
        logger.info("Pausing session")
        try await sessionManager.pauseSession()
        await blockingEngine.disable()
        timerEngine.pause()
        
        await automationEngine.executeHooks(for: .sessionPause, session: session)
    }
    
    func resumeSession() async throws {
        guard let session = currentSession else { return }
        
        logger.info("Resuming session")
        try await sessionManager.resumeSession()
        try await blockingEngine.applyRules(activeProfile.blockingRules)
        timerEngine.resume()
        
        await automationEngine.executeHooks(for: .sessionResume, session: session)
    }
    
    func endSession() async throws {
        guard let session = currentSession else { return }
        
        logger.info("Ending session")
        try await sessionManager.endSession()
        await blockingEngine.disable()
        timerEngine.stop()
        
        await automationEngine.executeHooks(for: .sessionEnd, session: session)
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
    
    func startInstantWorkMode(duration: TimeInterval = 25 * 60) async throws {
        let instantProfile = profileManager.createInstantWorkProfile(duration: duration)
        try await startSession(with: instantProfile)
    }
    
    // MARK: - Profile Management
    
    func switchProfile(_ profile: Profile) async throws {
        logger.info("Switching to profile: \(profile.name)")
        
        // End current session if active
        if currentSession != nil {
            try await endSession()
        }
        
        // Switch profile
        try await profileManager.setActiveProfile(profile)
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