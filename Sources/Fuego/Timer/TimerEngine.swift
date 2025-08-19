import Foundation
import Combine
import Logging

/// Manages Pomodoro timer functionality
@MainActor
class TimerEngine: ObservableObject {
    private let logger = Logger(label: "com.fuego.timer")
    
    @Published var state: TimerState = .idle
    @Published var currentCycle: Int = 0
    @Published var totalCycles: Int = 0
    
    private var timer: Timer?
    private var configuration: TimerConfiguration?
    private var startTime: Date?
    private var pausedTime: Date?
    private var totalPausedDuration: TimeInterval = 0
    
    // Callbacks for timer events
    var onWorkStart: (() -> Void)?
    var onWorkEnd: (() -> Void)?
    var onBreakStart: (() -> Void)?
    var onBreakEnd: (() -> Void)?
    var onCycleComplete: (() -> Void)?
    var onTimerComplete: (() -> Void)?
    
    // MARK: - Public Interface
    
    func start(with config: TimerConfiguration) async throws {
        logger.info("Starting timer with configuration")
        
        configuration = config
        currentCycle = 0
        totalCycles = 0
        totalPausedDuration = 0
        
        await startWorkPeriod()
    }
    
    func pause() {
        guard state.isActive && !state.isPaused else { return }
        
        logger.info("Pausing timer")
        pausedTime = Date()
        
        let currentState = state
        state = .paused(currentState)
        
        timer?.invalidate()
        timer = nil
    }
    
    func resume() {
        guard case .paused(let pausedState) = state else { return }
        
        logger.info("Resuming timer")
        
        if let pausedTime = pausedTime {
            totalPausedDuration += Date().timeIntervalSince(pausedTime)
            self.pausedTime = nil
        }
        
        state = pausedState
        startTimerForCurrentState()
    }
    
    func stop() {
        logger.info("Stopping timer")
        
        timer?.invalidate()
        timer = nil
        state = .idle
        configuration = nil
        startTime = nil
        pausedTime = nil
        totalPausedDuration = 0
        currentCycle = 0
        totalCycles = 0
    }
    
    func skip() async {
        logger.info("Skipping current timer period")
        
        timer?.invalidate()
        timer = nil
        
        switch state {
        case .work:
            await handleWorkComplete()
        case .shortBreak, .longBreak:
            await handleBreakComplete()
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func startWorkPeriod() async {
        guard let config = configuration else { return }
        
        logger.info("Starting work period \(currentCycle + 1)")
        
        let workDuration = config.workDuration
        state = .work(remaining: workDuration)
        startTime = Date()
        
        onWorkStart?()
        startTimerForCurrentState()
    }
    
    private func startBreakPeriod() async {
        guard let config = configuration else { return }
        
        let isLongBreak = (currentCycle % config.longBreakInterval == 0) && currentCycle > 0
        let breakDuration = isLongBreak ? config.longBreakDuration : config.shortBreakDuration
        
        logger.info("Starting \(isLongBreak ? "long" : "short") break period")
        
        if isLongBreak {
            state = .longBreak(remaining: breakDuration)
        } else {
            state = .shortBreak(remaining: breakDuration)
        }
        
        startTime = Date()
        onBreakStart?()
        startTimerForCurrentState()
    }
    
    private func startTimerForCurrentState() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateTimer()
            }
        }
    }
    
    private func updateTimer() async {
        guard let startTime = startTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime) - totalPausedDuration
        
        switch state {
        case .work(let total):
            let remaining = max(0, total - elapsed)
            state = .work(remaining: remaining)
            
            if remaining <= 0 {
                await handleWorkComplete()
            }
            
        case .shortBreak(let total):
            let remaining = max(0, total - elapsed)
            state = .shortBreak(remaining: remaining)
            
            if remaining <= 0 {
                await handleBreakComplete()
            }
            
        case .longBreak(let total):
            let remaining = max(0, total - elapsed)
            state = .longBreak(remaining: remaining)
            
            if remaining <= 0 {
                await handleBreakComplete()
            }
            
        default:
            break
        }
    }
    
    private func handleWorkComplete() async {
        logger.info("Work period completed")
        
        timer?.invalidate()
        timer = nil
        
        currentCycle += 1
        totalCycles += 1
        
        onWorkEnd?()
        onCycleComplete?()
        
        guard let config = configuration else {
            state = .idle
            return
        }
        
        // Auto-start break if configured
        if config.autoStartBreaks {
            await startBreakPeriod()
        } else {
            state = .idle
        }
    }
    
    private func handleBreakComplete() async {
        logger.info("Break period completed")
        
        timer?.invalidate()
        timer = nil
        
        onBreakEnd?()
        
        guard let config = configuration else {
            state = .idle
            return
        }
        
        // Auto-start next work period if configured
        if config.autoStartWork {
            await startWorkPeriod()
        } else {
            state = .idle
        }
    }
    
    // MARK: - Utility Methods
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func getCurrentPeriodType() -> PeriodType {
        switch state {
        case .work, .paused(.work):
            return .work
        case .shortBreak, .paused(.shortBreak):
            return .shortBreak
        case .longBreak, .paused(.longBreak):
            return .longBreak
        case .idle, .paused(.idle), .paused:
            return .none
        }
    }
    
    func getProgress() -> Double {
        guard let config = configuration else { return 0 }
        
        let totalDuration: TimeInterval
        switch state {
        case .work, .paused(.work):
            totalDuration = config.workDuration
        case .shortBreak, .paused(.shortBreak):
            totalDuration = config.shortBreakDuration
        case .longBreak, .paused(.longBreak):
            totalDuration = config.longBreakDuration
        case .idle, .paused(.idle), .paused:
            return 0
        }
        
        let remaining = state.remainingTime
        return max(0, min(1, (totalDuration - remaining) / totalDuration))
    }
}

// MARK: - Supporting Types

enum PeriodType {
    case none
    case work
    case shortBreak
    case longBreak
    
    var displayName: String {
        switch self {
        case .none: return "Idle"
        case .work: return "Work"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }
    
    var systemImage: String {
        switch self {
        case .none: return "pause.circle"
        case .work: return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak: return "bed.double"
        }
    }
}

// MARK: - Timer Statistics

struct TimerSession {
    let startTime: Date
    let endTime: Date?
    let totalWorkTime: TimeInterval
    let totalBreakTime: TimeInterval
    let cyclesCompleted: Int
    let wasCompleted: Bool
}

extension TimerEngine {
    func getCurrentSessionStats() -> TimerSession? {
        guard let startTime = startTime else { return nil }
        
        return TimerSession(
            startTime: startTime,
            endTime: state == .idle ? Date() : nil,
            totalWorkTime: TimeInterval(totalCycles) * (configuration?.workDuration ?? 0),
            totalBreakTime: 0, // Would need to track this separately
            cyclesCompleted: totalCycles,
            wasCompleted: false // Would need to track completion vs manual stop
        )
    }
}