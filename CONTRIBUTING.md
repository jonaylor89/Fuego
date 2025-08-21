# Contributing to Fuego

Thank you for your interest in contributing to Fuego! This document provides guidelines for contributing to the project.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/yourusername/fuego.git
   cd fuego
   ```
3. **Open the project** in Xcode:
   ```bash
   open Fuego.xcodeproj
   ```

## Development Setup

### Requirements
- macOS 12.0 or later
- Xcode 14.0 or later
- Apple Developer account (for Network Extension testing)

### Building
1. Open `Fuego.xcodeproj` in Xcode
2. Select your development team in project settings
3. Build and run the project (⌘+R)

### Network Extension Development
- Network Extensions require proper entitlements and code signing
- You'll need to update the team ID in both entitlement files
- Test on a real device, not just the simulator

## Code Style

### Swift
- Use Swift 5.5+ features when appropriate
- Follow standard Swift naming conventions
- Use `// MARK: -` comments to organize code sections
- Keep functions focused and single-purpose

### Structure
- Keep UI components in `Sources/Fuego/UI/`
- Keep core logic in `Sources/Fuego/Core/`
- Keep Network Extension code in `Sources/FuegoContentFilter/`
- Use meaningful file and folder names

### Comments
- Write clear, concise comments for complex logic
- Document public APIs with Swift documentation comments
- Avoid obvious comments that just restate the code

## Pull Request Process

### Before Submitting
1. **Test your changes** thoroughly
2. **Run the app** and verify core functionality works
3. **Test Network Extension** setup and blocking
4. **Check for console errors** or warnings
5. **Update documentation** if needed

### Pull Request Guidelines
1. **Create a focused PR** - one feature or fix per PR
2. **Write a clear title** describing the change
3. **Describe the changes** in the PR description:
   - What does this change?
   - Why is it needed?
   - How to test it?
4. **Link related issues** using "Fixes #123" or "Addresses #123"

### PR Description Template
```markdown
## What Changed
Brief description of the changes made.

## Why
Explain the motivation for this change.

## How to Test
1. Step one
2. Step two
3. Expected result

## Screenshots/Videos
If applicable, add screenshots or videos demonstrating the change.

## Checklist
- [ ] Tested on macOS 12+
- [ ] No console errors/warnings
- [ ] Network Extension functionality works
- [ ] Documentation updated if needed
```

## Issue Reporting

### Bug Reports
Use the bug report template and include:
- macOS version
- Fuego version
- Steps to reproduce
- Expected vs actual behavior
- Console logs if relevant

### Feature Requests
Use the feature request template and include:
- Clear description of the feature
- Use case or motivation
- Possible implementation ideas

## Types of Contributions

### Welcome Contributions
- **Bug fixes** - Always appreciated!
- **UI/UX improvements** - Keep it minimal and focused
- **Performance optimizations** - Especially for Network Extension
- **Documentation improvements** - Help others understand the code
- **Test coverage** - Help ensure reliability

### Discuss First
- **Major new features** - Create an issue to discuss approach
- **Breaking changes** - Need community input
- **Architecture changes** - Should align with project goals

## Development Notes

### Network Extension Limitations
- Network Extensions run in a sandboxed environment
- Limited API access compared to main app
- Debugging can be challenging - use logging liberally
- Changes require app restart to take effect

### Debugging Tips
- Use `Logger` for consistent logging across the app
- Check Console.app for Network Extension logs
- Test with System Preferences → Privacy & Security → Extensions

### Testing
- Test on both Intel and Apple Silicon Macs if possible
- Test Network Extension permissions flow thoroughly
- Verify app works correctly after macOS restarts
- Test with various websites and blocking scenarios

## Code of Conduct

- **Be respectful** and constructive in discussions
- **Help others** learn and contribute
- **Focus on the code**, not personal preferences
- **Keep discussions relevant** to the project

## Questions?

- **General questions**: Start a [Discussion](https://github.com/yourusername/fuego/discussions)
- **Bug reports**: Open an [Issue](https://github.com/yourusername/fuego/issues)
- **Feature requests**: Open an [Issue](https://github.com/yourusername/fuego/issues) with the feature template

## License

By contributing to Fuego, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to Fuego! 🔥
