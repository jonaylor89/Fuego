import AppKit
import Combine
import Foundation
import Logging

/// Turns website and app blocking on and off for a focus session.
@MainActor
final class BlockingEngine: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.blocking")

    @Published private(set) var isActive = false

    let filter = FilterController()
    private let appBlocker = AppBlocker()

    /// Blocks `websites` and `applications` until `until`.
    /// Website blocking needs the content filter to be set up; this sets it up if it isn't.
    func block(websites: Set<String>, applications: Set<String>, until: Date) async throws {
        if !websites.isEmpty {
            if filter.status != .ready {
                try await filter.setUp()
            }
            try await filter.apply(FilterPolicy(blockedDomains: websites, blockUntil: until))
        }
        appBlocker.start(blocking: applications)
        isActive = true
        logger.info("Blocking \(websites.count) sites and \(applications.count) apps")
    }

    func unblock() async {
        appBlocker.stop()
        if filter.status == .ready {
            do {
                try await filter.apply(.off)
            } catch {
                logger.error("Failed to clear filter policy: \(error)")
            }
        }
        isActive = false
        logger.info("Blocking stopped")
    }
}

// MARK: - App Blocking

/// Quits blocked apps and keeps them from staying open while blocking is on.
@MainActor
final class AppBlocker {
    private let logger = Logger(label: "dev.getfuego.appblocking")
    private var blockedApps: Set<String> = []
    private var workspaceObservers: [NSObjectProtocol] = []

    func start(blocking apps: Set<String>) {
        stop()
        blockedApps = Set(apps.map { $0.lowercased() })
        guard !blockedApps.isEmpty else { return }

        // Activation catches anything that slipped past the launch check
        let notifications = [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didActivateApplicationNotification]
        workspaceObservers = notifications.map { name in
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { return }
                MainActor.assumeIsolated { self?.quitIfBlocked(app) }
            }
        }
        NSWorkspace.shared.runningApplications.forEach(quitIfBlocked)
    }

    func stop() {
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers = []
        blockedApps = []
    }

    /// Matches on app name ("Discord") or bundle identifier ("com.hnc.Discord").
    private func quitIfBlocked(_ app: NSRunningApplication) {
        let names = [app.localizedName, app.bundleIdentifier].compactMap { $0?.lowercased() }
        guard names.contains(where: blockedApps.contains) else { return }

        logger.info("Quitting blocked app: \(app.localizedName ?? "unknown")")
        Task { await quit(app) }
    }

    /// A just-launched app ignores quit requests until it finishes launching, so keep asking for a few seconds.
    private func quit(_ app: NSRunningApplication) async {
        for _ in 0..<20 where !app.isTerminated && !blockedApps.isEmpty {
            if app.isFinishedLaunching {
                app.terminate()
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }
}
