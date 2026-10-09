import Combine
import Foundation
import Logging

/// Countdown timer for a focus session. Remaining time is derived from a deadline so it
/// stays accurate even if ticks are delayed (App Nap, sleep).
@MainActor
final class TimerEngine: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.timer")

    @Published private(set) var state: TimerState = .idle

    var onTimerComplete: (() -> Void)?

    private var timer: Timer?
    private var deadline: Date?
    private let tickInterval: TimeInterval

    init(tickInterval: TimeInterval = 1) {
        self.tickInterval = tickInterval
    }

    func start(duration: TimeInterval) {
        logger.info("Starting timer for \(duration) seconds")
        deadline = Date().addingTimeInterval(duration)
        state = .work(remaining: duration)
        scheduleTicks()
    }

    func pause() {
        guard case .work = state else { return }
        tick()
        guard case .work = state else { return }
        invalidateTimer()
        deadline = nil
        state = .paused(state)
    }

    func resume() {
        guard case .paused(let pausedState) = state else { return }
        deadline = Date().addingTimeInterval(pausedState.remainingTime)
        state = pausedState
        scheduleTicks()
    }

    func stop() {
        invalidateTimer()
        deadline = nil
        state = .idle
    }

    private func scheduleTicks() {
        invalidateTimer()
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let deadline, case .work = state else { return }
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            logger.info("Focus period completed")
            stop()
            onTimerComplete?()
        } else {
            state = .work(remaining: remaining.rounded(.up))
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
}
