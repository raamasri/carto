import Foundation
import CoreLocation
import SwiftUI

/**
 * GoogleMapsMocks
 * 
 * This file provides mock implementations of Google Maps and Places SDK types
 * to allow the app to compile and run when the SDK is not available. These mocks
 * will be replaced by actual SDK types once Google Maps is integrated.
 */

#if !canImport(GoogleMaps)

// MARK: - Google Maps Mocks

struct GMSCameraPosition {
    let target: CLLocationCoordinate2D
    let zoom: Float
    let bearing: CLLocationDirection
    let viewingAngle: Double
    
    init(latitude: Double, longitude: Double, zoom: Float, bearing: CLLocationDirection = 0, viewingAngle: Double = 0) {
        self.target = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.zoom = zoom
        self.bearing = bearing
        self.viewingAngle = viewingAngle
    }
    
    static let defaultSanFrancisco = GMSCameraPosition(
        latitude: 37.7749,
        longitude: -122.4194,
        zoom: 13.0
    )
}

enum GMSMapViewType {
    case normal, satellite, hybrid, terrain
}

class GMSMapView: UIView {
    var camera: GMSCameraPosition = .defaultSanFrancisco
    var mapType: GMSMapViewType = .normal
    var isMyLocationEnabled: Bool = false
    var delegate: GMSMapViewDelegate?
    
    struct GMSUISettings {
        var compassButton: Bool = true
        var myLocationButton: Bool = true
        var rotateGestures: Bool = true
        var scrollGestures: Bool = true
        var tiltGestures: Bool = true
        var zoomGestures: Bool = true
    }
    
    var settings = GMSUISettings()
    
    func animate(to camera: GMSCameraPosition) {
        self.camera = camera
    }
    
    func clear() {
        // Clear all markers
    }
}

protocol GMSMapViewDelegate: AnyObject {
    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition)
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool
    func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D)
}

class GMSMarker: NSObject {
    var position: CLLocationCoordinate2D = CLLocationCoordinate2D()
    var title: String?
    var snippet: String?
    var userData: Any?
    var map: GMSMapView?
    var icon: UIImage?
    var iconView: UIView?
    
    static func markerImage(with color: UIColor) -> UIImage? {
        return UIImage(systemName: "mappin.circle.fill")?.withTintColor(color)
    }
}

class GMSServices {
    static func provideAPIKey(_ key: String) {
        print("Mock: GMSServices API key provided")
    }
    
    static func openSourceLicenseInfo() -> String? {
        return "Mock Google Maps License Info"
    }
}

class GMSCoordinateBounds {
    let northEast: CLLocationCoordinate2D
    let southWest: CLLocationCoordinate2D
    
    init(coordinate: CLLocationCoordinate2D, coordinate2: CLLocationCoordinate2D) {
        self.northEast = coordinate
        self.southWest = coordinate2
    }
}

#endif

#if !canImport(GooglePlaces)

// MARK: - Google Places Mocks

// Always define GMSCoordinateBounds for GooglePlaces mocks
// (It might already exist from GoogleMaps, but redefinition in different conditional blocks is OK)
class GMSCoordinateBounds {
    let northEast: CLLocationCoordinate2D
    let southWest: CLLocationCoordinate2D
    
    init(coordinate: CLLocationCoordinate2D, coordinate2: CLLocationCoordinate2D) {
        self.northEast = coordinate
        self.southWest = coordinate2
    }
}

class GMSPlacesClient {
    static func provideAPIKey(_ key: String) {
        print("Mock: GMSPlacesClient API key provided")
    }
    
    static func shared() -> GMSPlacesClient {
        return GMSPlacesClient()
    }
    
    func findAutocompletePredictions(fromQuery query: String,
                                   bounds: GMSCoordinateBounds?,
                                   boundsMode: GMSAutocompleteBoundsMode,
                                   filter: GMSAutocompleteFilter?,
                                   callback: @escaping ([GMSAutocompletePrediction]?, Error?) -> Void) {
        // Mock implementation
        DispatchQueue.main.async {
            callback([], nil)
        }
    }
    
    func fetchPlace(fromPlaceID placeID: String,
                   placeFields: GMSPlaceField,
                   callback: @escaping (GMSPlace?, Error?) -> Void) {
        // Mock implementation
        DispatchQueue.main.async {
            callback(nil, NSError(domain: "GooglePlacesMock", code: -1, userInfo: nil))
        }
    }
}

struct GMSAutocompletePrediction {
    let placeID: String = ""
    let attributedPrimaryText: NSAttributedString = NSAttributedString(string: "Mock Place")
    let attributedSecondaryText: NSAttributedString? = NSAttributedString(string: "Mock Address")
}

class GMSAutocompleteFilter {
    var types: [GMSPlaceType] = []
    var countries: [String] = []
}

enum GMSPlaceType {
    case establishment
    case geocode
    case address
    case regions
    case cities
}

enum GMSAutocompleteBoundsMode {
    case bias
    case restrict
}

struct GMSPlaceField: OptionSet {
    let rawValue: UInt
    
    static let name = GMSPlaceField(rawValue: 1 << 0)
    static let coordinate = GMSPlaceField(rawValue: 1 << 1)
    static let placeID = GMSPlaceField(rawValue: 1 << 2)
    static let formattedAddress = GMSPlaceField(rawValue: 1 << 3)
    static let phoneNumber = GMSPlaceField(rawValue: 1 << 4)
    static let website = GMSPlaceField(rawValue: 1 << 5)
    static let rating = GMSPlaceField(rawValue: 1 << 6)
    static let priceLevel = GMSPlaceField(rawValue: 1 << 7)
    static let types = GMSPlaceField(rawValue: 1 << 8)
    static let businessStatus = GMSPlaceField(rawValue: 1 << 9)
}

class GMSPlace {
    let name: String? = "Mock Place"
    let coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    let placeID: String? = "mock_place_id"
    let formattedAddress: String? = "Mock Address, San Francisco, CA"
    let phoneNumber: String? = "+1234567890"
    let website: URL? = URL(string: "https://example.com")
    let rating: Float = 4.5
    let priceLevel: Int = 2
}

#endif 