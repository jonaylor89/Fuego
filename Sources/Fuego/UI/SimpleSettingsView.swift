import SwiftUI

struct SimpleSettingsView: View {
    @EnvironmentObject var core: FuegoCore
    @Environment(\.dismiss) private var dismiss
    
    @State private var settings: FuegoSettings
    @State private var newWebsite = ""
    @State private var newApp = ""
    
    init() {
        _settings = State(initialValue: FuegoSettings())
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Form {
                    Section {
                        HStack {
                            Text("Focus Duration")
                            Spacer()
                            Text("\(Int(settings.timerDuration / 60)) minutes")
                                .font(.headline)
                        }
                        
                        Slider(value: Binding(
                            get: { settings.timerDuration / 60 },
                            set: { settings.timerDuration = $0 * 60 }
                        ), in: 5...120, step: 5) {
                            Text("Duration")
                        } minimumValueLabel: {
                            Text("5m")
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("2h")
                                .font(.caption)
                        }
                        
                        HStack {
                            Spacer()
                            Button("Reset to 25 min") {
                                settings.timerDuration = 25 * 60
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                    } header: {
                        Text("Timer Settings")
                    } footer: {
                        Text("Standard Pomodoro technique uses 25-minute focus sessions.")
                    }
                    
                    Section {
                        HStack {
                            TextField("Enter website (e.g., facebook.com)", text: $newWebsite)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addWebsite()
                                }
                            
                            Button("Add") {
                                addWebsite()
                            }
                            .disabled(newWebsite.isEmpty)
                            .buttonStyle(.borderedProminent)
                        }
                        
                        // List of blocked websites
                        ForEach(Array(settings.blockedWebsites).sorted(), id: \.self) { website in
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.red)
                                Text(website)
                                Spacer()
                                Button("Remove") {
                                    settings.blockedWebsites.remove(website)
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                        }
                        
                        if settings.blockedWebsites.isEmpty {
                            Text("No blocked websites")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    } header: {
                        Text("Blocked Websites")
                    } footer: {
                        Text("Enter domain names without 'http://' or 'www.' These sites will be blocked during focus sessions.")
                    }
                    
                    Section {
                        // Add app field
                        HStack {
                            TextField("Enter app name (e.g., Safari)", text: $newApp)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("Add") {
                                if !newApp.isEmpty {
                                    settings.blockedApplications.insert(newApp)
                                    newApp = ""
                                }
                            }
                            .disabled(newApp.isEmpty)
                        }
                        
                        // List of blocked apps
                        ForEach(Array(settings.blockedApplications).sorted(), id: \.self) { app in
                            HStack {
                                Image(systemName: "app")
                                    .foregroundColor(.red)
                                Text(app)
                                Spacer()
                                Button("Remove") {
                                    settings.blockedApplications.remove(app)
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.red)
                            }
                        }
                        
                        if settings.blockedApplications.isEmpty {
                            Text("No blocked applications")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    } header: {
                        Text("Blocked Applications")
                    } footer: {
                        Text("Enter exact app names as they appear in Applications folder. These apps will be quit during focus sessions.")
                    }
                    
                    Section {
                        Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                        
                        Button("Reset All Settings") {
                            settings = FuegoSettings()
                        }
                        .foregroundColor(.red)
                    } header: {
                        Text("General")
                    }
                    
                    Section {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Build")
                            Spacer()
                            Text("1")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Bundle ID")
                            Spacer()
                            Text("com.fuego.focus-app")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("About")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            try? await core.updateSettings(settings)
                            dismiss()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 550, height: 650)
        .onAppear {
            settings = core.settings
        }
    }
}

#Preview {
    SimpleSettingsView()
        .environmentObject(FuegoCore())
}
