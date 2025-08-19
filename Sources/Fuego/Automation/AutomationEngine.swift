import Foundation
import AppKit
import OSAKit
import Logging

/// Manages automation hooks and scripting integration
@MainActor
class AutomationEngine: ObservableObject {
    private let logger = Logger(label: "com.fuego.automation")
    
    @Published var isExecutingHook = false
    @Published var lastExecutionResults: [HookExecutionResult] = []
    
    private let scriptExecutor = ScriptExecutor()
    private let shortcutRunner = ShortcutRunner()
    
    // MARK: - Hook Execution
    
    func executeHooks(for event: AutomationEvent, session: Session) async {
        logger.info("Executing hooks for event: \(event)")
        
        guard let profile = getCurrentProfile() else {
            logger.warning("No active profile found for hook execution")
            return
        }
        
        let hooks = getHooksForEvent(event, from: profile.automationHooks)
        guard !hooks.isEmpty else {
            logger.debug("No hooks configured for event: \(event)")
            return
        }
        
        isExecutingHook = true
        var results: [HookExecutionResult] = []
        
        for hook in hooks where hook.isEnabled {
            let result = await executeHook(hook, context: HookContext(event: event, session: session))
            results.append(result)
            
            // Add small delay between hooks to prevent overwhelming the system
            if hook.id != hooks.last?.id {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
        
        lastExecutionResults = results
        isExecutingHook = false
        
        logger.info("Completed executing \(hooks.count) hooks for event: \(event)")
    }
    
    private func executeHook(_ hook: AutomationHook, context: HookContext) async -> HookExecutionResult {
        let startTime = Date()
        
        do {
            logger.info("Executing hook: \(hook.name) (\(hook.type.rawValue))")
            
            switch hook.type {
            case .shellScript:
                try await scriptExecutor.executeShellScript(hook.command, context: context)
            case .appleScript:
                try await scriptExecutor.executeAppleScript(hook.command, context: context)
            case .shortcut:
                try await shortcutRunner.runShortcut(hook.command, context: context)
            }
            
            let duration = Date().timeIntervalSince(startTime)
            logger.info("Hook completed successfully: \(hook.name) (took \(duration)s)")
            
            return HookExecutionResult(
                hook: hook,
                success: true,
                error: nil,
                duration: duration,
                executedAt: startTime
            )
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            logger.error("Hook failed: \(hook.name) - \(error)")
            
            return HookExecutionResult(
                hook: hook,
                success: false,
                error: error,
                duration: duration,
                executedAt: startTime
            )
        }
    }
    
    // MARK: - Hook Management
    
    func validateHook(_ hook: AutomationHook) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        if hook.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyName)
        }
        
        if hook.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyCommand)
        }
        
        // Validate command syntax based on type
        switch hook.type {
        case .shellScript:
            if !hook.command.hasPrefix("/") && !hook.command.contains(" ") {
                errors.append(.invalidShellCommand)
            }
        case .appleScript:
            // Basic AppleScript validation
            if !hook.command.lowercased().contains("tell") {
                errors.append(.invalidAppleScript)
            }
        case .shortcut:
            if hook.command.isEmpty {
                errors.append(.invalidShortcutName)
            }
        }
        
        return errors
    }
    
    func testHook(_ hook: AutomationHook) async -> HookExecutionResult {
        let testSession = Session(
            profileId: UUID(),
            startTime: Date(),
            endTime: nil,
            pausedDuration: 0
        )
        
        let context = HookContext(event: .sessionStart, session: testSession)
        return await executeHook(hook, context: context)
    }
    
    // MARK: - Preset Hooks
    
    func getPresetHooks() -> [AutomationHook] {
        return [
            // Notification hooks
            AutomationHook(
                name: "Focus Start Notification",
                type: .appleScript,
                command: """
                display notification "Focus session started! Time to get productive." \\
                with title "Fuego" \\
                sound name "Glass"
                """
            ),
            
            AutomationHook(
                name: "Focus End Notification",
                type: .appleScript,
                command: """
                display notification "Focus session completed! Great work." \\
                with title "Fuego" \\
                sound name "Hero"
                """
            ),
            
            // Status updates
            AutomationHook(
                name: "Update Slack Status - Focusing",
                type: .appleScript,
                command: """
                tell application "Slack"
                    set status to "🔥 In focus mode"
                    set status expiration to (current date) + 25 * minutes
                end tell
                """
            ),
            
            AutomationHook(
                name: "Clear Slack Status",
                type: .appleScript,
                command: """
                tell application "Slack"
                    set status to ""
                end tell
                """
            ),
            
            // Do Not Disturb
            AutomationHook(
                name: "Enable Do Not Disturb",
                type: .shellScript,
                command: "shortcuts run 'Turn On Do Not Disturb'"
            ),
            
            AutomationHook(
                name: "Disable Do Not Disturb",
                type: .shellScript,
                command: "shortcuts run 'Turn Off Do Not Disturb'"
            ),
            
            // Music control
            AutomationHook(
                name: "Start Focus Music",
                type: .appleScript,
                command: """
                tell application "Music"
                    set focusPlaylist to playlist "Focus Music"
                    play focusPlaylist
                end tell
                """
            ),
            
            AutomationHook(
                name: "Pause Music",
                type: .appleScript,
                command: """
                tell application "Music"
                    pause
                end tell
                """
            ),
            
            // Screen setup
            AutomationHook(
                name: "Minimize All Windows",
                type: .appleScript,
                command: """
                tell application "System Events"
                    set visible of every process whose visible is true to false
                end tell
                """
            ),
            
            // Log session
            AutomationHook(
                name: "Log Session to File",
                type: .shellScript,
                command: """
                echo "$(date): Focus session completed - Duration: ${FUEGO_SESSION_DURATION}s" >> ~/Documents/focus_log.txt
                """
            )
        ]
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentProfile() -> Profile? {
        // This would typically get the current profile from FuegoCore
        // For now, return nil - this would be injected or retrieved from a shared instance
        return nil
    }
    
    private func getHooksForEvent(_ event: AutomationEvent, from hooks: AutomationHooks) -> [AutomationHook] {
        switch event {
        case .sessionStart:
            return hooks.onSessionStart
        case .sessionEnd:
            return hooks.onSessionEnd
        case .sessionPause:
            return hooks.onSessionPause
        case .sessionResume:
            return hooks.onSessionResume
        case .timerBreakStart:
            return hooks.onTimerBreakStart
        case .timerBreakEnd:
            return hooks.onTimerBreakEnd
        }
    }
}

