import NetworkExtension
import SwiftUI

struct MinimalSettingsView: View {
    @EnvironmentObject var core: FuegoCore
    @Environment(\.dismiss) private var dismiss

    @State private var settings: FuegoSettings
    @State private var newWebsite = ""
    @State private var newApp = ""

    init() {
        _settings = State(initialValue: FuegoSettings())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Minimal header
            HStack {
                Button("cancel") {
                    dismiss()
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)

                Spacer()

                Text("settings")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.light)

                Spacer()

                Button("save") {
                    Task {
                        try? await core.updateSettings(settings)
                        dismiss()
                    }
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            ScrollView {
                VStack(spacing: 32) {
                    // Timer duration
                    VStack(spacing: 16) {
                        HStack {
                            Text("duration")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textCase(.lowercase)

                            Spacer()

                            Text("\(Int(settings.timerDuration / 60))m")
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.ultraLight)
                        }

                        Slider(
                            value: Binding(
                                get: { settings.timerDuration / 60 },
                                set: { settings.timerDuration = $0 * 60 }
                            ), in: 5...120, step: 5
                        )
                        .accentColor(.primary)
                    }

                    Divider()
                        .opacity(0.3)

                    // Blocked websites
                    VStack(spacing: 16) {
                        HStack {
                            Text("blocked sites")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textCase(.lowercase)
                            Spacer()
                        }

                        VStack(spacing: 8) {
                            HStack {
                                TextField("domain.com", text: $newWebsite)
                                    .textFieldStyle(.plain)
                                    .font(.system(.body, design: .monospaced))
                                    .onSubmit { addWebsite() }

                                if !newWebsite.isEmpty {
                                    Button("add") {
                                        addWebsite()
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 4)

                            Rectangle()
                                .fill(.primary)
                                .frame(height: 1)
                                .opacity(0.2)

                            ForEach(Array(settings.blockedWebsites).sorted(), id: \.self) {
                                website in
                                HStack {
                                    Text(website)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Button("×") {
                                        settings.blockedWebsites.remove(website)
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Divider()
                        .opacity(0.3)

                    // Blocked apps
                    VStack(spacing: 16) {
                        HStack {
                            Text("blocked apps")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textCase(.lowercase)
                            Spacer()
                        }

                        VStack(spacing: 8) {
                            HStack {
                                TextField("AppName", text: $newApp)
                                    .textFieldStyle(.plain)
                                    .font(.system(.body, design: .monospaced))
                                    .onSubmit { addApp() }

                                if !newApp.isEmpty {
                                    Button("add") {
                                        addApp()
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.bottom, 4)

                            Rectangle()
                                .fill(.primary)
                                .frame(height: 1)
                                .opacity(0.2)

                            ForEach(Array(settings.blockedApplications).sorted(), id: \.self) {
                                app in
                                HStack {
                                    Text(app)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)

                                    Spacer()

                                    Button("×") {
                                        settings.blockedApplications.remove(app)
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Divider()
                        .opacity(0.3)

                    // Network Extension
                    VStack(spacing: 16) {
                        HStack {
                            Text("network blocking")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textCase(.lowercase)
                            Spacer()
                        }

                        HStack {
                            Text("status")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)

                            Spacer()

                            Text(core.networkExtensionStatus)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        if core.networkExtensionStatus == "Not Configured"
                            || core.networkExtensionStatus == "Unknown"
                        {
                            VStack(spacing: 8) {
                                HStack {
                                    Button("setup extension") {
                                        Task {
                                            await setupNetworkExtensionWithFeedback()
                                        }
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .buttonStyle(.plain)

                                    Spacer()

                                    Button("force register") {
                                        Task {
                                            await forceRegisterExtension()
                                        }
                                    }
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.orange)
                                    .buttonStyle(.plain)
                                }

                                Text(
                                    "extension must be set up before it appears in System Settings"
                                )
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // Test Network Extension
                        VStack(spacing: 8) {
                            HStack {
                                Button("test blocking") {
                                    testNetworkExtension()
                                }
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .buttonStyle(.plain)

                                Spacer()

                                Button("stop blocking") {
                                    Task {
                                        await core.blockingEngine.disable()
                                    }
                                }
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .buttonStyle(.plain)
                            }

                            HStack {
                                Button("refresh status") {
                                    Task {
                                        await core.blockingEngine.checkExtensionStatus()
                                    }
                                }
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .buttonStyle(.plain)

                                Spacer()

                                Button("debug setup") {
                                    Task {
                                        await debugNetworkExtensionSetup()
                                    }
                                }
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.orange)
                                .buttonStyle(.plain)
                            }

                            HStack {
                                Button("open settings") {
                                    openNetworkExtensionSettings()
                                }
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .buttonStyle(.plain)

                                Spacer()
                            }

                            // Debug info
                            VStack(alignment: .leading, spacing: 4) {
                                Text("debug info:")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Text("• active: \(core.isBlocked ? "yes" : "no")")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)

                                Text(
                                    "• blocked sites: \(core.blockingEngine.currentBlockedWebsites.count)"
                                )
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)

                                if core.networkExtensionStatus == "Not Configured" {
                                    Text(
                                        "• go to: System Settings → General → Login Items & Extensions → Network Extensions"
                                    )
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.orange)
                                }

                                Text("• extension status: \(core.networkExtensionStatus)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }

                    Divider()
                        .opacity(0.3)

                    // Options
                    VStack(spacing: 16) {
                        HStack {
                            Text("options")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textCase(.lowercase)
                            Spacer()
                        }

                        HStack {
                            Text("launch at login")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)

                            Spacer()

                            Toggle("", isOn: $settings.launchAtLogin)
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                        }

                        HStack {
                            Button("reset all") {
                                settings = FuegoSettings()
                            }
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(width: 320, height: 480)
        .background(.regularMaterial)
        .onAppear {
            settings = core.settings
        }
    }

    private func openNetworkExtensionSettings() {
        // Open the Login Items & Extensions settings in System Settings (macOS Sequoia)
        if let url = URL(
            string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        {
            NSWorkspace.shared.open(url)
        }
    }

    private func setupNetworkExtensionWithFeedback() async {
        do {
            // Use the simplified Network Extension approach
            if let blockingEngine = core.blockingEngine as? NetworkExtensionBlockingEngine {
                try await blockingEngine.networkExtension.setupWithUserGuidance()
            } else {
                try await core.requestNetworkExtensionSetup()
            }

            // Wait for status to update
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
            await core.blockingEngine.checkExtensionStatus()

        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Network Extension Setup Failed"
                alert.informativeText =
                    "Error: \(error.localizedDescription)\n\nTry the following:\n• Check System Settings → General → Login Items & Extensions → Network Extensions\n• Look for 'Fuego Content Filter' and enable it\n• Restart the app if needed"
                alert.alertStyle = .critical
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "OK")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
                    {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    private func forceRegisterExtension() async {
        // Force registration by directly calling NEFilterManager
        do {
            let manager = NEFilterManager.shared()
            try await manager.loadFromPreferences()

            // Create configuration if it doesn't exist
            if manager.providerConfiguration == nil {
                let configuration = NEFilterProviderConfiguration()
                configuration.username = "Fuego User"
                configuration.organization = "Fuego Focus App"
                configuration.filterSockets = true
                configuration.filterPackets = false
                configuration.vendorConfiguration = [:]

                manager.providerConfiguration = configuration
                manager.localizedDescription = "Fuego Content Filter"
                manager.isEnabled = true

                try await manager.saveToPreferences()

                // Wait longer for system to process
                try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
            }

            await core.blockingEngine.checkExtensionStatus()

            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Force Registration Complete"
                alert.informativeText = """
                    Attempted to force register the Network Extension.

                    Current status: \(self.core.networkExtensionStatus)

                    If still not visible, try:
                    • Restart the app
                    • Check Console.app for error logs
                    • Verify code signing is working
                    """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Force Registration Failed"
                alert.informativeText = "Error: \(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    private func debugNetworkExtensionSetup() async {
        print("🔧 DEBUG: Starting Network Extension setup debug...")

        do {
            // Direct access to the network extension manager
            let manager = NEFilterManager.shared()
            print("🔧 DEBUG: Got NEFilterManager instance")

            // Load preferences first
            try await manager.loadFromPreferences()
            print("🔧 DEBUG: Loaded preferences")
            print("🔧 DEBUG: Current isEnabled: \(manager.isEnabled)")
            print("🔧 DEBUG: Has configuration: \(manager.providerConfiguration != nil)")

            if let config = manager.providerConfiguration {
                print("🔧 DEBUG: Existing config: \(config)")
            }

            // Create a new configuration manually
            print("🔧 DEBUG: Creating new NEFilterProviderConfiguration...")
            let configuration = NEFilterProviderConfiguration()
            configuration.username = "Fuego User"
            configuration.organization = "Fuego Focus App"
            configuration.filterSockets = true
            configuration.filterPackets = false
            configuration.vendorConfiguration = [:]
            print("🔧 DEBUG: Configuration created")

            manager.providerConfiguration = configuration
            manager.localizedDescription = "Fuego Content Filter"
            manager.isEnabled = true

            print("🔧 DEBUG: Configuration assigned to manager")
            print("🔧 DEBUG: Manager isEnabled: \(manager.isEnabled)")
            print("🔧 DEBUG: Manager description: \(manager.localizedDescription ?? "nil")")

            // Try to save to preferences
            print("🔧 DEBUG: Attempting to save to preferences...")
            try await manager.saveToPreferences()
            print("🔧 DEBUG: ✅ saveToPreferences() succeeded!")

            // Wait and reload to check if it persisted
            try await Task.sleep(nanoseconds: 2_000_000_000)
            print("🔧 DEBUG: Reloading preferences after save...")
            try await manager.loadFromPreferences()

            print("🔧 DEBUG: After save - isEnabled: \(manager.isEnabled)")
            print("🔧 DEBUG: After save - has config: \(manager.providerConfiguration != nil)")
            print("🔧 DEBUG: After save - description: \(manager.localizedDescription ?? "nil")")

            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Debug Setup Complete"
                alert.informativeText = """
                    ✅ NEFilterManager.saveToPreferences() succeeded!

                    Extension enabled: \(manager.isEnabled)
                    Has config: \(manager.providerConfiguration != nil)

                    Check System Settings → General → Login Items & Extensions → Network Extensions
                    """
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }

        } catch {
            print("🔧 DEBUG: ❌ Setup failed with error: \(error)")
            print("🔧 DEBUG: Error type: \(type(of: error))")
            print("🔧 DEBUG: Error domain: \((error as NSError).domain)")
            print("🔧 DEBUG: Error code: \((error as NSError).code)")
            print("🔧 DEBUG: Error userInfo: \((error as NSError).userInfo)")

            if let neError = error as? NEVPNError {
                print("🔧 DEBUG: NEVPNError code: \((neError as NSError).code)")
                print("🔧 DEBUG: NEVPNError description: \(neError.localizedDescription)")
            }

            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Debug Setup Failed"
                alert.informativeText = """
                    ❌ NEFilterManager.saveToPreferences() failed!

                    Error: \(error.localizedDescription)
                    Domain: \((error as NSError).domain)
                    Code: \((error as NSError).code)

                    Check Xcode console for detailed logs.
                    """
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    private func testNetworkExtension() {
        Task {
            do {
                // First ensure extension is set up
                await setupNetworkExtensionWithFeedback()

                // Wait a moment
                try await Task.sleep(nanoseconds: 1_000_000_000)

                // Apply test blocking rules
                let testDomains: Set<String> = ["example.com", "httpbin.org"]
                try await core.blockingEngine.applyRules(testDomains, [])

                // Show alert with test instructions
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Network Extension Test"
                    alert.informativeText = """
                        Test domains blocked: example.com, httpbin.org

                        Try visiting these sites in Safari:
                        • http://example.com
                        • http://httpbin.org

                        You should see a focus page instead of the actual website.

                        If blocking doesn't work, check Console.app for logs.
                        """
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            } catch {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Network Extension Test Failed"
                    alert.informativeText =
                        "Failed to test network extension: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }

    private func addWebsite() {
        guard !newWebsite.isEmpty else { return }
        let cleanedWebsite =
            newWebsite
            .lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        settings.blockedWebsites.insert(cleanedWebsite)
        newWebsite = ""
    }

    private func addApp() {
        guard !newApp.isEmpty else { return }
        settings.blockedApplications.insert(newApp.trimmingCharacters(in: .whitespacesAndNewlines))
        newApp = ""
    }
}

#Preview {
    MinimalSettingsView()
        .environmentObject(FuegoCore())
}
