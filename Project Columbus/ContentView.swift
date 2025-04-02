import SwiftUI
import MapKit
import Combine
import Foundation
// MARK: - Models and Enums

enum PinReaction: String, CaseIterable {
    case lovedIt = "Loved It"
    case wantToGo = "Want to Go"
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D? = nil

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
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

struct User: Identifiable {
    let id: UUID
    let username: String
    let isPrivate: Bool
    var followers: [UUID]
    var following: [UUID]
    var followRequests: [UUID]
    var collections: [PinCollection] = []
    var favoriteSpots: [Pin] = []
    var activityFeed: [Pin] = []
}

struct Pin: Identifiable, Hashable {
    let id = UUID()
    let locationName: String
    let city: String
    let date: String
    let latitude: Double
    let longitude: Double
    var reaction: PinReaction
    
    
    // Implement Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Implement Equatable conformance
    static func == (lhs: Pin, rhs: Pin) -> Bool {
        return lhs.id == rhs.id
    }
}

struct PinCollection: Identifiable {
    let id = UUID()
    let name: String
    var pins: [Pin]
}

class PinStore: ObservableObject {
    @Published var masterPins: [Pin] = []
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

// MARK: - Search View

struct SearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [String] = []
    @State private var locationResults: [MKMapItem] = []
    @State private var cancellables = Set<AnyCancellable>()

    @State private var selectedMapItem: MKMapItem? = nil
    @State private var showLocationDetail = false
    @EnvironmentObject var pinStore: PinStore

    @State private var quickAddedItemIDs: Set<String> = [] // Track added pins by coordinate string

    var body: some View {
        NavigationView {
            VStack {
                TextField("Search @user, #tag, or place", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                    .onChange(of: searchText) { newValue in
                        performSearch(for: newValue)
                    }

                if searchText.starts(with: "@") {
                    List(searchResults, id: \.self) { user in
                        Text("User: \(user)")
                    }
                } else if searchText.starts(with: "#") {
                    List(searchResults, id: \.self) { tag in
                        Text("Tag: \(tag)")
                    }
                } else {
                    List {
                        ForEach(locationResults.indices, id: \.self) { index in
                            let item = locationResults[index]
                            let uniqueID = "\(item.placemark.coordinate.latitude),\(item.placemark.coordinate.longitude)"

                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.name ?? "Unknown Place")
                                        .font(.headline)
                                    Text(item.placemark.title ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if quickAddedItemIDs.contains(uniqueID) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .transition(.opacity)
                                } else {
                                    Button(action: {
                                        quickAddPin(for: item, id: uniqueID)
                                    }) {
                                        Image(systemName: "plus.circle")
                                            .font(.title2)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMapItem = item
                                showLocationDetail = true
                            }
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Search")
            .sheet(isPresented: $showLocationDetail) {
                if let selected = selectedMapItem {
                    NavigationView {
                        LocationDetailView(mapItem: selected) { newPin in
                            pinStore.masterPins.append(newPin)
                        }
                    }
                }
            }
        }
    }

    func performSearch(for query: String) {
        if query.starts(with: "@") {
            let users = ["@alice", "@bob", "@charlie", "@explorer123"]
            searchResults = users.filter { $0.contains(query.lowercased()) }
            locationResults = []
        } else if query.starts(with: "#") {
            let tags = ["#coffee", "#parks", "#museums", "#hiking"]
            searchResults = tags.filter { $0.contains(query.lowercased()) }
            locationResults = []
        } else {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )

            let search = MKLocalSearch(request: request)
            search.start { response, error in
                if let items = response?.mapItems {
                    self.locationResults = items
                } else {
                    self.locationResults = []
                }
                self.searchResults = []
            }
        }
    }

    func quickAddPin(for item: MKMapItem, id uniqueID: String) {
        let newPin = Pin(
            locationName: item.name ?? "Unknown Place",
            city: item.placemark.locality ?? "Unknown City",
            date: formattedDate(),
            latitude: item.placemark.coordinate.latitude,
            longitude: item.placemark.coordinate.longitude,
            reaction: .wantToGo
        )
        pinStore.masterPins.append(newPin)
        quickAddedItemIDs.insert(uniqueID)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            quickAddedItemIDs.remove(uniqueID)
        }
    }
}

// MARK: - Location Detail View

struct LocationDetailView: View {
    let mapItem: MKMapItem
    let onAdd: (Pin) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var added = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: mapItem.placemark.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )), annotationItems: [IdentifiableMapItem(mapItem: mapItem)]) { item in
                    MapMarker(coordinate: item.mapItem.placemark.coordinate, tint: .red)
                }
                .frame(height: 200)
                .cornerRadius(10)

