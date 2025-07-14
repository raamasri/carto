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

## Comprehensive File Documentation

### Core Application Files

#### `Project_ColumbusApp.swift`
**Purpose**: Main application entry point with lifecycle management
**Key Features**:
- Initializes core application managers (auth, location, data)
- Sets up SwiftData model container for future use
- Manages app lifecycle events (launch, foreground, background)
- Provides global state through environment objects
- Handles authentication state changes
- Coordinates location updates with user login status

#### `ContentView.swift`
**Purpose**: Main content view structure and navigation router
**Key Components**:
- **ContentView**: Main app router handling authentication states
- **MainMapView**: Core map interface with pins, search, and filtering
- **FullPOIView**: Detailed point of interest information display
- **CollectionMapView**: Map view for displaying pin collections
- **Custom Components**: Tab bar, navigation, search functionality

#### `StartupView.swift`
**Purpose**: Startup/onboarding interface with motion effects
**Key Features**:
- **MotionManager**: Device motion detection for parallax effects
- **StartupView**: Animated login/signup interface
- Motion-based parallax background effects
- Animated text introduction with character-by-character display
- Material design buttons with transparency effects

### Authentication System

#### `AuthManager.swift`
**Purpose**: Central authentication manager with comprehensive security
**Key Features**:
- User authentication (email/password, Apple Sign-In)
- Session management and persistence
- Biometric authentication setup and usage (Face ID/Touch ID)
- Secure keychain credential storage
- User profile management and fetching
- End-to-end encryption key management
- Account deletion and cleanup functionality

#### `AuthService.swift`
**Purpose**: Authentication service layer for Supabase integration
**Key Features**:
- Direct Supabase authentication API calls
- Session management utilities
- Error handling and validation

### Data Management

#### `Models.swift`
**Purpose**: Complete data model foundation for the application
**Key Components**:
- **Pin Model**: Core location data with social features
- **PinList Model**: Enhanced list system with sharing and collaboration
- **User Models**: User profiles and authentication data
- **Messaging Models**: Real-time messaging system with encryption
- **Database Models**: Supabase database integration structures
- **Conversion Extensions**: Type-safe database conversions

#### `PinStore.swift`
**Purpose**: Central data store for pins and lists management
**Key Features**:
- Central store for all pin-related data and operations
- Manages pins, lists, favorites, and database synchronization
- Reactive UI updates through @Published properties
- Database synchronization with local caching
- List and pin management operations

### Location Services

#### `LocationManager.swift`
**Purpose**: Comprehensive location management system
**Key Features**:
- Real-time location tracking with configurable accuracy
- Location history storage with privacy controls
- Background location monitoring for enhanced features
- Activity type detection (walking, cycling, driving)
- Distance calculations and utilities
- Integration with notification system for location-based alerts
- Comprehensive permission handling and user controls

### Utilities

#### `DateUtils.swift`
**Purpose**: Comprehensive date and time utility functions
**Key Features**:
- Multiple date formatters for different display contexts
- ISO8601 parsing and formatting for API integration
- Relative time formatting (e.g., "2 hours ago") for social features
- Smart date display logic for various UI contexts
- Time interval formatting for duration display
- Date range utilities for filtering and comparisons
- Age calculation utilities

#### `Logger.swift`
**Purpose**: Comprehensive logging system for debugging and monitoring
**Key Features**:
- Multiple log levels (debug, info, warning, error, success)
- Categorized logging for different app components
- Automatic file/line/function tracking for debugging
- Debug vs release mode handling
- Integration with Apple's unified logging system
- Convenient global logging functions

### Design System

#### `Constants.swift`
**Purpose**: Centralized constants and configuration values
**Key Features**:
- Design system constants (colors, fonts, spacing)
- API configuration values
- Feature flags and toggles
- Localization keys

#### `DistanceFormatter.swift`
**Purpose**: Location distance formatting utilities
**Key Features**:
- Human-readable distance formatting
- Unit conversion (metric/imperial)
- Contextual distance display

### Security & Privacy

#### `EncryptionManager.swift`
**Purpose**: End-to-end encryption management
**Key Features**:
- RSA key pair generation and management
- Message encryption and decryption
- Secure key storage in keychain
- Public key distribution system

#### `ValidationManager.swift`
**Purpose**: Input validation and data integrity
**Key Features**:
- Email and password validation
- Location data validation
- User input sanitization
- Security checks and validations

### Error Handling

#### `ErrorHandling.swift`
**Purpose**: Centralized error handling and user feedback
**Key Features**:
- Comprehensive error types and handling
- User-friendly error messages
- Error reporting and logging
- Recovery mechanisms and fallbacks

## Development Guidelines

### Code Organization Standards
- **File Headers**: All files include comprehensive descriptions and architecture notes
- **MARK Comments**: Clear section organization with descriptive markers
- **Function Documentation**: Detailed parameter and return value documentation
- **Type Safety**: Comprehensive enum usage for type safety
- **Error Handling**: Robust error handling with user-friendly messages

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

### Performance Optimization
- Image caching with Actor-based concurrency
- Efficient database queries with proper indexing
- Background location updates with smart filtering
- Memory management with proper cleanup

### Logging Standards
- Use appropriate log levels for different message types
- Categorize logs by functional area (Auth, Network, Database, etc.)
- Include sufficient context for debugging
- Use structured logging for better searchability

### Privacy & Security
- Implement privacy-first design patterns
- Use end-to-end encryption for sensitive data
- Provide granular privacy controls to users
- Follow Apple's privacy guidelines and requirements