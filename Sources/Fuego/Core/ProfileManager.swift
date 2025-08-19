import Foundation
import Combine
import Logging

/// Manages user profiles and profile switching
@MainActor
class ProfileManager: ObservableObject {
    private let logger = Logger(label: "com.fuego.profiles")
    private let persistence: PersistenceManager
    
    @Published var profiles: [Profile] = []
    @Published var activeProfile: Profile?
    
    init(persistence: PersistenceManager) {
        self.persistence = persistence
        loadProfiles()
    }
    
    // MARK: - Profile Management
    
    func loadProfiles() {
        profiles = persistence.fetchProfiles()
        
        // Set active profile to default or first profile
        if let defaultProfile = profiles.first(where: { $0.isDefault }) {
            activeProfile = defaultProfile
        } else if let firstProfile = profiles.first {
            activeProfile = firstProfile
        }
        
        logger.info("Loaded \(profiles.count) profiles")
    }
    
    func loadActiveProfile() -> Profile? {
        if profiles.isEmpty {
            loadProfiles()
        }
        return activeProfile
    }
    
    func createDefaultProfile() -> Profile {
        let profile = Profile(name: "Default")
        var defaultProfile = profile
        defaultProfile.isDefault = true
        
        // Set up default configuration
        defaultProfile.timerConfig.isEnabled = true
        defaultProfile.timerConfig.workDuration = 25 * 60 // 25 minutes
        defaultProfile.timerConfig.shortBreakDuration = 5 * 60 // 5 minutes
        defaultProfile.timerConfig.longBreakDuration = 15 * 60 // 15 minutes
        defaultProfile.timerConfig.autoStartBreaks = true
        
        // Save and add to profiles
        do {
            try persistence.saveProfile(defaultProfile)
            profiles.append(defaultProfile)
            activeProfile = defaultProfile
            logger.info("Created default profile")
        } catch {
            logger.error("Failed to create default profile: \(error)")
        }
        
        return defaultProfile
    }
    
