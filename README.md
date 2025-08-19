# Fuego 🔥

A powerful, open-source productivity app for macOS that helps you maintain focus through website blocking, app blocking, and Pomodoro timers.

## Features

### 🚫 **Advanced Blocking Engine**
- **Website Blocking**: Block specific domains, keywords, or entire internet access
- **Application Blocking**: Prevent distracting apps from launching during focus sessions  
- **Flexible Rules**: Support for allow-lists, block-lists, and whitelist-only modes
- **Network Extension**: Uses macOS Network Extension APIs for comprehensive blocking

### ⏱️ **Pomodoro Timer System**
- Customizable work/break durations
- Auto-start breaks and work sessions
- Long break intervals
- Visual progress indicators
- Session statistics and tracking

### 📅 **Smart Scheduling**  
- Auto-start focus sessions at specific times
- Flexible day-of-week scheduling
- Multiple scheduled sessions per day
- Automatic session ending after set durations

### 👤 **Profile Management**
- Multiple named profiles with different blocking rules
- Quick profile switching via menu bar
- Profile templates (Work Focus, Study Mode, Deep Focus)
- Instant Work Mode for quick 25-minute sessions

### 🔒 **Security & Locked Mode**
- Password protection for settings and session termination
- "Locked Mode" prevents quitting during active sessions
- Local-only data storage (no telemetry)

### 🤖 **Automation Hooks**
- Shell script execution on session events
- AppleScript integration
- macOS Shortcuts support
- Custom environment variables for scripts

### 📊 **Statistics & Analytics**
- Session duration tracking
- Daily/weekly/monthly/yearly statistics
- Profile usage analytics  
- Focus time trends and charts
- Export data functionality

### ⌨️ **Global Hotkeys**
- Customizable keyboard shortcuts
- Toggle sessions, switch profiles, show dashboard
- Menu bar integration with status indicators

## Architecture

### Core Components

```
Sources/Fuego/
├── Core/                    # Central coordination and models
│   ├── FuegoCore.swift     # Main coordinator
│   ├── Models.swift        # Core data models
│   ├── SessionManager.swift # Session lifecycle
│   └── ProfileManager.swift # Profile management
├── UI/                     # SwiftUI interface
│   ├── DashboardView.swift # Main tabbed interface
│   ├── MainDashboardView.swift # Focus session controls  
│   ├── PomodoroView.swift  # Timer interface
│   ├── ProfilesView.swift  # Profile management
│   ├── ScheduleView.swift  # Scheduling interface
│   ├── StatisticsView.swift # Analytics display
│   └── SettingsView.swift  # App preferences
├── BlockingEngine/         # Website/app blocking
│   └── BlockingEngine.swift # Blocking coordinator
├── Timer/                  # Pomodoro functionality
│   ├── TimerEngine.swift   # Timer logic
│   └── TimerDisplayView.swift # Timer UI components
├── Scheduler/              # Automatic session scheduling
│   └── ScheduleManager.swift # Schedule monitoring
├── Persistence/            # Data storage
│   ├── PersistenceManager.swift # Core Data management
│   └── FuegoDataModel.xcdatamodeld # Data model
├── Automation/             # Scripting and hooks
│   └── AutomationEngine.swift # Script execution
└── Settings/               # App preferences
    └── SettingsManager.swift # Settings coordination
```

### Module Interactions

```
FuegoCore (Central Hub)
    ├── SessionManager ──→ PersistenceManager
    ├── BlockingEngine ──→ Network Extensions
    ├── TimerEngine ──→ Timer State Management
    ├── ScheduleManager ──→ Automatic Triggers
    ├── ProfileManager ──→ PersistenceManager  
    ├── AutomationEngine ──→ Script Execution
    └── SettingsManager ──→ PersistenceManager

UI Layer ──→ FuegoCore (via @EnvironmentObject)
```

### Key Design Patterns

- **MVVM**: SwiftUI views observe `@MainActor` managers via `@ObservableObject`
- **Dependency Injection**: Core managers injected into UI via environment
- **Event-Driven**: Automation hooks triggered on session state changes  
- **Modular**: Each major feature area is self-contained with clear interfaces

