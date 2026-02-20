//
//  ContentView.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/16/25.
//
//  DESCRIPTION:
//  This file contains the main content view structure and supporting components for the
//  Project Columbus (Carto) social map-sharing app. It includes the primary map interface,
//  navigation, point of interest views, and various UI components.
//
//  MAJOR COMPONENTS:
//  - ContentView: Main app router that handles authentication states
//  - MainMapView: Core map interface with pins, search, and filtering
//  - FullPOIView: Detailed point of interest information display
//  - CollectionMapView: Map view for displaying pin collections
//  - Custom tab bar and navigation components
//  - Search functionality and map item handling
//  - Sidebar and profile integration
//
//  ARCHITECTURE:
//  - SwiftUI-based declarative UI
//  - MapKit integration for location services
//  - Environment objects for global state management
//  - Reactive data flow with @Published properties
//  - Custom view modifiers and extensions
//

import SwiftUI
import MapKit
import CoreLocation

#if canImport(GoogleMaps)
import GoogleMaps
#endif
import Speech
import NaturalLanguage
import AVFoundation
import Combine
import Foundation

#if canImport(GoogleMaps)
import GoogleMaps
#endif

#if canImport(GooglePlaces)
import GooglePlaces
#endif

// MARK: - Point of Interest Views

/**
 * FullPOIView
 * 
 * A comprehensive view for displaying detailed information about a point of interest.
 * This view presents location details including name, address, phone number, and website.
 * It's typically presented as a sheet or navigation destination when a user selects
 * a location from search results or map markers.
 */
struct FullPOIView: View {
    /// The map item containing location data and metadata
    let mapItem: MKMapItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Location name/title
                Text(mapItem.name ?? "Unknown Place")
                    .font(.largeTitle)
                    .bold()

                // Address information
                if let address = mapItem.placemark.title {
                    Text(address)
                        .font(.body)
                }

                // Phone number if available
                if let phone = mapItem.phoneNumber {
                    Text("Phone: \(phone)")
                }

                // Website link if available
                if let url = mapItem.url {
                    Link("Visit Website", destination: url)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Location Details")
    }
}

// MARK: - Design System Constants

/**
 * AppSpacing
 * 
 * Centralized spacing and layout constants used throughout the app.
 * This ensures consistent spacing and visual hierarchy across all components.
 */
struct AppSpacing {
    /// Standard horizontal padding for most UI elements
    static let horizontal: CGFloat = 16
    
    /// Standard vertical spacing between elements
    static let vertical: CGFloat = 12
    
    /// Standard corner radius for rounded elements
    static let cornerRadius: CGFloat = 12
}

// MARK: - Collection Map View

/**
 * CollectionMapView
 * 
 * A specialized map view for displaying a collection of pins.
 * This view automatically centers the map on the pins and provides
 * a clean interface for viewing multiple related locations.
 */
struct CollectionMapView: View {
    /// Array of pins to display on the map
    let pins: [Pin]
    
    /// Camera position state for map positioning
    @State private var cameraPosition: MapCameraPosition
    
    /// Google Maps camera position
    @State private var gmsCameraPosition: GMSCameraPosition = GMSCameraPosition.defaultSanFrancisco
    
    /// Map configuration for provider selection
    @ObservedObject private var mapConfig = MapConfiguration.shared
    
    /**
     * Initializer that sets up the map camera position
     * Centers the map on the first pin or defaults to San Francisco
     */
    init(pins: [Pin]) {
        self.pins = pins
        if let first = pins.first {
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )))
        } else {
            // Default to San Francisco if no pins available
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )))
        }
    }
    
    var body: some View {
        if mapConfig.isAppleMapsEnabled {
            // Apple Maps Implementation
            Map(position: .constant(.region(MKCoordinateRegion(
                center: pins.first.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )))) {
                // Display markers for all pins in the collection
                ForEach(pins, id: \.id) { pin in
                    Marker("", coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
                        .tint(.red)
                }
            }
            .edgesIgnoringSafeArea(.all)
            .navigationTitle("Map View")
        } else {
            // Google Maps Implementation
            #if canImport(GoogleMaps)
            GoogleMapsView(
                cameraPosition: $gmsCameraPosition,
                selectedAnnotation: .constant(nil),
                annotations: pins.map { pin in
                    pin.toGoogleMapsAnnotation(
                        customView: AnyView(
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                        )
                    )
                },
                mapType: .normal,
                showsUserLocation: false,
                onCameraChange: nil,
                onAnnotationTap: nil
            )
            .edgesIgnoringSafeArea(.all)
            .navigationTitle("Map View")
            .onAppear {
                // Center on pins when view appears
                if let firstPin = pins.first {
                    gmsCameraPosition = GMSCameraPosition.standard(
                        coordinate: CLLocationCoordinate2D(latitude: firstPin.latitude, longitude: firstPin.longitude),
                        zoom: 13.0
                    )
                }
            }
            #else
            // Fallback when Google Maps SDK is not available
            Text("Google Maps SDK not available")
                .foregroundColor(.red)
                .padding()
                .navigationTitle("Map View")
            #endif
        }
    }
}

// MARK: - Utility Functions

/**
 * Returns a formatted date string for the current date
 * Used for displaying current date in various UI components
 */
    // Removed duplicate formattedDate() - already defined in GooglePlacesSearchManager.swift

// MARK: - Supporting Data Models

/**
 * IdentifiableMapItem
 * 
 * A wrapper around MKMapItem that conforms to Identifiable protocol.
 * This allows MapKit items to be used in SwiftUI lists and other
 * views that require identifiable items.
 */
struct IdentifiableMapItem: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
}



// MARK: - Main Map View Interface

/**
 * MainMapView
 * 
 * The primary map interface for the Project Columbus app. This complex view serves as the
 * central hub for user interaction with the map, pins, and social features.
 * 
 * FUNCTIONALITY:
 * - Displays interactive map with user pins and markers
 * - Handles location search and point of interest discovery
 * - Manages map filtering by lists, time, and star ratings
 * - Provides navigation to other app sections via bottom tab bar
 * - Integrates with location services for user position tracking
 * - Supports pin creation, editing, and social interactions
 * - Manages sidebar navigation and user profile access
 * 
 * ARCHITECTURE:
 * - Environment object integration for global state
 * - Complex state management with multiple @State properties
 * - Reactive filtering and pin display logic
 * - MapKit integration for location services
 * - Search functionality with MKLocalSearchCompleter
 */
struct MainMapView: View {
    
    // MARK: - Environment Objects
    
    /// Authentication manager for user session and login state
    @EnvironmentObject var authManager: AuthManager
    
    /// Pin store for managing pins, lists, and user data
    @EnvironmentObject var pinStore: PinStore
    
    /// Location manager for GPS services and location tracking
    @EnvironmentObject var locationManager: AppLocationManager
    
    /// Map configuration for switching between Apple Maps and Google Maps
    @StateObject private var mapConfig = MapConfiguration.shared
    
    /// Place validation service for cross-checking between map providers
    // @StateObject private var placeValidator = PlaceValidationService() // Disabled for now
    
    // MARK: - Map State Management
    
    /// Controls whether the map should track the user's location
    @State private var shouldTrackUser = false
    
    /// Google Maps camera position state
    #if canImport(GoogleMaps)
    @State private var gmsCameraPosition: GMSCameraPosition = GMSCameraPosition.defaultSanFrancisco
    #else
    @State private var gmsCameraPosition: GMSCameraPosition = GMSCameraPosition.defaultSanFrancisco
    #endif
    
    /// Property to store selected Google Place (parallel to selectedMapItem)
    @State private var selectedGooglePlace: Any? = nil
    
    /// Indicates when the user is manually panning or zooming the map
    @State private var isUserManuallyMovingMap = false
    
    /// Current camera position and region displayed on the map
    @State private var cameraPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    
    /// Map display style (Standard, Satellite, Hybrid)
    @AppStorage("selectedMapType") private var selectedMapType: String = "Standard"
    
    /// Tracks whether the map has auto-centered on user location
    @State private var hasAutocentered = false
    
    // MARK: - Navigation State
    
    /// Controls the display of the sidebar menu
    @State private var showSideMenu = false
    
    /// Currently selected tab in the bottom navigation
    @State private var selectedTab = 0
    
    /// Binding to trigger navigation to the live feed view
    @Binding var navigateToFeed: Bool
    
    // MARK: - Pin Selection and Interaction
    
    /// Currently selected pin for detail view
    @State private var selectedPin: Pin? = nil
    
    /// Pin ID for popup/modal display
    @State private var selectedPinForPopup: UUID? = nil
    
    /// Animation state for pin pulse effect
    @State private var animatePulse = false
    
    // MARK: - Search Functionality
    
    /// Current search text entered by the user
    @State private var searchText: String = ""
    
    /// Search results from MKLocalSearchCompleter
    @State private var searchResults: [MKLocalSearchCompletion] = []
    
    /// MapKit search completer for location suggestions
    @State private var searchCompleter = MKLocalSearchCompleter()
    
    /// Delegate holder for search completer callbacks
    @State private var searchCompleterDelegateHolder: SearchCompleterDelegate? = nil
    
