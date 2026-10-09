import AppKit
import Combine
import Foundation
import Testing

@testable import Fuego

// MARK: - Test doubles

@MainActor
final class FakeContentFilter: ContentFilterControlling {
    @Published private(set) var status: FilterStatus = .ready
    var statusPublisher: AnyPublisher<FilterStatus, Never> { $status.eraseToAnyPublisher() }

    private(set) var filteredDomains: Set<String>?
    private(set) var installCount = 0
    var installError: Error?

    func install() async throws {
        installCount += 1
        if let installError { throw installError }
        status = .ready
    }

    func startFiltering(blockedDomains: Set<String>) async throws {
        filteredDomains = blockedDomains
        status = .filtering
    }

    func stopFiltering() async throws {
        filteredDomains = nil
        status = .ready
    }

    func refreshStatus() async {}
}

@MainActor
func makeCore(
    websites: Set<String> = ["reddit.com"],
    apps: Set<String> = [],
    duration: TimeInterval = 25 * 60,
    tickInterval: TimeInterval = 1
) async throws -> (FuegoCore, FakeContentFilter) {
    let defaults = UserDefaults(suiteName: "FuegoTests-\(UUID().uuidString)")!
    let filter = FakeContentFilter()
    let core = FuegoCore(
        blockingEngine: BlockingEngine(filter: filter),
        settingsManager: SettingsManager(userDefaults: defaults, applyLaunchAtLogin: { _ in }),
        timerEngine: TimerEngine(tickInterval: tickInterval))
    var settings = core.settings
    settings.blockedWebsites = websites
    settings.blockedApplications = apps
    settings.timerDuration = duration
    try await core.updateSettings(settings)
    return (core, filter)
}

@MainActor
func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return condition()
}

// MARK: - Domain matching

struct DomainMatcherTests {
    @Test(arguments: [
        ("reddit.com", "reddit.com"),
        ("https://www.Reddit.com/r/swift", "reddit.com"),
        ("http://news.ycombinator.com:443/item?id=1", "news.ycombinator.com"),
        ("  YouTube.com.  ", "youtube.com"),
    ])
    func normalizesUserInput(input: String, expected: String) {
        #expect(DomainMatcher.normalize(input) == expected)
    }

    @Test(arguments: ["", "   ", "localhost", "not a domain"])
    func rejectsInvalidInput(input: String) {
        #expect(DomainMatcher.normalize(input) == nil)
    }

    @Test func matchesDomainsAndSubdomains() {
        let blocked: Set<String> = ["reddit.com", "x.com"]
        #expect(DomainMatcher.isBlocked(host: "reddit.com", blockedDomains: blocked))
        #expect(DomainMatcher.isBlocked(host: "www.reddit.com", blockedDomains: blocked))
        #expect(DomainMatcher.isBlocked(host: "old.REDDIT.com.", blockedDomains: blocked))
        #expect(DomainMatcher.isBlocked(host: "api.x.com", blockedDomains: blocked))
    }

    @Test func doesNotMatchLookalikes() {
        let blocked: Set<String> = ["reddit.com", "x.com"]
        #expect(!DomainMatcher.isBlocked(host: "notreddit.com", blockedDomains: blocked))
        #expect(!DomainMatcher.isBlocked(host: "reddit.com.evil.net", blockedDomains: blocked))
        #expect(!DomainMatcher.isBlocked(host: "box.com", blockedDomains: blocked))
        #expect(!DomainMatcher.isBlocked(host: "github.com", blockedDomains: []))
    }

    @Test func vendorConfigurationRoundTrips() {
        let config = FilterVendorConfiguration.make(blockedDomains: ["reddit.com", "x.com"])
        // The system hands vendorConfiguration to the extension as a plist; make sure it survives.
        let data = try! PropertyListSerialization.data(fromPropertyList: config, format: .binary, options: 0)
        let decoded = try! PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        #expect(FilterVendorConfiguration.blockedDomains(from: decoded) == ["reddit.com", "x.com"])
        #expect(FilterVendorConfiguration.blockedDomains(from: nil).isEmpty)
    }
}

// MARK: - Session lifecycle

@MainActor
struct SessionLifecycleTests {
    @Test func startPauseResumeEnd() async throws {
        let (core, filter) = try await makeCore(websites: ["reddit.com", "x.com"])

        try await core.startSession()
        #expect(core.currentSession != nil)
        #expect(core.isBlocked)
        #expect(filter.filteredDomains == ["reddit.com", "x.com"])
        guard case .work = core.timerState else {
            Issue.record("timer should be running, got \(core.timerState)")
            return
        }

        try await core.pauseSession()
        #expect(!core.isBlocked)
        #expect(filter.filteredDomains == nil)
        guard case .paused = core.timerState else {
            Issue.record("timer should be paused, got \(core.timerState)")
            return
        }

        try await core.resumeSession()
        #expect(core.isBlocked)
        #expect(filter.filteredDomains == ["reddit.com", "x.com"])

        try await core.endSession()
        #expect(core.currentSession == nil)
        #expect(!core.isBlocked)
        #expect(filter.filteredDomains == nil)
        #expect(core.timerState == .idle)
    }

