import Foundation

// MARK: - Core Models

/// Represents a focus session
struct Session: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var pausedDuration: TimeInterval = 0
    var pauseStartTime: Date?
    
    init(startTime: Date, endTime: Date? = nil, pausedDuration: TimeInterval = 0) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.pausedDuration = pausedDuration
        self.pauseStartTime = nil
    }
    
    init(id: UUID, startTime: Date, endTime: Date? = nil, pausedDuration: TimeInterval = 0) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.pausedDuration = pausedDuration
        self.pauseStartTime = nil
    }
    
    var duration: TimeInterval {
        let endTime = self.endTime ?? Date()
        return endTime.timeIntervalSince(startTime) - pausedDuration
    }
    
    var isActive: Bool {
        endTime == nil
    }
    
    var isPaused: Bool {
        pauseStartTime != nil
    }
}

/// Simple blocking configuration
struct BlockingConfiguration: Codable {
    var blockedWebsites: Set<String> = []
    var blockedApplications: Set<String> = []
    var timerDuration: TimeInterval = 25 * 60 // 25 minutes default
    
    init() {}
}



// MARK: - Timer State

indirect enum TimerState: Equatable {
    case idle
    case work(remaining: TimeInterval)
    case shortBreak(remaining: TimeInterval)
    case longBreak(remaining: TimeInterval)
    case paused(TimerState)
    
    var isActive: Bool {
        switch self {
        case .idle: return false
        default: return true
        }
    }
    
    var isPaused: Bool {
        if case .paused = self {
            return true
        }
        return false
    }
    
    var remainingTime: TimeInterval {
        switch self {
        case .work(let remaining),
             .shortBreak(let remaining),
             .longBreak(let remaining):
            return remaining
        case .paused(let pausedState):
            return pausedState.remainingTime
        case .idle:
            return 0
        }
    }
}

// MARK: - Settings

struct FuegoSettings: Codable {
    var launchAtLogin: Bool = true
    var blockedWebsites: Set<String> = []
    var blockedApplications: Set<String> = []
    var timerDuration: TimeInterval = 25 * 60 // 25 minutes
    
    init() {}
}