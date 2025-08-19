import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var selectedTab: DashboardTab = .dashboard
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with app title
            headerView
            
            // Tab navigation
            tabBar
            
            // Content area
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 360, height: 480)
        .background(Color(.windowBackgroundColor))
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
                .font(.title2)
            
            Text("Fuego")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            // Session indicator
            if core.currentSession != nil {
                HStack(spacing: 4) {
                    Circle()
                        .fill(core.isBlocked ? Color.red : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(core.isBlocked ? "Blocking" : "Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.secondary.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .dashboard:
            MainDashboardView()
        case .pomodoro:
            PomodoroView()
        case .schedule:
            ScheduleView()
        case .profiles:
            ProfilesView()
        case .statistics:
            StatisticsView()
        case .settings:
            SettingsView()
        }
    }
}

enum DashboardTab: String, CaseIterable {
    case dashboard = "dashboard"
    case pomodoro = "pomodoro"
    case schedule = "schedule"
    case profiles = "profiles"
    case statistics = "statistics"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .dashboard: return "Focus"
        case .pomodoro: return "Timer"
        case .schedule: return "Schedule"
        case .profiles: return "Profiles"
        case .statistics: return "Stats"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "play.circle.fill"
        case .pomodoro: return "timer"
        case .schedule: return "calendar"
        case .profiles: return "person.2.fill"
        case .statistics: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}