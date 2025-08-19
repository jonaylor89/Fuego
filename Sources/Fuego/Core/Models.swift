import Foundation

// MARK: - Core Models

/// Represents a focus session
struct Session: Identifiable, Codable {
    let id: UUID
    let profileId: UUID
    let startTime: Date
    var endTime: Date?
    var pausedDuration: TimeInterval = 0
    var pauseStartTime: Date?
    
    init(profileId: UUID, startTime: Date, endTime: Date? = nil, pausedDuration: TimeInterval = 0) {
        self.id = UUID()
        self.profileId = profileId
        self.startTime = startTime
        self.endTime = endTime
        self.pausedDuration = pausedDuration
        self.pauseStartTime = nil
    }
    
    init(id: UUID, profileId: UUID, startTime: Date, endTime: Date? = nil, pausedDuration: TimeInterval = 0) {
        self.id = id
        self.profileId = profileId
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

/// User profile with blocking rules and settings
struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var blockingRules: BlockingRules
    var timerConfig: TimerConfiguration
    var scheduleConfig: ScheduleConfiguration
    var automationHooks: AutomationHooks
    var isDefault: Bool = false
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.blockingRules = BlockingRules()
        self.timerConfig = TimerConfiguration()
        self.scheduleConfig = ScheduleConfiguration()
        self.automationHooks = AutomationHooks()
    }
    
    init(id: UUID, name: String, blockingRules: BlockingRules = BlockingRules(), timerConfig: TimerConfiguration = TimerConfiguration(), scheduleConfig: ScheduleConfiguration = ScheduleConfiguration(), automationHooks: AutomationHooks = AutomationHooks(), isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.blockingRules = blockingRules
        self.timerConfig = timerConfig
        self.scheduleConfig = scheduleConfig
        self.automationHooks = automationHooks
        self.isDefault = isDefault
    }
}

/// Blocking configuration
struct BlockingRules: Codable {
    var blockEntireInternet: Bool = false
    var blockedWebsites: Set<String> = []
    var allowedWebsites: Set<String> = []
    var blockedKeywords: Set<String> = []
    var blockedApplications: Set<String> = []
    var allowedApplications: Set<String> = []
    var useWhitelistMode: Bool = false // If true, only allowed sites/apps work
    
    init() {}
}

/// Timer/Pomodoro configuration
struct TimerConfiguration: Codable {
    var isEnabled: Bool = false
    var workDuration: TimeInterval = 25 * 60 // 25 minutes
    var shortBreakDuration: TimeInterval = 5 * 60 // 5 minutes
    var longBreakDuration: TimeInterval = 15 * 60 // 15 minutes
    var longBreakInterval: Int = 4 // After every 4 work sessions
    var autoStartBreaks: Bool = true
    var autoStartWork: Bool = false
    
    init() {}
}

/// Scheduling configuration
struct ScheduleConfiguration: Codable {
    var isEnabled: Bool = false
    var scheduledSessions: [ScheduledSession] = []
    
    init() {}
}

struct ScheduledSession: Identifiable, Codable {
    let id: UUID
    var startTime: DateComponents
    var duration: TimeInterval
    var daysOfWeek: Set<Int> // 1 = Sunday, 2 = Monday, etc.
    var profileId: UUID?
    var isEnabled: Bool = true
    
    init(startTime: DateComponents, duration: TimeInterval, daysOfWeek: Set<Int>) {
        self.id = UUID()
        self.startTime = startTime
        self.duration = duration
        self.daysOfWeek = daysOfWeek
    }
    
    init(id: UUID, startTime: DateComponents, duration: TimeInterval, daysOfWeek: Set<Int>, profileId: UUID? = nil, isEnabled: Bool = true) {
        self.id = id
        self.startTime = startTime
        self.duration = duration
        self.daysOfWeek = daysOfWeek
        self.profileId = profileId
        self.isEnabled = isEnabled
    }
}

/// Automation hooks
struct AutomationHooks: Codable {
    var onSessionStart: [AutomationHook] = []
    var onSessionEnd: [AutomationHook] = []
    var onSessionPause: [AutomationHook] = []
    var onSessionResume: [AutomationHook] = []
    var onTimerBreakStart: [AutomationHook] = []
    var onTimerBreakEnd: [AutomationHook] = []
    
    init() {}
}

struct AutomationHook: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: HookType
    var command: String
    var isEnabled: Bool = true
    
    enum HookType: String, Codable, CaseIterable {
        case shellScript = "shell"
        case appleScript = "applescript"
        case shortcut = "shortcut"
    }
    
    init(name: String, type: HookType, command: String) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.command = command
    }
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

// MARK: - Statistics

struct SessionStats: Codable {
    let date: Date
    let totalFocusTime: TimeInterval
    let sessionCount: Int
    let averageSessionLength: TimeInterval
    let mostUsedProfile: String?
}

struct PeriodStats: Codable {
    let period: StatsPeriod
    let totalFocusTime: TimeInterval
    let totalSessions: Int
    let averageSessionLength: TimeInterval
    let longestSession: TimeInterval
    let dailyAverages: [Date: TimeInterval]
    let profileUsage: [String: TimeInterval]
}

enum StatsPeriod: String, Codable, CaseIterable {
    case week = "week"
    case month = "month"
    case year = "year"
    case all = "all"
}

// MARK: - Settings

struct FuegoSettings: Codable {
    var launchAtLogin: Bool = true
    var globalHotkeys: GlobalHotkeys = GlobalHotkeys()
    var notifications: NotificationSettings = NotificationSettings()
    var security: SecuritySettings = SecuritySettings()
    var appearance: AppearanceSettings = AppearanceSettings()
}

struct GlobalHotkeys: Codable {
    var toggleSession: String? = "⌃⌥F"
    var instantWork: String? = "⌃⌥W"
    var showDashboard: String? = "⌃⌥D"
}

struct NotificationSettings: Codable, Equatable {
    var sessionStart: Bool = true
    var sessionEnd: Bool = true
    var timerBreakStart: Bool = true
    var timerBreakEnd: Bool = true
    var soundEnabled: Bool = true
}

struct SecuritySettings: Codable {
    var passwordProtected: Bool = false
    var passwordHash: String?
    var lockedModeEnabled: Bool = false
    var requirePasswordToQuit: Bool = false
}

struct AppearanceSettings: Codable {
    var menuBarIcon: MenuBarIcon = .flame
    var showTimeInMenuBar: Bool = false
    var theme: AppTheme = .system
}

enum MenuBarIcon: String, Codable, CaseIterable {
    case flame = "flame.fill"
    case circle = "circle.fill"
    case square = "square.fill"
    case shield = "shield.fill"
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}

// MARK: - Events

enum AutomationEvent {
    case sessionStart
    case sessionEnd
    case sessionPause
    case sessionResume
    case timerBreakStart
    case timerBreakEnd
}