                Text(mapItem.name ?? "Unknown Place")
                    .font(.title)
                    .bold()

                if let address = mapItem.placemark.title {
                    Text(address)
                        .font(.subheadline)
                }
                if let phone = mapItem.phoneNumber {
                    Text("Phone: \(phone)")
                        .font(.subheadline)
                }
                if let url = mapItem.url {
                    Link("Website", destination: url)
                }

                Spacer()

                if added {
                    Label("Added!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                        .transition(.opacity)
                        .padding()
                } else {
                    Button(action: {
                        let newPin = Pin(
                            locationName: mapItem.name ?? "Unknown Place",
                            city: mapItem.placemark.locality ?? "Unknown City",
                            date: formattedDate(),
                            latitude: mapItem.placemark.coordinate.latitude,
                            longitude: mapItem.placemark.coordinate.longitude,
                            reaction: .wantToGo
                        )
                        onAdd(newPin)
                        withAnimation {
                            added = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Add to List")
                                .bold()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Details")
    }
}

// MARK: - Main Map View with Bottom Nav and Side Menu

struct MainMapView: View {
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
                }
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

                if showSideMenu {
                    SideMenuView(showSideMenu: $showSideMenu)
                }

                VStack {
                    HStack {
                        Button(action: {
                            // Open Settings View
                        }) {
                            Image(systemName: "gear")
                                .font(.title2)
                                .padding()
                        }
                        Spacer()

                        Button(action: {
                            selectedTab = 4
                        }) {
                            Image(systemName: "person.circle")
                                .font(.title2)
                                .padding()
                        }
                    }
                    Spacer()
                }
            } else if selectedTab == 4 {
                UserProfileView()
            } else if selectedTab == 5 {
                FindFriendsView()
            } else if selectedTab == 1 {
                SearchView()
                    .environmentObject(pinStore)
            } else {
                LiveFeedView()
                    .environmentObject(pinStore)
            }

        VStack {
            Spacer()
            HStack {
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
                .padding(.bottom, 100)
                .padding(.trailing)
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
                NavBarButton(icon: "location.circle", selected: $selectedTab, index: 5)
            }
            .padding()
            .padding(.bottom, 0)
            .background(
                Color.white.opacity(0.5)
                    .background(.ultraThinMaterial)
                    .blur(radius: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                    .padding(.horizontal, 0)
            )
        }
        }
        .onAppear {
            requestUserLocation()
            // Add some initial pins
            if pinStore.masterPins.isEmpty {
                pinStore.masterPins = [
                    Pin(locationName: "Coffee Shop", city: "San Francisco", date: "Mar 10", latitude: 37.7750, longitude: -122.4183, reaction: .lovedIt),
                    Pin(locationName: "Park Bench", city: "San Francisco", date: "Mar 11", latitude: 37.7740, longitude: -122.4200, reaction: .wantToGo)
                ]
            }
        }
    }

    func requestUserLocation() {
        if let location = locationManager.userLocation {
            self.userLocation = location
            cameraPosition = .region(MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
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

struct UserProfileView: View {
    let currentUserID = UUID()

    @State var profileUser = User(
        id: UUID(),
        username: "mojojojo23",
        isPrivate: false,
        followers: Array(repeating: UUID(), count: 5),
        following: Array(repeating: UUID(), count: 10),
        followRequests: [],
        collections: [
        PinCollection(name: "San Francisco", pins: [
            Pin(locationName: "Zuni Café", city: "San Francisco", date: "Mar 26", latitude: 37.7730, longitude: -122.4210, reaction: .lovedIt),
            Pin(locationName: "Tartine Bakery", city: "San Francisco", date: "Mar 25", latitude: 37.7614, longitude: -122.4241, reaction: .lovedIt),
            Pin(locationName: "House of Prime Rib", city: "San Francisco", date: "Mar 24", latitude: 37.7930, longitude: -122.4228, reaction: .wantToGo),
            Pin(locationName: "La Taqueria", city: "San Francisco", date: "Mar 23", latitude: 37.7502, longitude: -122.4185, reaction: .wantToGo),
            Pin(locationName: "Swan Oyster Depot", city: "San Francisco", date: "Mar 22", latitude: 37.7913, longitude: -122.4212, reaction: .lovedIt)
        ]),
            PinCollection(name: "Bday", pins: []),
            PinCollection(name: "Car Tour", pins: []),
            PinCollection(name: "Europe 25", pins: []),
            PinCollection(name: "Psychos", pins: []),
            PinCollection(name: "Pizza", pins: [])
        ],
        favoriteSpots: [],
        activityFeed: []
    )

    @State private var bio = "✨ Travel lover. Coffee first. Exploring the world one pin at a time! 🌍"
    @State private var selectedSection = "Just Added"
    let sections = ["Just Added", "Loved", "Want to Go", "Recommendations"]

    @State var recentPins: [Pin] = [
        Pin(locationName: "Golden Gate Park", city: "San Francisco", date: "Mar 10", latitude: 37.7694, longitude: -122.4862, reaction: .lovedIt),
        Pin(locationName: "Central Park", city: "New York", date: "Feb 22", latitude: 40.7851, longitude: -73.9683, reaction: .wantToGo),
        Pin(locationName: "Eiffel Tower", city: "Paris", date: "Jan 18", latitude: 48.8584, longitude: 2.2945, reaction: .lovedIt)
    ]

    @State private var selectedFilter: PinReaction? = nil

    var filteredPins: [Pin] {
        if let filter = selectedFilter {
            return recentPins.filter { $0.reaction == filter }
        } else {
            return recentPins
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Profile Header
                ZStack(alignment: .topTrailing) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("@\(profileUser.username)")
                                .font(.headline)

                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(2)

                            Text("\(profileUser.followers.count) followers • \(profileUser.following.count) following")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    Button(action: {
                        // Future editable profile logic
                    }) {
                        Text("Edit")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .padding(.trailing)
                }
                
                
                Divider()
 
                // Reaction Filter
                
 
                // Recent Pins Section
                VStack(alignment: .leading, spacing: 8) {
                    Menu {
                        ForEach(sections, id: \.self) { section in
                            Button(action: {
                                selectedSection = section
                            }) {
                                Text(section)
                            }
                        }
                    } label: {
                        Text(selectedSection)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }

                    ForEach(filteredPins) { pin in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.locationName)
                                .font(.subheadline)
                                .bold()
                            Text("\(pin.city) • \(pin.date)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    }
                }
 
                Divider()
 
 
 
                // New Collections Section
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Collections")
                        .font(.headline)
                        .padding(.horizontal)
                
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                        ForEach(profileUser.collections) { collection in
                            NavigationLink(destination: CollectionDetailView(collection: collection)) {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.blue.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                        .overlay(Text("📍"))
                                    Text(collection.name)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 60)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Live Feed View Placeholder




    // MARK: - App Entry Point

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()

    var body: some View {
        if authManager.isLoggedIn {
            MainMapView()
                .environmentObject(authManager)
                .environmentObject(PinStore())
        } else {
            StartupView()
                .environmentObject(authManager)
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
