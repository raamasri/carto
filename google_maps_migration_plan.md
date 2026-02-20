# Google Maps Migration Plan for Project Columbus

## Executive Summary

This document outlines the complete migration from Apple MapKit to Google Maps Platform, preserving 100% feature parity with zero UI/UX changes. The migration affects 19 files and covers all map interactions, POI features, search functionality, and location services.

## Current MapKit Implementation Analysis

### Files Requiring Migration (19 total):
1. **ContentView.swift** - Main map interface with complex annotations
2. **SearchView.swift** - Location search and autocomplete
3. **CreatePostView.swift** - POI search for post creation
4. **FindFriendsView.swift** - Friend location mapping
5. **GeofenceManagementView.swift** - Geofence visualization
6. **LocationDetailView.swift** - Location detail maps
7. **LocationHistoryView.swift** - Historical location display
8. **LocationStoriesView.swift** - Story location markers
9. **LiveFeedView.swift** - Feed location displays
10. **PinCardView.swift** - Small map previews
11. **UserProfileView.swift** - Profile location maps
12. **FriendReviewListView.swift** - Review location maps
13. **LocationManager.swift** - Location services
14. **Models.swift** - Data model conversions
15. **SettingsView.swift** - Map type preferences
16. **SmartRecommendationsView.swift** - Recommendation maps
17. **ProximityAlertsView.swift** - Alert location maps
18. **FriendActivityFeedView.swift** - Activity location maps
19. **SendToFriendsView.swift** - Share location maps

### Current Features to Preserve:
- **Map Types**: Standard, Satellite, Hybrid
- **Camera Management**: Smooth transitions, user tracking, auto-centering
- **Annotations**: Custom pin views, user location, search results
- **Search**: Autocomplete, POI discovery, location details
- **Interactions**: Pin tapping, map gestures, sheet presentations
- **Data Models**: Pin conversion, location storage

## Phase 1: Google Maps SDK Setup

### 1.1 Add Dependencies
```swift
// Add to Xcode project or Package.swift
dependencies: [
    .package(url: "https://github.com/googlemaps/ios-maps-sdk", from: "8.0.0")
]
```

### 1.2 API Key Configuration
- Enable APIs: Maps SDK, Places API, Geocoding API
- Add to Info.plist:
```xml
<key>GMSApiKey</key>
<string>YOUR_GOOGLE_MAPS_API_KEY</string>
```

### 1.3 App Initialization
```swift
// In Project_ColumbusApp.swift
import GoogleMaps
import GooglePlaces

@main
struct Project_ColumbusApp: App {
    init() {
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let apiKey = plist["API_KEY"] as? String {
            GMSServices.provideAPIKey(apiKey)
            GMSPlacesClient.provideAPIKey(apiKey)
        }
    }
    // ... rest of app
}
```

## Phase 2: Core Google Maps Wrapper Components

### 2.1 Google Maps View Wrapper
```swift
// New file: GoogleMapsWrapper.swift
import SwiftUI
import GoogleMaps

struct GoogleMapsView: UIViewRepresentable {
    @Binding var cameraPosition: GMSCameraPosition
    @Binding var selectedAnnotation: UUID?
    
    let annotations: [PinAnnotation]
    let mapType: GMSMapViewType
    let showsUserLocation: Bool
    let onCameraChange: ((GMSCameraPosition) -> Void)?
    let onAnnotationTap: ((UUID) -> Void)?
    
    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView()
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = showsUserLocation
        mapView.mapType = mapType
        mapView.camera = cameraPosition
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.camera = cameraPosition
        mapView.mapType = mapType
        mapView.isMyLocationEnabled = showsUserLocation
        
        // Update annotations
        mapView.clear()
        context.coordinator.annotations = annotations
        
        for annotation in annotations {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: annotation.latitude, longitude: annotation.longitude)
            marker.title = annotation.title
            marker.userData = annotation.id
            marker.map = mapView
            
            // Custom marker view if provided
            if let customView = annotation.customView {
                marker.iconView = UIHostingController(rootView: customView).view
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapsView
        var annotations: [PinAnnotation] = []
        
        init(_ parent: GoogleMapsView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            parent.onCameraChange?(position)
        }
        
        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let annotationId = marker.userData as? UUID {
                parent.onAnnotationTap?(annotationId)
                parent.selectedAnnotation = annotationId
            }
            return true
        }
    }
}
```

### 2.2 Annotation Data Structure
```swift
// In Models.swift - Add Google Maps support
struct PinAnnotation: Identifiable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let title: String
    let customView: AnyView?
    
    init(from pin: Pin, customView: AnyView? = nil) {
        self.id = pin.id
        self.latitude = pin.latitude
        self.longitude = pin.longitude
        self.title = pin.locationName
        self.customView = customView
    }
}

extension Pin {
    func toGoogleMapsAnnotation(customView: AnyView? = nil) -> PinAnnotation {
        return PinAnnotation(from: self, customView: customView)
    }
}
```

