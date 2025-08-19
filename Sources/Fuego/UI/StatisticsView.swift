import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var selectedPeriod: StatsPeriod = .week
    @State private var selectedMetric: StatsMetric = .focusTime
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with period selector
            HStack {
                Text("Statistics")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(StatsPeriod.allCases, id: \.self) { period in
                        Text(period.displayName)
                            .tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Overview cards
                    overviewCards
                    
                    // Chart section
                    chartSection
                    
                    // Detailed stats
                    detailedStatsSection
                    
                    // Profile breakdown
                    profileBreakdownSection
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var overviewCards: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            StatsCard(
                title: "Total Focus Time",
                value: formatDuration(getTotalFocusTime()),
                icon: "clock.fill",
                color: .blue
            )
            
            StatsCard(
                title: "Sessions",
                value: "\(getTotalSessions())",
                icon: "play.circle.fill",
                color: .green
            )
            
            StatsCard(
                title: "Average Session",
                value: formatDuration(getAverageSessionLength()),
                icon: "chart.bar.fill",
                color: .orange
            )
            
            StatsCard(
                title: "Longest Session",
                value: formatDuration(getLongestSession()),
                icon: "trophy.fill",
                color: .purple
            )
        }
    }
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus Trends")
                    .font(.headline)
                
                Spacer()
                
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(StatsMetric.allCases, id: \.self) { metric in
                        Text(metric.displayName)
                            .tag(metric)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
            }
            
            // Chart view
            if #available(macOS 13.0, *) {
                Chart(getChartData()) { dataPoint in
                    BarMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.displayName, dataPoint.value)
                    )
                    .foregroundStyle(selectedMetric.color)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            } else {
                // Fallback for older macOS versions
                Text("Charts require macOS 13.0 or later")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var detailedStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Statistics")
                .font(.headline)
            
            VStack(spacing: 8) {
                DetailStatsRow(
                    label: "This \(selectedPeriod.displayName.lowercased())",
                    value: formatDuration(getTotalFocusTime())
                )
                
                DetailStatsRow(
                    label: "Daily average",
                    value: formatDuration(getDailyAverage())
                )
                
                DetailStatsRow(
                    label: "Most productive day",
                    value: getMostProductiveDay()
                )
                
                DetailStatsRow(
                    label: "Success rate",
                    value: "\(Int(getSuccessRate() * 100))%"
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var profileBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile Usage")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(getProfileUsage(), id: \.name) { usage in
                    HStack {
                        Circle()
                            .fill(usage.color)
                            .frame(width: 12, height: 12)
                        
                        Text(usage.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatDuration(usage.duration))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("\(usage.percentage, specifier: "%.1f")%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Data Methods
    
    private func getTotalFocusTime() -> TimeInterval {
        // Mock data for now - would integrate with real persistence layer
        switch selectedPeriod {
        case .week: return 12.5 * 3600 // 12.5 hours
        case .month: return 50 * 3600 // 50 hours
        case .year: return 600 * 3600 // 600 hours
        case .all: return 1200 * 3600 // 1200 hours
        }
    }
    
    private func getTotalSessions() -> Int {
        switch selectedPeriod {
        case .week: return 25
        case .month: return 100
        case .year: return 1200
        case .all: return 2400
        }
    }
    
    private func getAverageSessionLength() -> TimeInterval {
        let total = getTotalFocusTime()
        let sessions = getTotalSessions()
        return sessions > 0 ? total / Double(sessions) : 0
    }
    
    private func getLongestSession() -> TimeInterval {
        return 2.5 * 3600 // 2.5 hours
    }
    
    private func getDailyAverage() -> TimeInterval {
        let total = getTotalFocusTime()
        let days: Double = switch selectedPeriod {
        case .week: 7
        case .month: 30
        case .year: 365
        case .all: 730 // Assuming 2 years of data
        }
        return total / days
    }
    
    private func getMostProductiveDay() -> String {
        return "Tuesday"
    }
    
    private func getSuccessRate() -> Double {
        return 0.85 // 85% success rate
    }
    
    private func getChartData() -> [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        
        let days: Int = switch selectedPeriod {
        case .week: 7
        case .month: 30
        case .year: 52 // Weekly data points for year
        case .all: 12 // Monthly data points for all time
        }
        
        return (0..<days).compactMap { i in
            let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            let value = generateMockValue(for: date)
            return ChartDataPoint(date: date, value: value)
        }.reversed()
    }
    
    private func generateMockValue(for date: Date) -> Double {
        // Generate realistic mock data based on date
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // Lower values on weekends
        let baseValue: Double = (weekday == 1 || weekday == 7) ? 1.5 : 3.0
        
        // Add some randomness
        let randomFactor = Double.random(in: 0.5...1.5)
        
        return baseValue * randomFactor
    }
    
    private func getProfileUsage() -> [ProfileUsage] {
        return [
            ProfileUsage(name: "Work Focus", duration: 8 * 3600, color: .blue),
            ProfileUsage(name: "Study Mode", duration: 3 * 3600, color: .green),
            ProfileUsage(name: "Deep Focus", duration: 2 * 3600, color: .purple),
            ProfileUsage(name: "Quick Focus", duration: 1.5 * 3600, color: .orange)
        ]
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct DetailStatsRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Supporting Types

enum StatsMetric: CaseIterable {
    case focusTime
    case sessions
    case averageLength
    
    var displayName: String {
        switch self {
        case .focusTime: return "Focus Time"
        case .sessions: return "Sessions"
        case .averageLength: return "Avg Length"
        }
    }
    
    var color: Color {
        switch self {
        case .focusTime: return .blue
        case .sessions: return .green
        case .averageLength: return .orange
        }
    }
}

extension StatsPeriod {
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .all: return "All Time"
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ProfileUsage {
    let name: String
    let duration: TimeInterval
    let color: Color
    
    var percentage: Double {
        let total: TimeInterval = 14.5 * 3600 // Total from mock data
        return (duration / total) * 100
    }
}