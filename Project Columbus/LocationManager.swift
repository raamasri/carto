//
//  LocationManager.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//
import CoreLocation
import Combine

class AppLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Location access granted")
        case .denied, .restricted:
            print("❌ Location access denied or restricted")
        case .notDetermined:
            print("ℹ️ Waiting for user to grant location access")
        @unknown default:
            break
        }
    }
}
