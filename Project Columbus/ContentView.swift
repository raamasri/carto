
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




// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D? = nil
    @Published var isUserManuallyMovingMap: Bool = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied or restricted")
        case .notDetermined:
            print("Waiting for location permission")
        @unknown default:
            break
        }
    }
    
    func requestUserLocationManually() {
        manager.startUpdatingLocation()
    }
}

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
        Map(position: $cameraPosition) {
            ForEach(pins, id: \.id) { pin in
                Marker(pin.locationName, coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
            }
        }
        .edgesIgnoringSafeArea(.all)
        .navigationTitle("Map View")
    }

}

// MARK: - Collection Detail View
struct CollectionDetailView: View {
    let collection: PinCollection
    @State private var selectedCategory: String = "All"
    let categories = ["All", "Hotel", "Restaurant", "Bar", "Shopping"]

    var filteredPins: [Pin] {
        if selectedCategory == "All" {
            return collection.pins
        } else {
            return collection.pins.filter { $0.locationName.localizedCaseInsensitiveContains(selectedCategory) }
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.leading)

                    Spacer()

                    NavigationLink(destination: CollectionMapView(pins: filteredPins)) {
                        Image(systemName: "map")
                            .font(.title2)
                            .padding(.trailing)
                    }
                }

                List(filteredPins) { pin in
                    VStack(alignment: .leading) {
                        Text(pin.locationName)
                            .font(.headline)
                        Text("\(pin.city) • \(pin.date)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(collection.name)
        }
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
    
    @State private var shouldTrackUser = false
    @State private var isUserManuallyMovingMap = false
    @State private var cameraPosition = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))

    @State private var userLocation: CLLocationCoordinate2D? = nil
    @StateObject private var locationManager = LocationManager()
    @State private var showSideMenu = false
    @State private var selectedTab = 0
    @State private var navigateToFeed = false
    @State private var selectedPin: Pin? = nil
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

    struct POIPopup: View {
        let mapItem: MKMapItem
        let userLocation: CLLocationCoordinate2D?
        @Binding var showPOISheet: Bool
        @Binding var showFullPOIView: Bool
    // Removed lookAroundScene since it's no longer needed

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
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
                if let address = mapItem.placemark.title {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                LookAroundPreview(coordinate: mapItem.placemark.coordinate)
                    .frame(height: 200)
                    .cornerRadius(12)
                if let distance = userLocation.map({ CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: CLLocation(latitude: mapItem.placemark.coordinate.latitude, longitude: mapItem.placemark.coordinate.longitude)) }) {
                    Text(String(format: "Distance: %.2f km", distance / 1000))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                ZStack(alignment: .bottomLeading) {
                    Button("Add to List") {
                        // Add your action here
                        print("Add to List tapped")
                    }
                    .padding(.leading)
                    
                HStack {
                    Spacer()
                    Button("Show More") {
                        showPOISheet = false
                        DispatchQueue.main.async {
                            showFullPOIView = true
                        }
                    }
                }
                }
                .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(16)
                .padding(.horizontal, 4)
                .padding(.bottom, 60)
            }
// Removed .task block that loaded lookAroundScene
        }
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
            
            // Create a new pin based on the search result.
            let newPin = Pin(
                locationName: item.name ?? "Unknown Place",
                city: "", // Optionally set a city, if available
                date: formattedDate(), // Using the existing formattedDate() function
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                reaction: .lovedIt // Default reaction
            )
            // Check if this pin does not already exist to avoid duplicates, then append
            if !pinStore.masterPins.contains(where: { $0.latitude == newPin.latitude && $0.longitude == newPin.longitude }) {
                pinStore.masterPins.append(newPin)
            }
            
            selectedMapItem = item
            showPOISheet = true
            print("Selected POI: \(item.name ?? "Unknown") at \(coordinate)")
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
                NavigationLink(destination: LiveFeedView(), isActive: $navigateToFeed) {
                    EmptyView()
                }

