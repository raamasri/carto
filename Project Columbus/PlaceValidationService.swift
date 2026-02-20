import Foundation
import Combine
import CoreLocation
import MapKit

#if canImport(GooglePlaces)
import GooglePlaces
#endif

/**
 * PlaceValidationService
 * 
 * Provides cross-validation between Apple Maps and Google Maps place data to ensure
 * seamless experience regardless of the user's selected map provider. This service
 * validates places exist in both services and reconciles coordinate differences.
 */
class PlaceValidationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isValidating = false
    @Published var lastValidationError: Error?
    
    // MARK: - Validation Models
    
    struct ValidatedPlace {
        let applePlace: MKMapItem?
        let googlePlace: GMSPlace?
        let isValidated: Bool
        let preferredCoordinate: CLLocationCoordinate2D
        let confidence: PlaceConfidence
        let validationMessage: String
        let coordinateDistance: Double? // Distance in meters between coordinates
        
        var canBeAdded: Bool {
            return isValidated && confidence != .unknown
        }
        
        var displayName: String {
            // Prefer Google Maps name if available, fallback to Apple Maps
            return googlePlace?.name ?? applePlace?.name ?? "Unknown Place"
        }
        
        var displayAddress: String {
            return googlePlace?.formattedAddress ?? 
                   applePlace?.placemark.thoroughfare ?? "Address unavailable"
        }
    }
    
    enum PlaceConfidence {
        case high      // Found in both services, coordinates within tolerance
        case medium    // Found in both, coordinates differ but within acceptable range
        case low       // Only found in one service
        case unknown   // Validation failed or no results
        
        var displayText: String {
            switch self {
            case .high:
                return "✅ Verified in both maps"
            case .medium:
                return "⚠️ Coordinates differ slightly"
            case .low:
                return "🔍 Found in one map only"
            case .unknown:
                return "❌ Could not validate"
            }
        }
        
        var color: String {
            switch self {
            case .high:
                return "green"
            case .medium:
                return "orange"
            case .low:
                return "yellow"
            case .unknown:
                return "red"
            }
        }
    }
    
    // MARK: - Constants
    
    private static let coordinateTolerance: Double = 100.0 // 100 meters
    private static let searchRadius: Double = 2000.0 // 2km search radius
    
    // MARK: - Private Properties
    
    #if canImport(GooglePlaces)
    private let placesClient = GMSPlacesClient.shared()
    #endif
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    /**
     * Validates a place by searching both Apple Maps and Google Places
     * Returns a ValidatedPlace with cross-reference information
     */
    func validatePlace(query: String, userLocation: CLLocationCoordinate2D? = nil) async -> ValidatedPlace {
        await MainActor.run {
            isValidating = true
            lastValidationError = nil
        }
        
        defer {
            Task { @MainActor in
                isValidating = false
            }
        }
        
        do {
            // Perform parallel searches in both services
            async let appleResults = searchAppleMaps(query: query, userLocation: userLocation)
            async let googleResults = searchGooglePlaces(query: query, userLocation: userLocation)
            
            let (applePlace, googlePlace) = try await (appleResults, googleResults)
            
            // Cross-validate and create result
            let validatedPlace = crossValidate(
                applePlace: applePlace,
                googlePlace: googlePlace,
                originalQuery: query
            )
            
            return validatedPlace
            
        } catch {
            await MainActor.run {
                lastValidationError = error
            }
            
            return ValidatedPlace(
                applePlace: nil,
                googlePlace: nil,
                isValidated: false,
                preferredCoordinate: userLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                confidence: .unknown,
                validationMessage: "Validation failed: \(error.localizedDescription)",
                coordinateDistance: nil
            )
        }
    }
    
    /**
     * Quick validation for existing coordinates
     * Useful for validating places that were added before cross-validation was implemented
     */
    func validateExistingPlace(coordinate: CLLocationCoordinate2D, name: String) async -> ValidatedPlace {
        // Search near the existing coordinate to find matches
        return await validatePlace(query: name, userLocation: coordinate)
    }
    
    // MARK: - Private Methods
    
    private func searchAppleMaps(query: String, userLocation: CLLocationCoordinate2D?) async throws -> MKMapItem? {
        return try await withCheckedThrowingContinuation { continuation in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            
            // Set search region based on user location or default to Bay Area
            if let userLocation = userLocation {
                request.region = MKCoordinateRegion(
                    center: userLocation,
                    latitudinalMeters: Self.searchRadius * 2,
                    longitudinalMeters: Self.searchRadius * 2
                )
            } else {
                request.region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                    span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                )
            }
            
            let search = MKLocalSearch(request: request)
            search.start { response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    // Return the first (most relevant) result
                    continuation.resume(returning: response?.mapItems.first)
                }
            }
        }
    }
    
    private func searchGooglePlaces(query: String, userLocation: CLLocationCoordinate2D?) async throws -> GMSPlace? {
        #if canImport(GooglePlaces)
        return try await withCheckedThrowingContinuation { continuation in
            let filter = GMSAutocompleteFilter()
            filter.types = [.establishment, .geocode]
            filter.countries = ["US"]
            
            // Create bounds if location is provided
            var bounds: GMSCoordinateBounds?
            if let location = userLocation {
                let radiusInDegrees = Self.searchRadius / 111000.0
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
            ) { [weak self] predictions, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let firstPrediction = predictions?.first,
                      let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Get detailed place information
                let fields: GMSPlaceField = [
                    .name, .coordinate, .placeID, .formattedAddress,
                    .phoneNumber, .website, .rating, .types
                ]
                
                self.placesClient.fetchPlace(
                    fromPlaceID: firstPrediction.placeID,
                    placeFields: fields
                ) { place, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: place)
                    }
                }
            }
        }
        #else
        // Return nil if Google Places SDK is not available
        return nil
        #endif
    }
    
    private func crossValidate(
        applePlace: MKMapItem?,
        googlePlace: GMSPlace?,
        originalQuery: String
    ) -> ValidatedPlace {
        
        // Determine confidence and validation status
        let (confidence, isValidated, message, distance) = evaluateResults(
            applePlace: applePlace,
            googlePlace: googlePlace
        )
        
        // Determine preferred coordinate (favor Google Maps as specified)
        let preferredCoordinate: CLLocationCoordinate2D
        if let googleCoordinate = googlePlace?.coordinate {
            preferredCoordinate = googleCoordinate
        } else if let appleCoordinate = applePlace?.placemark.coordinate {
            preferredCoordinate = appleCoordinate
        } else {
            preferredCoordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        return ValidatedPlace(
            applePlace: applePlace,
            googlePlace: googlePlace,
            isValidated: isValidated,
            preferredCoordinate: preferredCoordinate,
            confidence: confidence,
            validationMessage: message,
            coordinateDistance: distance
        )
    }
    
    private func evaluateResults(
        applePlace: MKMapItem?,
        googlePlace: GMSPlace?
    ) -> (confidence: PlaceConfidence, isValidated: Bool, message: String, distance: Double?) {
        
        guard let applePlace = applePlace, let googlePlace = googlePlace else {
            if applePlace != nil {
                return (.low, false, "Found in Apple Maps only - cannot verify with Google Maps", nil)
            } else if googlePlace != nil {
                return (.low, false, "Found in Google Maps only - cannot verify with Apple Maps", nil)
            } else {
                return (.unknown, false, "Place not found in either service", nil)
            }
        }
        
        // Both places found - calculate coordinate distance
        let appleCoordinate = applePlace.placemark.coordinate
        let googleCoordinate = googlePlace.coordinate
        
        let distance = calculateDistance(
            from: appleCoordinate,
            to: googleCoordinate
        )
        
        if distance <= Self.coordinateTolerance {
            return (.high, true, "Found in both services with matching coordinates", distance)
        } else {
            let distanceText = String(format: "%.0f", distance)
            return (.medium, true, "Found in both services (coordinates differ by \(distanceText)m)", distance)
        }
    }
    
    private func calculateDistance(
        from coordinate1: CLLocationCoordinate2D,
        to coordinate2: CLLocationCoordinate2D
    ) -> Double {
        let location1 = CLLocation(latitude: coordinate1.latitude, longitude: coordinate1.longitude)
        let location2 = CLLocation(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
        return location1.distance(from: location2)
    }
}

// MARK: - Error Types

enum PlaceValidationError: LocalizedError {
    case noResults
    case coordinateMismatch(distance: Double)
    case serviceUnavailable(service: String)
    case invalidQuery
    
    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No places found matching your search"
        case .coordinateMismatch(let distance):
            return "Place coordinates differ by \(String(format: "%.0f", distance))m between services"
        case .serviceUnavailable(let service):
            return "\(service) is currently unavailable"
        case .invalidQuery:
            return "Please enter a valid place name or address"
        }
    }
}