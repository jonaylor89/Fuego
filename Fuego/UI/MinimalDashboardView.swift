import SwiftUI

struct MinimalDashboardView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var showingSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Minimal header
            HStack {
                Text("fuego")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.light)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if core.currentSession != nil {
                    Circle()
                        .fill(.primary)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            Spacer()
            
            // Central focus area
            VStack(spacing: 32) {
                if core.currentSession != nil {
                    // Active session state
                    VStack(spacing: 16) {
                        Text(formatDuration(core.timerState.remainingTime))
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.ultraLight)
                            .foregroundColor(.primary)
                        
                        Text(core.isPaused ? "paused" : "focus")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textCase(.lowercase)
                    }
                    
                    // Minimal controls
                    HStack(spacing: 24) {
                        Button(action: {
                            Task {
                                if core.isPaused {
                                    await core.resumeSession()
                                } else {
                                    await core.pauseSession()
                                }
                            }
                        }) {
                            Text(core.isPaused ? "resume" : "pause")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        
                        Button("end") {
                            Task { await core.endSession() }
                        }
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .buttonStyle(.plain)
                    }
                } else {
                    // Ready to start state
                    VStack(spacing: 24) {
                        Text("\(Int(core.settings.timerDuration / 60)):00")
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.ultraLight)
                            .foregroundColor(.secondary)
                        
                        Button("begin") {
                            Task { await core.startSession() }
                        }
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .buttonStyle(.plain)
                    }
                }
            }
            
            statusMessage
                .padding(.horizontal, 24)
                .padding(.top, 24)
            
            Spacer()
            
            // Minimal footer
            HStack {
                Button("settings") {
                    showingSettings = true
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
                
                Spacer()
                
                Button("quit") {
                    NSApp.terminate(nil)
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 280, height: 360)
        .background(.regularMaterial)
        .sheet(isPresented: $showingSettings) {
            MinimalSettingsView()
                .environmentObject(core)
        }
    }
    
    /// Errors, plus a nudge when website blocking can't work yet.
    @ViewBuilder
    private var statusMessage: some View {
        if let error = core.lastError {
            Text(error)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        } else if core.filterStatus == .awaitingApproval {
            Button("allow fuego in system settings to block sites") {
                core.filter.openSystemSettings()
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.orange)
            .buttonStyle(.plain)
        } else if core.filterStatus == .disabled {
            Button("site blocking is off in system settings") {
                core.filter.openSystemSettings()
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(.orange)
            .buttonStyle(.plain)
        } else if core.currentSession == nil, core.settings.blockedWebsites.isEmpty,
            core.settings.blockedApplications.isEmpty
        {
            Text("add sites or apps to block in settings")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    MinimalDashboardView()
        .environmentObject(FuegoCore())
}
