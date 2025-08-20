import Combine
import Foundation
import Logging

/// Simple timer engine for basic countdown functionality
@MainActor
class TimerEngine: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.timer")

    @Published var state: TimerState = .idle

    private var timer: Timer?
    private var startTime: Date?
    private var pausedTime: Date?
    private var totalPausedDuration: TimeInterval = 0

    // Callbacks for timer events
    var onWorkStart: (() -> Void)?
    var onWorkEnd: (() -> Void)?
    var onTimerComplete: (() -> Void)?

    // MARK: - Public Interface

    func start(duration: TimeInterval) async throws {
        logger.info("Starting timer for \(duration) seconds")

        totalPausedDuration = 0
        await startWorkPeriod(duration: duration)
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

        // Add paused duration
        if let pauseStart = pausedTime {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }

        state = pausedState
        pausedTime = nil

        startTimerForCurrentState()
    }

    func stop() {
        logger.info("Stopping timer")

        timer?.invalidate()
        timer = nil
        state = .idle
        startTime = nil
        pausedTime = nil
        totalPausedDuration = 0
    }

    // MARK: - Private Methods

    private func startWorkPeriod(duration: TimeInterval) async {
        logger.info("Starting work period")

        state = .work(remaining: duration)
        startTime = Date()

        onWorkStart?()
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
        switch state {
        case .work(let remaining):
            let newRemaining = remaining - 1

            if newRemaining <= 0 {
                await handleWorkComplete()
            } else {
                state = .work(remaining: newRemaining)
            }

        case .idle, .paused, .shortBreak, .longBreak:
            // These states don't need updates or are handled elsewhere
            break
        }
    }

    private func handleWorkComplete() async {
        logger.info("Work period completed")

        timer?.invalidate()
        timer = nil

        onWorkEnd?()
        onTimerComplete?()

        state = .idle
    }
}
