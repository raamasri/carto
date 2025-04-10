import SwiftUI
import MapKit
import Combine

// MARK: - Search View

struct SearchView: View {
    private let searchCompleter = MKLocalSearchCompleter()
    @State private var autocompleteDelegate: AutocompleteHandler?
    @State private var completions: [MKLocalSearchCompletion] = []
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
                    .onAppear {
                        let handler = AutocompleteHandler { newCompletions in
                            self.completions = newCompletions
                        }
                        self.autocompleteDelegate = handler
                        self.searchCompleter.delegate = handler
                        self.searchCompleter.region = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                        )
                    }
                    .onChange(of: searchText) { newValue in
                        if newValue.starts(with: "@") || newValue.starts(with: "#") {
                            performSearch(for: newValue)
                        } else {
                            searchCompleter.queryFragment = newValue
                        }
                    }

                if searchText.starts(with: "@") {
                    List(searchResults, id: \.self) { user in
                        Text("User: \(user)")
                    }
                } else if searchText.starts(with: "#") {
                    List(searchResults, id: \.self) { tag in
                        Text("Tag: \(tag)")
                    }
                } else if !searchText.isEmpty {
                    List {
                        ForEach(completions, id: \.self) { completion in
                            VStack(alignment: .leading) {
                                Text(completion.title)
                                    .font(.headline)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                searchForCompletion(completion)
                            }
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Search")
            .sheet(isPresented: $showLocationDetail) {
                Group {
                    if let selected = selectedMapItem {
                        NavigationView {
                            LocationDetailView(mapItem: selected) { newPin in
                                pinStore.masterPins.append(newPin)
                            }
                        }
                    } else {
                        VStack {
                            Spacer()
                            ProgressView("Loading location...")
                            Spacer()
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

    func searchForCompletion(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let item = response?.mapItems.first {
                selectedMapItem = item
                showLocationDetail = true
            }
        }
    }
}

final class AutocompleteHandler: NSObject, MKLocalSearchCompleterDelegate {
    private let onUpdate: ([MKLocalSearchCompletion]) -> Void

    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onUpdate([])
        print("Autocomplete error: \(error.localizedDescription)")
    }
}

struct LookAroundPreview: UIViewControllerRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let controller = MKLookAroundViewController()
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        Task {
            if let scene = try? await request.scene {
                controller.scene = scene
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MKLookAroundViewController, context: Context) {}
}

struct LocationDetailView: View {
    let mapItem: MKMapItem
    let onAddPin: (Pin) -> Void

    @State private var showCollectionSheet = false
    @EnvironmentObject var pinStore: PinStore

    var body: some View {
        ScrollView {
            content
                .padding()
        }
        .navigationTitle("Details")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleSection
            LookAroundPreview(coordinate: mapItem.placemark.coordinate)
                .frame(height: 250)
                .cornerRadius(12)
            infoSection
            addButton
        }
    }

    private var titleSection: some View {
        Text(mapItem.name ?? "Unknown Place")
            .font(.largeTitle)
            .bold()
    }

    private var infoSection: some View {
        Group {
            if let category = mapItem.pointOfInterestCategory {
                Label(category.rawValue.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: "tag")
            }

            if let phone = mapItem.phoneNumber {
                Label(phone, systemImage: "phone")
            }

            if let url = mapItem.url {
                Link("Website", destination: url)
            }

            if let address = mapItem.placemark.title {
                Label(address, systemImage: "mappin.circle")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label("Lat: \(mapItem.placemark.coordinate.latitude), Lon: \(mapItem.placemark.coordinate.longitude)", systemImage: "location")

            if let tz = mapItem.timeZone {
                Label(tz.identifier, systemImage: "clock")
            }
        }
    }

    private var addButton: some View {
        VStack {
            Button(action: {
                showCollectionSheet = true
            }) {
                HStack {
                    Spacer()
                    Label("Add to Pins", systemImage: "plus.circle.fill")
                        .font(.title2)
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .sheet(isPresented: $showCollectionSheet) {
                collectionPickerSheet
            }
        }
    }

    private var collectionPickerSheet: some View {
        NavigationView {
            collectionList
                .navigationTitle("Select a Collection")
        }
    }

    private var collectionList: some View {
        List {
            ForEach(pinStore.collections) { collection in
                Button(action: {
                    addPin(to: collection)
                    showCollectionSheet = false
                }) {
                    Text("Add to \(collection.name)")
                }
            }
        }
    }

    private func addPin(to collection: PinCollection) {
        let newPin = Pin(
            locationName: mapItem.name ?? "Unknown Place",
            city: mapItem.placemark.locality ?? "Unknown City",
            date: formattedDate(),
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude,
            reaction: .wantToGo
        )
        if let index = pinStore.collections.firstIndex(where: { $0.id == collection.id }) {
            pinStore.collections[index].pins.append(newPin)
        }
    }
}
