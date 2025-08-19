import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var showingProfilePicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current profile section
                profileSection
                
                // Session control section
                sessionControlSection
                
                // Timer display (if active)
                if core.timerState.isActive {
                    timerSection
                }
                
                // Quick actions
                quickActionsSection
                
                // Current session info
                if let session = core.currentSession {
                    currentSessionSection(session)
                }
            }
            .padding(16)
        }
    }
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Active Profile")
                    .font(.headline)
                Spacer()
                Button("Change") {
                    showingProfilePicker.toggle()
                }
                .font(.caption)
            }
            
            ProfileCard(profile: core.activeProfile)
        }
        .sheet(isPresented: $showingProfilePicker) {
            ProfilePickerView()
                .environmentObject(core)
        }
    }
    
    private var sessionControlSection: some View {
        VStack(spacing: 12) {
            if let session = core.currentSession {
                // Active session controls
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Session Active")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Started \(session.startTime, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(formatDuration(session.duration))
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            Task { try await core.pauseSession() }
                        }) {
                            Label("Pause", systemImage: "pause.fill")
                        }
                        .disabled(core.sessionManager.isPaused)
                        
                        Button(action: {
                            Task { try await core.resumeSession() }
                        }) {
                            Label("Resume", systemImage: "play.fill")
                        }
                        .disabled(!core.sessionManager.isPaused)
                        
                        Button(action: {
                            Task { try await core.endSession() }
                        }) {
                            Label("End", systemImage: "stop.fill")
                        }
                        .foregroundColor(.red)
                    }
                }
            } else {
                // Start session button
                Button(action: {
                    Task { try await core.startSession() }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Focus Session")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    @ViewBuilder
    private var timerSection: some View {
        VStack(spacing: 8) {
            Text("Pomodoro Timer")
                .font(.headline)
            
            TimerDisplayView(state: core.timerState)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                QuickActionButton(
                    title: "Instant Work",
                    icon: "bolt.fill",
                    color: .blue
                ) {
                    Task { try await core.startInstantWorkMode() }
                }
                
                QuickActionButton(
                    title: "Deep Focus",
                    icon: "brain.head.profile",
                    color: .purple
                ) {
                    // Could start a deep focus profile
                }
                
                QuickActionButton(
                    title: "Study Mode",
                    icon: "book.fill",
                    color: .green
                ) {
                    // Could start a study profile
                }
                
                QuickActionButton(
                    title: "Meeting Mode",
                    icon: "video.fill",
                    color: .orange
                ) {
                    // Could start a meeting profile
                }
            }
        }
    }
    
    private func currentSessionSection(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Details")
                .font(.headline)
            
            VStack(spacing: 4) {
                DetailRow(label: "Started", value: session.startTime.formatted(date: .omitted, time: .shortened))
                DetailRow(label: "Duration", value: formatDuration(session.duration))
                DetailRow(label: "Status", value: session.isPaused ? "Paused" : "Active")
                if session.pausedDuration > 0 {
                    DetailRow(label: "Paused Time", value: formatDuration(session.pausedDuration))
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct ProfileCard: View {
    let profile: Profile
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    if profile.timerConfig.isEnabled {
                        Label("\(Int(profile.timerConfig.workDuration / 60))m", systemImage: "timer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if profile.blockingRules.blockEntireInternet {
                        Label("Full Block", systemImage: "wifi.slash")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else if !profile.blockingRules.blockedWebsites.isEmpty {
                        Label("\(profile.blockingRules.blockedWebsites.count) sites", systemImage: "globe.badge.chevron.backward")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
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
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .font(.caption)
    }
}