## Building & Running

### Prerequisites
- macOS 13.0+ (for SwiftUI features)  
- Xcode 15.0+
- Swift 5.9+
- Apple Developer Account (for entitlements)

### Setup

1. **Clone the repository:**
```bash
git clone https://github.com/yourname/fuego.git
cd fuego
```

2. **Update Bundle Identifier:**
Edit `Info.plist` and replace `com.fuego.focus-app` with your unique bundle identifier.

3. **Configure Entitlements:**
Update `Fuego.entitlements` with your Team ID:
```xml
<key>com.apple.developer.team-identifier</key>
<string>YOUR_TEAM_ID_HERE</string>
```

4. **Build with Xcode:**
```bash
open Fuego.xcodeproj
# Or build from command line:
xcodebuild -scheme Fuego -configuration Release
```

5. **Grant Permissions:**
The app requires several permissions on first run:
- **Full Disk Access** (for hosts file modification)
- **Accessibility** (for app blocking)  
- **Network Extension** (for comprehensive website blocking)

### Swift Package Manager

Alternatively, build as a Swift Package:

```bash
swift build -c release
swift run
```

## Usage

### Quick Start

1. **Launch Fuego** - The app appears in your menu bar as a flame icon 🔥
2. **Click the icon** to open the dashboard
3. **Create a Profile** - Set up your first focus profile with blocking rules
4. **Start a Session** - Click "Start Focus Session" to begin
5. **Customize** - Add Pomodoro timers, scheduling, and automation hooks

### Example Profiles

**Work Focus Profile:**
- Block social media (Facebook, Twitter, Instagram, TikTok)
- Block entertainment (YouTube, Netflix, Reddit)  
- 25-minute Pomodoro with 5-minute breaks
- Slack status automation hook

**Study Mode Profile:**
- Block all non-educational sites
- Allow Wikipedia, Khan Academy, educational resources
- 50-minute work periods with 10-minute breaks
- Enable Do Not Disturb automation

**Deep Focus Profile:**  
- Block entire internet except essential development sites
- 90-minute work periods with 15-minute breaks
- Password-protected locked mode
- Focus music automation

### Automation Examples

**Session Start Hook (AppleScript):**
```applescript
tell application "Slack"
    set status to "🔥 In focus mode"
    set status expiration to (current date) + 25 * minutes
end tell
```

**Session End Hook (Shell Script):**
```bash
echo "$(date): Completed focus session - Duration: ${FUEGO_SESSION_DURATION}s" >> ~/focus_log.txt
shortcuts run "Turn Off Do Not Disturb"
```

## Contributing

We welcome contributions! Fuego is designed to be modular and extensible.

### Development Areas
- **New Blocking Methods**: Alternative blocking techniques
- **UI Improvements**: Enhanced dashboard, charts, animations
- **Automation Integrations**: Additional scripting platforms  
- **Statistics**: Advanced analytics and insights
- **Platform Extensions**: iOS companion app, web dashboard

### Code Style
- Follow Swift conventions and use SwiftLint
- Add comprehensive comments for public interfaces
- Maintain modular architecture with clear separation of concerns
- Write tests for core business logic

### Pull Request Process
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Security & Privacy

### Local-First Approach
- **No Telemetry**: Fuego collects no usage analytics or tracking data
- **Local Storage**: All data stored locally using Core Data
- **No Network Communication**: No data sent to external servers
- **Open Source**: Full transparency - audit the code yourself

### Permissions Explained
- **Full Disk Access**: Required to modify `/etc/hosts` for domain blocking
- **Network Extension**: Enables comprehensive website filtering
- **Accessibility**: Monitors and blocks application launches
- **Automation**: Allows scripting integration (AppleScript, shell scripts)

### Secure Design
- Password hashing for locked mode (upgrade to bcrypt/Argon2 for production)
- Sandboxing where possible while maintaining functionality
- Minimal required permissions with clear usage descriptions

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Inspired by [Focus](https://heyfocus.com) and other productivity apps

Built with love for the open source community

**Stay focused. Stay productive. 🔥**
