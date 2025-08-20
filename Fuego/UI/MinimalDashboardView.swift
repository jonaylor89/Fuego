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
                if let session = core.currentSession {
                    // Active session state
                    VStack(spacing: 16) {
                        Text(formatDuration(session.duration))
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.ultraLight)
                            .foregroundColor(.primary)
                        
                        Text(core.sessionManager.isPaused ? "paused" : "focus")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textCase(.lowercase)
                    }
                    
                    // Minimal controls
                    HStack(spacing: 24) {
                        Button(action: {
                            Task { 
                                if core.sessionManager.isPaused {
                                    try? await core.resumeSession()
                                } else {
                                    try? await core.pauseSession()
                                }
                            }
                        }) {
                            Text(core.sessionManager.isPaused ? "resume" : "pause")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        
                        Button("end") {
                            Task { try? await core.endSession() }
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
                            Task { try? await core.startSession() }
                        }
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .buttonStyle(.plain)
                    }
                }
            }
            
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
