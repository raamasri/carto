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
    @State private var showSettingsSheet = false
    @State private var searchText: String = ""
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var searchCompleter = MKLocalSearchCompleter()
    @State private var searchCompleterDelegateHolder: SearchCompleterDelegate? = nil
    @State private var selectedMapItem: MKMapItem? = nil
    @State private var showFullPOIView: Bool = false
    @State private var showPOISheet: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showDirectMessaging = false
    
    // Enhanced Map Filter States
    @State private var showMapFilters = false
    @State private var selectedReactionFilter: Reaction? = nil
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedStarFilter: StarFilter = .all
    @State private var mapSearchText = ""
    
    // Computed filtered pins for enhanced map
    private var filteredPins: [Pin] {
        var pins = pinStore.masterPins
        
        // Filter by reaction
        if let reaction = selectedReactionFilter {
            pins = pins.filter { $0.reaction == reaction }
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
        selectedReactionFilter != nil || 
        selectedTimeFilter != .all || 
        selectedStarFilter != .all || 
        !mapSearchText.isEmpty
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if selectedReactionFilter != nil { count += 1 }
        if selectedTimeFilter != .all { count += 1 }
        if selectedStarFilter != .all { count += 1 }
        if !mapSearchText.isEmpty { count += 1 }
        return count
    }
    
    // Helper function to center map on filtered pins
    private func centerMapOnFilteredPins() {
        let pins = filteredPins
        guard !pins.isEmpty else { return }
        
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
        @State private var showAddedAlert = false
        @State private var showAddToList = false

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

        private var mainPopupContent: some View {
            VStack(alignment: .leading, spacing: 8) {
                titleBar
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
        }

        private var titleBar: some View {
            ZStack(alignment: .topTrailing) {
                Text(mapItem.name ?? "Unknown Place")
                    .font(.title.bold())
                    .lineLimit(1)
                    .padding(.trailing, 100)

                HStack(spacing: 10) {
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
                    Text(String(format: "Distance: %.2f km", distance / 1000))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }

        private var addToListButton: some View {
            HStack {
                Button("Add to List") {
                    showAddToList = true
                }
                .padding(.leading)
                Spacer()
                Button("Show More") {
                    showFullPOIView = true
                }
            }
            .padding(.top, 8)
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
    
    @EnvironmentObject var pinStore: PinStore

    var body: some View {
        ZStack {
            if selectedTab == 0 {

                ZStack(alignment: .topLeading) {
                    Map(position: $cameraPosition, selection: $selectedPinForPopup) {
                        ForEach(filteredPins, id: \.id) { pin in
                            Annotation(pin.locationName, coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                                MainMapEnhancedPinAnnotation(pin: pin)
                            }
                            .tag(pin.id)
                        }
                    }
                    .onChange(of: filteredPins) { _, _ in
                        centerMapOnFilteredPins()
                    }
                    
                    // Filter Panel (Collapsible)
                    if showMapFilters {
                        VStack(spacing: 12) {
                            MainMapFilterPanel(
                                selectedReaction: $selectedReactionFilter,
                                selectedTimeFilter: $selectedTimeFilter,
                                selectedStarFilter: $selectedStarFilter,
                                searchText: $mapSearchText
                            )
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
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
                ListsView()
                    .environmentObject(pinStore)
                    .environmentObject(authManager)
                    .environmentObject(locationManager)
            } else if selectedTab == 1 {
                FindFriendsView()
            } else if selectedTab == 2 {
                CreatePostView()
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
                        Button(action: {
                            showSettingsSheet = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.gray)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .sheet(isPresented: $showSettingsSheet) {
                            SettingsView()
                        }
                        .padding(.bottom, 60)
                        .padding(.leading)

                        Spacer()
                        
                        // Filter Button
                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                showMapFilters.toggle()
                            }
                        }) {
                            ZStack {
                                Image(systemName: showMapFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                    .foregroundColor(showMapFilters ? .blue : .gray)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                                
                                // Filter count badge
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

                        Button(action: {
                            shouldTrackUser.toggle()
                            if shouldTrackUser {
                                requestUserLocation()
                                withAnimation {
                                    if let location = locationManager.location {
                                        cameraPosition = .region(MKCoordinateRegion(
                                            center: location,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        ))
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .foregroundColor(shouldTrackUser ? .blue : .gray)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.bottom, 60)
                        .padding(.trailing)
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        selectedTab = 0
                        let allPins = pinStore.masterPins
                        if !allPins.isEmpty {
                            let averageLatitude = allPins.map { $0.latitude }.reduce(0, +) / Double(allPins.count)
                            let averageLongitude = allPins.map { $0.longitude }.reduce(0, +) / Double(allPins.count)
                            let center = CLLocationCoordinate2D(latitude: averageLatitude, longitude: averageLongitude)
                            withAnimation {
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: center,
                                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                ))
                            }
                        }
                    }) {
                        Image(systemName: "house")
                            .font(.title2)
                            .foregroundColor(selectedTab == 0 ? .blue : .gray)
                    }
                    Spacer()
                    NavBarButton(icon: "person.2", selected: $selectedTab, index: 1)
                    Spacer()
                    NavBarButton(icon: "plus.circle", selected: $selectedTab, index: 2)
                    Spacer()
                    NavBarButton(icon: "newspaper", selected: $selectedTab, index: 3)
                    Spacer()
                    NavBarButton(icon: "person.circle", selected: $selectedTab, index: 4)
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
            }
        }
        .onAppear {
            requestUserLocation()
            animatePulse = true
            self.searchCompleterDelegateHolder = SearchCompleterDelegate { results in
                self.searchResults = results
            }
            searchCompleter.delegate = self.searchCompleterDelegateHolder
            // Add some initial pins
            if pinStore.masterPins.isEmpty {
                pinStore.masterPins = [
                    Pin(
                        locationName: "Tonys Pizza",
                        city: "San Francisco",
                        date: "May 1",
                        latitude: 37.8000,
                        longitude: -122.4100,
                        reaction: .lovedIt,
                        reviewText: "I loved the za here. @pinalowers ask for Jeremy and he will hook you up. Def going back soon.",
                        mediaURLs: [
                            "https://picsum.photos/400/300",
                            "https://www.w3schools.com/html/mov_bbb.mp4"
                        ],
                        mentionedFriends: [UUID(), UUID()],
                        starRating: 4.8,
                        distance: 4.1,
                        authorHandle: "@raama",
                        createdAt: Date().addingTimeInterval(-3600 * 24 * 6), // 6 days ago
                        tripName: "SF Trip"
                    ),
                    Pin(
                        locationName: "Blue Bottle Coffee",
                        city: "San Francisco",
                        date: "Apr 15",
                        latitude: 37.7764,
                        longitude: -122.4231,
                        reaction: .lovedIt,
                        reviewText: nil,
                        mediaURLs: [],
                        mentionedFriends: [],
                        starRating: 4.2,
                        distance: nil,
                        authorHandle: "@you",
                        createdAt: Date(),
                        tripName: nil
                    ),
                    Pin(
                        locationName: "Tartine Bakery",
                        city: "San Francisco",
                        date: "Apr 14",
                        latitude: 37.7616,
                        longitude: -122.4241,
                        reaction: .lovedIt,
                        reviewText: nil,
                        mediaURLs: [],
                        mentionedFriends: [],
                        starRating: 4.0,
                        distance: nil,
                        authorHandle: "@you",
                        createdAt: Date(),
                        tripName: nil
                    ),
                    Pin(
                        locationName: "The Mill",
                        city: "San Francisco",
                        date: "Apr 13",
                        latitude: 37.7763,
                        longitude: -122.4375,
                        reaction: .lovedIt,
                        reviewText: nil,
                        mediaURLs: [],
                        mentionedFriends: [],
                        starRating: 3.8,
                        distance: nil,
                        authorHandle: "@you",
                        createdAt: Date(),
                        tripName: nil
                    ),
                    Pin(
                        locationName: "Bi-Rite Creamery",
                        city: "San Francisco",
                        date: "Apr 12",
                        latitude: 37.7615,
                        longitude: -122.4258,
                        reaction: .lovedIt,
                        reviewText: nil,
                        mediaURLs: [],
                        mentionedFriends: [],
                        starRating: 4.5,
                        distance: nil,
                        authorHandle: "@you",
                        createdAt: Date(),
                        tripName: nil
                    ),
                    Pin(
                        locationName: "Dolores Park",
                        city: "San Francisco",
                        date: "Apr 11",
                        latitude: 37.7596,
                        longitude: -122.4269,
                        reaction: .wantToGo,
                        reviewText: nil,
                        mediaURLs: [],
                        mentionedFriends: [],
                        starRating: 4.1,
                        distance: nil,
                        authorHandle: "@you",
                        createdAt: Date(),
                        tripName: nil
                    ),
                    Pin(
                        locationName: "City Lights Booksellers",
                        city: "San Francisco",
                        date: "Apr 10",
                        latitude: 37.7975,
                        longitude: -122.4060,
                        reaction: .lovedIt,
                        reviewText: nil,
                        mediaURLs: [],
                        mentionedFriends: [],
                        starRating: 3.9,
                        distance: nil,
                        authorHandle: "@you",
                        createdAt: Date(),
                        tripName: nil
                    ),
                    Pin(
                        locationName: "Ferry Building Marketplace",
                        city: "San Francisco",
                        date: "Apr 09",
                        latitude: 37.7955,
                        longitude: -122.3937,
                        reaction: .lovedIt,
                        reviewText: nil,
                        mediaURLs: [],
                        mentionedFriends: [],
                        starRating: 4.3,
                        distance: nil,
                        authorHandle: "@you",
                        createdAt: Date(),
                        tripName: nil
                    )
                ]
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
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating messaging button - only show on FindFriendsView tab
            if selectedTab == 1 {
                Button(action: {
                    showDirectMessaging = true
                }) {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .padding(.bottom, 80) // Position just above navbar
                .padding(.trailing, 20)
                .sheet(isPresented: $showDirectMessaging) {
                    DirectMessagingView()
                        .environmentObject(authManager)
                }
            }
        }
    }

    func requestUserLocation() {
        locationManager.requestUserLocationManually()
    }
}

// MARK: - Enhanced Pin Annotation for Main Map
struct MainMapEnhancedPinAnnotation: View {
    let pin: Pin
    
    var body: some View {
        ZStack {
            // Pin background with reaction color
            Circle()
                .fill(reactionColor)
                .frame(width: 32, height: 32)
                .shadow(radius: 3)
            
            // Pin icon based on reaction
            Image(systemName: reactionIcon)
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
    
    private var reactionColor: Color {
        switch pin.reaction {
        case .lovedIt:
            return .red
        case .wantToGo:
            return .blue
        }
    }
    
    private var reactionIcon: String {
        switch pin.reaction {
        case .lovedIt:
            return "heart.fill"
        case .wantToGo:
            return "bookmark.fill"
        }
    }
}

// MARK: - Main Map Filter Panel
struct MainMapFilterPanel: View {
    @Binding var selectedReaction: Reaction?
    @Binding var selectedTimeFilter: TimeFilter
    @Binding var selectedStarFilter: StarFilter
    @Binding var searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search locations, cities, trips...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundColor(.blue)
                }
            }
            
            // Filter Categories
            VStack(spacing: 12) {
                // Reaction Filter
                HStack {
                    Text("Reaction:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    HStack(spacing: 8) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedReaction == nil,
                            action: { selectedReaction = nil }
                        )
                        FilterChip(
                            title: "❤️ Loved It",
                            isSelected: selectedReaction == .lovedIt,
                            action: { selectedReaction = .lovedIt }
                        )
                        FilterChip(
                            title: "🔖 Want to Go",
                            isSelected: selectedReaction == .wantToGo,
                            action: { selectedReaction = .wantToGo }
                        )
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
                        selectedReaction = nil
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
        selectedReaction != nil || 
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
    @StateObject private var authManager = AuthManager()
    @StateObject private var pinStore = PinStore()
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







