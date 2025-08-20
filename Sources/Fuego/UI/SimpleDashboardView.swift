import SwiftUI

struct SimpleDashboardView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerView
            
            // Main control area
            mainControlView
            
            // Current session info
            if let session = core.currentSession {
                sessionInfoView(session)
            }
            
            // Timer display
            if core.timerState.isActive {
                timerView
            }
            
            Spacer()
            
            // Settings button
            settingsButton
        }
        .padding(20)
        .frame(width: 360, height: 480)
        .background(Color(.windowBackgroundColor))
        .sheet(isPresented: $showingSettings) {
            SimpleSettingsView()
                .environmentObject(core)
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
                .font(.title)
            
            Text("Fuego")
                .font(.title)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Status indicator
            if core.currentSession != nil {
                HStack(spacing: 4) {
                    Circle()
                        .fill(core.isBlocked ? Color.red : Color.orange)
                        .frame(width: 10, height: 10)
                    
                    Text(core.isBlocked ? "Blocking" : "Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var mainControlView: some View {
        VStack(spacing: 16) {
            if let session = core.currentSession {
                // Session active - show controls
                VStack(spacing: 12) {
                    Text("Focus Session Active")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(formatDuration(session.duration))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    HStack(spacing: 12) {
                        if core.sessionManager.isPaused {
                            Button("Resume") {
                                Task { try? await core.resumeSession() }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Pause") {
                                Task { try? await core.pauseSession() }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("End Session") {
                            Task { try? await core.endSession() }
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
            } else {
                // No session - show start button
                VStack(spacing: 12) {
                    Text("Ready to Focus")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Button(action: {
                        Task { try? await core.startSession() }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Focus Session")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private func sessionInfoView(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Info")
                .font(.headline)
            
            HStack {
                Text("Started:")
                Spacer()
                Text(session.startTime.formatted(date: .omitted, time: .shortened))
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if session.isPaused {
                HStack {
                    Text("Status:")
                    Spacer()
                    Text("Paused")
                        .foregroundColor(.orange)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var timerView: some View {
        VStack(spacing: 8) {
            Text("Timer")
                .font(.headline)
            
            HStack {
                Image(systemName: "timer")
                Text(formatDuration(core.timerState.remainingTime))
                    .font(.title2)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var settingsButton: some View {
        Button("Settings") {
            showingSettings = true
        }
        .buttonStyle(.bordered)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    SimpleDashboardView()
        .environmentObject(FuegoCore())
}