// MARK: - Script Executor

class ScriptExecutor {
    private let logger = Logger(label: "com.fuego.script")
    
    func executeShellScript(_ command: String, context: HookContext) async throws {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", substituteVariables(command, context: context)]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set environment variables
        var environment = ProcessInfo.processInfo.environment
        environment["FUEGO_SESSION_ID"] = context.session.id.uuidString
        environment["FUEGO_SESSION_DURATION"] = String(Int(context.session.duration))
        environment["FUEGO_EVENT"] = context.event.description
        process.environment = environment
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: AutomationError.scriptFailed(errorString))
                }
            }
            
            do {
                process.launch()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    func executeAppleScript(_ script: String, context: HookContext) async throws {
        let appleScript = OSAScript(source: substituteVariables(script, context: context))
        
        return try await withCheckedThrowingContinuation { continuation in
            var error: NSDictionary?
            let _ = appleScript.executeAndReturnError(&error)
            
            if let error = error {
                let errorDescription = error.description
                continuation.resume(throwing: AutomationError.appleScriptFailed(errorDescription))
            } else {
                continuation.resume()
            }
        }
    }
    
    private func substituteVariables(_ command: String, context: HookContext) -> String {
        var substituted = command
        
        substituted = substituted.replacingOccurrences(of: "${FUEGO_SESSION_ID}", with: context.session.id.uuidString)
        substituted = substituted.replacingOccurrences(of: "${FUEGO_SESSION_DURATION}", with: String(Int(context.session.duration)))
        substituted = substituted.replacingOccurrences(of: "${FUEGO_EVENT}", with: context.event.description)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        substituted = substituted.replacingOccurrences(of: "${FUEGO_TIMESTAMP}", with: formatter.string(from: Date()))
        
        return substituted
    }
}

// MARK: - Shortcut Runner

class ShortcutRunner {
    private let logger = Logger(label: "com.fuego.shortcuts")
    
    func runShortcut(_ shortcutName: String, context: HookContext) async throws {
        let process = Process()
        process.launchPath = "/usr/bin/shortcuts"
        process.arguments = ["run", shortcutName]
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: AutomationError.shortcutFailed("Shortcut '\(shortcutName)' failed"))
                }
            }
            
            do {
                process.launch()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Supporting Types

struct HookContext {
    let event: AutomationEvent
    let session: Session
    
    var variables: [String: String] {
        return [
            "FUEGO_SESSION_ID": session.id.uuidString,
            "FUEGO_SESSION_DURATION": String(Int(session.duration)),
            "FUEGO_EVENT": event.description,
            "FUEGO_TIMESTAMP": ISO8601DateFormatter().string(from: Date())
        ]
    }
}

struct HookExecutionResult {
    let hook: AutomationHook
    let success: Bool
    let error: Error?
    let duration: TimeInterval
    let executedAt: Date
}

enum ValidationError {
    case emptyName
    case emptyCommand
    case invalidShellCommand
    case invalidAppleScript
    case invalidShortcutName
    
    var description: String {
        switch self {
        case .emptyName:
            return "Hook name cannot be empty"
        case .emptyCommand:
            return "Hook command cannot be empty"
        case .invalidShellCommand:
            return "Invalid shell command format"
        case .invalidAppleScript:
            return "Invalid AppleScript syntax"
        case .invalidShortcutName:
            return "Invalid shortcut name"
        }
    }
}

enum AutomationError: LocalizedError {
    case scriptFailed(String)
    case appleScriptFailed(String)
    case shortcutFailed(String)
    case invalidHook(String)
    
    var errorDescription: String? {
        switch self {
        case .scriptFailed(let message):
            return "Shell script failed: \(message)"
        case .appleScriptFailed(let message):
            return "AppleScript failed: \(message)"
        case .shortcutFailed(let message):
            return "Shortcut failed: \(message)"
        case .invalidHook(let message):
            return "Invalid hook: \(message)"
        }
    }
}

// MARK: - Extensions

extension AutomationEvent {
    var description: String {
        switch self {
        case .sessionStart: return "session_start"
        case .sessionEnd: return "session_end"
        case .sessionPause: return "session_pause"
        case .sessionResume: return "session_resume"
        case .timerBreakStart: return "timer_break_start"
        case .timerBreakEnd: return "timer_break_end"
        }
    }
}