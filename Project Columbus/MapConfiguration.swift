import SwiftUI

/**
 * MapConfiguration
 * 
 * Manages the map provider selection for the app, allowing seamless switching
 * between Apple Maps and Google Maps during migration. This feature flag system
 * ensures the app can compile and run with either provider.
 */
class MapConfiguration: ObservableObject {
    @AppStorage("selected_map_provider") var provider: MapProvider = .apple
    
    static let shared = MapConfiguration()
    
    private init() {}
    
    func switchToGoogleMaps() {
        provider = .google
    }
    
    func switchToAppleMaps() {
        provider = .apple
    }
    
    var isGoogleMapsEnabled: Bool {
        provider == .google
    }
    
    var isAppleMapsEnabled: Bool {
        provider == .apple
    }
}

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

// MARK: - Conditional Imports Wrapper

/**
 * Wrapper to handle conditional compilation based on whether Google Maps SDK is available
 */
struct GoogleMapsAvailability {
    static var isSDKAvailable: Bool {
        #if canImport(GoogleMaps)
        return true
        #else
        return false
        #endif
    }
} 