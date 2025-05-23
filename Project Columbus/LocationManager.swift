//
//  LocationManager.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//
import CoreLocation
import Combine
import MapKit

class AppLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D? = nil
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            // Handle permission denied
            break
        case .notDetermined:
            // Waiting for user permission
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newLocation = locations.last {
            self.location = newLocation.coordinate
            self.currentLocation = newLocation
        }
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
    
    func requestUserLocationManually() {
        manager.startUpdatingLocation()
    }
}