                Map(position: $cameraPosition) {
                    pinAnnotations
                    if let userLoc = userLocation {
                        Annotation("Current Location", coordinate: userLoc) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 12, height: 12)
                                
                                Circle()
                                    .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                                    .frame(width: 24, height: 24)
                                    .scaleEffect(animatePulse ? 1.5 : 1.0)
                                    .opacity(animatePulse ? 0.1 : 0.6)
                                    .animation(.easeOut(duration: 1).repeatForever(autoreverses: true), value: animatePulse)
                            }
                        }
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
                UserProfileView()
                
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
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(searchResults, id: \.self) { result in
                                            Button(action: {
                                                handleSearchSelection(result)
                                                searchText = ""
                                                searchResults = []
                                            }) {
                                                VStack(alignment: .leading) {
                                                    Text(result.title)
                                                        .font(.headline)
                                                        .foregroundColor(.white)
                                                    if !result.subtitle.isEmpty {
                                                        Text(result.subtitle)
                                                            .font(.caption)
                                                            .foregroundColor(.white.opacity(0.8))
                                                    }
                                                }
                                                .padding()
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                        }
                                    }
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
                    TextField("Where will you go?", text: $searchText)
                        .autocorrectionDisabled()
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
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .blur(radius: 0.3)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                    .padding(.top, 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onChange(of: searchText) { newValue in
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

                        Button(action: {
                            shouldTrackUser.toggle()
                            if shouldTrackUser {
                                requestUserLocation()
                                withAnimation {
                                    if let location = locationManager.userLocation {
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
                    NavBarButton(icon: "house", selected: $selectedTab, index: 0)
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

            if let mapItem = selectedMapItem {
                if showPOISheet {
                    POIPopup(mapItem: mapItem, userLocation: userLocation, showPOISheet: $showPOISheet, showFullPOIView: $showFullPOIView)
                }
                NavigationLink(
                    destination: FullPOIView(mapItem: mapItem),
                    isActive: $showFullPOIView
                ) {
                    EmptyView()
                }
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
                    Pin(locationName: "Blue Bottle Coffee", city: "San Francisco", date: "Apr 15", latitude: 37.7764, longitude: -122.4231, reaction: .lovedIt, ),
                    Pin(locationName: "Tartine Bakery", city: "San Francisco", date: "Apr 14", latitude: 37.7616, longitude: -122.4241, reaction: .lovedIt, ),
                    Pin(locationName: "The Mill", city: "San Francisco", date: "Apr 13", latitude: 37.7763, longitude: -122.4375, reaction: .lovedIt, ),
                    Pin(locationName: "Bi-Rite Creamery", city: "San Francisco", date: "Apr 12", latitude: 37.7615, longitude: -122.4258, reaction: .lovedIt, ),
                    Pin(locationName: "Dolores Park", city: "San Francisco", date: "Apr 11", latitude: 37.7596, longitude: -122.4269, reaction: .wantToGo, ),
                    Pin(locationName: "City Lights Booksellers", city: "San    Francisco", date: "Apr 10", latitude: 37.7975, longitude: -122.4060, reaction: .lovedIt, ),
                    Pin(locationName: "Ferry Building Marketplace", city: "San Francisco", date: "Apr 09", latitude: 37.7955, longitude: -122.3937, reaction: .lovedIt, )
                ]
            }
        }
        .onReceive(locationManager.$userLocation.compactMap { $0 }) { location in
            if shouldTrackUser && !isUserManuallyMovingMap {
                self.userLocation = location
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
        .onChange(of: selectedTab) { newTab in
            // Dismiss the POI popup and clear search results when switching tabs
            showPOISheet = false
            showFullPOIView = false
            searchResults = []
            searchText = ""
        }
    }

    func requestUserLocation() {
        locationManager.requestUserLocationManually()
    }
    
    private var pinAnnotations: some MapContent {
        ForEach(pinStore.masterPins, id: \.id) { pin in
            Annotation("Pin", coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                PinAnnotationDot(pin: pin, isSelected: pin == selectedPin) {
                    selectedPin = pin
                    let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
                    let item = MKMapItem(placemark: placemark)
                    item.name = pin.locationName
                    selectedMapItem = item
                    showFullPOIView = true  // This now shows the full POI view directly
                }
            }
        }
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
            .background(Color(.systemBackground))

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
    @AppStorage("themePreference") private var themePreference: String = "Auto"

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                MainMapView()
                    .environmentObject(authManager)
                    .environmentObject(PinStore())
            } else {
                StartupView()
                    .environmentObject(authManager)
            }
        }
        .preferredColorScheme(colorScheme)
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



