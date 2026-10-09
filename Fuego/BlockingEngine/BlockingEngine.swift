import AppKit
import Combine
import Foundation
import Logging

/// Applies website and app blocking for a focus session.
@MainActor
final class BlockingEngine: ObservableObject {
    private let logger = Logger(label: "dev.getfuego.blocking")

    @Published private(set) var isActive = false
    @Published private(set) var blockedWebsites: Set<String> = []

    let filter: ContentFilterControlling
    let appBlocker: AppBlocker

    init(filter: ContentFilterControlling, appBlocker: AppBlocker? = nil) {
        self.filter = filter
        self.appBlocker = appBlocker ?? AppBlocker()
    }

    func apply(websites: Set<String>, apps: Set<String>) async throws {
        logger.info("Applying blocking rules: \(websites.count) sites, \(apps.count) apps")

        appBlocker.start(blocking: apps)
        blockedWebsites = websites
        isActive = true

        if websites.isEmpty {
            try await filter.stopFiltering()
        } else {
            try await filter.startFiltering(blockedDomains: websites)
        }
    }

    func disable() async {
        logger.info("Disabling blocking")
        appBlocker.stop()
        blockedWebsites = []
        isActive = false

        do {
            try await filter.stopFiltering()
        } catch {
            logger.error("Failed to stop content filter: \(error.localizedDescription)")
        }
    }
}

// MARK: - App Blocking

/// Quits blocked apps that are running, and any that launch while blocking is on.
@MainActor
final class AppBlocker {
    private let logger = Logger(label: "dev.getfuego.appblocking")
    private let workspace: NSWorkspace
    private var blockedApps: Set<String> = []
    private var launchObserver: NSObjectProtocol?

    init(workspace: NSWorkspace? = nil) {
        self.workspace = workspace ?? .shared
    }

    var isBlocking: Bool { launchObserver != nil }

    func start(blocking apps: Set<String>) {
        stop()
        blockedApps = Set(apps.map { $0.lowercased() })
        guard !blockedApps.isEmpty else { return }

        // App launch notifications are only posted on NSWorkspace's notification center.
        launchObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
            else { return }
            MainActor.assumeIsolated { self?.quitLaunchedApp(app) }
        }

        workspace.runningApplications.forEach(terminateIfBlocked)
    }

    func stop() {
        if let launchObserver {
            workspace.notificationCenter.removeObserver(launchObserver)
        }
        launchObserver = nil
        blockedApps = []
    }

    func isBlocked(_ app: NSRunningApplication) -> Bool {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
        let names = [app.localizedName, app.bundleIdentifier].compactMap { $0?.lowercased() }
        return names.contains(where: blockedApps.contains)
    }

    /// Apps often ignore a quit request while they're still starting up, so keep asking
    /// and force-quit if they're still open after a few seconds. A just-launched app has no
    /// unsaved work to lose.
    private func quitLaunchedApp(_ app: NSRunningApplication) {
        guard isBlocked(app) else { return }
        terminateIfBlocked(app)
        Task { [weak self] in
            for _ in 0..<6 {
                try? await Task.sleep(for: .milliseconds(500))
                guard !app.isTerminated, self?.isBlocking == true else { return }
                app.terminate()
            }
            if !app.isTerminated, self?.isBlocking == true {
                app.forceTerminate()
            }
        }
    }

    private func terminateIfBlocked(_ app: NSRunningApplication) {
        guard isBlocked(app) else { return }
        logger.info("Quitting blocked app: \(app.localizedName ?? app.bundleIdentifier ?? "unknown")")
        app.terminate()
    }
}
