import SwiftUI
import AppKit

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
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let fuegoCore = FuegoCore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !DEBUG
        // macOS only installs the content filter for apps in /Applications. Opening Fuego
        // from the disk image or Downloads runs it from a temporary copy instead.
        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else {
            askToMoveToApplications()
            return
        }
        #endif
        setupMenuBar()
        UpdateController.shared.startIfConfigured()
        Task { await fuegoCore.start() }
    }

    private func askToMoveToApplications() {
        let alert = NSAlert()
        alert.messageText = "Move Fuego to Applications"
        alert.informativeText = "Fuego can only block websites when it runs from your Applications folder. Drag Fuego into Applications, then open it from there."
        alert.addButton(withTitle: "Quit")
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Fuego")
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.contentSize = NSSize(width: 280, height: 360)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: DashboardView()
                .environmentObject(fuegoCore)
        )
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        if UpdateController.shared.isAvailable {
            let updates = menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
            updates.target = self
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Quit Fuego", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil  // so left clicks open the popover again
    }

    @objc private func checkForUpdates() {
        UpdateController.shared.checkForUpdates()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // End the session first so websites aren't left blocked after quitting
        Task {
            await fuegoCore.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
