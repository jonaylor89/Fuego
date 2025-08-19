import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var settings: FuegoSettings
    @State private var showingPasswordSetup = false
    @State private var tempPassword = ""
    
    init() {
        _settings = State(initialValue: FuegoSettings())
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // General Settings
                generalSection
                
                // Notifications
                notificationSection
                
                // Security
                securitySection
                
                // Appearance
                appearanceSection
                
                // Hotkeys
                hotkeysSection
                
                // About
                aboutSection
            }
            .padding()
        }
    }
    
    private var generalSection: some View {
        SettingsSection(title: "General") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _ in
                        saveSettings()
                    }
                
                HStack {
                    Text("Menu bar icon")
                    Spacer()
                    Picker("Menu bar icon", selection: $settings.appearance.menuBarIcon) {
                        ForEach(MenuBarIcon.allCases, id: \.self) { icon in
                            HStack {
                                Image(systemName: icon.rawValue)
                                Text(icon.displayName)
                            }
                            .tag(icon)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 120)
                    .onChange(of: settings.appearance.menuBarIcon) { _ in
                        saveSettings()
                    }
                }
                
                Toggle("Show time in menu bar", isOn: $settings.appearance.showTimeInMenuBar)
                    .onChange(of: settings.appearance.showTimeInMenuBar) { _ in
                        saveSettings()
                    }
            }
        }
    }
    
    private var notificationSection: some View {
        SettingsSection(title: "Notifications") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Session start", isOn: $settings.notifications.sessionStart)
                Toggle("Session end", isOn: $settings.notifications.sessionEnd)
                Toggle("Timer break start", isOn: $settings.notifications.timerBreakStart)
                Toggle("Timer break end", isOn: $settings.notifications.timerBreakEnd)
                Toggle("Sound notifications", isOn: $settings.notifications.soundEnabled)
            }
            .onChange(of: settings.notifications) { _ in
                saveSettings()
            }
        }
    }
    
    private var securitySection: some View {
        SettingsSection(title: "Security & Privacy") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Password protect settings", isOn: $settings.security.passwordProtected)
                    .onChange(of: settings.security.passwordProtected) { enabled in
                        if enabled && settings.security.passwordHash == nil {
                            showingPasswordSetup = true
                        } else if !enabled {
                            settings.security.passwordHash = nil
                            saveSettings()
                        }
                    }
                
                if settings.security.passwordProtected {
                    Toggle("Locked mode (prevent quitting during sessions)", 
                           isOn: $settings.security.lockedModeEnabled)
                        .onChange(of: settings.security.lockedModeEnabled) { _ in
                            saveSettings()
                        }
                    
                    Toggle("Require password to quit app", 
                           isOn: $settings.security.requirePasswordToQuit)
                        .onChange(of: settings.security.requirePasswordToQuit) { _ in
                            saveSettings()
                        }
                    
                    Button("Change Password") {
                        showingPasswordSetup = true
                    }
                    .font(.caption)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Fuego stores all data locally on your device. No telemetry or analytics are collected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Export Data") {
                            exportUserData()
                        }
                        .font(.caption)
                        
                        Button("Reset All Data") {
                            resetAllData()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPasswordSetup) {
            PasswordSetupView { password in
                settings.security.passwordHash = hashPassword(password)
                saveSettings()
                showingPasswordSetup = false
            }
        }
    }
    
    private var appearanceSection: some View {
        SettingsSection(title: "Appearance") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Theme")
                    Spacer()
                    Picker("Theme", selection: $settings.appearance.theme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 200)
                    .onChange(of: settings.appearance.theme) { _ in
                        saveSettings()
                    }
                }
            }
        }
    }
    
    private var hotkeysSection: some View {
        SettingsSection(title: "Keyboard Shortcuts") {
            VStack(alignment: .leading, spacing: 12) {
                HotkeyRow(
                    label: "Toggle Session",
                    shortcut: $settings.globalHotkeys.toggleSession
                )
                
                HotkeyRow(
                    label: "Instant Work Mode",
                    shortcut: $settings.globalHotkeys.instantWork
                )
                
                HotkeyRow(
                    label: "Show Dashboard",
                    shortcut: $settings.globalHotkeys.showDashboard
                )
            }
            .onChange(of: settings.globalHotkeys) { _ in
                saveSettings()
            }
        }
    }
    
    private var aboutSection: some View {
        SettingsSection(title: "About Fuego") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fuego")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("A powerful, open-source productivity app for macOS focused on helping you maintain focus through website blocking, app blocking, and Pomodoro timers.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Button("GitHub Repository") {
                        openURL("https://github.com/yourname/fuego")
                    }
                    .font(.caption)
                    
                    Button("Report Issue") {
                        openURL("https://github.com/yourname/fuego/issues")
                    }
                    .font(.caption)
                    
                    Button("Donate") {
                        openURL("https://github.com/sponsors/yourname")
                    }
                    .font(.caption)
                }
            }
        }
    }
    
    private func saveSettings() {
        core.settingsManager.saveSettings(settings)
    }
    
    private func exportUserData() {
        // Implementation for exporting user data
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "fuego-export.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            core.persistenceManager.exportData(to: url)
        }
    }
    
    private func resetAllData() {
        let alert = NSAlert()
        alert.messageText = "Reset All Data"
        alert.informativeText = "This will permanently delete all your profiles, statistics, and settings. This action cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            core.persistenceManager.resetAllData()
            settings = FuegoSettings() // Reset to defaults
        }
    }
    
    private func hashPassword(_ password: String) -> String {
        // Simple hash for demo - use proper crypto in production
        return password.data(using: .utf8)?.base64EncodedString() ?? ""
    }
    
    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct HotkeyRow: View {
    let label: String
    @Binding var shortcut: String?
    @State private var isRecording = false
    @State private var currentShortcut = ""
    
    var body: some View {
        HStack {
            Text(label)
            
            Spacer()
            
            Button(action: {
                if isRecording {
                    // Cancel recording
                    isRecording = false
                    currentShortcut = ""
                } else {
                    // Start recording
                    isRecording = true
                    currentShortcut = ""
                }
            }) {
                Text(isRecording ? "Press keys..." : (shortcut ?? "Not set"))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.accentColor.opacity(0.3) : Color(.controlBackgroundColor))
                    .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            
            if shortcut != nil {
                Button(action: {
                    shortcut = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct PasswordSetupView: View {
    let onComplete: (String) -> Void
    
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set Password")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Password")
                    .font(.subheadline)
                SecureField("Enter password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Confirm Password")
                    .font(.subheadline)
                SecureField("Confirm password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if showError {
                    Text("Passwords do not match")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Set Password") {
                    if password == confirmPassword && !password.isEmpty {
                        onComplete(password)
                    } else {
                        showError = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300, height: 250)
    }
}

// MARK: - Extensions

extension MenuBarIcon {
    var displayName: String {
        switch self {
        case .flame: return "Flame"
        case .circle: return "Circle"
        case .square: return "Square"
        case .shield: return "Shield"
        }
    }
}

extension AppTheme {
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}