### 2.3 Camera Position Converter
```swift
// New file: MapKitToGoogleMapsConverter.swift
import MapKit
import GoogleMaps

struct MapConverter {
    static func gmsCamera(from mkRegion: MKCoordinateRegion) -> GMSCameraPosition {
        return GMSCameraPosition(
            latitude: mkRegion.center.latitude,
            longitude: mkRegion.center.longitude,
            zoom: zoomLevel(from: mkRegion.span)
        )
    }
    
    static func mkRegion(from gmsCamera: GMSCameraPosition, span: MKCoordinateSpan) -> MKCoordinateRegion {
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: gmsCamera.target.latitude, longitude: gmsCamera.target.longitude),
            span: span
        )
    }
    
    static func mapType(from string: String) -> GMSMapViewType {
        switch string {
        case "Satellite": return .satellite
        case "Hybrid": return .hybrid
        default: return .normal
        }
    }
    
    private static func zoomLevel(from span: MKCoordinateSpan) -> Float {
        // Convert MKCoordinateSpan to Google Maps zoom level
        let maxZoom: Float = 21.0
        let longitudeDelta = span.longitudeDelta
        if longitudeDelta <= 0 { return maxZoom }
        
        let mapWidthInPixels: Double = UIScreen.main.bounds.width
        let zoomScale = longitudeDelta * mapWidthInPixels / 360.0
        let zoom = Float(log2(zoomScale))
        return max(0, min(maxZoom, 21 - zoom))
    }
}
```

## Phase 3: Google Places API Integration

### 3.1 Replace MKLocalSearch
```swift
// New file: GooglePlacesSearchManager.swift  
import GooglePlaces
import Combine

class GooglePlacesSearchManager: ObservableObject {
    private let placesClient = GMSPlacesClient.shared()
    @Published var searchResults: [GMSAutocompletePrediction] = []
    @Published var isLoading = false
    
    func search(query: String, location: CLLocationCoordinate2D? = nil) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        
        let filter = GMSAutocompleteFilter()
        filter.types = [.establishment, .geocode]
        
        var bounds: GMSCoordinateBounds?
        if let location = location {
            let northeast = CLLocationCoordinate2D(latitude: location.latitude + 0.1, longitude: location.longitude + 0.1)
            let southwest = CLLocationCoordinate2D(latitude: location.latitude - 0.1, longitude: location.longitude - 0.1)
            bounds = GMSCoordinateBounds(coordinate: northeast, coordinate: southwest)
        }
        
        placesClient.findAutocompletePredictions(fromQuery: query,
                                               bounds: bounds,
                                               boundsMode: .bias,
                                               filter: filter) { [weak self] results, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    print("Google Places search error: \(error)")
                    return
                }
                self?.searchResults = results ?? []
            }
        }
    }
    
    func getPlaceDetails(for prediction: GMSAutocompletePrediction) -> AnyPublisher<GMSPlace, Error> {
        Future<GMSPlace, Error> { [weak self] promise in
            let fields: GMSPlaceField = [.name, .coordinate, .placeID, .formattedAddress, .phoneNumber, .website]
            
            self?.placesClient.fetchPlace(fromPlaceID: prediction.placeID, placeFields: fields) { place, error in
                if let error = error {
                    promise(.failure(error))
                } else if let place = place {
                    promise(.success(place))
                } else {
                    promise(.failure(NSError(domain: "GooglePlacesError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
```

### 3.2 Search Result Conversion
```swift
// Extension to convert Google Places to Pin
extension GMSPlace {
    func toPin(authorHandle: String = "@you") -> Pin {
        return Pin(
            locationName: self.name ?? "Unknown Place",
            city: self.formattedAddress?.components(separatedBy: ", ").dropFirst().first ?? "",
            date: formattedDate(),
            latitude: self.coordinate.latitude,
            longitude: self.coordinate.longitude,
            reaction: .lovedIt,
            reviewText: nil,
            mediaURLs: [],
            mentionedFriends: [],
            starRating: nil,
            distance: nil,
            authorHandle: authorHandle,
            createdAt: Date(),
            tripName: nil
        )
    }
}

extension GMSAutocompletePrediction {
    var primaryText: String { attributedPrimaryText.string }
    var secondaryText: String { attributedSecondaryText?.string ?? "" }
}
```

## Phase 4: File Migration Strategy

### 4.1 ContentView.swift Migration
**Key Changes:**
```swift
// Replace MapKit imports
import GoogleMaps

// Replace Map component in MainMapView
GoogleMapsView(
    cameraPosition: $gmsCameraPosition,
    selectedAnnotation: $selectedPinForPopup,
    annotations: filteredPins.map { $0.toGoogleMapsAnnotation(customView: AnyView(MainMapEnhancedPinAnnotation(pin: $0, pinStore: pinStore))) },
    mapType: MapConverter.mapType(from: selectedMapType),
    showsUserLocation: true,
    onCameraChange: { position in
        // Handle camera changes
    },
    onAnnotationTap: { pinId in
        // Handle pin tap
    }
)
```

