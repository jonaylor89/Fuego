# 🔥 Fuego

A powerful, open-source productivity app for macOS that helps you maintain focus through website blocking, app blocking, and Pomodoro timers.


## Features

- **🚫 Website & App Blocking**: Intelligent blocking engine with custom rules
- **⏲️ Pomodoro Timer**: Customizable work/break intervals with notifications
- **📊 Time Tracking**: Detailed statistics and session history
- **👤 Profiles**: Multiple focus modes for different types of work
- **⏰ Scheduling**: Automatic focus sessions at scheduled times
- **🤖 Automation**: AppleScript and shell script integration
- **⌨️ Hotkeys**: Global keyboard shortcuts for quick control
- **🎯 Menu Bar**: Lightweight menu bar interface
- **📈 Statistics**: Track your productivity over time
- **🔒 Privacy-First**: All data stored locally, no tracking

## Installation

### Homebrew (Recommended)
```bash
brew install --cask fuego
```

### Direct Download
1. Download the latest `Fuego.dmg` from [GitHub Releases](https://github.com/your-username/Fuego/releases)
2. Open the DMG and drag Fuego to Applications
3. Launch Fuego from Applications or Spotlight

### Build from Source
```bash
git clone https://github.com/your-username/Fuego.git
cd Fuego
./scripts/build-local.sh
cp -r build/Fuego.app /Applications/
```

## 🎯 Quick Start

1. **Launch Fuego** - Look for the 🔥 icon in your menu bar
2. **Create a Profile** - Set up your first focus profile with blocking rules
3. **Start a Session** - Click the menu bar icon and start focusing
4. **Customize Settings** - Configure timers, notifications, and automation

- **[Distribution Guide](DISTRIBUTION.md)** - How to distribute through different channels

## 🛠 Development

### Requirements
- macOS 13.0+
- Xcode 15.0+
- Swift 6.0+

### Setup
```bash
git clone https://github.com/your-username/Fuego.git
cd Fuego
swift build
swift run
```

### Build Scripts
```bash
# Local development build
./scripts/build-local.sh

# Developer ID signed build
./scripts/build-developer-id.sh

# Mac App Store build
./scripts/build-app-store.sh
```

### Project Structure
```
Sources/Fuego/
├── Core/                 # Core app logic and models
├── UI/                   # SwiftUI user interface
├── BlockingEngine/       # Website/app blocking system
├── Timer/                # Pomodoro timer engine
├── Persistence/          # Core Data storage
├── Automation/           # Script automation system
├── Scheduler/            # Session scheduling
└── FuegoApp.swift       # Main app entry point
```

## 🔒 Security & Privacy

- **Local Storage**: All data stored locally on your Mac
- **No Analytics**: No usage tracking or data collection
- **Open Source**: Full transparency of what the app does
- **Code Signed**: Releases are signed and notarized by Apple
- **Sandboxed**: Mac App Store version runs in App Sandbox

## 🏗 Architecture

Fuego is built with modern Swift technologies:

- **SwiftUI**: Declarative user interface
- **Core Data**: Local data persistence
- **Combine**: Reactive programming
- **Network Extension**: Advanced website blocking
- **AppKit**: Native macOS integration
- **Swift Concurrency**: Modern async/await patterns

## 📋 Roadmap

- [ ] **Safari Extension**: Enhanced website blocking
- [ ] **Focus Modes Integration**: Native macOS Focus modes
- [ ] **Shortcuts Support**: Siri Shortcuts integration
- [ ] **Widgets**: Menu bar and desktop widgets
- [ ] **Teams Features**: Shared focus sessions
- [ ] **Advanced Analytics**: ML-powered insights
- [ ] **Cloud Sync**: Optional iCloud synchronization

## 🐛 Issues & Support

- **Bug Reports**: [GitHub Issues](https://github.com/your-username/Fuego/issues)
- **Feature Requests**: [GitHub Discussions](https://github.com/your-username/Fuego/discussions)
- **Security Issues**: Send email to security@fuego.dev

## 📄 License

Fuego is released under the MIT License. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

- Inspired by [Focus](https://heyfocus.com/) and other productivity apps
- Built with love for the open-source community
- Thanks to all contributors and testers

---

**Made with 🔥 by the open-source community**

*Fuego is not affiliated with Focus or any other commercial productivity app.*
