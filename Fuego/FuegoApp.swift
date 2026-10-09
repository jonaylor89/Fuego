import AppKit
import SwiftUI

@main
struct FuegoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var core: FuegoCore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Unit tests use this app as their host; they build their own FuegoCore with fakes.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let core = FuegoCore(blockingEngine: BlockingEngine(filter: ContentFilterController()))
        self.core = core

        popover.contentSize = NSSize(width: 280, height: 360)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: DashboardView().environmentObject(core))

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Fuego")
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.setAccessibilityIdentifier("fuego.statusItem")
        }
        self.statusItem = statusItem

        Task { await core.refreshFilterStatus() }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let core else { return .terminateNow }
        Task {
            await core.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
