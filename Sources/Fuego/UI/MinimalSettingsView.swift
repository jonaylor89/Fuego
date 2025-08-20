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
                        
                        Slider(value: Binding(
                            get: { settings.timerDuration / 60 },
                            set: { settings.timerDuration = $0 * 60 }
                        ), in: 5...120, step: 5)
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
                            
                            ForEach(Array(settings.blockedWebsites).sorted(), id: \.self) { website in
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
                            
                            ForEach(Array(settings.blockedApplications).sorted(), id: \.self) { app in
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
    
    private func addWebsite() {
        guard !newWebsite.isEmpty else { return }
        let cleanedWebsite = newWebsite
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
