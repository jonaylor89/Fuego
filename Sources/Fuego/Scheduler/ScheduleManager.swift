import Foundation
import Combine
import Logging

/// Manages scheduled focus sessions
@MainActor
class ScheduleManager: ObservableObject {
    private let logger = Logger(label: "com.fuego.scheduler")
    
    @Published var upcomingSessions: [UpcomingSession] = []
    @Published var isSchedulingEnabled = false
    
    private var scheduleTimer: Timer?
    private var fuegoCore: FuegoCore?
    
    init() {
        startScheduleMonitoring()
        logger.info("Schedule manager initialized")
    }
    
    // MARK: - Core Integration
    
    func setFuegoCore(_ core: FuegoCore) {
        self.fuegoCore = core
        updateScheduleFromActiveProfile()
    }
    
    private func updateScheduleFromActiveProfile() {
        guard let core = fuegoCore else { return }
        
        isSchedulingEnabled = core.activeProfile.scheduleConfig.isEnabled
        
        if isSchedulingEnabled {
            updateUpcomingSessions(from: core.activeProfile.scheduleConfig.scheduledSessions)
        } else {
            upcomingSessions.removeAll()
        }
    }
    
    // MARK: - Schedule Monitoring
    
    private func startScheduleMonitoring() {
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForScheduledSessions()
            }
        }
    }
    
    private func checkForScheduledSessions() async {
        guard isSchedulingEnabled,
              let core = fuegoCore else { return }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Check each scheduled session
        for scheduledSession in core.activeProfile.scheduleConfig.scheduledSessions {
            guard scheduledSession.isEnabled else { continue }
            
            // Check if this session should start now
            if shouldStartSession(scheduledSession, at: now) {
                await startScheduledSession(scheduledSession, core: core)
            }
        }
        
        // Update upcoming sessions
        updateUpcomingSessions(from: core.activeProfile.scheduleConfig.scheduledSessions)
    }
    
    private func shouldStartSession(_ session: ScheduledSession, at date: Date) -> Bool {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        
        // Check if today is one of the scheduled days
        guard session.daysOfWeek.contains(currentWeekday) else { return false }
        
        // Check if current time matches scheduled time (within 1 minute tolerance)
        let scheduledHour = session.startTime.hour ?? 0
        let scheduledMinute = session.startTime.minute ?? 0
        
        let timeDifferenceMinutes = abs((currentHour * 60 + currentMinute) - (scheduledHour * 60 + scheduledMinute))
        
        return timeDifferenceMinutes <= 1
    }
    
    private func startScheduledSession(_ scheduledSession: ScheduledSession, core: FuegoCore) async {
        // Don't start if there's already an active session
        guard core.currentSession == nil else {
            logger.info("Skipping scheduled session - another session is already active")
            return
        }
        
        do {
            logger.info("Starting scheduled session: \(scheduledSession.id)")
            
            // Determine which profile to use
            let profile: Profile
            if let profileId = scheduledSession.profileId,
               let targetProfile = core.profileManager.profiles.first(where: { $0.id == profileId }) {
                profile = targetProfile
            } else {
                profile = core.activeProfile
            }
            
            // Start the session
            try await core.startSession(with: profile)
            
            // Schedule automatic end if duration is specified
            if scheduledSession.duration > 0 {
                scheduleSessionEnd(after: scheduledSession.duration, core: core)
            }
            
            logger.info("Scheduled session started successfully")
            
        } catch {
            logger.error("Failed to start scheduled session: \(error)")
        }
    }
    
    private func scheduleSessionEnd(after duration: TimeInterval, core: FuegoCore) {
        Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            Task { @MainActor in
                if core.currentSession != nil {
                    do {
                        try await core.endSession()
                        self.logger.info("Automatically ended scheduled session after \(duration) seconds")
                    } catch {
                        self.logger.error("Failed to automatically end session: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Upcoming Sessions
    
    private func updateUpcomingSessions(from scheduledSessions: [ScheduledSession]) {
        let calendar = Calendar.current
        let now = Date()
        
        var upcoming: [UpcomingSession] = []
        
        for scheduledSession in scheduledSessions.filter({ $0.isEnabled }) {
            // Find next few occurrences
            for dayOffset in 0..<14 { // Look ahead 2 weeks
                let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
                let targetWeekday = calendar.component(.weekday, from: targetDate)
                
                if scheduledSession.daysOfWeek.contains(targetWeekday) {
                    // Create the specific date/time for this occurrence
                    var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
                    components.hour = scheduledSession.startTime.hour ?? 0
                    components.minute = scheduledSession.startTime.minute ?? 0
                    components.second = 0
                    
                    if let sessionTime = calendar.date(from: components),
                       sessionTime > now {
                        
                        let upcomingSession = UpcomingSession(
                            scheduledSession: scheduledSession,
                            nextOccurrence: sessionTime
                        )
                        upcoming.append(upcomingSession)
                    }
                }
            }
        }
        
        // Sort by next occurrence and limit to next 10
        upcomingSessions = Array(upcoming.sorted { $0.nextOccurrence < $1.nextOccurrence }.prefix(10))
    }
    
    // MARK: - Schedule Management
    
    func enableScheduling() {
        isSchedulingEnabled = true
        updateScheduleFromActiveProfile()
        logger.info("Scheduling enabled")
    }
    
    func disableScheduling() {
        isSchedulingEnabled = false
        upcomingSessions.removeAll()
        logger.info("Scheduling disabled")
    }
    
    func getNextScheduledSession() -> UpcomingSession? {
        return upcomingSessions.first
    }
    
    func getScheduledSessionsForDay(_ date: Date) -> [ScheduledSession] {
        guard let core = fuegoCore else { return [] }
        
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        return core.activeProfile.scheduleConfig.scheduledSessions.filter { session in
            session.isEnabled && session.daysOfWeek.contains(weekday)
        }
    }
    
    func getTodaysScheduledSessions() -> [ScheduledSession] {
        return getScheduledSessionsForDay(Date())
    }
    
    // MARK: - Statistics
    
    func getScheduleStatistics() -> ScheduleStatistics {
        guard let core = fuegoCore else {
            return ScheduleStatistics(
                totalScheduledSessions: 0,
                completedSessions: 0,
                missedSessions: 0,
                averageAdherence: 0
            )
        }
        
        let scheduledSessions = core.activeProfile.scheduleConfig.scheduledSessions
        let totalScheduled = scheduledSessions.filter { $0.isEnabled }.count * 7 // Rough weekly estimate
        
        // This would typically query actual session data to calculate real statistics
        return ScheduleStatistics(
            totalScheduledSessions: totalScheduled,
            completedSessions: Int(Double(totalScheduled) * 0.8), // Mock 80% completion
            missedSessions: Int(Double(totalScheduled) * 0.2), // Mock 20% missed
            averageAdherence: 0.8
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        scheduleTimer?.invalidate()
        logger.info("Schedule manager deinitialized")
    }
}

// MARK: - Supporting Types

struct UpcomingSession: Identifiable {
    let id = UUID()
    let scheduledSession: ScheduledSession
    let nextOccurrence: Date
    
    var timeUntilStart: TimeInterval {
        nextOccurrence.timeIntervalSince(Date())
    }
    
    var isStartingSoon: Bool {
        timeUntilStart <= 5 * 60 // 5 minutes
    }
}

struct ScheduleStatistics {
    let totalScheduledSessions: Int
    let completedSessions: Int
    let missedSessions: Int
    let averageAdherence: Double // 0.0 to 1.0
    
    var adherencePercentage: Int {
        Int(averageAdherence * 100)
    }
}