    @Test func timerCompletionEndsSessionAndUnblocks() async throws {
        let (core, filter) = try await makeCore(duration: 0.5, tickInterval: 0.05)

        try await core.startSession()
        #expect(filter.filteredDomains == ["reddit.com"])

        #expect(await waitUntil { core.currentSession == nil })
        #expect(await waitUntil { !core.isBlocked })
        #expect(filter.filteredDomains == nil)
        #expect(core.timerState == .idle)
    }

    @Test func emptyBlocklistDoesNotEnableFilter() async throws {
        let (core, filter) = try await makeCore(websites: [])
        try await core.startSession()
        #expect(core.isBlocked)
        #expect(filter.filteredDomains == nil)
        try await core.endSession()
    }

    @Test func editingBlocklistDuringSessionUpdatesFilter() async throws {
        let (core, filter) = try await makeCore(websites: ["reddit.com"])
        try await core.startSession()

        var settings = core.settings
        settings.blockedWebsites.insert("youtube.com")
        try await core.updateSettings(settings)
        #expect(filter.filteredDomains == ["reddit.com", "youtube.com"])

        try await core.endSession()
    }

    @Test func installErrorIsSurfaced() async throws {
        let (core, filter) = try await makeCore()
        filter.installError = NSError(
            domain: "OSSystemExtensionErrorDomain", code: 8,
            userInfo: [NSLocalizedDescriptionKey: "extension not approved"])
        await core.installContentFilter()
        #expect(core.lastError == "extension not approved")
    }
}

// MARK: - Settings

@MainActor
struct SettingsTests {
    @Test func settingsPersistAcrossLaunches() throws {
        let suite = "FuegoTests-\(UUID().uuidString)"
        var launchAtLoginCalls: [Bool] = []
        let manager = SettingsManager(
            userDefaults: UserDefaults(suiteName: suite)!,
            applyLaunchAtLogin: { launchAtLoginCalls.append($0) })
        #expect(manager.settings == FuegoSettings())
        #expect(manager.settings.launchAtLogin == false)

        var settings = manager.settings
        settings.blockedWebsites = ["reddit.com"]
        settings.blockedApplications = ["Slack"]
        settings.timerDuration = 50 * 60
        settings.launchAtLogin = true
        try manager.saveSettings(settings)
        #expect(launchAtLoginCalls == [true])

        let reloaded = SettingsManager(
            userDefaults: UserDefaults(suiteName: suite)!, applyLaunchAtLogin: { _ in })
        #expect(reloaded.settings == settings)
    }
}

// MARK: - App blocking (launches a real app)

@MainActor
@Suite(.serialized)
struct AppBlockingIntegrationTests {
    static let appURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
    static let bundleID = "com.apple.TextEdit"

    func runningTextEdit() -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID)
    }

    func launchTextEdit() async throws -> NSRunningApplication {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = false
        return try await NSWorkspace.shared.openApplication(at: Self.appURL, configuration: configuration)
    }

    func quitTextEdit() async {
        runningTextEdit().forEach { $0.forceTerminate() }
        _ = await waitUntil { runningTextEdit().isEmpty }
    }

    @Test func quitsBlockedAppsAlreadyRunningAndOnLaunch() async throws {
        await quitTextEdit()
        let (core, _) = try await makeCore(websites: [], apps: ["TextEdit"])

        _ = try await launchTextEdit()
        #expect(await waitUntil { !runningTextEdit().isEmpty })

        try await core.startSession()
        #expect(await waitUntil(timeout: 10) { runningTextEdit().isEmpty }, "running app should be quit")

        _ = try await launchTextEdit()
        #expect(await waitUntil(timeout: 10) { runningTextEdit().isEmpty }, "relaunched app should be quit")

        try await core.endSession()
        _ = try await launchTextEdit()
        try await Task.sleep(for: .seconds(2))
        #expect(!runningTextEdit().isEmpty, "app should stay open after the session ends")

        await quitTextEdit()
    }

    @Test func matchesByBundleIdentifierCaseInsensitively() async throws {
        await quitTextEdit()
        let blocker = AppBlocker()
        blocker.start(blocking: ["COM.APPLE.TEXTEDIT"])
        defer { blocker.stop() }

        _ = try await launchTextEdit()
        #expect(await waitUntil(timeout: 10) { runningTextEdit().isEmpty })
        #expect(blocker.isBlocking)
    }
}
