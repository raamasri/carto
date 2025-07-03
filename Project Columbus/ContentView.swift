struct FullPOIView: View {
    let mapItem: MKMapItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(mapItem.name ?? "Unknown Place")
                    .font(.largeTitle)
                    .bold()

                if let address = mapItem.placemark.title {
                    Text(address)
                        .font(.body)
                }

                if let phone = mapItem.phoneNumber {
                    Text("Phone: \(phone)")
                }

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
import SwiftUI
import MapKit
import Combine
import Foundation

// MARK: - Models and Enums
// MARK: - Global Spacing & Radius Constants
struct AppSpacing {
    static let horizontal: CGFloat = 16
    static let vertical: CGFloat = 12
    static let cornerRadius: CGFloat = 12
}



// MARK: - Location Manager - Using AppLocationManager from LocationManager.swift

struct CollectionMapView: View {
    let pins: [Pin]
    
    @State private var cameraPosition: MapCameraPosition
    
    init(pins: [Pin]) {
        self.pins = pins
        if let first = pins.first {
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )))
        } else {
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )))
        }
    }
    
    var body: some View {
        Map(coordinateRegion: .constant(MKCoordinateRegion(
            center: pins.first.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) } ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )), annotationItems: pins) { pin in
            MapMarker(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude), tint: .red)
        }
        .edgesIgnoringSafeArea(.all)
        .navigationTitle("Map View")
    }

}

// MARK: - Utility Functions

func formattedDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM dd"
    return formatter.string(from: Date())
}

// MARK: - Identifiable Map Item

struct IdentifiableMapItem: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
}



// MARK: - Main Map View with Bottom Nav and Side Menu
import SwiftUI
import MapKit
struct MainMapView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    @State private var shouldTrackUser = false
    @State private var isUserManuallyMovingMap = false
    @State private var cameraPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))

    @EnvironmentObject var locationManager: AppLocationManager
    @State private var showSideMenu = false
    @State private var selectedTab = 0
    @Binding var navigateToFeed: Bool
    @State private var selectedPin: Pin? = nil
    @State private var selectedPinForPopup: UUID? = nil
    @State private var animatePulse = false
    @AppStorage("selectedMapType") private var selectedMapType: String = "Standard"

    @State private var searchText: String = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegateHolder: SearchCompleterDelegate? = nil
    @State private var selectedMapItem: MKMapItem? = nil
    @State private var showFullPOIView: Bool = false
    @State private var showPOISheet: Bool = false
    @FocusState private var isSearchFieldFocused: Bool

    
    // Sidebar sheet state variables
    @State private var showUserProfile = false

    @State private var showAccountMenu = false
    @State private var showProfileEdit = false
    @State private var showAccountSettings = false
    
    // Enhanced Map Filter States
    @State private var showMapFilters = false
    @State private var selectedListFilter: UUID? = nil
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedStarFilter: StarFilter = .all
    @State private var mapSearchText = ""
    
    // Auto-centering state
    @State private var hasAutocentered = false
    
    // Computed filtered pins for enhanced map
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
        
        // Filter by reaction
        if let listId = selectedListFilter {
            pins = pins.filter { pin in
                pinStore.lists.first(where: { $0.id == listId })?.pins.contains(where: { $0.id == pin.id }) == true
            }
        }
        
        // Filter by time
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
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let item = response?.mapItems.first else { return }
            let coordinate = item.placemark.coordinate
            withAnimation {
                let shiftedCoordinate = CLLocationCoordinate2D(
                    latitude: coordinate.latitude - 0.0045,
                    longitude: coordinate.longitude
                )
                cameraPosition = .region(MKCoordinateRegion(
                    center: shiftedCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
            
            // Create a new pin based on the search result, including all required parameters.
            let newPin = Pin(
                locationName: item.name ?? "Unknown Place",
                city: "", // Optionally set a city, if available
                date: formattedDate(), // Using the existing formattedDate() function
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                reaction: .lovedIt, // Default reaction
                reviewText: nil,
                mediaURLs: [],
                mentionedFriends: [],
                starRating: nil,
                distance: nil,
                authorHandle: "@you",
                createdAt: Date(),
                tripName: nil
            )
            // Check if this pin does not already exist to avoid duplicates, then append
            if !pinStore.masterPins.contains(where: { $0.latitude == newPin.latitude && $0.longitude == newPin.longitude }) {
                pinStore.masterPins.append(newPin)
            }
            
            selectedMapItem = item
            showPOISheet = true
            // Handle POI selection
        }
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

    var body: some View {
        ZStack {
            if selectedTab == 0 {

                ZStack {
                    ZStack {
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
                            
                            // Show user location
                            UserAnnotation()
                        }
                        .onChange(of: filteredPins) { _, _ in
                            if !pinStore.isLoading {
                                centerMapOnFilteredPins()
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
                    TextField("Places, Memories, Ideas, #tags", text: $searchText)
                        .autocorrectionDisabled()
                        .focused($isSearchFieldFocused)
                        .padding(8)
 
                    if !searchText.isEmpty || !searchResults.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
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
            selectedPinForPopup = nil
            searchResults = []
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
                        authManager.logOut()
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showSideMenu = false
                        }
                    },
                    .cancel()
                ]
            )
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
        .onChange(of: user.avatarURL) { _ in
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







