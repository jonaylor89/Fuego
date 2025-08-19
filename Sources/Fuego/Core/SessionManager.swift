import Foundation
import Combine
import Logging

/// Manages focus session lifecycle and state
@MainActor
class SessionManager: ObservableObject {
    private let logger = Logger(label: "com.fuego.session")
    private let persistence: PersistenceManager
    
    @Published var currentSession: Session?
    @Published var isPaused: Bool = false
    
    private var pauseStartTime: Date?
    
    init(persistence: PersistenceManager) {
        self.persistence = persistence
    }
    
    // MARK: - Session Control
    
    func startSession(with profile: Profile) async throws -> Session {
        // End any existing session first
        if currentSession != nil {
            try await endSession()
        }
        
        let session = Session(
            profileId: profile.id,
            startTime: Date(),
            endTime: nil,
            pausedDuration: 0
        )
        
        currentSession = session
        isPaused = false
        pauseStartTime = nil
        
        // Save to persistence
        try persistence.saveSession(session)
        
        logger.info("Session started with profile: \(profile.name)")
        return session
    }
    
    func pauseSession() async throws {
        guard let session = currentSession, !isPaused else {
            throw SessionError.invalidState("Cannot pause: no active session or already paused")
        }
        
        isPaused = true
        pauseStartTime = Date()
        
        // Update session with pause info
        var updatedSession = session
        updatedSession.pauseStartTime = pauseStartTime
        currentSession = updatedSession
        
        logger.info("Session paused")
    }
    
    func resumeSession() async throws {
        guard let session = currentSession, isPaused else {
            throw SessionError.invalidState("Cannot resume: no active session or not paused")
        }
        
        guard let pauseStart = pauseStartTime else {
            throw SessionError.invalidState("No pause start time recorded")
        }
        
        let pauseDuration = Date().timeIntervalSince(pauseStart)
        
        var updatedSession = session
        updatedSession.pausedDuration += pauseDuration
        updatedSession.pauseStartTime = nil
        currentSession = updatedSession
        
        isPaused = false
        pauseStartTime = nil
        
        // Update in persistence
        try persistence.updateSession(updatedSession)
        
        logger.info("Session resumed after \(pauseDuration) seconds")
    }
    
    func endSession() async throws {
        guard let session = currentSession else {
            throw SessionError.invalidState("No active session to end")
        }
        
        // If session is paused, account for final pause duration
        if isPaused, let pauseStart = pauseStartTime {
            let finalPauseDuration = Date().timeIntervalSince(pauseStart)
            var updatedSession = session
            updatedSession.pausedDuration += finalPauseDuration
            updatedSession.endTime = Date()
            updatedSession.pauseStartTime = nil
            
            try persistence.updateSession(updatedSession)
        } else {
            var updatedSession = session
            updatedSession.endTime = Date()
            try persistence.updateSession(updatedSession)
        }
        
        currentSession = nil
        isPaused = false
        pauseStartTime = nil
        
        logger.info("Session ended, duration: \(session.duration) seconds")
    }
    
    // MARK: - Session Queries
    
    func getRecentSessions(limit: Int = 10) -> [Session] {
        return persistence.fetchSessions(limit: limit)
    }
    
    func getSessionsForProfile(_ profileId: UUID, limit: Int? = nil) -> [Session] {
        return persistence.fetchSessions(for: profileId, limit: limit)
    }
    
    func getTodaysSessions() -> [Session] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return persistence.fetchSessions().filter { session in
            session.startTime >= today && session.startTime < tomorrow
        }
    }
    
    func getTodaysFocusTime() -> TimeInterval {
        return getTodaysSessions().reduce(0) { $0 + $1.duration }
    }
    
    func getCurrentSessionDuration() -> TimeInterval {
        guard let session = currentSession else { return 0 }
        return session.duration
    }
    
    func getCurrentSessionProgress(totalDuration: TimeInterval) -> Double {
        guard let session = currentSession else { return 0 }
        let elapsed = session.duration
        return min(1.0, elapsed / totalDuration)
    }
}

// MARK: - Error Types

enum SessionError: LocalizedError {
    case invalidState(String)
    case persistenceError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidState(let message):
            return "Invalid session state: \(message)"
        case .persistenceError(let error):
            return "Persistence error: \(error.localizedDescription)"
        }
    }
}