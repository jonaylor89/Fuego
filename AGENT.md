# Fuego Agent Instructions

## Build Commands
- `swift build -c release` - Build release version
- `swift build` - Build debug version  
- `swift run` - Run the executable
- `swift test` - Run all tests
- `swift test --filter FuegoTests.TestClassName.testMethodName` - Run single test

## Code Style Guidelines
- Use **@MainActor** for UI-related classes and Core managers
- Follow **MVVM pattern** with @ObservableObject/@Published for state management
- Use **dependency injection** via environment objects and init parameters
- **Import order**: Foundation first, then other system frameworks, then third-party
- Use **comprehensive documentation comments** with /// for public interfaces
- Prefer **computed properties** over methods for simple state calculations
- Use **async/await** for asynchronous operations, avoid completion handlers
- Apply **structs for data models**, classes for managers/engines with state
- Use **Set<>** for collections that need uniqueness (blocked sites, apps)
- Implement **proper error handling** with custom error types and throws
- Follow **SwiftUI naming**: Views end with "View", Managers end with "Manager"
- Use **meaningful variable names** - no abbreviations except common ones (id, url)
- Group related functionality with **// MARK:** comments
- Keep **models in separate files** - don't mix UI and business logic

## Architecture
- Core managers coordinate through FuegoCore singleton
- UI layer uses environment objects for state binding
- All persistence goes through PersistenceManager
- Modular design: each feature area is self-contained
