# Carto - Social Map Sharing App

A social map-sharing iOS app built with SwiftUI and Supabase that allows users to discover, share, and organize location-based experiences.

## 🚀 Features

- **Social Map Sharing**: Share favorite locations with friends
- **Location Discovery**: Search and discover new places
- **Collections**: Organize pins into custom lists (Favorites, Coffee Shops, etc.)
- **Following System**: Follow friends and see their recommendations
- **Real-time Feed**: Live updates from people you follow
- **Authentication**: Email/password and Apple Sign-In support
- **Biometric Login**: Face ID / Touch ID support

## 🛠️ Setup Instructions

### Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Supabase account

### Configuration

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd carto
   ```

2. **Create Config.plist** (REQUIRED)
   
   Create a file named `Config.plist` in the `Project Columbus` directory with your Supabase credentials:
   
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

   ⚠️ **IMPORTANT**: Never commit `Config.plist` to version control. It's already included in `.gitignore`.

3. **Install Dependencies**
   
   Open `Project Columbus.xcodeproj` in Xcode and ensure all Swift Package dependencies are resolved.

4. **Build and Run**
   
   Select your target device/simulator and press `Cmd+R` to build and run.

## 🏗️ Architecture

- **SwiftUI**: Modern declarative UI framework
- **MVVM Pattern**: Clean separation of concerns
- **Supabase**: Backend-as-a-Service for authentication and data
- **MapKit**: Native iOS mapping functionality
- **Combine**: Reactive programming for data flow

## 📁 Project Structure

```
Project Columbus/
├── Models/
│   ├── Models.swift          # Core data models (Pin, User, etc.)
│   ├── AppUser.swift         # User model with Supabase integration
│   └── PinStore.swift        # Pin data management
├── Views/
│   ├── ContentView.swift     # Main app container
│   ├── LiveFeedView.swift    # Social feed interface
│   ├── UserProfileView.swift # User profile management
│   └── ...
├── Managers/
│   ├── AuthManager.swift     # Authentication logic
│   ├── SupabaseManager.swift # Backend API integration
│   └── LocationManager.swift # Location services
└── Config.plist             # Secure configuration (not in repo)
```

## 🔒 Security

- Credentials are stored in `Config.plist` (excluded from version control)
- Biometric authentication support
- Secure keychain storage for user credentials
- Proper session management

## 🚧 Development Status

This project is currently in development. Recent improvements include:

✅ **Completed**:
- Fixed hardcoded credentials security issue
- Cleaned up debug code for production
- Consolidated location manager implementations
- Fixed async/await patterns
- Improved pin comparison logic

🔄 **In Progress**:
- Real-time feed updates
- Comprehensive error handling
- Performance optimizations

## 📝 Contributing

1. Ensure `Config.plist` is properly configured
2. Follow SwiftUI and iOS development best practices
3. Test on both simulator and physical devices
4. Never commit sensitive configuration files

## 📄 License

[Add your license information here]

---

**Note**: This app requires a Supabase backend setup. Contact the development team for database schema and RPC function details.