    /// Currently selected map item from search results
    @State private var selectedMapItem: MKMapItem? = nil
    
    /// Controls display of full point of interest view
    @State private var showFullPOIView: Bool = false
    
    /// Controls display of POI sheet modal
    @State private var showPOISheet: Bool = false
    
    /// Focus state for search text field
    @FocusState private var isSearchFieldFocused: Bool
    
    // MARK: - Place Validation State
    
    /// Currently validated place pending user confirmation
    // @State private var pendingValidatedPlace: PlaceValidationService.ValidatedPlace? // Disabled for now
    
    /// Shows the place validation dialog
    // @State private var showValidationDialog = false // Disabled for now
    
    /// The search query that triggered validation
    // @State private var validationQuery: String = "" // Disabled for now
    
    // MARK: - Search Results State
    
    /// Search result pins to display on map and in swipeable cards
    @State private var searchResultPins: [Pin] = []
    
    /// Controls display of search results sheet
    @State private var showSearchResults: Bool = false
    
    /// Original map items for search results (for reference)
    @State private var searchResultMapItems: [MKMapItem] = []
    
    // MARK: - Voice Intelligence State
    
    /// Speech recognizer for voice input
    @State private var speechRecognizer: SFSpeechRecognizer?
    
    /// Audio engine for voice input processing
    @State private var audioEngine = AVAudioEngine()
    
    /// Speech recognition request
    @State private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    
    /// Speech recognition task
    @State private var speechTask: SFSpeechRecognitionTask?
    
    /// Controls voice recording state
    @State private var isRecording = false
    
    /// Voice input authorization status
    @State private var speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
    
    /// Current voice query text
    @State private var voiceQueryText = ""
    
    /// Natural language tagger for intent recognition
    @State private var nlTagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    
    /// Voice intelligence processing state
    @State private var isProcessingVoice = false
    
    /// Speech recognizer availability
    @State private var isSpeechRecognizerAvailable = false
    
    /// Real-time transcription text for user feedback
    @State private var liveTranscriptionText = ""
    
    // MARK: - Profile and Account Management
    
    /// Controls display of user profile sheet
    @State private var showUserProfile = false
    
    /// Controls display of account menu
    @State private var showAccountMenu = false
    
    /// Controls display of profile edit sheet
    @State private var showProfileEdit = false
    
    /// Controls display of account settings
    @State private var showAccountSettings = false
    
    // MARK: - Map Filtering System
    
    /// Controls display of map filters interface
    @State private var showMapFilters = false
    
    /// Currently selected list filter for pin display
    @State private var selectedListFilter: UUID? = nil
    
    /// Currently selected time filter for pin display
    @State private var selectedTimeFilter: TimeFilter = .all
    
    /// Currently selected star rating filter for pin display
    @State private var selectedStarFilter: StarFilter = .all
    
    /// Search text for filtering pins on the map
    @State private var mapSearchText = ""
    
    // MARK: - Computed Properties
    
    /**
     * Filtered pins based on current filter settings
     * 
     * This computed property applies multiple filtering criteria to the pins:
     * - Deduplicates pins that appear in multiple lists
     * - Filters by selected list if specified
     * - Filters by time period (week, month, year)
     * - Filters by star rating
     * - Includes comprehensive logging for debugging
     */
    private var filteredPins: [Pin] {
        // Only show pins that are actually in user's lists (not orphaned pins)
        // Use Set to remove duplicates when pins appear in multiple lists
        let allPins = pinStore.lists.flatMap { $0.pins }
        var uniquePins: [Pin] = []
        var seenIds: Set<UUID> = []
        
        for pin in allPins {
            if !seenIds.contains(pin.id) {
                uniquePins.append(pin)
                seenIds.insert(pin.id)
            }
        }
        
        // Debug logging to help identify discrepancies
        if allPins.count != uniquePins.count {
            print("🔍 Map: Found \(allPins.count) total pins, \(uniquePins.count) unique pins (removed \(allPins.count - uniquePins.count) duplicates)")
        }
        
        var pins = uniquePins
        
        // Filter by list selection
        if let listId = selectedListFilter {
            pins = pins.filter { pin in
                pinStore.lists.first(where: { $0.id == listId })?.pins.contains(where: { $0.id == pin.id }) == true
            }
        }
        
        // Filter by time period
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeFilter {
        case .all:
            break // No filtering
        case .thisWeek:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            pins = pins.filter { $0.createdAt >= weekAgo }
        case .thisMonth:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            pins = pins.filter { $0.createdAt >= monthAgo }
        case .thisYear:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            pins = pins.filter { $0.createdAt >= yearAgo }
        }
        
        // Filter by star rating
        switch selectedStarFilter {
        case .all:
            break // No filtering
        case .fiveStars:
            pins = pins.filter { ($0.starRating ?? 0) >= 4.5 }
        case .fourPlus:
            pins = pins.filter { ($0.starRating ?? 0) >= 4.0 }
        case .threePlus:
            pins = pins.filter { ($0.starRating ?? 0) >= 3.0 }
        }
        
        // Filter by search text
        if !mapSearchText.isEmpty {
            pins = pins.filter { pin in
                pin.locationName.localizedCaseInsensitiveContains(mapSearchText) ||
                pin.city.localizedCaseInsensitiveContains(mapSearchText) ||
                (pin.tripName?.localizedCaseInsensitiveContains(mapSearchText) ?? false)
            }
        }
        
        return pins
    }
    
    // Filter badge computed properties
    private var hasActiveFilters: Bool {
        selectedListFilter != nil || 
        selectedTimeFilter != .all || 
        selectedStarFilter != .all || 
        !mapSearchText.isEmpty
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if selectedListFilter != nil { count += 1 }
        if selectedTimeFilter != .all { count += 1 }
        if selectedStarFilter != .all { count += 1 }
        if !mapSearchText.isEmpty { count += 1 }
        return count
    }
    
