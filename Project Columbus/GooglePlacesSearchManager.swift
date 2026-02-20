import Foundation
import Combine
import CoreLocation

#if canImport(GooglePlaces)
import GooglePlaces
#endif

/**
 * GooglePlacesSearchManager
 * 
 * Replaces MKLocalSearchCompleter and MKLocalSearch functionality with Google Places API.
 * Provides autocomplete suggestions and detailed place information while maintaining
 * the same interface as the existing MapKit implementation.
 */
class GooglePlacesSearchManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var searchResults: [GMSAutocompletePrediction] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private let placesClient = GMSPlacesClient.shared()
    private var searchCancellable: AnyCancellable?
    
    // MARK: - Public Methods
    
    /**
     * Search for places with autocomplete suggestions
     * Replaces MKLocalSearchCompleter functionality
     */
    func search(query: String, location: CLLocationCoordinate2D? = nil, radius: Double = 10000) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isLoading = true
        error = nil
        
        let filter = GMSAutocompleteFilter()
        filter.types = [.establishment, .geocode]
        filter.countries = ["US"] // Adjust as needed for your target regions
        
        // Create bounds if location is provided
        var bounds: GMSCoordinateBounds?
        if let location = location {
            let radiusInDegrees = radius / 111000.0 // Approximate conversion
            let northeast = CLLocationCoordinate2D(
                latitude: location.latitude + radiusInDegrees,
                longitude: location.longitude + radiusInDegrees
            )
            let southwest = CLLocationCoordinate2D(
                latitude: location.latitude - radiusInDegrees,
                longitude: location.longitude - radiusInDegrees
            )
            bounds = GMSCoordinateBounds(coordinate: northeast, coordinate2: southwest)
        }
        
        placesClient.findAutocompletePredictions(
            fromQuery: query,
            bounds: bounds,
            boundsMode: .bias,
            filter: filter
        ) { [weak self] results, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error
                    print("Google Places search error: \(error)")
                    return
                }
                
                self?.searchResults = results ?? []
            }
        }
    }
    
    /**
     * Get detailed place information from a prediction
     * Replaces MKLocalSearch.Request functionality
     */
    func getPlaceDetails(for prediction: GMSAutocompletePrediction) -> AnyPublisher<GMSPlace, Error> {
        let fields: GMSPlaceField = [
            .name,
            .coordinate,
            .placeID,
            .formattedAddress,
            .phoneNumber,
            .website,
            .rating,
            .priceLevel,
            .types,
            .businessStatus
        ]
        
        return Future<GMSPlace, Error> { [weak self] promise in
            self?.placesClient.fetchPlace(
                fromPlaceID: prediction.placeID,
                placeFields: fields
            ) { place, error in
                if let error = error {
                    promise(.failure(error))
                } else if let place = place {
                    promise(.success(place))
                } else {
                    promise(.failure(GooglePlacesError.unknownError))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /**
     * Search for nearby places of specific types
     * Useful for POI discovery in CreatePostView
     */
    func searchNearbyPlaces(
        location: CLLocationCoordinate2D,
        radius: Double = 2000,
        types: [String] = ["restaurant", "cafe", "bar", "shopping_mall"]
    ) -> AnyPublisher<[GMSPlace], Error> {
        // Note: This would typically use the Nearby Search API from the Places API (Web Service)
        // For now, we'll simulate this with a text search
        
        let searchQueries = types.map { type in
            searchPlacesOfType(type, near: location, radius: radius)
        }
        
        return Publishers.MergeMany(searchQueries)
            .collect()
            .map { results in
                // Flatten and deduplicate results
                let allPlaces = results.flatMap { $0 }
                var uniquePlaces: [GMSPlace] = []
                var seenPlaceIDs: Set<String> = []
                
                for place in allPlaces {
                    if let placeID = place.placeID, !seenPlaceIDs.contains(placeID) {
                        seenPlaceIDs.insert(placeID)
                        uniquePlaces.append(place)
                    }
                }
                
                return Array(uniquePlaces.prefix(20)) // Limit results
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func searchPlacesOfType(
        _ type: String,
        near location: CLLocationCoordinate2D,
        radius: Double
    ) -> AnyPublisher<[GMSPlace], Error> {
        
        return Future<[GMSPlace], Error> { [weak self] promise in
            let query = type.replacingOccurrences(of: "_", with: " ")
            
            let filter = GMSAutocompleteFilter()
            filter.types = [.establishment]
            
            let radiusInDegrees = radius / 111000.0
            let northeast = CLLocationCoordinate2D(
                latitude: location.latitude + radiusInDegrees,
                longitude: location.longitude + radiusInDegrees
            )
            let southwest = CLLocationCoordinate2D(
                latitude: location.latitude - radiusInDegrees,
                longitude: location.longitude - radiusInDegrees
            )
            let bounds = GMSCoordinateBounds(coordinate: northeast, coordinate2: southwest)
            
            self?.placesClient.findAutocompletePredictions(
                fromQuery: query,
                bounds: bounds,
                boundsMode: .restrict,
                filter: filter
            ) { predictions, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                let predictions = predictions?.prefix(5) ?? []
                guard let self = self else {
                    promise(.failure(GooglePlacesError.unknownError))
                    return
                }
                
                let detailRequests = predictions.map { prediction in
                    self.getPlaceDetails(for: prediction)
                }
                
                Publishers.MergeMany(detailRequests)
                    .collect()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                promise(.failure(error))
                            }
                        },
                        receiveValue: { places in
                            promise(.success(places))
                        }
                    )
                    .store(in: &self.cancellables)
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties for Combine
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Extensions for MapKit Compatibility

extension GMSAutocompletePrediction {
    /// Primary text (equivalent to MKLocalSearchCompletion.title)
    var primaryText: String {
        return attributedPrimaryText.string
    }
    
    /// Secondary text (equivalent to MKLocalSearchCompletion.subtitle)
    var secondaryText: String {
        return attributedSecondaryText?.string ?? ""
    }
}

extension GMSPlace {
    /**
     * Convert GMSPlace to Pin model
     * Replaces MKMapItem to Pin conversion
     */
    func toPin(authorHandle: String = "@you") -> Pin {
        return Pin(
            locationName: self.name ?? "Unknown Place",
            city: extractCity(from: self.formattedAddress),
            date: formattedDate(),
            latitude: self.coordinate.latitude,
            longitude: self.coordinate.longitude,
            reaction: .lovedIt,
            reviewText: nil,
            mediaURLs: [],
            mentionedFriends: [],
            starRating: self.rating > 0 ? Double(self.rating) : nil,
            distance: nil,
            authorHandle: authorHandle,
            createdAt: Date(),
            tripName: nil
        )
    }
    
    /**
     * Create a temporary Pin for display purposes
     * Used in POI popups and previews
     */
    func toTemporaryPin() -> Pin {
        return Pin(
            locationName: self.name ?? "Unknown Place",
            city: extractCity(from: self.formattedAddress),
            date: formattedDate(),
            latitude: self.coordinate.latitude,
            longitude: self.coordinate.longitude,
            reaction: .lovedIt,
            reviewText: nil,
            mediaURLs: [],
            mentionedFriends: [],
            starRating: self.rating > 0 ? Double(self.rating) : nil,
            distance: nil,
            authorHandle: "@you",
            createdAt: Date(),
            tripName: nil
        )
    }
    
    // MARK: - Private Helpers
    
    private func extractCity(from address: String?) -> String {
        guard let address = address else { return "" }
        let components = address.components(separatedBy: ", ")
        // Typically the city is the second component in a formatted address
        return components.count > 1 ? components[1] : ""
    }
}

// MARK: - Error Handling

enum GooglePlacesError: LocalizedError {
    case unknownError
    case noResults
    case invalidQuery
    
    var errorDescription: String? {
        switch self {
        case .unknownError:
            return "An unknown error occurred while searching places"
        case .noResults:
            return "No places found for your search"
        case .invalidQuery:
            return "Invalid search query"
        }
    }
}

// MARK: - Utility Functions

/// Format current date (moved from ContentView.swift for reuse)
func formattedDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM dd"
    return formatter.string(from: Date())
} 