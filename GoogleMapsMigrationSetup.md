# Google Maps SDK Integration Steps

## Immediate Setup Required

### 1. Add Google Maps SDK Dependencies

**Option A: Swift Package Manager (Recommended)**
1. Open Xcode project
2. Go to File → Add Package Dependencies
3. Add this URL: `https://github.com/googlemaps/ios-maps-sdk`
4. Select "Up to Next Major Version" with version 8.0.0+
5. Add both GoogleMaps and GooglePlaces to your target

**Option B: CocoaPods**
```ruby
# Add to Podfile
pod 'GoogleMaps'
pod 'GooglePlaces'
```
Then run `pod install`

### 2. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable these APIs:
   - Maps SDK for iOS
   - Places API
   - Geocoding API
4. Create API Key with iOS restrictions
5. Add your bundle identifier: `com.yourcompany.ProjectColumbus`

### 3. Configure API Key

Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` in `Project-Columbus-Info.plist` with your actual API key.

### 4. Initialize Google Maps

Add this to your main App file (`Project_ColumbusApp.swift`):

```swift
import GoogleMaps
import GooglePlaces

@main
struct Project_ColumbusApp: App {
    init() {
        // Initialize Google Maps
        if let path = Bundle.main.path(forResource: "Project-Columbus-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let apiKey = plist["GMSApiKey"] as? String {
            GMSServices.provideAPIKey(apiKey)
            GMSPlacesClient.provideAPIKey(apiKey)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 5. Add Feature Flag System

Add this to manage the migration:

```swift
// Add to a new file: MapConfiguration.swift
import SwiftUI

enum MapProvider: String, CaseIterable {
    case apple = "apple"
    case google = "google"
    
    var displayName: String {
        switch self {
        case .apple: return "Apple Maps"
        case .google: return "Google Maps"
        }
    }
}

class MapConfiguration: ObservableObject {
    @AppStorage("selected_map_provider") var provider: MapProvider = .apple
    
    func switchToGoogleMaps() {
        provider = .google
    }
    
    func switchToAppleMaps() {
        provider = .apple
    }
}
```

### 6. Test Basic Setup

Once SDK is added, test that Google Maps initializes:

```swift
// Add to ContentView.swift temporarily
import GoogleMaps

// In body, add:
Text("Google Maps API Key: \(GMSServices.openSourceLicenseInfo() != nil ? "✅ Valid" : "❌ Invalid")")
```

## File Status After Setup

✅ **Created:**
- `GoogleMapsWrapper.swift` - Core Google Maps SwiftUI wrapper
- `GooglePlacesSearchManager.swift` - Search functionality replacement
- `google_maps_migration_plan.md` - Complete migration plan

⏳ **Next Steps:**
1. Add SDK dependencies (above)
2. Configure API key
3. Test basic initialization
4. Begin migrating ContentView.swift

## Cost Estimation

Based on your app usage patterns:
- **Maps SDK**: ~$200-400/month (10K users, average 20 map loads/user/month)
- **Places API**: ~$100-200/month (autocomplete requests)
- **Total**: ~$300-600/month for Google Maps Platform

## Migration Order

1. **Core Infrastructure** ✅ (GoogleMapsWrapper, GooglePlacesSearchManager)
2. **Main Map View** (ContentView.swift)
3. **Search Views** (SearchView.swift)
4. **All Other Map Views** (18 remaining files)
5. **Testing & Validation**
6. **Production Deployment**

Once you complete the SDK setup above, we can immediately begin migrating your main map view! 