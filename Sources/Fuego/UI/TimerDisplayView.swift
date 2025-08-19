import SwiftUI

struct TimerDisplayView: View {
    let state: TimerState
    @EnvironmentObject var core: FuegoCore
    
    var body: some View {
        VStack(spacing: 16) {
            // Timer circle with progress
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                // Progress circle
                Circle()
                    .trim(from: 0.0, to: progress)
                    .stroke(periodColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Time display
                VStack(spacing: 4) {
                    Text(formatTime(state.remainingTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    
                    Text(periodType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Period type indicator
            HStack(spacing: 8) {
                Image(systemName: periodType.systemImage)
                    .foregroundColor(periodColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(periodType.displayName)
                        .font(.headline)
                    
                    if core.timerEngine.currentCycle > 0 {
                        Text("Cycle \(core.timerEngine.currentCycle)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Timer controls
            timerControls
        }
    }
    
    @ViewBuilder
    private var timerControls: some View {
        HStack(spacing: 16) {
            if state.isPaused {
                Button(action: {
                    core.timerEngine.resume()
                }) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.caption)
                }
            } else if state.isActive {
                Button(action: {
                    core.timerEngine.pause()
                }) {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.caption)
                }
            }
            
            if state.isActive {
                Button(action: {
                    Task {
                        await core.timerEngine.skip()
                    }
                }) {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.caption)
                }
                
                Button(action: {
                    core.timerEngine.stop()
                }) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
    }
    
    private var periodType: PeriodType {
        core.timerEngine.getCurrentPeriodType()
    }
    
    private var periodColor: Color {
        switch periodType {
        case .work:
            return .red
        case .shortBreak:
            return .green
        case .longBreak:
            return .blue
        case .none:
            return .gray
        }
    }
    
    private var progress: Double {
        core.timerEngine.getProgress()
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PomodoroView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var showingSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Pomodoro Timer")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        showingSettings.toggle()
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
                .padding(.horizontal)
                
                // Timer display
                if core.timerState.isActive {
                    TimerDisplayView(state: core.timerState)
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(16)
                } else {
                    timerSetupView
                }
                
                // Quick timer buttons
                if !core.timerState.isActive {
                    quickTimerButtons
                }
                
                // Statistics
                timerStatsView
            }
            .padding()
        }
        .sheet(isPresented: $showingSettings) {
            TimerSettingsView()
                .environmentObject(core)
        }
    }
    
    private var timerSetupView: some View {
        VStack(spacing: 16) {
            Text("Ready to Focus?")
                .font(.title3)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Work Time:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(core.activeProfile.timerConfig.workDuration / 60)) minutes")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Short Break:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(core.activeProfile.timerConfig.shortBreakDuration / 60)) minutes")
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Long Break:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(core.activeProfile.timerConfig.longBreakDuration / 60)) minutes")
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            Button(action: {
                Task {
                    var config = core.activeProfile.timerConfig
                    config.isEnabled = true
                    try await core.timerEngine.start(with: config)
                }
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Pomodoro")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(16)
    }
    
    private var quickTimerButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Timers")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                QuickTimerButton(title: "5 min", duration: 5 * 60)
                QuickTimerButton(title: "10 min", duration: 10 * 60)
                QuickTimerButton(title: "25 min", duration: 25 * 60)
                QuickTimerButton(title: "45 min", duration: 45 * 60)
            }
        }
    }
    
    private var timerStatsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Focus")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatCard(
                    title: "Cycles",
                    value: "\(core.timerEngine.totalCycles)",
                    icon: "arrow.triangle.2.circlepath"
                )
                
                StatCard(
                    title: "Current",
                    value: "\(core.timerEngine.currentCycle)",
                    icon: "target"
                )
            }
        }
    }
}

struct QuickTimerButton: View {
    let title: String
    let duration: TimeInterval
    @EnvironmentObject var core: FuegoCore
    
    var body: some View {
        Button(action: {
            Task {
                var config = TimerConfiguration()
                config.isEnabled = true
                config.workDuration = duration
                config.autoStartBreaks = false
                try await core.timerEngine.start(with: config)
            }
        }) {
            VStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct TimerSettingsView: View {
    @EnvironmentObject var core: FuegoCore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text("Timer Settings")
                .font(.title2)
                .fontWeight(.semibold)
                .padding()
            
            Text("Timer settings would go here")
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .padding()
        }
        .frame(width: 300, height: 400)
    }
}