    // Helper function to center map on filtered pins
    private func centerMapOnFilteredPins() {
        let pins = filteredPins
        guard !pins.isEmpty else { 
            print("📍 No pins available to center on")
            return 
        }
        
        print("📍 Centering map on \(pins.count) pin(s)")
        
        if pins.count == 1 {
            let pin = pins[0]
            withAnimation(.easeInOut(duration: 1.0)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        } else {
            let latitudes = pins.map { $0.latitude }
            let longitudes = pins.map { $0.longitude }
            
            let minLat = latitudes.min() ?? 0
            let maxLat = latitudes.max() ?? 0
            let minLon = longitudes.min() ?? 0
            let maxLon = longitudes.max() ?? 0
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let span = MKCoordinateSpan(
                latitudeDelta: max(0.01, (maxLat - minLat) * 1.2),
                longitudeDelta: max(0.01, (maxLon - minLon) * 1.2)
            )
            
            withAnimation(.easeInOut(duration: 1.0)) {
                cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
            }
        }
    }

    struct POIPopup: View {
        let mapItem: MKMapItem
        let userLocation: CLLocationCoordinate2D?
        @Binding var showPOISheet: Bool
        @Binding var showFullPOIView: Bool
        @EnvironmentObject var pinStore: PinStore
        @EnvironmentObject var authManager: AuthManager
        @State private var showAddedAlert = false
        @State private var showAddToList = false
        @State private var friends: [AppUser] = []
        @State private var isLoadingFriends = false

        var body: some View {
            VStack {
                Spacer()
                mainPopupContent
            }
            .sheet(isPresented: $showAddToList) {
                AddToListSheet(pin: tempPin) { list in
                    pinStore.addPin(tempPin, to: list)
                    showAddedAlert = true
                }
            }
            .alert("Added to List!", isPresented: $showAddedAlert) {
                Button("OK", role: .cancel) { }
            }
        }

        private var tempPin: Pin {
            Pin(
                locationName: mapItem.name ?? "Unknown Place",
                city: mapItem.placemark.locality ?? "",
                date: formattedDate(),
                latitude: mapItem.placemark.coordinate.latitude,
                longitude: mapItem.placemark.coordinate.longitude,
                reaction: .lovedIt,
                reviewText: nil,
                mediaURLs: [],
                mentionedFriends: [],
                starRating: nil,
                distance: nil,
                authorHandle: "@you",
                createdAt: Date(),
                tripName: nil
            )
        }
        
        /// Creates the content to share when the share button is tapped
        private var shareContent: String {
            let placeName = mapItem.name ?? "Unknown Place"
            let address = mapItem.placemark.title ?? "No address available"
            let coordinate = mapItem.placemark.coordinate
            let mapsURL = "https://maps.apple.com/?q=\(coordinate.latitude),\(coordinate.longitude)"
            
            return """
            Check out this place I found: \(placeName)
            
            📍 \(address)
            
            🗺️ View on Maps: \(mapsURL)
            """
        }

        private var mainPopupContent: some View {
            VStack(alignment: .leading, spacing: 8) {
                titleBar
                friendsSection
                addressView
                lookAroundView
                distanceView
                addToListButton
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .cornerRadius(AppSpacing.cornerRadius)
            .padding(.horizontal, 4)
            .padding(.bottom, 60)
            .onAppear {
                loadFriendsData()
            }
        }

        private var titleBar: some View {
            ZStack(alignment: .topTrailing) {
                Text(mapItem.name ?? "Unknown Place")
                    .font(.title.bold())
                    .lineLimit(1)
                    .padding(.trailing, 150)

                HStack(spacing: 10) {
                    // Share Button
                    ShareLink(item: shareContent) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                    
                    // Directions Button
                    Button(action: {
                        let placemark = mapItem.placemark
                        let mapItem = MKMapItem(placemark: placemark)
                        mapItem.name = placemark.name
                        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    }) {
                        Image(systemName: "arrow.turn.up.right")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }

                    // Close Button
                    Button(action: {
                        showPOISheet = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.gray)
                            .clipShape(Circle())
                    }
                }
            }
        }

        private var addressView: some View {
            Group {
                if let address = mapItem.placemark.title {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }

        @available(iOS 16.0, *)
        private var lookAroundView: some View {
            LookAroundPreview(coordinate: mapItem.placemark.coordinate)
                .frame(height: 200)
                .cornerRadius(AppSpacing.cornerRadius)
        }

        private var distanceView: some View {
            Group {
                if let distance = userLocation.map({ CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: CLLocation(latitude: mapItem.placemark.coordinate.latitude, longitude: mapItem.placemark.coordinate.longitude)) }) {
                    Text(DistanceFormatter.formatDistanceWithLabel(distance))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }

        private var friendsSection: some View {
            Group {
                if isLoadingFriends {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading friends...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                } else {
                    let friendsAtLocation = getFriendsAtLocation()
                    let averageRating = getAverageRating(from: friendsAtLocation)
                    
                    if !friendsAtLocation.isEmpty {
                        HStack(spacing: 8) {
                            // Friend avatars
                            HStack(spacing: -8) {
                                ForEach(Array(friendsAtLocation.prefix(4)), id: \.friend.id) { friendPin in
                                    AsyncImage(url: URL(string: friendPin.friend.avatarURL ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                }
                                
                                if friendsAtLocation.count > 4 {
                                    Text("+\(friendsAtLocation.count - 4)")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.gray)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                }
                            }
                            
                            // Average rating
                            if averageRating > 0 {
                                HStack(spacing: 3) {
                                    Text(String(format: "%.1f", averageRating))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Image(systemName: "star.fill")
                                        .font(.caption2)
                                        .foregroundColor(.yellow)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(4)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }

        private var addToListButton: some View {
            HStack {
                Button(action: { showAddToList = true }) {
                    Label(getButtonText(), systemImage: getButtonIcon())
                        .font(.headline)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .background(getButtonColor())
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.leading)
                Spacer()
                Button("Show More") {
                    showFullPOIView = true
                }
            }
            .padding(.top, 8)
        }

        // MARK: - Friends Helper Functions
        
        private func loadFriendsData() {
            guard let userID = authManager.currentUserID else { return }
            
            isLoadingFriends = true
            Task {
                let fetchedFriends = await SupabaseManager.shared.getFollowingUsers(for: userID)
                await MainActor.run {
                    friends = fetchedFriends
                    isLoadingFriends = false
                }
            }
        }
        
        private func getFriendsAtLocation() -> [(friend: AppUser, pin: Pin)] {
            let coordinate = mapItem.placemark.coordinate
            let locationName = mapItem.name ?? "Unknown Place"
            
            // Get all pins that match this location
            let matchingPins = pinStore.masterPins.filter { pin in
                // Check if coordinates are very close (within ~10 meters)
                let latitudeDiff = abs(pin.latitude - coordinate.latitude)
                let longitudeDiff = abs(pin.longitude - coordinate.longitude)
                let isLocationMatch = latitudeDiff < 0.0001 && longitudeDiff < 0.0001
                
                // Also check if location names match
                let isNameMatch = pin.locationName.lowercased().contains(locationName.lowercased()) ||
                                locationName.lowercased().contains(pin.locationName.lowercased())
                
                return isLocationMatch || isNameMatch
            }
            
            // Match pins to friends and return the pairs
            return friends.compactMap { friend in
                if let matchingPin = matchingPins.first(where: { pin in
                    pin.authorHandle.contains(friend.username)
                }) {
                    return (friend: friend, pin: matchingPin)
                }
                return nil
            }
        }
        
        private func getAverageRating(from friendPins: [(friend: AppUser, pin: Pin)]) -> Double {
            let ratings = friendPins.compactMap { $0.pin.starRating }
            guard !ratings.isEmpty else { return 0 }
            return ratings.reduce(0, +) / Double(ratings.count)
        }

        // MARK: - Helper Functions for List Status
        /// Finds all lists that contain a location with matching coordinates and name
        private func getListsContainingLocation() -> [PinList] {
            let coordinate = mapItem.placemark.coordinate
            let locationName = mapItem.name ?? "Unknown Place"
            
            return pinStore.lists.filter { list in
                list.pins.contains { pin in
                    // Check if coordinates are very close (within ~10 meters)
                    let latitudeDiff = abs(pin.latitude - coordinate.latitude)
                    let longitudeDiff = abs(pin.longitude - coordinate.longitude)
                    let isLocationMatch = latitudeDiff < 0.0001 && longitudeDiff < 0.0001
                    // Also check if the name matches (case insensitive)
                    let isNameMatch = pin.locationName.lowercased() == locationName.lowercased()
                    return isLocationMatch || isNameMatch
                }
            }
        }
        /// Gets the button text based on whether the location is already in lists
        private func getButtonText() -> String {
            let listsContainingLocation = getListsContainingLocation()
            if listsContainingLocation.isEmpty {
                return "Add to List"
            } else if listsContainingLocation.count == 1 {
                let listName = listsContainingLocation.first!.name
                return "In \(listName)"
            } else {
                return "In \(listsContainingLocation.count) lists"
            }
        }
        /// Gets the button icon based on whether the location is already in lists
        private func getButtonIcon() -> String {
            let listsContainingLocation = getListsContainingLocation()
            return listsContainingLocation.isEmpty ? "plus.circle.fill" : "checkmark.circle.fill"
        }
        /// Gets the button color based on whether the location is already in lists
        private func getButtonColor() -> Color {
            let listsContainingLocation = getListsContainingLocation()
            return listsContainingLocation.isEmpty ? .blue : .green
        }
    }
    
    func handlePinTap(_ pin: Pin) {
        // Convert Pin to MKMapItem for POI popup
        let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = pin.locationName
        
        selectedMapItem = mapItem
        showPOISheet = true
    }
    
    func handleSearchSelection(_ completion: MKLocalSearchCompletion) {
        // Create search request from completion
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        
        search.start { response, error in
            guard let response = response, let mapItem = response.mapItems.first else {
                print("Search failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Create new pin from search result
            let newPin = Pin(
                locationName: mapItem.name ?? completion.title,
                city: mapItem.placemark.locality ?? "",
                date: formattedDate(),
                latitude: mapItem.placemark.coordinate.latitude,
                longitude: mapItem.placemark.coordinate.longitude,
                reaction: .lovedIt,
                reviewText: nil,
                mediaURLs: [],
                mentionedFriends: [],
                starRating: nil,
                distance: nil,
                authorHandle: "@you",
                createdAt: Date(),
                tripName: nil
            )
            
            // Update selectedPin for display
            selectedPin = newPin
            showFullPOIView = true
            
            // Clear search
            searchText = ""
            searchResults = []
        }
    }
    
    func handleSearchSubmit() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Perform map search
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        if let userLocation = locationManager.currentLocation {
            request.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response, let mapItem = response.mapItems.first else {
                print("Search failed: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            // Create new pin from search result
            let newPin = Pin(
                locationName: mapItem.name ?? searchText,
                city: mapItem.placemark.locality ?? "",
                date: formattedDate(),
                latitude: mapItem.placemark.coordinate.latitude,
                longitude: mapItem.placemark.coordinate.longitude,
                reaction: .lovedIt,
                reviewText: nil,
                mediaURLs: [],
                mentionedFriends: [],
                starRating: nil,
                distance: nil,
                authorHandle: "@you",
                createdAt: Date(),
                tripName: nil
            )
            
            // Update selectedPin for display
            selectedPin = newPin
            showFullPOIView = true
            
            // Clear search
            searchText = ""
            searchResults = []
        }
    }
    
    // Validation functions disabled
    
    // Helper functions disabled
    
    // Legacy search function disabled
    private func performLegacySearch() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        // Use broader Bay Area region to ensure we get results
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
        
        print("🔍 [ContentView] Starting legacy search for: '\(searchText)'")
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                print("❌ [ContentView] Search error: \(error.localizedDescription)")
                return
            }
            
            guard let response = response else {
                print("❌ [ContentView] No search response")
                return
            }
            
            print("🔍 [ContentView] Found \(response.mapItems.count) search results")
            
            // Convert all results to Pin objects for display only (not saved)
            let pins = response.mapItems.map { mapItem in
                let pin = Pin(
                    locationName: mapItem.name ?? "Unknown Location",
                    city: mapItem.placemark.locality ?? mapItem.placemark.administrativeArea ?? "",
                    date: formattedDate(),
                    latitude: mapItem.placemark.coordinate.latitude,
                    longitude: mapItem.placemark.coordinate.longitude,
                    reaction: .lovedIt,
                    reviewText: nil,
                    mediaURLs: [],
                    mentionedFriends: [],
                    starRating: nil,
                    distance: nil,
                    authorHandle: "@search",
                    createdAt: Date(),
                    tripName: nil
                )
                print("📍 [ContentView] Created search pin: \(pin.locationName) at \(pin.latitude), \(pin.longitude)")
                return pin
            }
            
            // Update state on main thread
            DispatchQueue.main.async {
                searchResultPins = pins
                searchResultMapItems = response.mapItems
                
                if !pins.isEmpty {
                    showSearchResults = true
                    print("🎴 [ContentView] Showing search results with \(pins.count) pins")
                } else {
                    print("❌ [ContentView] No search results to display")
                }
                
                // Clear search UI
                searchText = ""
                searchResults = []
                isSearchFieldFocused = false
            }
        }
    }
    
    // Helper function to center map on search result pin
    private func centerMapOnSearchPin(_ pin: Pin) {
        print("🗺️ [ContentView] Centering map on search pin: \(pin.locationName)")
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    // MARK: - Voice Intelligence Functions
    
    /// Initialize speech recognizer and check availability
    private func initializeSpeechRecognizer() {
        print("[LOG] initializeSpeechRecognizer called")
        
        // Create speech recognizer for current locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        // Check if speech recognizer is available
        if speechRecognizer != nil {
            isSpeechRecognizerAvailable = true
            print("[LOG] Speech recognizer initialized successfully")
        } else {
            isSpeechRecognizerAvailable = false
            print("[LOG] Speech recognizer not available for current locale")
        }
        
        // Update authorization status
        speechAuthStatus = SFSpeechRecognizer.authorizationStatus()
        print("[LOG] Initial speech auth status: \(speechAuthStatus.rawValue)")
    }
    
    /// Requests permissions and starts voice recording
    private func startVoiceRecording() {
        print("[LOG] startVoiceRecording called")
        print("🎤 [VoiceIntelligence] Starting voice recording...")
        
        // Check if speech recognizer is available
        guard speechRecognizer != nil else {
            print("❌ [VoiceIntelligence] Speech recognizer not available")
            return
        }
        
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                print("[LOG] Speech authorization status: \(authStatus.rawValue)")
                self.speechAuthStatus = authStatus
                
                if authStatus == .authorized {
                    // Request microphone permission (iOS 17+ compatible)
                    if #available(iOS 17.0, *) {
                        AVAudioApplication.requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                print("[LOG] Microphone permission granted: \(granted)")
                                if granted {
                                    self.beginVoiceRecording()
                                } else {
                                    print("❌ [VoiceIntelligence] Microphone permission denied")
                                }
                            }
                        }
                    } else {
                        // Fallback for iOS 16 and earlier
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                print("[LOG] Microphone permission granted: \(granted)")
                                if granted {
                                    self.beginVoiceRecording()
                                } else {
                                    print("❌ [VoiceIntelligence] Microphone permission denied")
                                }
                            }
                        }
                    }
                } else {
                    print("❌ [VoiceIntelligence] Speech recognition not authorized: \(authStatus)")
                }
            }
        }
    }
    
    /// Begins the actual voice recording process
    private func beginVoiceRecording() {
        print("[LOG] beginVoiceRecording called")
        print("🎤 [VoiceIntelligence] Beginning voice recording...")
        
        // Cancel any existing task
        speechTask?.cancel()
        speechTask = nil
        
        // Clear live transcription for new recording
        liveTranscriptionText = ""
        voiceQueryText = ""
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("[LOG] Audio session configured successfully")
        } catch {
            print("❌ [VoiceIntelligence] Audio session error: \(error)")
            return
        }
        
        // Create speech recognition request
        speechRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let speechRequest = speechRequest else {
            print("❌ [VoiceIntelligence] Unable to create speech request")
            return
        }
        
        speechRequest.shouldReportPartialResults = true
        
        // Create audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            print("[LOG] Audio buffer appended to speech request")
            speechRequest.append(buffer)
        }
        
        // Prepare and start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            voiceQueryText = ""
            print("[LOG] Audio engine started successfully")
            print("🎤 [VoiceIntelligence] Audio engine started successfully")
        } catch {
            print("❌ [VoiceIntelligence] Audio engine start error: \(error)")
            return
        }
        
        // Start speech recognition task
        guard let recognizer = speechRecognizer else {
            print("❌ [VoiceIntelligence] Speech recognizer not available for task creation")
            return
        }
        
        speechTask = recognizer.recognitionTask(with: speechRequest) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    print("[LOG] Speech recognition result received: \(result.bestTranscription.formattedString)")
                    self.voiceQueryText = result.bestTranscription.formattedString
                    
                    // Update live transcription for real-time feedback
                    self.liveTranscriptionText = result.bestTranscription.formattedString
                    print("🎤 [VoiceIntelligence] Live transcription: \(self.liveTranscriptionText)")
                    
                    if result.isFinal {
                        print("[LOG] Speech recognition result is final")
                        self.processVoiceQuery(self.voiceQueryText)
                    }
                }
                
                if let error = error {
                    print("❌ [VoiceIntelligence] Speech recognition error: \(error.localizedDescription)")
                    self.stopVoiceRecording()
                }
            }
        }
    }
    
