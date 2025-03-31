import SwiftUI
import MapKit
import Combine
import Foundation
// MARK: - Models and Enums

enum PinReaction: String, CaseIterable {
    case lovedIt = "Loved It"
    case wantToGo = "Want to Go"
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
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    @State private var userLocation: CLLocationCoordinate2D? = nil
    @State private var showSideMenu = false
    @State private var selectedTab = 0
    @State private var navigateToFeed = false
    @EnvironmentObject var pinStore: PinStore

    var body: some View {
        ZStack {
            if selectedTab == 0 {
                NavigationLink(destination: LiveFeedView(), isActive: $navigateToFeed) {
                    EmptyView()
                }

                Map(coordinateRegion: $region, annotationItems: pinStore.masterPins) { pin in
                    MapMarker(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude), tint: .blue)
                    
                }
                .gesture(MagnificationGesture())
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
                            // Open Chat View
                        }) {
                            Image(systemName: "message")
                                .font(.title2)
                                .padding()
                        }
                    }
                    Spacer()
                }
            } else if selectedTab == 4 {
                UserProfileView()
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
                .background(Color.black.opacity(0.9))
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
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        if let location = manager.location?.coordinate {
            self.userLocation = location
            region.center = location
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
        followers: [],
        following: [],
        followRequests: [],
        collections: [PinCollection(name: "Favorites", pins: [])],
        favoriteSpots: [],
        activityFeed: []
    )

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
            VStack(alignment: .leading) {
                Text(profileUser.username)
                    .font(.title)
                    .padding()

                HStack {
                    Button(action: { selectedFilter = nil }) {
                        Text("All")
                            .padding(6)
                            .background(selectedFilter == nil ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(selectedFilter == nil ? .white : .black)
                            .cornerRadius(8)
                    }
                    // Fixed the error here: using id: \.self instead of an invalid key path.
                    ForEach(PinReaction.allCases, id: \.self) { reaction in
                        Button(action: { selectedFilter = reaction }) {
                            Text(reaction.rawValue)
                                .padding(6)
                                .background(selectedFilter == reaction ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedFilter == reaction ? .white : .black)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                ForEach(filteredPins) { pin in
                    Text("\(pin.locationName) - \(pin.reaction.rawValue)")
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }

                Text("Collections")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(profileUser.collections) { collection in
                    Text(collection.name)
                        .font(.subheadline)
                        .padding(.horizontal)
                }

                Text("Activity Feed")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(profileUser.activityFeed) { pin in
                    Text("\(pin.locationName) - \(pin.reaction.rawValue)")
                        .font(.caption)
                        .padding(.horizontal)
                }
            }
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
