import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var showingCreateProfile = false
    @State private var selectedProfile: Profile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Profiles")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingCreateProfile.toggle()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            // Profile list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(core.profileManager.profiles) { profile in
                        ProfileRowView(
                            profile: profile,
                            isActive: profile.id == core.activeProfile.id,
                            onSelect: {
                                Task {
                                    try await core.switchProfile(profile)
                                }
                            },
                            onEdit: {
                                selectedProfile = profile
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingCreateProfile) {
            ProfileEditView()
                .environmentObject(core)
        }
        .sheet(item: $selectedProfile) { profile in
            ProfileEditView(profile: profile)
                .environmentObject(core)
        }
    }
}

struct ProfileRowView: View {
    let profile: Profile
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile indicator
            Circle()
                .fill(isActive ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)
            
            // Profile info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                        .fontWeight(isActive ? .semibold : .medium)
                    
                    if profile.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }
                
                // Profile summary
                HStack(spacing: 16) {
                    if profile.timerConfig.isEnabled {
                        Label("\(Int(profile.timerConfig.workDuration / 60))m work", 
                              systemImage: "timer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if profile.blockingRules.blockEntireInternet {
                        Label("Full block", systemImage: "wifi.slash")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if !profile.blockingRules.blockedWebsites.isEmpty {
                        Label("\(profile.blockingRules.blockedWebsites.count) sites blocked", 
                              systemImage: "globe.badge.chevron.backward")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if !profile.blockingRules.blockedApplications.isEmpty {
                        Label("\(profile.blockingRules.blockedApplications.count) apps blocked", 
                              systemImage: "app.badge.checkmark")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if !isActive {
                    Button("Use", action: onSelect)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                } else {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.2))
                        .foregroundColor(.accentColor)
                        .cornerRadius(6)
                }
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

struct ProfileEditView: View {
    @EnvironmentObject var core: FuegoCore
    @Environment(\.dismiss) var dismiss
    
    let editingProfile: Profile?
    
    @State private var name: String
    @State private var timerEnabled: Bool
    @State private var workDuration: Double
    @State private var shortBreakDuration: Double
    @State private var longBreakDuration: Double
    @State private var blockEntireInternet: Bool
    @State private var blockedWebsites: String
    @State private var allowedWebsites: String
    @State private var blockedApps: String
    
    init(profile: Profile? = nil) {
        self.editingProfile = profile
        
        _name = State(initialValue: profile?.name ?? "New Profile")
        _timerEnabled = State(initialValue: profile?.timerConfig.isEnabled ?? false)
        _workDuration = State(initialValue: profile?.timerConfig.workDuration ?? 25 * 60)
        _shortBreakDuration = State(initialValue: profile?.timerConfig.shortBreakDuration ?? 5 * 60)
        _longBreakDuration = State(initialValue: profile?.timerConfig.longBreakDuration ?? 15 * 60)
        _blockEntireInternet = State(initialValue: profile?.blockingRules.blockEntireInternet ?? false)
        _blockedWebsites = State(initialValue: profile?.blockingRules.blockedWebsites.joined(separator: "\n") ?? "")
        _allowedWebsites = State(initialValue: profile?.blockingRules.allowedWebsites.joined(separator: "\n") ?? "")
        _blockedApps = State(initialValue: profile?.blockingRules.blockedApplications.joined(separator: "\n") ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text(editingProfile == nil ? "Create Profile" : "Edit Profile")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic info
                    profileBasicSection
                    
                    // Timer settings
                    timerSettingsSection
                    
                    // Blocking settings
                    blockingSettingsSection
                }
            }
            
            // Save button
            HStack {
                Spacer()
                Button("Save Profile") {
                    saveProfile()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 600)
    }
    
    private var profileBasicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Details")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Profile name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    private var timerSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pomodoro Timer")
                .font(.headline)
            
            Toggle("Enable timer", isOn: $timerEnabled)
            
            if timerEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Work Duration: \(Int(workDuration / 60)) minutes")
                            .font(.subheadline)
                        Slider(value: $workDuration, in: 5*60...60*60, step: 5*60)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Short Break: \(Int(shortBreakDuration / 60)) minutes")
                            .font(.subheadline)
                        Slider(value: $shortBreakDuration, in: 1*60...15*60, step: 1*60)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Long Break: \(Int(longBreakDuration / 60)) minutes")
                            .font(.subheadline)
                        Slider(value: $longBreakDuration, in: 10*60...30*60, step: 5*60)
                    }
                }
                .padding(.leading)
            }
        }
    }
    
    private var blockingSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Blocking Rules")
                .font(.headline)
            
            Toggle("Block entire internet", isOn: $blockEntireInternet)
            
            if !blockEntireInternet {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blocked Websites")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("One domain per line (e.g., facebook.com)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $blockedWebsites)
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            if blockEntireInternet {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allowed Websites")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Essential sites that remain accessible")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $allowedWebsites)
                        .frame(height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Blocked Applications")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Bundle IDs (e.g., com.apple.Safari)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $blockedApps)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
    
    private func saveProfile() {
        let profile: Profile
        
        if let editingProfile = editingProfile {
            profile = editingProfile
        } else {
            profile = Profile(name: name)
        }
        
        // Update profile properties
        var updatedProfile = profile
        updatedProfile.name = name
        
        // Timer configuration
        updatedProfile.timerConfig.isEnabled = timerEnabled
        updatedProfile.timerConfig.workDuration = workDuration
        updatedProfile.timerConfig.shortBreakDuration = shortBreakDuration
        updatedProfile.timerConfig.longBreakDuration = longBreakDuration
        
        // Blocking rules
        updatedProfile.blockingRules.blockEntireInternet = blockEntireInternet
        updatedProfile.blockingRules.blockedWebsites = Set(blockedWebsites.components(separatedBy: .newlines).compactMap { 
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines)
        })
        updatedProfile.blockingRules.allowedWebsites = Set(allowedWebsites.components(separatedBy: .newlines).compactMap { 
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines)
        })
        updatedProfile.blockingRules.blockedApplications = Set(blockedApps.components(separatedBy: .newlines).compactMap { 
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0.trimmingCharacters(in: .whitespacesAndNewlines)
        })
        
        // Save profile
        core.profileManager.saveProfile(updatedProfile)
    }
}

struct ProfilePickerView: View {
    @EnvironmentObject var core: FuegoCore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Profile")
                .font(.title2)
                .fontWeight(.semibold)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(core.profileManager.profiles) { profile in
                        ProfileRowView(
                            profile: profile,
                            isActive: profile.id == core.activeProfile.id,
                            onSelect: {
                                Task {
                                    try await core.switchProfile(profile)
                                    dismiss()
                                }
                            },
                            onEdit: { }
                        )
                    }
                }
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .padding()
        .frame(width: 350, height: 400)
    }
}