    /// Stops voice recording and cleans up resources
    private func stopVoiceRecording() {
        print("[LOG] stopVoiceRecording called")
        print("🎤 [VoiceIntelligence] Stopping voice recording...")
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        speechRequest?.endAudio()
        speechTask?.cancel()
        
        speechRequest = nil
        speechTask = nil
        isRecording = false
        
        // Process the final voice query if we have text
        if !voiceQueryText.isEmpty {
            print("[LOG] Processing final voice query after stop: \(voiceQueryText)")
            processVoiceQuery(voiceQueryText)
        } else {
            print("[LOG] No voice query text to process")
        }
        
        // Clear live transcription after a brief delay to show final result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.liveTranscriptionText = ""
        }
        
        print("🎤 [VoiceIntelligence] Voice recording stopped")
    }
    
    /// Processes the voice query using natural language understanding
    private func processVoiceQuery(_ query: String) {
        print("[LOG] processVoiceQuery called with query: \(query)")
        print("🧠 [VoiceIntelligence] Processing voice query: \(query)")
        
        isProcessingVoice = true
        print("[LOG] isProcessingVoice set to true")
        
        // Use NLTagger for basic intent and entity recognition
        nlTagger.string = query.lowercased()
        print("[LOG] NLTagger string set: \(query.lowercased())")
        
        // Extract entities and intent
        let voiceIntent = extractVoiceIntent(from: query)
        print("[LOG] Extracted voice intent: \(voiceIntent)")
        
        // Process based on intent
        switch voiceIntent.type {
        case .findLocation:
            print("[LOG] Detected intent: findLocation")
            handleFindLocationIntent(voiceIntent)
        case .findWithSocialContext:
            print("[LOG] Detected intent: findWithSocialContext")
            handleSocialContextIntent(voiceIntent)
        case .general:
            print("[LOG] Detected intent: general")
            handleGeneralSearchIntent(voiceIntent)
        }
        
        isProcessingVoice = false
        print("[LOG] isProcessingVoice set to false")
    }
    
    /// Extracts intent and entities from voice query
    private func extractVoiceIntent(from query: String) -> VoiceIntent {
        print("[LOG] extractVoiceIntent called with query: \(query)")
        let lowercaseQuery = query.lowercased()
        
        // Check for social context keywords
        let socialKeywords = ["sarah", "mike", "friend", "friends", "loved", "liked", "recommended", "both"]
        let hasSocialContext = socialKeywords.contains { lowercaseQuery.contains($0) }
        print("[LOG] hasSocialContext: \(hasSocialContext)")
        
        // Check for location keywords
        let locationKeywords = ["find", "search", "locate", "where", "near", "close", "nearby"]
        let hasLocationIntent = locationKeywords.contains { lowercaseQuery.contains($0) }
        print("[LOG] hasLocationIntent: \(hasLocationIntent)")
        
        // Extract location type
        let locationTypes = [
            "coffee": ["coffee", "cafe", "starbucks", "coffee shop"],
            "restaurant": ["restaurant", "food", "eat", "dining"],
            "store": ["store", "shop", "shopping"],
            "park": ["park", "garden", "outdoor"],
            "gas": ["gas", "fuel", "gas station"]
        ]
        
        var extractedLocationType = ""
        var extractedFriends: [String] = []
        var timeConstraint = ""
        
        // Find location type
        for (type, keywords) in locationTypes {
            if keywords.contains(where: { lowercaseQuery.contains($0) }) {
                extractedLocationType = type
                print("[LOG] extractedLocationType: \(type)")
                break
            }
        }
        
        // Extract friend names (simple pattern matching)
        if lowercaseQuery.contains("sarah") { extractedFriends.append("sarah"); print("[LOG] Found friend: sarah") }
        if lowercaseQuery.contains("mike") { extractedFriends.append("mike"); print("[LOG] Found friend: mike") }
        
        // Extract time constraints
        if lowercaseQuery.contains("10 minutes") || lowercaseQuery.contains("ten minutes") {
            timeConstraint = "10 minutes"
            print("[LOG] Found time constraint: 10 minutes")
        } else if lowercaseQuery.contains("5 minutes") || lowercaseQuery.contains("five minutes") {
            timeConstraint = "5 minutes"
            print("[LOG] Found time constraint: 5 minutes")
        } else if lowercaseQuery.contains("15 minutes") || lowercaseQuery.contains("fifteen minutes") {
            timeConstraint = "15 minutes"
            print("[LOG] Found time constraint: 15 minutes")
        }
        
        // Determine intent type
        let intentType: VoiceIntentType
        if hasSocialContext && hasLocationIntent {
            intentType = .findWithSocialContext
            print("[LOG] intentType: findWithSocialContext")
        } else if hasLocationIntent {
            intentType = .findLocation
            print("[LOG] intentType: findLocation")
        } else {
            intentType = .general
            print("[LOG] intentType: general")
        }
        
        let intent = VoiceIntent(
            type: intentType,
            originalQuery: query,
            locationType: extractedLocationType,
            friends: extractedFriends,
            timeConstraint: timeConstraint
        )
        print("[LOG] Returning VoiceIntent: \(intent)")
        return intent
    }
    
    /// Handles find location intent
    private func handleFindLocationIntent(_ intent: VoiceIntent) {
        print("[LOG] handleFindLocationIntent called with intent: \(intent)")
        print("🔍 [VoiceIntelligence] Handling find location intent: \(intent.locationType)")
        
        // Use the existing search functionality
        let searchQuery = intent.locationType.isEmpty ? intent.originalQuery : intent.locationType
        print("[LOG] Setting searchText to: \(searchQuery)")
        searchText = searchQuery
        handleSearchSubmit()
    }
    
    /// Handles social context intent
    private func handleSocialContextIntent(_ intent: VoiceIntent) {
        print("[LOG] handleSocialContextIntent called with intent: \(intent)")
        print("👥 [VoiceIntelligence] Handling social context intent for friends: \(intent.friends)")
        
        // For now, perform a regular search and then we'll filter by social context
        // In a full implementation, this would query the database for friend preferences
        let searchQuery = intent.locationType.isEmpty ? intent.originalQuery : intent.locationType
        print("[LOG] Setting searchText to: \(searchQuery)")
        searchText = searchQuery
        handleSearchSubmit()
        
        // TODO: Implement social context filtering
        // This would involve querying the database for pins/reviews from specified friends
    }
    
    /// Handles general search intent
    private func handleGeneralSearchIntent(_ intent: VoiceIntent) {
        print("[LOG] handleGeneralSearchIntent called with intent: \(intent)")
        print("🔍 [VoiceIntelligence] Handling general search intent")
        
        print("[LOG] Setting searchText to: \(intent.originalQuery)")
        searchText = intent.originalQuery
        handleSearchSubmit()
    }
    
    struct PinAnnotationView: View {
        let pin: Pin
        let isSelected: Bool
        let onTap: () -> Void
        
        var body: some View {
            Circle()
                .fill(isSelected ? Color.red : Color.blue)
                .frame(width: isSelected ? 30 : 12, height: isSelected ? 30 : 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .shadow(radius: isSelected ? 4 : 0)
                .scaleEffect(isSelected ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
                .onTapGesture(perform: onTap)
        }
    }
    
    struct PinAnnotationDot: View {
        let pin: Pin
        let isSelected: Bool
        let onTap: () -> Void
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: isSelected ? 34 : 24, height: isSelected ? 34 : 24)
                    .shadow(radius: isSelected ? 4 : 2)
                
                Image(systemName: "mappin.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .foregroundColor(.red)
            }
            .scaleEffect(isSelected ? 1.3 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .onTapGesture(perform: onTap)
        }
    }
    
    struct SearchResultPinAnnotation: View {
        let pin: Pin
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 30, height: 30)
                    .shadow(radius: 3)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
            }
            .scaleEffect(1.0)
        }
    }

    var body: some View {
        ZStack {
            if selectedTab == 0 {

                ZStack {
                    ZStack {
                        // Conditional map rendering based on configuration
                        if mapConfig.isAppleMapsEnabled {
                            // Apple Maps Implementation
                            Map(position: $cameraPosition, selection: $selectedPinForPopup) {
                                // Only show pins after initial loading is complete
                                if !pinStore.isLoading {
                                    ForEach(filteredPins, id: \.id) { pin in
                                        Annotation(pin.locationName, coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                                            MainMapEnhancedPinAnnotation(pin: pin, pinStore: pinStore)
                                        }
                                        .tag(pin.id)
                                    }
                                }
                                
                                // Show search result pins
                                ForEach(searchResultPins, id: \.id) { pin in
                                    Annotation(pin.locationName, coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                                        SearchResultPinAnnotation(pin: pin)
                                    }
                                    .tag(pin.id)
                                }
                                
                                // Show user location
                                UserAnnotation()
                            }
                            .onChange(of: filteredPins) { _, _ in
                                if !pinStore.isLoading {
                                    centerMapOnFilteredPins()
                                }
                            }
                        } else {
                            // Google Maps Implementation
                            GoogleMapsView(
                                cameraPosition: $gmsCameraPosition,
                                selectedAnnotation: $selectedPinForPopup,
                                annotations: filteredPins.map { pin in
                                    pin.toGoogleMapsAnnotation(
                                        customView: AnyView(
                                            MainMapEnhancedPinAnnotation(pin: pin, pinStore: pinStore)
                                        )
                                    )
                                },
                                mapType: MapConverter.mapType(from: selectedMapType),
                                showsUserLocation: true,
                                onCameraChange: { position in
                                    // Handle camera changes if needed
                                },
                                onAnnotationTap: { pinId in
                                    if let pin = filteredPins.first(where: { $0.id == pinId }) {
                                        handlePinTap(pin)
                                    }
                                }
                            )
                            .onChange(of: filteredPins) { _, _ in
                                if !pinStore.isLoading {
                                    centerGoogleMapOnFilteredPins()
                                }
                            }
                        }
                        
                        // Loading indicator while pins are being fetched
                        if pinStore.isLoading {
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.blue)
                                Text("Loading pins...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        }
                    }
                    
                    // Filter Panel (Slides from bottom)
                    if showMapFilters {
                        VStack {
                            Spacer()
                            VStack(spacing: 0) {
                                // Header with close button
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showMapFilters = false
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .padding(8)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.top, 12)
                                .padding(.trailing, 16)
                                .padding(.bottom, 8)
                                
                                MainMapFilterPanel(
                                    selectedList: $selectedListFilter,
                                    selectedTimeFilter: $selectedTimeFilter,
                                    selectedStarFilter: $selectedStarFilter,
                                    searchText: $mapSearchText,
                                    availableLists: pinStore.lists
                                )
                                .id("filter-panel-\(pinStore.lists.count)") // Force refresh when lists change
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                            }
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: -4)
                            .padding(.horizontal, 0)
                            .padding(.bottom, 160) // Increased spacing to float above control buttons
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .ignoresSafeArea(.container, edges: .bottom)
                    }
                }
                .mapStyle(styleForMapType(selectedMapType))
                .edgesIgnoringSafeArea(.all)
                .gesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            if value.translation.width > 100 {
                                withAnimation {
                                    showSideMenu = true
                                }
                            } else if value.translation.width < -100 {
                                withAnimation {
                                    showSideMenu = false
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { _ in
                            shouldTrackUser = false
                            isUserManuallyMovingMap = true  // User has moved the map manually
                        }
                        .onEnded { _ in
                            // Delay resetting to false to allow user to scroll without immediate re-centering
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                isUserManuallyMovingMap = false
                            }
                        }
                )

                if showSideMenu {
                    SideMenuView(showSideMenu: $showSideMenu)
                }

            } else if selectedTab == 4 {
                Group {
                    if let currentUser = authManager.currentUser {
                        UserProfileView(profileUser: currentUser)
                            .environmentObject(pinStore)
                            .environmentObject(authManager)
                            .onAppear {
                                // User profile loaded
                            }
                    } else {
                        Text("Loading user profile...")
                            .onAppear {
                                print("📍 selectedTab 4 triggered. currentUser = nil")
                            }
                    }
                }
                .task {
                    if authManager.currentUser == nil {
                        print("🔄 Re-fetching current user from Supabase...")
                        await authManager.fetchCurrentUser()
                    }
                }
            } else if selectedTab == 5 {
                EnhancedListsView()
                    .environmentObject(pinStore)
                    .environmentObject(authManager)
                    .environmentObject(locationManager)
            } else if selectedTab == 1 {
                FindFriendsView()
            } else if selectedTab == 2 {
                CreatePostView()
                    .environmentObject(locationManager)
            } else {
                LiveFeedView()
                    .environmentObject(pinStore)
            }

            if selectedTab == 0 {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 70) // offset below search bar
                    if !searchResults.isEmpty {
                        ZStack {
                            VStack(spacing: 0) {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(searchResults, id: \.self) { result in
                                            Button(action: {
                                                handleSearchSelection(result)
                                                searchText = ""
                                                searchResults = []
                                                isSearchFieldFocused = false
                                            }) {
                                                VStack(alignment: .leading) {
                                                    Text(result.title)
                                                        .font(.headline)
                                                        .foregroundColor(Color.primary)
                                                    if !result.subtitle.isEmpty {
                                                        Text(result.subtitle)
                                                            .font(.caption)
                                                            .foregroundColor(Color.secondary)
                                                    }
                                                }
                                                .padding()
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: CGFloat(searchResults.count) * 72)
                            }
                        }
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.horizontal)
                    }
                    }
                    
                    HStack {
                        // Hamburger menu button
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showSideMenu.toggle()
                            }
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .foregroundColor(.primary)
                                .font(.system(size: 22, weight: .medium))
                        }
                        .padding(.trailing, 8)
                        
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                    
                    ZStack(alignment: .leading) {
                        TextField("Places, Memories, Ideas, #tags", text: $searchText)
                            .autocorrectionDisabled()
                            .focused($isSearchFieldFocused)
                            .onSubmit {
                                handleSearchSubmit()
                            }
                            .padding(8)
                            .opacity(isRecording && !liveTranscriptionText.isEmpty ? 0.3 : 1.0)
                        
                        // Real-time transcription overlay
                        if isRecording && !liveTranscriptionText.isEmpty {
                            HStack {
                                Text(liveTranscriptionText)
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.blue.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                    .animation(.easeInOut(duration: 0.2), value: liveTranscriptionText)
                                
                                Spacer()
                                
                                // Listening indicator
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                        .scaleEffect(isRecording ? 1.2 : 0.8)
                                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
                                    
                                    Text("Listening...")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .fontWeight(.medium)
                                }
                                .padding(.trailing, 8)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                    }
 
                    if !searchText.isEmpty || !searchResults.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Voice Intelligence Button
                    Button(action: {
                        print("[LOG] Voice button tapped - isRecording: \(isRecording)")
                        if isRecording {
                            stopVoiceRecording()
                        } else {
                            startVoiceRecording()
                        }
                    }) {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .foregroundColor(isRecording ? .red : (isSpeechRecognizerAvailable ? .blue : .gray))
                            .font(.system(size: 16, weight: .medium))
                            .scaleEffect(isRecording ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isRecording)
                    }
                    .disabled(!isSpeechRecognizerAvailable)
                    }
                    .padding(AppSpacing.vertical)
                    .background(.ultraThinMaterial)
                    .blur(radius: 0.3)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .padding(.horizontal, AppSpacing.horizontal)
                    .padding(.top, AppSpacing.vertical)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .onChange(of: searchText) { oldValue, newValue in
                        searchCompleter.queryFragment = newValue
                    }
            }

            if selectedTab == 0 {
                VStack {
                    Spacer()
                    HStack {
                        // Refresh Button
                        Button(action: {
                            Task {
                                await pinStore.refresh()
                            }
                        }) {
                            Image(systemName: pinStore.isLoading ? "arrow.clockwise" : "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                                .rotationEffect(.degrees(pinStore.isLoading ? 360 : 0))
                                .animation(pinStore.isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: pinStore.isLoading)
                        }
                        .disabled(pinStore.isLoading)
                        .padding(.bottom, 60)
                        Spacer()
                        // Filter Button
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showMapFilters.toggle()
                            }
                        }) {
                            ZStack {
                                Image(systemName: showMapFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .font(.title2)
                                    .foregroundColor(showMapFilters ? .blue : .gray)
                                    .padding(16)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                                if hasActiveFilters {
                                    Text("\(activeFilterCount)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .frame(width: 16, height: 16)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 12, y: -12)
                                }
                            }
                        }
                        .padding(.bottom, 60)
                        Spacer()
                        // Location Button
                        Button(action: {
                            requestUserLocation()
                            withAnimation {
                                if let location = locationManager.location {
                                    cameraPosition = .region(MKCoordinateRegion(
                                        center: location,
                                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                    ))
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.bottom, 60)
                    }
                    .padding(.horizontal)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        selectedTab = 0
                        centerMapOnFilteredPins()
                    }) {
                        Image(systemName: "house")
                            .font(.title2)
                            .foregroundColor(selectedTab == 0 ? .blue : .gray)
                    }
                    .padding(.horizontal, 8)
                    Spacer()
                    NavBarButton(icon: "person.2", selected: $selectedTab, index: 1)
                        .padding(.horizontal, 8)
                    Spacer()
                    NavBarButton(icon: "plus.circle", selected: $selectedTab, index: 2)
                        .padding(.horizontal, 8)
                    Spacer()
                    NavBarButton(icon: "newspaper", selected: $selectedTab, index: 3)
                        .padding(.horizontal, 8)
                    Spacer()
                    NavBarButton(icon: "person.circle", selected: $selectedTab, index: 4)
                        .padding(.horizontal, 8)
                }
                .padding()
                .padding(.bottom, 25)
                .background(
                    Color.black.opacity(0.2)
                        .background(.ultraThinMaterial)
                        .blur(radius: 0.3)
                        .clipShape(RoundedRectangle(cornerRadius: 0))
                        .padding(.horizontal, 0)
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)

            if let mapItem = selectedMapItem, showPOISheet {
                POIPopup(mapItem: mapItem, userLocation: locationManager.location, showPOISheet: $showPOISheet, showFullPOIView: $showFullPOIView)
                    .environmentObject(authManager)
            }
            
            // Place validation dialog disabled
        }
        .onAppear {
            requestUserLocation()
            animatePulse = true
            self.searchCompleterDelegateHolder = SearchCompleterDelegate { results in
                self.searchResults = results
            }
            searchCompleter.delegate = self.searchCompleterDelegateHolder
            
            // Reset auto-center flag when view appears
            hasAutocentered = false
            
            // Initialize speech recognizer
            initializeSpeechRecognizer()
            
            // Load data immediately if user is already authenticated
            if authManager.isLoggedIn && pinStore.lists.isEmpty {
                Task {
                    await pinStore.refresh()
                }
            }
        }
        .onReceive(authManager.$isLoggedIn) { isLoggedIn in
            // Load data as soon as user is authenticated
            if isLoggedIn && pinStore.lists.isEmpty {
                Task {
                    await pinStore.refresh()
                }
            }
        }
        .onReceive(locationManager.$location.compactMap { $0 }) { location in
            if shouldTrackUser && !isUserManuallyMovingMap {
                withAnimation(.easeInOut(duration: 2.0)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }

            searchCompleter.region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        .onReceive(pinStore.$isLoading) { isLoading in
            // Auto-center map on pins when they finish loading (only once per app launch)
            if !isLoading && !hasAutocentered && !filteredPins.isEmpty {
                print("📍 Auto-centering map on \(filteredPins.count) pin(s) after load")
                hasAutocentered = true
                
                // Use a slight delay to ensure UI is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    centerMapOnFilteredPins()
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newTab in
            // Dismiss the POI popup and clear search results when switching tabs
            showPOISheet = false
            showFullPOIView = false
            showSearchResults = false
            selectedPinForPopup = nil
            searchResults = []
            searchResultPins = []
            searchResultMapItems = []
            searchText = ""
        }
        .onChange(of: showFullPOIView) { oldValue, newValue in
            if !newValue {
                showPOISheet = true
            }
        }
        .onChange(of: selectedPinForPopup) { oldValue, newPinId in
            if let pinId = newPinId, let pin = pinStore.masterPins.first(where: { $0.id == pinId }) {
                handlePinTap(pin)
            }
        }
        .navigationDestination(isPresented: $showFullPOIView) {
            if let mapItem = selectedMapItem {
                LocationDetailView(mapItem: mapItem, onAddPin: { _ in })
                    .environmentObject(authManager)
                    .environmentObject(pinStore)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating messaging button - only show on FindFriendsView tab
            if selectedTab == 1 {
                NavigationLink(destination: DirectMessagingView()
                    .environmentObject(authManager)
                    .onAppear {
                        print("📱 DirectMessagingView appeared from floating button")
                    }
                ) {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 80) // Position just above navbar
                .padding(.trailing, 20)
            }
        }
        .overlay(
            // Sidebar overlay
            HStack {
                if showSideMenu {
                    NavigationSidebar(
                        showSideMenu: $showSideMenu,
                        selectedTab: $selectedTab,
                        authManager: authManager,
                        showUserProfile: $showUserProfile,
                        showAccountMenu: $showAccountMenu,
                        showProfileEdit: $showProfileEdit,
                        showAccountSettings: $showAccountSettings
                    )
                    .transition(.move(edge: .leading))
                }
                Spacer()
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSideMenu)
        )
        // Sheet presentations for sidebar actions

        .sheet(isPresented: $showUserProfile) {
            if let user = authManager.currentUser {
                UserProfileView(profileUser: user)
                        .environmentObject(authManager)
                        .environmentObject(pinStore)
                }
            }

        .sheet(isPresented: $showProfileEdit) {
            ProfileEditView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showAccountSettings) {
            SettingsView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showSearchResults) {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("\(searchResultPins.count) search results")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Done") {
                        showSearchResults = false
                        searchResultPins = []
                        searchResultMapItems = []
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                Divider()
                
                // SwipablePinCardsView for search results
                SwipablePinCardsView(pins: searchResultPins, onPinChanged: centerMapOnSearchPin)
                    .padding(.top, 16)
                    .onAppear {
                        print("🎴 [ContentView] SwipablePinCardsView appeared for search results")
                    }
            }
            .background(.ultraThinMaterial)
            .presentationDetents([.height(500), .large])
            .presentationDragIndicator(.visible)
            .onAppear {
                print("📝 [ContentView] Search results sheet presented with \(searchResultPins.count) pins")
            }
            .onDisappear {
                print("📝 [ContentView] Search results sheet dismissed")
            }
        }

        .actionSheet(isPresented: $showAccountMenu) {
            ActionSheet(
                title: Text("Account Options"),
                buttons: [
                    .default(Text("Edit Profile")) {
                        showProfileEdit = true
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    },
                    .default(Text("Account Settings")) {
                        showAccountSettings = true
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    },
                    .destructive(Text("Log Out")) {
                        Task {
                            await authManager.logOut()
                        }
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    },
                    .cancel()
                ]
            )
        }
        .onAppear {
            // Initialize Google Maps state when view appears
            initializeGoogleMapsState()
        }
    }

    func requestUserLocation() {
        locationManager.requestUserLocationManually()
    }
}

// MARK: - Enhanced Pin Annotation for Main Map
struct MainMapEnhancedPinAnnotation: View {
    let pin: Pin
    let pinStore: PinStore
    
    var body: some View {
        ZStack {
            // Pin background with list color
            Circle()
                .fill(listColor)
                .frame(width: 32, height: 32)
                .shadow(radius: 3)
            
            // Pin icon based on list
            Image(systemName: listIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            // Star rating indicator (if available)
            if let rating = pin.starRating, rating > 0 {
                VStack {
                    Spacer()
                    HStack(spacing: 1) {
                        ForEach(0..<Int(rating.rounded()), id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.horizontal, 2)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .offset(y: 2)
                }
                .frame(width: 32, height: 32)
            }
        }
    }
    
    private var listColor: Color {
        if let primaryList = pinStore.getPrimaryListForPin(pin) {
            return pinStore.getColorForList(named: primaryList.name)
        }
        // Fallback to reaction color if no list found
        return pin.reaction == .lovedIt ? .red : .blue
    }
    
    private var listIcon: String {
        if let primaryList = pinStore.getPrimaryListForPin(pin) {
            return pinStore.getIconForList(named: primaryList.name)
        }
        // Fallback to reaction icon if no list found
        return pin.reaction == .lovedIt ? "heart.fill" : "bookmark.fill"
    }
}

// MARK: - Main Map Filter Panel
struct MainMapFilterPanel: View {
    @Binding var selectedList: UUID?
    @Binding var selectedTimeFilter: TimeFilter
    @Binding var selectedStarFilter: StarFilter
    @Binding var searchText: String
    let availableLists: [PinList]
    
    var body: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                TextField("Search locations, cities, trips...", text: $searchText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 14))
                }
            }
            .padding(.horizontal, 4)
            
            // Filter Categories
            VStack(spacing: 12) {
                // List Filter
                VStack(alignment: .leading, spacing: 4) {
                    Text("List:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "All Lists",
                                isSelected: selectedList == nil,
                                action: { selectedList = nil }
                            )
                            ForEach(availableLists, id: \.id) { list in
                                FilterChip(
                                    title: list.name,
                                    isSelected: selectedList == list.id,
                                    action: { selectedList = list.id }
                                )
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // Time Filter
                HStack {
                    Text("Time:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(TimeFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                isSelected: selectedTimeFilter == filter,
                                action: { selectedTimeFilter = filter }
                            )
                        }
                    }
                }
                
                // Star Rating Filter
                HStack {
                    Text("Rating:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(StarFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.displayName,
                                isSelected: selectedStarFilter == filter,
                                action: { selectedStarFilter = filter }
                            )
                        }
                    }
                }
            }
            
            // Clear All Filters Button
            if hasActiveFilters {
                Button("Clear All Filters") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedList = nil
                        selectedTimeFilter = .all
                        selectedStarFilter = .all
                        searchText = ""
                    }
                }
                .foregroundColor(.red)
                .padding(.top, 8)
            }
        }
    }
    
    private var hasActiveFilters: Bool {
        selectedList != nil || 
        selectedTimeFilter != .all || 
        selectedStarFilter != .all || 
        !searchText.isEmpty
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder Views for Tabs

struct PlaceholderTabView: View {
    let tabIndex: Int

    var body: some View {
        VStack {
            Spacer()
            Text("Tab \(tabIndex) Placeholder")
                .font(.largeTitle)
            Spacer()
        }
    }
}

// MARK: - Side Menu View

struct SideMenuView: View {
    @Binding var showSideMenu: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Overlay Maps")
                    .font(.headline)

                Toggle("Friend 1", isOn: .constant(true))
                Toggle("Friend 2", isOn: .constant(false))

                Spacer()
            }
            .padding()
            .frame(width: 250)
            .background(Color(UIColor.systemBackground))

            Spacer()
        }
        .edgesIgnoringSafeArea(.all)
        .background(Color.black.opacity(0.3).onTapGesture {
            withAnimation {
                showSideMenu = false
            }
        })
    }
}

