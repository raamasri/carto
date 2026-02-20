import Foundation
import SwiftUI
import CoreLocation

#if canImport(GooglePlaces)
import GooglePlaces
#endif

/**
 * GooglePlacesDiagnostic
 * 
 * Diagnostic tool to test and validate Google Places API functionality
 * This helps debug issues with place search and API configuration
 */
class GooglePlacesDiagnostic: ObservableObject {
    
    @Published var isRunning = false
    @Published var results: [DiagnosticResult] = []
    @Published var lastError: String?
    
    struct DiagnosticResult {
        let timestamp: Date
        let test: String
        let success: Bool
        let details: String
        let data: Any?
    }
    
    // MARK: - Main Diagnostic Function
    
    func runDiagnostics() async {
        await MainActor.run {
            isRunning = true
            results.removeAll()
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isRunning = false
            }
        }
        
        // Test 1: Check SDK Availability
        await testSDKAvailability()
        
        // Test 2: Check API Key Configuration
        await testAPIKeyConfiguration()
        
        // Test 3: Test Basic Place Search
        await testBasicPlaceSearch()
        
        // Test 4: Test Specific Well-Known Places
        await testWellKnownPlaces()
        
        // Test 5: Test Different Search Parameters
        await testSearchParameters()
    }
    
    // MARK: - Individual Tests
    
    private func testSDKAvailability() async {
        #if canImport(GooglePlaces)
        await addResult(
            test: "Google Places SDK Availability",
            success: true,
            details: "Google Places SDK is available and imported successfully"
        )
        #else
        await addResult(
            test: "Google Places SDK Availability",
            success: false,
            details: "Google Places SDK is not available - check Swift Package Manager integration"
        )
        #endif
    }
    
    private func testAPIKeyConfiguration() async {
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: configPath),
              let apiKey = config["GoogleMapsAPIKey"] as? String else {
            await addResult(
                test: "API Key Configuration",
                success: false,
                details: "Could not find GoogleMapsAPIKey in Config.plist"
            )
            return
        }
        
        let isValidFormat = apiKey.hasPrefix("AIza") && apiKey.count > 35
        await addResult(
            test: "API Key Configuration",
            success: isValidFormat,
            details: isValidFormat ? 
                "API key found and appears valid (starts with AIza, length: \(apiKey.count))" :
                "API key found but format appears invalid (length: \(apiKey.count), prefix: \(String(apiKey.prefix(4))))"
        )
    }
    
    private func testBasicPlaceSearch() async {
        #if canImport(GooglePlaces)
        await performPlaceSearch(
            query: "Starbucks",
            testName: "Basic Place Search (Starbucks)",
            userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // San Francisco
        )
        #else
        await addResult(
            test: "Basic Place Search",
            success: false,
            details: "Google Places SDK not available"
        )
        #endif
    }
    
    private func testWellKnownPlaces() async {
        let testPlaces = [
            ("Apple Park", CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)),
            ("Golden Gate Bridge", CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783)),
            ("Times Square", CLLocationCoordinate2D(latitude: 40.7589, longitude: -73.9851))
        ]
        
        for (place, location) in testPlaces {
            await performPlaceSearch(
                query: place,
                testName: "Well-Known Place (\(place))",
                userLocation: location
            )
        }
    }
    
    private func testSearchParameters() async {
        // Test without location restriction
        await performPlaceSearch(
            query: "McDonald's",
            testName: "Search Without Location",
            userLocation: nil
        )
        
        // Test with broader radius
        await performPlaceSearchWithCustomRadius(
            query: "Coffee",
            testName: "Search With Broad Radius",
            userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 50000 // 50km
        )
    }
    
    // MARK: - Helper Functions
    
    private func performPlaceSearch(query: String, testName: String, userLocation: CLLocationCoordinate2D?) async {
        #if canImport(GooglePlaces)
        do {
            let place = try await searchGooglePlaces(query: query, userLocation: userLocation)
            
            if let place = place {
                await addResult(
                    test: testName,
                    success: true,
                    details: """
                    Found: \(place.name ?? "Unknown")
                    Address: \(place.formattedAddress ?? "No address")
                    Coordinate: \(place.coordinate.latitude), \(place.coordinate.longitude)
                    Place ID: \(place.placeID ?? "No ID")
                    """,
                    data: place
                )
            } else {
                await addResult(
                    test: testName,
                    success: false,
                    details: "No place found for query: \(query)"
                )
            }
        } catch {
            await addResult(
                test: testName,
                success: false,
                details: "Error searching: \(error.localizedDescription)"
            )
        }
        #endif
    }
    
    private func performPlaceSearchWithCustomRadius(query: String, testName: String, userLocation: CLLocationCoordinate2D?, radius: Double) async {
        #if canImport(GooglePlaces)
        do {
            let place = try await searchGooglePlacesWithRadius(query: query, userLocation: userLocation, radius: radius)
            
            if let place = place {
                await addResult(
                    test: testName,
                    success: true,
                    details: """
                    Found: \(place.name ?? "Unknown")
                    Address: \(place.formattedAddress ?? "No address")
                    Coordinate: \(place.coordinate.latitude), \(place.coordinate.longitude)
                    Radius: \(radius)m
                    """,
                    data: place
                )
            } else {
                await addResult(
                    test: testName,
                    success: false,
                    details: "No place found for query: \(query) with radius: \(radius)m"
                )
            }
        } catch {
            await addResult(
                test: testName,
                success: false,
                details: "Error searching with custom radius: \(error.localizedDescription)"
            )
        }
        #endif
    }
    
    #if canImport(GooglePlaces)
    private func searchGooglePlaces(query: String, userLocation: CLLocationCoordinate2D?) async throws -> GMSPlace? {
        return try await withCheckedThrowingContinuation { continuation in
            let filter = GMSAutocompleteFilter()
            filter.types = [.establishment, .geocode]
            filter.countries = ["US"]
            
            var bounds: GMSCoordinateBounds?
            if let location = userLocation {
                let radiusInDegrees = 2000.0 / 111000.0 // 2km
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
            
            GMSPlacesClient.shared().findAutocompletePredictions(
                fromQuery: query,
                bounds: bounds,
                boundsMode: .bias,
                filter: filter
            ) { predictions, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let firstPrediction = predictions?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let fields: GMSPlaceField = [
                    .name, .coordinate, .placeID, .formattedAddress,
                    .phoneNumber, .website, .rating, .types
                ]
                
                GMSPlacesClient.shared().fetchPlace(
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
    }
    
    private func searchGooglePlacesWithRadius(query: String, userLocation: CLLocationCoordinate2D?, radius: Double) async throws -> GMSPlace? {
        return try await withCheckedThrowingContinuation { continuation in
            let filter = GMSAutocompleteFilter()
            filter.types = [.establishment, .geocode]
            filter.countries = ["US"]
            
            var bounds: GMSCoordinateBounds?
            if let location = userLocation {
                let radiusInDegrees = radius / 111000.0
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
            
            GMSPlacesClient.shared().findAutocompletePredictions(
                fromQuery: query,
                bounds: bounds,
                boundsMode: .bias,
                filter: filter
            ) { predictions, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let firstPrediction = predictions?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let fields: GMSPlaceField = [
                    .name, .coordinate, .placeID, .formattedAddress,
                    .phoneNumber, .website, .rating, .types
                ]
                
                GMSPlacesClient.shared().fetchPlace(
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
    }
    #endif
    
    private func addResult(test: String, success: Bool, details: String, data: Any? = nil) async {
        await MainActor.run {
            let result = DiagnosticResult(
                timestamp: Date(),
                test: test,
                success: success,
                details: details,
                data: data
            )
            results.append(result)
        }
    }
}

// MARK: - Diagnostic View

struct GooglePlacesDiagnosticView: View {
    @StateObject private var diagnostic = GooglePlacesDiagnostic()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Google Places Diagnostic")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Test Google Places API integration and search functionality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Run Diagnostic Button
                Button(action: {
                    Task {
                        await diagnostic.runDiagnostics()
                    }
                }) {
                    HStack {
                        if diagnostic.isRunning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.shield")
                        }
                        Text(diagnostic.isRunning ? "Running Diagnostics..." : "Run Diagnostics")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(diagnostic.isRunning ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(diagnostic.isRunning)
                
                // Results
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(diagnostic.results.indices, id: \.self) { index in
                            let result = diagnostic.results[index]
                            DiagnosticResultCard(result: result)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct DiagnosticResultCard: View {
    let result: GooglePlacesDiagnostic.DiagnosticResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.test)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(DateFormatter.localizedString(from: result.timestamp, dateStyle: .none, timeStyle: .medium))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(result.details)
                .font(.caption)
                .foregroundColor(.primary)
                .padding(.leading, 32)
        }
        .padding()
        .background(result.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(result.success ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct GooglePlacesDiagnosticView_Previews: PreviewProvider {
    static var previews: some View {
        GooglePlacesDiagnosticView()
    }
}
#endif