### 4.2 SearchView.swift Migration
```swift
// Replace MKLocalSearchCompleter with GooglePlacesSearchManager
@StateObject private var placesManager = GooglePlacesSearchManager()

// Update search functionality
.onChange(of: searchText) { _, newValue in
    if newValue.starts(with: "@") || newValue.starts(with: "#") {
        performSearch(for: newValue)
    } else {
        placesManager.search(query: newValue, location: locationManager.lastKnownLocation?.coordinate)
    }
}

// Update results display
ForEach(placesManager.searchResults, id: \.placeID) { prediction in
    VStack(alignment: .leading) {
        Text(prediction.primaryText)
            .font(.headline)
        if !prediction.secondaryText.isEmpty {
            Text(prediction.secondaryText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    .onTapGesture {
        selectPlace(prediction)
    }
}
```

### 4.3 Data Model Updates
```swift
// Update Pin model extensions in Models.swift
extension Pin {
    // Remove toMapItem(), add toGMSPlace()
    func toGMSPlace() -> GMSPlace? {
        // Create GMSPlace equivalent if needed
        // Most functionality will use PinAnnotation instead
        return nil
    }
}
```

## Phase 5: Complete File Migration List

### Priority 1 - Core Map Views:
1. **ContentView.swift** - Main map interface
2. **SearchView.swift** - Search functionality  
3. **Models.swift** - Data model updates

### Priority 2 - Map Display Views:
4. **CreatePostView.swift** - Post creation maps
5. **LocationDetailView.swift** - Location detail maps
6. **UserProfileView.swift** - Profile maps
7. **FindFriendsView.swift** - Friend location maps

### Priority 3 - Secondary Map Views:
8. **LiveFeedView.swift** - Feed location displays
9. **PinCardView.swift** - Map previews
10. **LocationHistoryView.swift** - History maps
11. **LocationStoriesView.swift** - Story markers
12. **FriendReviewListView.swift** - Review maps

### Priority 4 - Specialized Views:
13. **GeofenceManagementView.swift** - Geofence visualization
14. **SmartRecommendationsView.swift** - Recommendation maps
15. **ProximityAlertsView.swift** - Alert location maps
16. **FriendActivityFeedView.swift** - Activity maps
17. **SendToFriendsView.swift** - Share location maps

### Priority 5 - Settings and Manager:
18. **SettingsView.swift** - Map type preferences
19. **LocationManager.swift** - Location services integration

## Phase 6: Testing and Validation

### 6.1 Feature Parity Checklist:
- [ ] Map displays correctly with all three types (Standard, Satellite, Hybrid)
- [ ] Camera positioning matches original behavior
- [ ] All pin annotations display with custom views
- [ ] Search autocomplete works identically
- [ ] POI selection and details work
- [ ] User location tracking functions
- [ ] Map gestures and interactions preserved
- [ ] Performance matches or exceeds original

### 6.2 Data Migration:
- [ ] Existing pins display correctly
- [ ] Pin lists maintain functionality  
- [ ] Search history preserved (if any)
- [ ] User preferences maintained

## Phase 7: Deployment Strategy

### 7.1 Feature Flag Implementation:
```swift
enum MapProvider {
    case apple, google
}

class AppConfiguration: ObservableObject {
    @Published var mapProvider: MapProvider = .apple
    
    func enableGoogleMaps() {
        mapProvider = .google
    }
}
```

### 7.2 Gradual Rollout:
1. Deploy with Apple Maps as default
2. Enable Google Maps for testing users
3. Monitor performance and user feedback
4. Full rollout once validated
5. Remove Apple Maps code after successful migration

## Cost Considerations

### Google Maps Platform Pricing:
- **Maps SDK**: $2.00 per 1,000 map loads
- **Places API**: $0.032 per autocomplete request
- **Geocoding**: $0.005 per request

### Estimated Monthly Costs (for 10K active users):
- Map loads: ~$200-400/month
- Search requests: ~$100-200/month
- Total: ~$300-600/month

## Implementation Timeline

- **Week 1**: Setup, wrapper components, core infrastructure
- **Week 2**: Priority 1 files migration
- **Week 3**: Priority 2 files migration  
- **Week 4**: Priority 3 & 4 files migration
- **Week 5**: Testing, bug fixes, performance optimization
- **Week 6**: Feature flag deployment and gradual rollout

## Next Steps

1. **Start with Phase 1**: Set up Google Maps SDK
2. **Create wrapper components**: Build the foundational Google Maps wrapper
3. **Migrate ContentView.swift**: Replace the main map implementation
4. **Test core functionality**: Ensure basic map display works
5. **Continue with search migration**: Replace MKLocalSearch
6. **Proceed systematically**: Through all 19 files in priority order

This migration preserves 100% of existing functionality while switching to Google Maps as the underlying provider. The UI/UX remains identical to users. 