import SwiftUI
import MapKit
import Combine

// MARK: - List-Based Search View (Non-map results)

struct SearchView: View {
    private let searchCompleter = MKLocalSearchCompleter()
    @State private var autocompleteDelegate: AutocompleteHandler?
    @State private var completions: [MKLocalSearchCompletion] = []
    @State private var searchText = ""
    @State private var searchResults: [String] = []
    @State private var locationResults: [MKMapItem] = []
    @State private var cancellables = Set<AnyCancellable>()

    @State private var selectedMapItem: MKMapItem? = nil
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
                    .onChange(of: searchText) { _, newValue in
                        if newValue.starts(with: "@") || newValue.starts(with: "#") {
                            performSearch(for: newValue)
                        } else {
                            searchCompleter.queryFragment = newValue
                        }
                    }

                if searchText.starts(with: "@") {
                    List {
                        ForEach(searchResults, id: \.self) { user in
                            Text("User: \(user)")
                        }
                    }
                } else if searchText.starts(with: "#") {
                    List {
                        ForEach(searchResults, id: \.self) { tag in
                            Text("Tag: \(tag)")
                        }
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
            .sheet(item: $selectedMapItem) { selected in
                NavigationView {
                    LocationDetailView(mapItem: selected) { newPin in
                        pinStore.masterPins.append(newPin)
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
            reaction: .wantToGo,
            reviewText: nil,
            mediaURLs: [],
            mentionedFriends: [],
            starRating: nil,
            distance: nil,
            authorHandle: "@you",
            createdAt: Date(),
            tripName: nil
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
                DispatchQueue.main.async {
                    selectedMapItem = item
                }
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

extension MKMapItem: @retroactive Identifiable {
    public var id: String { self.name ?? UUID().uuidString }
}

extension MKPointOfInterestCategory {
    var displayName: String {
        switch self {
        case .airport: return "Airport"
        case .amusementPark: return "Amusement Park"
        case .aquarium: return "Aquarium"
        case .atm: return "ATM"
        case .bakery: return "Bakery"
        case .bank: return "Bank"
        case .beach: return "Beach"
        case .brewery: return "Brewery"
        case .cafe: return "Cafe"
        case .campground: return "Campground"
        case .carRental: return "Car Rental"
        case .evCharger: return "EV Charger"
        case .fireStation: return "Fire Station"
        case .fitnessCenter: return "Fitness Center"
        case .foodMarket: return "Food Market"
        case .gasStation: return "Gas Station"
        case .hospital: return "Hospital"
        case .hotel: return "Hotel"
        case .laundry: return "Laundry"
        case .library: return "Library"
        case .marina: return "Marina"
        case .movieTheater: return "Movie Theater"
        case .museum: return "Museum"
        case .nationalPark: return "National Park"
        case .nightlife: return "Nightlife"
        case .park: return "Park"
        case .parking: return "Parking"
        case .pharmacy: return "Pharmacy"
        case .police: return "Police"
        case .postOffice: return "Post Office"
        case .publicTransport: return "Public Transport"
        case .restaurant: return "Restaurant"
        case .restroom: return "Restroom"
        case .school: return "School"
        case .stadium: return "Stadium"
        case .store: return "Store"
        case .theater: return "Theater"
        case .university: return "University"
        case .winery: return "Winery"
        case .zoo: return "Zoo"
        default: return "Point of Interest"
        }
    }
}
