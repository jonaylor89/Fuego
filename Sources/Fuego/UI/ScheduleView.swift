import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var core: FuegoCore
    @State private var showingCreateSchedule = false
    @State private var selectedSchedule: ScheduledSession?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Schedule")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingCreateSchedule.toggle()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            // Schedule toggle
            HStack {
                Toggle("Enable Scheduling", isOn: Binding(
                    get: { core.activeProfile.scheduleConfig.isEnabled },
                    set: { enabled in
                        var profile = core.activeProfile
                        profile.scheduleConfig.isEnabled = enabled
                        core.profileManager.saveProfile(profile)
                    }
                ))
                .font(.headline)
            }
            .padding(.horizontal)
            
            if core.activeProfile.scheduleConfig.isEnabled {
                // Next scheduled session
                if let nextSession = getNextScheduledSession() {
                    nextSessionCard(nextSession)
                        .padding(.horizontal)
                }
                
                // Scheduled sessions list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(core.activeProfile.scheduleConfig.scheduledSessions) { session in
                            ScheduledSessionRowView(
                                session: session,
                                onEdit: {
                                    selectedSchedule = session
                                },
                                onToggle: {
                                    toggleScheduledSession(session)
                                },
                                onDelete: {
                                    deleteScheduledSession(session)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Disabled state
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Schedule Disabled")
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("Enable scheduling to automatically start focus sessions at specific times.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .sheet(isPresented: $showingCreateSchedule) {
            ScheduleEditView()
                .environmentObject(core)
        }
        .sheet(item: $selectedSchedule) { schedule in
            ScheduleEditView(schedule: schedule)
                .environmentObject(core)
        }
    }
    
    private func nextSessionCard(_ session: ScheduledSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Next Session")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                
                Spacer()
                
                Text(getNextOccurrence(for: session), style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(session.startTime))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(formatDuration(session.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatDaysOfWeek(session.daysOfWeek))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func getNextScheduledSession() -> ScheduledSession? {
        let enabledSessions = core.activeProfile.scheduleConfig.scheduledSessions.filter { $0.isEnabled }
        
        // Find the next upcoming session
        let calendar = Calendar.current
        let now = Date()
        
        var nextSession: ScheduledSession?
        var nextDate = Date.distantFuture
        
        for session in enabledSessions {
            for dayOfWeek in session.daysOfWeek {
                if let occurrence = getNextOccurrence(for: session, dayOfWeek: dayOfWeek, after: now) {
                    if occurrence < nextDate {
                        nextDate = occurrence
                        nextSession = session
                    }
                }
            }
        }
        
        return nextSession
    }
    
    private func getNextOccurrence(for session: ScheduledSession) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        var nextDate = Date.distantFuture
        
        for dayOfWeek in session.daysOfWeek {
            if let occurrence = getNextOccurrence(for: session, dayOfWeek: dayOfWeek, after: now) {
                if occurrence < nextDate {
                    nextDate = occurrence
                }
            }
        }
        
        return nextDate
    }
    
    private func getNextOccurrence(for session: ScheduledSession, dayOfWeek: Int, after date: Date) -> Date? {
        let calendar = Calendar.current
        
        // Create a date components for the target day and time
        var components = DateComponents()
        components.weekday = dayOfWeek
        components.hour = session.startTime.hour
        components.minute = session.startTime.minute
        
        // Find next occurrence
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }
    
    private func toggleScheduledSession(_ session: ScheduledSession) {
        var profile = core.activeProfile
        if let index = profile.scheduleConfig.scheduledSessions.firstIndex(where: { $0.id == session.id }) {
            profile.scheduleConfig.scheduledSessions[index].isEnabled.toggle()
            core.profileManager.saveProfile(profile)
        }
    }
    
    private func deleteScheduledSession(_ session: ScheduledSession) {
        var profile = core.activeProfile
        profile.scheduleConfig.scheduledSessions.removeAll { $0.id == session.id }
        core.profileManager.saveProfile(profile)
    }
    
    private func formatTime(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        if let date = Calendar.current.date(from: dateComponents) {
            return formatter.string(from: date)
        }
        
        return "\(hour):\(String(format: "%02d", minute))"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDaysOfWeek(_ days: Set<Int>) -> String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sortedDays = days.sorted().compactMap { day in
            day >= 1 && day <= 7 ? dayNames[day - 1] : nil
        }
        
        if sortedDays.count == 7 {
            return "Every day"
        } else if Set(days) == Set([2, 3, 4, 5, 6]) {
            return "Weekdays"
        } else if Set(days) == Set([1, 7]) {
            return "Weekends"
        } else {
            return sortedDays.joined(separator: ", ")
        }
    }
}

struct ScheduledSessionRowView: View {
    let session: ScheduledSession
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Enabled toggle
            Button(action: onToggle) {
                Image(systemName: session.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(session.isEnabled ? .accentColor : .gray)
                    .font(.title3)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Session info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formatTime(session.startTime))
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("for \(formatDuration(session.duration))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(formatDaysOfWeek(session.daysOfWeek))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .opacity(session.isEnabled ? 1.0 : 0.6)
    }
    
    private func formatTime(_ components: DateComponents) -> String {
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        if let date = Calendar.current.date(from: dateComponents) {
            return formatter.string(from: date)
        }
        
        return "\(hour):\(String(format: "%02d", minute))"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDaysOfWeek(_ days: Set<Int>) -> String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let sortedDays = days.sorted().compactMap { day in
            day >= 1 && day <= 7 ? dayNames[day - 1] : nil
        }
        
        if sortedDays.count == 7 {
            return "Every day"
        } else if Set(days) == Set([2, 3, 4, 5, 6]) {
            return "Weekdays"
        } else if Set(days) == Set([1, 7]) {
            return "Weekends"
        } else {
            return sortedDays.joined(separator: ", ")
        }
    }
}

struct ScheduleEditView: View {
    @EnvironmentObject var core: FuegoCore
    @Environment(\.dismiss) var dismiss
    
    let editingSchedule: ScheduledSession?
    
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var duration: Double
    @State private var selectedDays: Set<Int>
    @State private var isEnabled: Bool
    
    init(schedule: ScheduledSession? = nil) {
        self.editingSchedule = schedule
        
        _startHour = State(initialValue: schedule?.startTime.hour ?? 9)
        _startMinute = State(initialValue: schedule?.startTime.minute ?? 0)
        _duration = State(initialValue: schedule?.duration ?? 25 * 60)
        _selectedDays = State(initialValue: schedule?.daysOfWeek ?? Set([2, 3, 4, 5, 6])) // Weekdays
        _isEnabled = State(initialValue: schedule?.isEnabled ?? true)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text(editingSchedule == nil ? "New Schedule" : "Edit Schedule")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Time settings
                    timeSettingsSection
                    
                    // Duration settings
                    durationSettingsSection
                    
                    // Days of week
                    daysOfWeekSection
                    
                    // Enabled toggle
                    Toggle("Enabled", isOn: $isEnabled)
                        .font(.headline)
                }
            }
            
            // Save button
            HStack {
                Spacer()
                Button("Save Schedule") {
                    saveSchedule()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
    
    private var timeSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start Time")
                .font(.headline)
            
            HStack {
                Picker("Hour", selection: $startHour) {
                    ForEach(0..<24) { hour in
                        Text("\(hour)")
                            .tag(hour)
                    }
                }
                .frame(width: 80)
                
                Text(":")
                    .font(.title2)
                
                Picker("Minute", selection: $startMinute) {
                    ForEach([0, 15, 30, 45], id: \.self) { minute in
                        Text(String(format: "%02d", minute))
                            .tag(minute)
                    }
                }
                .frame(width: 80)
                
                Spacer()
                
                Text(formatPreviewTime())
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private var durationSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duration")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Int(duration / 60)) minutes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Slider(value: $duration, in: 5*60...180*60, step: 5*60) {
                    Text("Duration")
                } minimumValueLabel: {
                    Text("5m")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("3h")
                        .font(.caption)
                }
            }
        }
    }
    
    private var daysOfWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Days of Week")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(Array(zip([1, 2, 3, 4, 5, 6, 7], ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])), id: \.0) { day, name in
                    Button(action: {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }) {
                        Text(name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedDays.contains(day) ? Color.accentColor : Color(.controlBackgroundColor))
                            .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    private func formatPreviewTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var components = DateComponents()
        components.hour = startHour
        components.minute = startMinute
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        
        return "\(startHour):\(String(format: "%02d", startMinute))"
    }
    
    private func saveSchedule() {
        let startTime = DateComponents(hour: startHour, minute: startMinute)
        
        let schedule: ScheduledSession
        if let editingSchedule = editingSchedule {
            schedule = ScheduledSession(
                id: editingSchedule.id,
                startTime: startTime,
                duration: duration,
                daysOfWeek: selectedDays,
                profileId: editingSchedule.profileId,
                isEnabled: isEnabled
            )
        } else {
            schedule = ScheduledSession(
                startTime: startTime,
                duration: duration,
                daysOfWeek: selectedDays
            )
        }
        
        // Update profile
        var profile = core.activeProfile
        
        if let editingSchedule = editingSchedule,
           let index = profile.scheduleConfig.scheduledSessions.firstIndex(where: { $0.id == editingSchedule.id }) {
            // Update existing schedule
            profile.scheduleConfig.scheduledSessions[index] = schedule
        } else {
            // Add new schedule
            profile.scheduleConfig.scheduledSessions.append(schedule)
        }
        
        core.profileManager.saveProfile(profile)
    }
}