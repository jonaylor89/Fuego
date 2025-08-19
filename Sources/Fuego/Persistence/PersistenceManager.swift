import Foundation
import CoreData
import Logging

/// Manages data persistence using Core Data
class PersistenceManager: ObservableObject {
    private let logger = Logger(label: "com.fuego.persistence")
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FuegoDataModel")
        
        // Configure for app sandboxing
        let storeURL = getApplicationDocumentsDirectory().appendingPathComponent("Fuego.sqlite")
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldInferMappingModelAutomatically = true
        storeDescription.shouldMigrateStoreAutomatically = true
        
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                self.logger.error("Core Data error: \(error), \(error.userInfo)")
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        // Set merge policy for background contexts
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Session Management
    
    func saveSession(_ session: Session) throws {
        let sessionEntity = SessionEntity(context: context)
        sessionEntity.id = session.id
        sessionEntity.profileId = session.profileId
        sessionEntity.startTime = session.startTime
        sessionEntity.endTime = session.endTime
        sessionEntity.pausedDuration = session.pausedDuration
        
        try saveContext()
        logger.info("Session saved: \(session.id)")
    }
    
    func fetchSessions(for profileId: UUID? = nil, limit: Int? = nil) -> [Session] {
        let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        
        if let profileId = profileId {
            request.predicate = NSPredicate(format: "profileId == %@", profileId as CVarArg)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionEntity.startTime, ascending: false)]
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        do {
            let sessionEntities = try context.fetch(request)
            return sessionEntities.compactMap { entity in
                guard let id = entity.id,
                      let profileId = entity.profileId,
                      let startTime = entity.startTime else {
                    return nil
                }
                
                return Session(
                    id: id,
                    profileId: profileId,
                    startTime: startTime,
                    endTime: entity.endTime,
                    pausedDuration: entity.pausedDuration
                )
            }
        } catch {
            logger.error("Failed to fetch sessions: \(error)")
            return []
        }
    }
    
    func updateSession(_ session: Session) throws {
        let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let sessionEntity = results.first {
                sessionEntity.endTime = session.endTime
                sessionEntity.pausedDuration = session.pausedDuration
                try saveContext()
                logger.info("Session updated: \(session.id)")
            }
        } catch {
            logger.error("Failed to update session: \(error)")
            throw error
        }
    }
    
    // MARK: - Profile Management
    
    func saveProfile(_ profile: Profile) throws {
        // Check if profile already exists
        let request: NSFetchRequest<ProfileEntity> = ProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", profile.id as CVarArg)
        
        let profileEntity: ProfileEntity
        
        do {
            let results = try context.fetch(request)
            profileEntity = results.first ?? ProfileEntity(context: context)
        } catch {
            logger.error("Failed to fetch profile: \(error)")
            throw error
        }
        
        // Update profile entity
        profileEntity.id = profile.id
        profileEntity.name = profile.name
        profileEntity.isDefault = profile.isDefault
        profileEntity.blockingRulesData = try encodeBlockingRules(profile.blockingRules)
        profileEntity.timerConfigData = try encodeTimerConfig(profile.timerConfig)
        profileEntity.scheduleConfigData = try encodeScheduleConfig(profile.scheduleConfig)
        profileEntity.automationHooksData = try encodeAutomationHooks(profile.automationHooks)
        profileEntity.createdAt = profileEntity.createdAt ?? Date()
        profileEntity.updatedAt = Date()
        
        try saveContext()
        logger.info("Profile saved: \(profile.name)")
    }
    
    func fetchProfiles() -> [Profile] {
        let request: NSFetchRequest<ProfileEntity> = ProfileEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProfileEntity.isDefault, ascending: false),
            NSSortDescriptor(keyPath: \ProfileEntity.name, ascending: true)
        ]
        
        do {
            let profileEntities = try context.fetch(request)
            return profileEntities.compactMap { entity in
                guard let id = entity.id,
                      let name = entity.name else {
                    return nil
                }
                
                // Decode configurations
                let blockingRules = entity.blockingRulesData.flatMap { try? decodeBlockingRules($0) } ?? BlockingRules()
                let timerConfig = entity.timerConfigData.flatMap { try? decodeTimerConfig($0) } ?? TimerConfiguration()
                let scheduleConfig = entity.scheduleConfigData.flatMap { try? decodeScheduleConfig($0) } ?? ScheduleConfiguration()
                let automationHooks = entity.automationHooksData.flatMap { try? decodeAutomationHooks($0) } ?? AutomationHooks()
                
                let profile = Profile(
                    id: id,
                    name: name,
                    blockingRules: blockingRules,
                    timerConfig: timerConfig,
                    scheduleConfig: scheduleConfig,
                    automationHooks: automationHooks,
                    isDefault: entity.isDefault
                )
                
                return profile
            }
        } catch {
            logger.error("Failed to fetch profiles: \(error)")
            return []
        }
    }
    
    func deleteProfile(_ profileId: UUID) throws {
        let request: NSFetchRequest<ProfileEntity> = ProfileEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", profileId as CVarArg)
        
        do {
            let results = try context.fetch(request)
            for profile in results {
                context.delete(profile)
            }
            try saveContext()
            logger.info("Profile deleted: \(profileId)")
        } catch {
            logger.error("Failed to delete profile: \(error)")
            throw error
        }
    }
    
    // MARK: - Settings Management
    
    func saveSettings(_ settings: FuegoSettings) throws {
        let request: NSFetchRequest<SettingsEntity> = SettingsEntity.fetchRequest()
        
        let settingsEntity: SettingsEntity
        
        do {
            let results = try context.fetch(request)
            settingsEntity = results.first ?? SettingsEntity(context: context)
        } catch {
            logger.error("Failed to fetch settings: \(error)")
            throw error
        }
        
        settingsEntity.settingsData = try JSONEncoder().encode(settings)
        settingsEntity.updatedAt = Date()
        
        try saveContext()
        logger.info("Settings saved")
    }
    
    func fetchSettings() -> FuegoSettings {
        let request: NSFetchRequest<SettingsEntity> = SettingsEntity.fetchRequest()
        
        do {
            let results = try context.fetch(request)
            if let settingsEntity = results.first,
               let settingsData = settingsEntity.settingsData {
                return try JSONDecoder().decode(FuegoSettings.self, from: settingsData)
            }
        } catch {
            logger.error("Failed to fetch settings: \(error)")
        }
        
        // Return default settings if none found
        return FuegoSettings()
    }
    
    // MARK: - Statistics
    
    func getSessionStats(for period: StatsPeriod) -> PeriodStats {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date
        switch period {
        case .week:
            startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .all:
            startDate = Date.distantPast
        }
        
        let sessions = fetchSessionsInRange(from: startDate, to: now)
        
        let totalFocusTime = sessions.reduce(0) { $0 + $1.duration }
        let totalSessions = sessions.count
        let averageSessionLength = totalSessions > 0 ? totalFocusTime / Double(totalSessions) : 0
        let longestSession = sessions.max(by: { $0.duration < $1.duration })?.duration ?? 0
        
        // Calculate daily averages
        var dailyAverages: [Date: TimeInterval] = [:]
        let groupedSessions = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        
        for (date, dailySessions) in groupedSessions {
            let dailyTotal = dailySessions.reduce(0) { $0 + $1.duration }
            dailyAverages[date] = dailyTotal
        }
        
        // Calculate profile usage (mock for now)
        let profileUsage: [String: TimeInterval] = [
            "Work Focus": totalFocusTime * 0.5,
            "Study Mode": totalFocusTime * 0.3,
            "Deep Focus": totalFocusTime * 0.2
        ]
        
        return PeriodStats(
            period: period,
            totalFocusTime: totalFocusTime,
            totalSessions: totalSessions,
            averageSessionLength: averageSessionLength,
            longestSession: longestSession,
            dailyAverages: dailyAverages,
            profileUsage: profileUsage
        )
    }
    
    private func fetchSessionsInRange(from startDate: Date, to endDate: Date) -> [Session] {
        let request: NSFetchRequest<SessionEntity> = SessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "startTime >= %@ AND startTime <= %@", startDate as NSDate, endDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionEntity.startTime, ascending: true)]
        
        do {
            let sessionEntities = try context.fetch(request)
            return sessionEntities.compactMap { entity in
                guard let id = entity.id,
                      let profileId = entity.profileId,
                      let startTime = entity.startTime else {
                    return nil
                }
                
                return Session(
                    id: id,
                    profileId: profileId,
                    startTime: startTime,
                    endTime: entity.endTime,
                    pausedDuration: entity.pausedDuration
                )
            }
        } catch {
            logger.error("Failed to fetch sessions in range: \(error)")
            return []
        }
    }
    
    // MARK: - Data Export/Import
    
    func exportData(to url: URL) {
        let exportData = ExportData(
            profiles: fetchProfiles(),
            sessions: fetchSessions(),
            settings: fetchSettings(),
            exportDate: Date()
        )
        
        do {
            let jsonData = try JSONEncoder().encode(exportData)
            try jsonData.write(to: url)
            logger.info("Data exported to: \(url.path)")
        } catch {
            logger.error("Failed to export data: \(error)")
        }
    }
    
    func resetAllData() {
        // Delete all entities
        let entityNames = ["SessionEntity", "ProfileEntity", "SettingsEntity"]
        
        for entityName in entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            
            do {
                try context.execute(deleteRequest)
            } catch {
                logger.error("Failed to delete \(entityName): \(error)")
            }
        }
        
        do {
            try saveContext()
            logger.info("All data reset")
        } catch {
            logger.error("Failed to save after reset: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    private func getApplicationDocumentsDirectory() -> URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }
    
    // MARK: - Encoding/Decoding Helpers
    
    private func encodeBlockingRules(_ rules: BlockingRules) throws -> Data {
        return try JSONEncoder().encode(rules)
    }
    
    private func decodeBlockingRules(_ data: Data) throws -> BlockingRules {
        return try JSONDecoder().decode(BlockingRules.self, from: data)
    }
    
    private func encodeTimerConfig(_ config: TimerConfiguration) throws -> Data {
        return try JSONEncoder().encode(config)
    }
    
    private func decodeTimerConfig(_ data: Data) throws -> TimerConfiguration {
        return try JSONDecoder().decode(TimerConfiguration.self, from: data)
    }
    
    private func encodeScheduleConfig(_ config: ScheduleConfiguration) throws -> Data {
        return try JSONEncoder().encode(config)
    }
    
    private func decodeScheduleConfig(_ data: Data) throws -> ScheduleConfiguration {
        return try JSONDecoder().decode(ScheduleConfiguration.self, from: data)
    }
    
    private func encodeAutomationHooks(_ hooks: AutomationHooks) throws -> Data {
        return try JSONEncoder().encode(hooks)
    }
    
    private func decodeAutomationHooks(_ data: Data) throws -> AutomationHooks {
        return try JSONDecoder().decode(AutomationHooks.self, from: data)
    }
}

// MARK: - Core Data Entities

@objc(SessionEntity)
class SessionEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var profileId: UUID?
    @NSManaged var startTime: Date?
    @NSManaged var endTime: Date?
    @NSManaged var pausedDuration: TimeInterval
    @NSManaged var createdAt: Date?
}

extension SessionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SessionEntity> {
        return NSFetchRequest<SessionEntity>(entityName: "SessionEntity")
    }
}

@objc(ProfileEntity)
class ProfileEntity: NSManagedObject {
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var isDefault: Bool
    @NSManaged var blockingRulesData: Data?
    @NSManaged var timerConfigData: Data?
    @NSManaged var scheduleConfigData: Data?
    @NSManaged var automationHooksData: Data?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
}

extension ProfileEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProfileEntity> {
        return NSFetchRequest<ProfileEntity>(entityName: "ProfileEntity")
    }
}

@objc(SettingsEntity)
class SettingsEntity: NSManagedObject {
    @NSManaged var settingsData: Data?
    @NSManaged var updatedAt: Date?
}

extension SettingsEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SettingsEntity> {
        return NSFetchRequest<SettingsEntity>(entityName: "SettingsEntity")
    }
}

// MARK: - Export Data Structure

struct ExportData: Codable {
    let profiles: [Profile]
    let sessions: [Session]
    let settings: FuegoSettings
    let exportDate: Date
}