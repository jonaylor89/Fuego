import Combine
import Foundation
import Logging

/// Simple countdown timer for a focus session
@MainActor
class TimerEngine: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.timer")

    @Published var state: TimerState = .idle

    private var timer: Timer?
    /// Counting against a wall-clock end date keeps the timer right across sleep,
    /// and in step with the filter's own cutoff.
    private var endDate: Date?

    var onTimerComplete: (() -> Void)?

    // MARK: - Public Interface

    func start(duration: TimeInterval) {
        logger.info("Starting timer for \(duration) seconds")
        endDate = Date().addingTimeInterval(duration)
        state = .work(remaining: duration)
        scheduleTicks()
    }

    func pause() {
        guard case .work = state else { return }
        logger.info("Pausing timer")
        tick()
        state = .paused(state)
        endDate = nil
        cancelTicks()
    }

    func resume() {
        guard case .paused(let pausedState) = state else { return }
        logger.info("Resuming timer")
        endDate = Date().addingTimeInterval(pausedState.remainingTime)
        state = pausedState
        scheduleTicks()
    }

    func stop() {
        logger.info("Stopping timer")
        cancelTicks()
        endDate = nil
        state = .idle
    }

    // MARK: - Private Methods

    private func scheduleTicks() {
        cancelTicks()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)  // keep ticking while menus are open
        self.timer = timer
    }

    private func cancelTicks() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let endDate, case .work = state else { return }
        let remaining = endDate.timeIntervalSinceNow.rounded()
        if remaining <= 0 {
            logger.info("Work period completed")
            stop()
            onTimerComplete?()
        } else {
            state = .work(remaining: remaining)
        }
    }
}