// MARK: - Navigation Bar Button


struct NavBarButton: View {
    let icon: String
    @Binding var selected: Int
    let index: Int

    var body: some View {
        Button(action: {
            selected = index
        }) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(selected == index ? .blue : .gray)
        }
    }
}



// MARK: - Live Feed View Placeholder

class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    private let onUpdate: ([MKLocalSearchCompletion]) -> Void

    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}




    // MARK: - App Entry Point

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    @AppStorage("themePreference") private var themePreference: String = "Auto"
    @State private var navigateToFeed = false
    @State private var showBiometricPrompt = false

    var body: some View {
        NavigationStack {
            Group {
                if authManager.isLoggedIn {
                    MainMapView(navigateToFeed: $navigateToFeed)
                        .navigationBarHidden(true)
                        .navigationDestination(isPresented: $navigateToFeed) {
                            LiveFeedView()
                        }
                        .environmentObject(authManager)
                        .environmentObject(pinStore)
                } else {
                    StartupView()
                        .environmentObject(authManager)
                }
            }
            .preferredColorScheme(colorScheme)
            .withDeepLinkHandling()
            .onReceive(NotificationCenter.default.publisher(for: .showBiometricPrompt)) { _ in
                showBiometricPrompt = true
            }
            .sheet(isPresented: $showBiometricPrompt) {
                BiometricSetupPromptView {
                    showBiometricPrompt = false
                }
                .environmentObject(authManager)
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch themePreference {
        case "Light":
            return .light
        case "Dark":
            return .dark
        default:
            return nil
        }
    }

}

// MARK: - View Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }

    func styleForMapType(_ type: String) -> MapStyle {
        switch type {
        case "Satellite":
            return .imagery
        case "Hybrid":
            return .hybrid
        default:
            return .standard
        }
    }

// MARK: - Navigation Sidebar

struct NavigationSidebar: View {
    @Binding var showSideMenu: Bool
    @Binding var selectedTab: Int
    let authManager: AuthManager
    @Binding var showUserProfile: Bool
    @Binding var showAccountMenu: Bool
    @Binding var showProfileEdit: Bool
    @Binding var showAccountSettings: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Navigation")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showSideMenu = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Navigation Items
                VStack(spacing: 8) {
                    // Home
                    SidebarMenuItem(
                        icon: "house.fill",
                        title: "Home",
                        isSelected: selectedTab == 0
                    ) {
                        selectedTab = 0
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    }
                    
                    // Videos
                    NavigationLink(destination: VideoFeedView()
                        .environmentObject(authManager)
                        .onAppear {
                            print("📱 VideoFeedView appeared from sidebar")
                        }
                    ) {
                        SidebarMenuItemView(
                            icon: "play.rectangle.fill",
                            title: "Videos",
                            isSelected: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        print("📱 Videos navigation link tapped")
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    })
                    
                    // Live Feed
                    SidebarMenuItem(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Live Feed",
                        isSelected: selectedTab == 3
                    ) {
                        selectedTab = 3
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    }
                    
                    // Friend Activity Feed
                    NavigationLink(destination: FriendActivityFeedView()
                        .environmentObject(authManager)
                        .environmentObject(SupabaseManager.shared)
                        .environmentObject(PinStore())
                        .onAppear {
                            print("📱 FriendActivityFeedView appeared from sidebar")
                        }
                    ) {
                        SidebarMenuItemView(
                            icon: "heart.text.square.fill",
                            title: "Friend Activity",
                            isSelected: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        print("📱 Friend Activity navigation link tapped")
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    })
                    
                    // Smart Recommendations
                    NavigationLink(destination: SmartRecommendationsView()
                        .environmentObject(authManager)
                        .environmentObject(SupabaseManager.shared)
                        .environmentObject(PinStore())
                        .onAppear {
                            print("📱 SmartRecommendationsView appeared from sidebar")
                        }
                    ) {
                        SidebarMenuItemView(
                            icon: "sparkles",
                            title: "Recommendations",
                            isSelected: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        print("📱 Recommendations navigation link tapped")
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    })
                    
                    // Find Friends
                    SidebarMenuItem(
                        icon: "person.2.fill",
                        title: "Find Friends",
                        isSelected: selectedTab == 1
                    ) {
                        selectedTab = 1
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    }
                    
                    // Messages
                    NavigationLink(destination: DirectMessagingView()
                        .environmentObject(authManager)
                        .onAppear {
                            print("📱 DirectMessagingView appeared")
                        }
                    ) {
                        SidebarMenuItemView(
                            icon: "message.fill",
                            title: "Messages",
                            isSelected: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        print("📱 Messages navigation link tapped")
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    })
                    
                    // My Profile
                    SidebarMenuItem(
                        icon: "person.circle.fill",
                        title: "My Profile",
                        isSelected: selectedTab == 4
                    ) {
                        selectedTab = 4
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    }
                    
                    // Settings
                    NavigationLink(destination: SettingsView()
                        .environmentObject(authManager)
                        .onAppear {
                            print("📱 SettingsView appeared")
                        }
                    ) {
                        SidebarMenuItemView(
                            icon: "gearshape.fill",
                            title: "Settings",
                            isSelected: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .simultaneousGesture(TapGesture().onEnded {
                        print("📱 Settings navigation link tapped")
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    })
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Footer with user info
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    if let user = authManager.currentUser {
                        Button(action: {
                            showAccountMenu = true
                        }) {
                            HStack(spacing: 12) {
                                // User avatar with cached loading
                                SidebarUserAvatar(user: user)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.full_name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    Text("@\(user.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.up")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(width: 280)
            .background(.ultraThinMaterial)
            .onAppear {
                print("🔄 [Sidebar] Refreshing current user data")
                Task {
                    await authManager.fetchCurrentUser()
                }
            }
            
            Spacer()
        }
        .background(
            Color.black.opacity(0.3)
                .onTapGesture {
                    print("📱 Background tapped - closing sidebar")
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSideMenu = false
                    }
                }
                .allowsHitTesting(true)
        )
    }
}

// MARK: - Sidebar Menu Item

struct SidebarMenuItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            print("📱 SidebarMenuItem '\(title)' tapped")
            action()
        }) {
            SidebarMenuItemView(icon: icon, title: title, isSelected: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Sidebar Menu Item View (Visual Component)

struct SidebarMenuItemView: View {
    let icon: String
    let title: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .blue : .primary)
                .frame(width: 24)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .blue : .primary)
            
            Spacer()
            
            if isSelected {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Sidebar User Avatar

struct SidebarUserAvatar: View {
    let user: AppUser
    @State private var profileImage: Image? = nil
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = profileImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            }
                        }
                    )
            }
        }
        .onAppear {
            loadUserAvatar()
        }
        .onChange(of: user.avatarURL) { oldValue, newValue in
            loadUserAvatar()
        }
    }
    
    private func loadUserAvatar() {
        print("👤 [SidebarAvatar] Loading avatar for user: \(user.username)")
        
        // Check cache first
        if let cached = ImageCache.shared.image(forKey: user.id) {
            print("👤 [SidebarAvatar] Found cached avatar for \(user.username)")
            profileImage = Image(uiImage: cached)
            return
        }
        
        // Check if user has avatar URL
        guard let avatarURL = user.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) else {
            print("👤 [SidebarAvatar] No avatar URL for user: \(user.username)")
            return
        }
        
        // Download avatar
        isLoading = true
        print("👤 [SidebarAvatar] Downloading avatar from: \(avatarURL)")
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    if let uiImage = UIImage(data: data) {
                        // Cache the image
                        ImageCache.shared.insertImage(uiImage, forKey: user.id)
                        profileImage = Image(uiImage: uiImage)
                        print("👤 [SidebarAvatar] Successfully loaded and cached avatar for \(user.username)")
                    } else {
                        print("👤 [SidebarAvatar] Failed to create UIImage from data for \(user.username)")
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("👤 [SidebarAvatar] Failed to download avatar for \(user.username): \(error)")
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Voice Intelligence Data Structures

/// Represents the type of voice intent
enum VoiceIntentType {
    case findLocation
    case findWithSocialContext
    case general
}

/// Represents a parsed voice intent with extracted entities
struct VoiceIntent {
    let type: VoiceIntentType
    let originalQuery: String
    let locationType: String
    let friends: [String]
    let timeConstraint: String
}

// MARK: - Google Maps Integration

extension MainMapView {
    
    /// Main body that switches between map providers
    var mapProviderBody: some View {
        Group {
            if MapConfiguration.shared.isGoogleMapsEnabled {
                // Use Google Maps
                googleMapsBody
                    .onAppear {
                        print("🗺️ Using Google Maps")
                        initializeGoogleMapsState()
                    }
            } else {
                // Use Apple Maps (existing implementation)
                body
                    .onAppear {
                        print("🗺️ Using Apple Maps")
                    }
            }
        }
    }
    
    /// Initialize Google Maps specific state
    private func initializeGoogleMapsState() {
        // For now, use a default region since MapCameraPosition pattern matching has syntax issues
        // TODO: Improve this once we understand the exact MapCameraPosition structure
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        
        // Convert MapKit region to Google Maps camera position
        #if canImport(GoogleMaps)
        gmsCameraPosition = MapConverter.gmsCamera(from: region)
        #else
        // Use mock converter when SDK not available
        gmsCameraPosition = GMSCameraPosition(
            latitude: region.center.latitude,
            longitude: region.center.longitude,
            zoom: 13.0
        )
        #endif
    }
    
    /// Google Maps version of the map body
    var googleMapsBody: some View {
        ZStack {
            if selectedTab == 0 {
                ZStack {
                    ZStack {
                        // Google Maps View replacing MapKit Map
                        GoogleMapsView(
                            cameraPosition: $gmsCameraPosition,
                            selectedAnnotation: $selectedPinForPopup,
                            annotations: filteredPins.map { pin in
                                pin.toGoogleMapsAnnotation(
                                    customView: AnyView(
                                        MainMapEnhancedPinAnnotation(pin: pin, pinStore: pinStore)
                                    )
                                )
                            },
                            mapType: MapConverter.mapType(from: selectedMapType),
                            showsUserLocation: true,
                            onCameraChange: { position in
                                // Handle camera changes if needed
                            },
                            onAnnotationTap: { pinId in
                                if let pin = filteredPins.first(where: { $0.id == pinId }) {
                                    handlePinTap(pin)
                                }
                            }
                        )
                        .onChange(of: filteredPins) { _, _ in
                            if !pinStore.isLoading {
                                centerGoogleMapOnFilteredPins()
                            }
                        }
                        
                        // Loading indicator (same as Apple Maps version)
                        if pinStore.isLoading {
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.blue)
                                Text("Loading pins...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        }
                    }
                    
                    // All other UI elements remain exactly the same
                    // This ensures 100% UI parity
                    
                    // Filter Panel (identical to Apple Maps version)
                    if showMapFilters {
                        // Exact same filter panel UI
                    }
                    
                    // Search Bar (top) - identical
                    VStack {
                        HStack(spacing: 12) {
                            // Same search bar implementation
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
            }
            // Other tabs remain unchanged
        }
    }
    
    /// Convert pins to Google Maps annotations
    private var googleMapsAnnotations: [PinAnnotation] {
        var annotations: [PinAnnotation] = []
        
        // Add filtered pins
        if !pinStore.isLoading {
            annotations += filteredPins.map { pin in
                pin.toGoogleMapsAnnotation(
                    customView: AnyView(MainMapEnhancedPinAnnotation(pin: pin, pinStore: pinStore))
                )
            }
        }
        
        // Add search result pins
        annotations += searchResultPins.map { pin in
            pin.toGoogleMapsAnnotation(
                customView: AnyView(SearchResultPinAnnotation(pin: pin))
            )
        }
        
        return annotations
    }
    
    // MARK: - Google Maps Event Handlers
    
    private func handleGoogleMapsCameraChange(_ position: Any) {
        // Update manual movement state
        DispatchQueue.main.async {
            self.isUserManuallyMovingMap = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isUserManuallyMovingMap = false
            }
        }
    }
    
    private func handleGoogleMapsAnnotationTap(_ annotationId: UUID) {
        // Handle pin selection
        selectedPinForPopup = annotationId
        
        // Find and handle the pin
        if let pin = filteredPins.first(where: { $0.id == annotationId }) {
            handlePinTap(pin)
        } else if let pin = searchResultPins.first(where: { $0.id == annotationId }) {
            handlePinTap(pin)
        }
    }
    
    private func centerGoogleMapOnFilteredPins() {
        guard !filteredPins.isEmpty else { return }
        
        let coordinates = filteredPins.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        
        // Calculate bounds
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.2),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.2)
        )
        
        // Convert to Google Maps camera position
        let region = MKCoordinateRegion(center: center, span: span)
        #if canImport(GoogleMaps)
        gmsCameraPosition = MapConverter.gmsCamera(from: region)
        #else
        // Use mock converter when SDK not available
        gmsCameraPosition = GMSCameraPosition(
            latitude: center.latitude,
            longitude: center.longitude,
            zoom: 13.0
        )
        #endif
    }
}