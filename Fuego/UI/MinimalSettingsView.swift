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

                                Button("open settings") {
                                    openNetworkExtensionSettings()
                                }
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .buttonStyle(.plain)
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
            try await core.requestNetworkExtensionSetup()

            // Wait for status to update
            try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            await core.blockingEngine.checkExtensionStatus()

            DispatchQueue.main.async {
                let alert = NSAlert()
                if self.core.networkExtensionStatus == "Active" {
                    alert.messageText = "Network Extension Setup Complete"
                    alert.informativeText =
                        "The Network Extension is now configured and ready to use."
                    alert.alertStyle = .informational
                } else {
                    alert.messageText = "Network Extension Setup"
                    alert.informativeText = """
                        Extension setup initiated. If it doesn't appear in System Settings:

                        1. Wait 30 seconds and check again
                        2. Try the "force register" button
                        3. Check System Settings → General → Login Items & Extensions
                        4. Look for "Fuego Content Filter" under Network Extensions
                        """
                    alert.alertStyle = .warning
                }
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Network Extension Setup Failed"
                alert.informativeText =
                    "Error: \(error.localizedDescription)\n\nTry using the 'force register' option or check System Settings manually."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
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
