struct CreatePostView: View {
    @State private var placeName: String = ""
    @State private var location: String = ""
    @State private var rating: Int = 0
    @State private var recommendation: Bool = false
    @State private var recommendedTo: String = "Everyone"
    private let recommendedOptions = ["Everyone", "Family", "Friends"]
    @State private var postContent: String = ""
    @State private var selectedImage: Image? = nil
    @State private var showingImagePicker: Bool = false
    @State private var isFollowingUser: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create a New Post")
                    .font(.title)
                    .padding(.bottom, 8)

                Group {
                    Text("Place Name")
                        .font(.headline)
                    TextField("Enter place name", text: $placeName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Group {
                    Text("Rating")
                        .font(.headline)
                    HStack {
                        ForEach(1..<11) { star in  // Change the range to 1..<11 for 10 stars
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    rating = star
                                }
                        }
                    }
                }

                Group {
                    Toggle("Recommendation", isOn: $recommendation)
                    if recommendation {
                        Picker("Recommended To", selection: $recommendedTo) {
                            ForEach(recommendedOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }

                Group {
                    Text("Post Content")
                        .font(.headline)
                    TextField("Enter your post content", text: $postContent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Group {
                    Button(action: {
                        // Action to show image picker
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Select Image")
                        }
                    }
                    if let image = selectedImage {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                }

                Button(action: {
                    // Submit post action
                }) {
                    Text("Post")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
        // .sheet(isPresented: $showingImagePicker) { ImagePicker(selectedImage: $selectedImage) }
    }
}
import SwiftUI
import MapKit
import Combine
import Foundation
// MARK: - Models and Enums



struct SettingsView: View {
    @Environment(\.presentationMode) var dismiss
    @AppStorage("themePreference") private var themePreference: String = "Auto"
    @AppStorage("selectedMapType") private var selectedMapType: String = "Standard"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    NavigationLink("Edit Profile", destination: Text("Profile Editor Placeholder"))
                    NavigationLink("Change Password", destination: Text("Password Change Placeholder"))
                    Toggle("Private Account", isOn: .constant(false))
                }
                
                Section(header: Text("Map Preferences")) {
                    Picker("Map Type", selection: $selectedMapType) {
                        Text("Standard").tag("Standard")
                        Text("Satellite").tag("Satellite")
                        Text("Hybrid").tag("Hybrid")
                    }
                    Toggle("Show My Location", isOn: .constant(true))
                    Toggle("Show Reactions", isOn: .constant(true))
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Friend Activity", isOn: .constant(true))
                    Toggle("Nearby Pins", isOn: .constant(true))
                    Toggle("New Followers", isOn: .constant(false))
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $themePreference) {
                        Text("Auto").tag("Auto")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                }
                
                Section(header: Text("About")) {
                    NavigationLink("Help & Support", destination: Text("Help Placeholder"))
                    NavigationLink("Privacy Policy", destination: Text("Privacy Placeholder"))
                    NavigationLink("Terms of Use", destination: Text("Terms Placeholder"))
                    Text("App Version 1.0.0")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

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
    
    func handleSearchSelection(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let item = response?.mapItems.first else { return }
            let coordinate = item.placemark.coordinate
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
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
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                                        .scaleEffect(animatePulse ? 2.2 : 1.2)
                                        .opacity(animatePulse ? 0.1 : 0.6)
                                        .animation(.easeOut(duration: 1).repeatForever(autoreverses: true), value: animatePulse)
                                )
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
                SearchView()
                    .environmentObject(pinStore)
            } else if selectedTab == 2 {
                CreatePostView()
            } else {
                LiveFeedView()
                    .environmentObject(pinStore)
            }

            if selectedTab == 0 {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search places or friends", text: $searchText)
                            .autocorrectionDisabled()
                            .padding(8)
                    }
                    .padding(10)
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 50)

                    if !searchResults.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(searchResults, id: \.self) { result in
                                Button(action: {
                                    handleSearchSelection(result)
                                    searchText = result.title
                                    searchResults = []
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(result.title).font(.headline)
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.95))
                                }
                            }
                        }
                        .background(Color.white.opacity(0.95))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    Spacer()
                }
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
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black)
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
                            requestUserLocation()
                        }) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
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
                    NavBarButton(icon: "magnifyingglass", selected: $selectedTab, index: 1)
                    Spacer()
                    NavBarButton(icon: "plus.circle", selected: $selectedTab, index: 2)
                    Spacer()
                    NavBarButton(icon: "person.2", selected: $selectedTab, index: 3)
                    Spacer()
                    NavBarButton(icon: "person.circle", selected: $selectedTab, index: 4)
                }
                .padding()
                .padding(.bottom, 25)
                .background(
                    Color.black.opacity(0.5)
                        .background(.ultraThinMaterial)
                        .blur(radius: 0)
                        .clipShape(RoundedRectangle(cornerRadius: 0))
                        .padding(.horizontal, 0)
                )
            }
            .ignoresSafeArea(.container, edges: .bottom)
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
                    Pin(locationName: "Coffee Shop", city: "San Francisco", date: "Mar 10", latitude: 37.7750, longitude: -122.4183, reaction: .lovedIt),
                    Pin(locationName: "Park Bench", city: "San Francisco", date: "Mar 11", latitude: 37.7740, longitude: -122.4200, reaction: .wantToGo)
                ]
            }
        }
        .onReceive(locationManager.$userLocation.compactMap { $0 }) { location in
            if !isUserManuallyMovingMap {
                cameraPosition = .region(MKCoordinateRegion(
                    center: location,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
            // Bias search results towards the user's location
            searchCompleter.region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
    }

    func requestUserLocation() {
        locationManager.requestUserLocationManually()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let location = locationManager.userLocation, !isUserManuallyMovingMap {
                self.userLocation = location
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            } else {
                print("User location unavailable or manual map movement detected.")
            }
        }
    }
    
    private var pinAnnotations: some MapContent {
        ForEach(pinStore.masterPins, id: \.id) { pin in
            Annotation("Pin", coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                PinAnnotationDot(pin: pin, isSelected: pin == selectedPin) {
                    selectedPin = pin
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

struct FindFriendsView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Find Friends")
                .font(.largeTitle)
            Text("This is where you’ll see your friends on the map.")
                .font(.subheadline)
                .padding()
            Spacer()
        }
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