    func saveProfile(_ profile: Profile) {
        do {
            try persistence.saveProfile(profile)
            
            // Update local profiles array
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profile
            } else {
                profiles.append(profile)
            }
            
            // Update active profile if it's the same ID
            if activeProfile?.id == profile.id {
                activeProfile = profile
            }
            
            logger.info("Profile saved: \(profile.name)")
        } catch {
            logger.error("Failed to save profile: \(error)")
        }
    }
    
    func deleteProfile(_ profileId: UUID) throws {
        // Prevent deleting the last profile
        guard profiles.count > 1 else {
            throw ProfileError.cannotDeleteLastProfile
        }
        
        // Prevent deleting the currently active profile
        guard activeProfile?.id != profileId else {
            throw ProfileError.cannotDeleteActiveProfile
        }
        
        try persistence.deleteProfile(profileId)
        profiles.removeAll { $0.id == profileId }
        
        logger.info("Profile deleted: \(profileId)")
    }
    
    func duplicateProfile(_ profile: Profile, newName: String) -> Profile {
        let newProfile = Profile(
            id: UUID(),
            name: newName,
            blockingRules: profile.blockingRules,
            timerConfig: profile.timerConfig,
            scheduleConfig: profile.scheduleConfig,
            automationHooks: profile.automationHooks,
            isDefault: false
        )
        
        saveProfile(newProfile)
        return newProfile
    }
    
    // MARK: - Profile Switching
    
    func setActiveProfile(_ profile: Profile) async throws {
        guard let existingProfile = profiles.first(where: { $0.id == profile.id }) else {
            throw ProfileError.profileNotFound
        }
        
        activeProfile = existingProfile
        logger.info("Active profile changed to: \(existingProfile.name)")
    }
    
    func switchToProfile(named name: String) async throws {
        guard let profile = profiles.first(where: { $0.name == name }) else {
            throw ProfileError.profileNotFound
        }
        
        try await setActiveProfile(profile)
    }
    
    func switchToProfile(withId id: UUID) async throws {
        guard let profile = profiles.first(where: { $0.id == id }) else {
            throw ProfileError.profileNotFound
        }
        
        try await setActiveProfile(profile)
    }
    
    // MARK: - Special Profiles
    
    func createInstantWorkProfile(duration: TimeInterval = 25 * 60) -> Profile {
        var profile = Profile(name: "Instant Work")
        
        // Configure for instant work mode
        profile.timerConfig.isEnabled = true
        profile.timerConfig.workDuration = duration
        profile.timerConfig.autoStartBreaks = false
        profile.timerConfig.autoStartWork = false
        
        // Block social media and entertainment sites
        profile.blockingRules.blockedWebsites = Set([
            "facebook.com", "twitter.com", "instagram.com", "tiktok.com",
            "youtube.com", "netflix.com", "reddit.com", "linkedin.com"
        ])
        
        // Block entertainment apps
        profile.blockingRules.blockedApplications = Set([
            "com.apple.TV", "com.netflix.Netflix", "com.spotify.client",
            "com.tinyspeck.slackmacgap", "com.facebook.Messenger"
        ])
        
        return profile
    }
    
    func createDeepFocusProfile() -> Profile {
        var profile = Profile(name: "Deep Focus")
        
        // Configure for deep focus
        profile.timerConfig.isEnabled = true
        profile.timerConfig.workDuration = 90 * 60 // 90 minutes
        profile.timerConfig.shortBreakDuration = 15 * 60 // 15 minutes
        profile.timerConfig.longBreakDuration = 30 * 60 // 30 minutes
        profile.timerConfig.autoStartBreaks = true
        
        // Block entire internet except essential sites
        profile.blockingRules.blockEntireInternet = true
        profile.blockingRules.allowedWebsites = Set([
            "localhost", "127.0.0.1", "stackoverflow.com", "github.com",
            "developer.apple.com", "docs.microsoft.com"
        ])
        
        return profile
    }
    
    func createStudyModeProfile() -> Profile {
        var profile = Profile(name: "Study Mode")
        
        // Configure for studying
        profile.timerConfig.isEnabled = true
        profile.timerConfig.workDuration = 50 * 60 // 50 minutes
        profile.timerConfig.shortBreakDuration = 10 * 60 // 10 minutes
        profile.timerConfig.longBreakDuration = 20 * 60 // 20 minutes
        
        // Block distracting sites but allow educational content
        profile.blockingRules.blockedWebsites = Set([
            "facebook.com", "twitter.com", "instagram.com", "tiktok.com",
            "youtube.com", "netflix.com", "reddit.com", "twitch.tv",
            "discord.com", "snapchat.com"
        ])
        
        profile.blockingRules.allowedWebsites = Set([
            "wikipedia.org", "khanacademy.org", "coursera.org", "edx.org",
            "stackoverflow.com", "github.com", "scholar.google.com"
        ])
        
        return profile
    }
    
    // MARK: - Profile Templates
    
    func getProfileTemplates() -> [Profile] {
        return [
            createInstantWorkProfile(),
            createDeepFocusProfile(),
            createStudyModeProfile()
        ]
    }
    
    func createProfileFromTemplate(_ template: Profile, name: String) -> Profile {
        let newProfile = Profile(
            id: UUID(),
            name: name,
            blockingRules: template.blockingRules,
            timerConfig: template.timerConfig,
            scheduleConfig: template.scheduleConfig,
            automationHooks: template.automationHooks,
            isDefault: false
        )
        
        saveProfile(newProfile)
        return newProfile
    }
    
    // MARK: - Profile Statistics
    
    func getProfileUsageStats() -> [ProfileUsageStats] {
        return profiles.map { profile in
            let sessions = persistence.fetchSessions(for: profile.id)
            let totalTime = sessions.reduce(0) { $0 + $1.duration }
            let sessionCount = sessions.count
            
            return ProfileUsageStats(
                profile: profile,
                totalFocusTime: totalTime,
                sessionCount: sessionCount,
                averageSessionLength: sessionCount > 0 ? totalTime / Double(sessionCount) : 0
            )
        }
    }
    
    func getMostUsedProfile() -> Profile? {
        let stats = getProfileUsageStats()
        return stats.max(by: { $0.totalFocusTime < $1.totalFocusTime })?.profile
    }
}

// MARK: - Supporting Types

struct ProfileUsageStats {
    let profile: Profile
    let totalFocusTime: TimeInterval
    let sessionCount: Int
    let averageSessionLength: TimeInterval
}

enum ProfileError: LocalizedError {
    case profileNotFound
    case cannotDeleteLastProfile
    case cannotDeleteActiveProfile
    case duplicateProfileName
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            return "Profile not found"
        case .cannotDeleteLastProfile:
            return "Cannot delete the last remaining profile"
        case .cannotDeleteActiveProfile:
            return "Cannot delete the currently active profile"
        case .duplicateProfileName:
            return "A profile with this name already exists"
        }
    }
}