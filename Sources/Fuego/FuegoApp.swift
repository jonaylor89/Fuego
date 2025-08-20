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

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var fuegoCore: FuegoCore?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupCore()
        
        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Fuego")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        setupPopover()
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 480)
        popover?.behavior = .transient
        
        // Create the core first if needed
        if fuegoCore == nil {
            Task { @MainActor in
                fuegoCore = FuegoCore()
                await setupPopoverContent()
            }
        } else {
            Task { @MainActor in
                await setupPopoverContent()
            }
        }
    }
    
    @MainActor
    private func setupPopoverContent() async {
        popover?.contentViewController = NSHostingController(
            rootView: DashboardView()
                .environmentObject(fuegoCore!)
        )
    }
    
    @MainActor
    private func setupCore() {
        fuegoCore = FuegoCore()
        
        // Run persistence test for debugging
        #if DEBUG
        // Test removed for simplicity
        #endif
    }
    
    @objc private func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(sender)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                popover?.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        fuegoCore?.shutdown()
    }
}