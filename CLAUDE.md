# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Required Setup
- **Create Config.plist**: This file is REQUIRED and must be created in the `Project Columbus` directory with Supabase credentials:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SupabaseURL</key>
    <string>YOUR_SUPABASE_URL</string>
    <key>SupabaseKey</key>
    <string>YOUR_SUPABASE_ANON_KEY</string>
</dict>
</plist>
```
- **NEVER commit Config.plist** - it's already in .gitignore
- **Xcode 15.0+** and **iOS 17.0+** required

### Build Commands
```bash
# Build for simulator
xcodebuild -project "Project Columbus copy.xcodeproj" -scheme "Project Columbus" -destination "platform=iOS Simulator,name=iPhone 15" build

# Build for device
xcodebuild -project "Project Columbus copy.xcodeproj" -scheme "Project Columbus" -destination "generic/platform=iOS" build

# Run tests
xcodebuild -project "Project Columbus copy.xcodeproj" -scheme "Project Columbus" -destination "platform=iOS Simulator,name=iPhone 15" test

# Archive for distribution
xcodebuild -project "Project Columbus copy.xcodeproj" -scheme "Project Columbus" -archivePath "Project Columbus.xcarchive" archive
```

### Deployment Scripts
```bash
# Setup verification (run first)
./scripts/check_setup.sh

# Complete deployment (commit + push + TestFlight)
./scripts/deploy.sh "Your commit message"

# TestFlight upload only
./scripts/deploy_testflight.sh
```

## Architecture Overview

### Core Design Pattern
- **SwiftUI + MVVM**: Modern declarative UI with clean separation of concerns
- **Supabase Backend**: Authentication, real-time data, and database operations
- **Combine Framework**: Reactive programming for data flow and state management

### Key Architectural Components

#### 1. Data Layer (`Models.swift`)
- **Pin**: Core location model with social features (reactions, comments, star ratings)
- **PinList**: Collection system with sharing capabilities (private, public, collaborative)
- **User/AppUser**: User management with following/follower relationships
- **Message/Conversation**: Real-time messaging system
- **Location Models**: History tracking, geofencing, privacy settings
- Database conversion extensions for Supabase integration

#### 2. Backend Integration (`SupabaseManager.swift`)
- Singleton pattern for centralized backend operations
- Real-time subscriptions for live updates
- Handles authentication, CRUD operations, and social features
- Secure credential management via Config.plist

#### 3. Authentication (`AuthManager.swift` + `AuthService.swift`)
- Session management with automatic persistence
- Apple Sign-In and email/password authentication
- Biometric authentication (Face ID/Touch ID) support
- Secure keychain storage for credentials

#### 4. State Management (`PinStore.swift`)
- Central data store using `@StateObject` pattern
- Database synchronization with local caching
- Reactive updates throughout the UI
- List and pin management operations

#### 5. Location Services (`LocationManager.swift`)
- Real-time location tracking with privacy controls
- Geofencing capabilities for location-based features
- Background location updates with user consent
- Location history and analytics

#### 6. Deep Linking (`URLRouter.swift`)
- Universal Links support for sharing profiles/content
- URL pattern matching for navigation
- Associated domains configuration required

### Data Flow Architecture
1. **Authentication Flow**: AuthManager → SupabaseManager → Session Storage
2. **Data Loading**: PinStore → SupabaseManager → Database → UI Updates
3. **Real-time Updates**: Supabase Realtime → SupabaseManager → Published Properties → UI
4. **User Actions**: UI → PinStore/AuthManager → SupabaseManager → Database

### Key Features Implementation
- **Social Map Sharing**: Pin creation, reactions, comments system
- **Lists & Collections**: Organizational system with privacy controls
- **Following System**: Social graph with activity feeds
- **Real-time Messaging**: Direct messages and notifications
- **Location Privacy**: Granular controls for location sharing
- **Biometric Security**: Face ID/Touch ID for enhanced security

## Development Guidelines

### Configuration Management
- All sensitive data goes in Config.plist (excluded from git)
- Environment-specific settings should use build configurations
- Never hardcode API keys or credentials in source code

### State Management Pattern
- Use `@StateObject` for data stores (PinStore, AuthManager)
- Use `@EnvironmentObject` for sharing state across views
- Leverage `@Published` properties for reactive UI updates

### Database Operations
- All database calls go through SupabaseManager
- Use conversion extensions for type safety (Pin ↔ PinDB)
- Handle async operations with proper error handling

### Testing Strategy
- Unit tests in `Project ColumbusTests/`
- UI tests in `Project ColumbusUITests/`
- Test authentication flows and data persistence
- Mock SupabaseManager for isolated testing

### Deep Linking Setup
- Requires hosting apple-app-site-association file at `https://carto.app/.well-known/apple-app-site-association`
- Update bundle ID and team ID in association file
- Test with Branch.io AASA validator

### Security Considerations
- Config.plist excluded from version control
- Keychain integration for credential storage
- Proper session management and token refresh
- Location privacy controls and user consent