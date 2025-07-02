//
//  LocationManager.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//
import CoreLocation
import Combine
import MapKit
import UserNotifications
import Foundation

class AppLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocationCoordinate2D? = nil
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationHistoryEnabled: Bool = UserDefaults.standard.bool(forKey: "locationHistoryEnabled")
    
    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
    
    // Location tracking settings
    private var isTracking: Bool = false
    private var lastLocationUpdate: Date = Date()
    private let minimumUpdateInterval: TimeInterval = 30 // 30 seconds
    private let minimumDistanceThreshold: CLLocationDistance = 10 // 10 meters

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = minimumDistanceThreshold
        
        // Request notification permissions
        requestNotificationPermissions()
    }
    
    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        #if os(iOS)
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        #endif
        
        isTracking = true
        manager.startUpdatingLocation()
        
        // Start significant location changes for background tracking
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        }
    }
    
    func stopLocationUpdates() {
        isTracking = false
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }
    
    func enableLocationHistory() {
        isLocationHistoryEnabled = true
        UserDefaults.standard.set(true, forKey: "locationHistoryEnabled")
        
        if !isTracking {
            startLocationUpdates()
        }
    }
    
    func disableLocationHistory() {
        isLocationHistoryEnabled = false
        UserDefaults.standard.set(false, forKey: "locationHistoryEnabled")
    }
    
    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location.coordinate
            self.currentLocation = location
        }
        
        // Save to location history if enabled
        if isLocationHistoryEnabled {
            saveLocationToHistory(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            #if os(iOS)
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.isLocationHistoryEnabled {
                    self.startLocationUpdates()
                }
            case .denied, .restricted:
                self.stopLocationUpdates()
            case .notDetermined:
                break
            @unknown default:
                break
            }
            #endif
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error)")
    }
    
    // MARK: - Private Methods
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("✅ Notification permissions granted: \(granted)")
            }
        }
    }
    
    private func saveLocationToHistory(_ location: CLLocation) {
        // Check if enough time has passed since last update
        let now = Date()
        guard now.timeIntervalSince(lastLocationUpdate) >= minimumUpdateInterval else {
            return
        }
        
        lastLocationUpdate = now
        
        // TODO: Integrate with SupabaseManager when import issues are resolved
        // For now, save locally with enhanced data structure
        saveLocationLocally(location, timestamp: now)
        
        // Future implementation will include:
        // - Database integration via SupabaseManager
        // - Activity type detection
        // - Reverse geocoding for location names
        print("✅ Location saved to history: \(location.coordinate)")
    }
    
    /// Save location locally as backup/cache
    private func saveLocationLocally(_ location: CLLocation, timestamp: Date) {
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "speed": location.speed,
            "heading": location.course,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        
        // Store in UserDefaults as a simple cache
        var locationHistory = UserDefaults.standard.array(forKey: "locationHistory") as? [[String: Any]] ?? []
        locationHistory.append(locationData)
        
        // Keep only last 100 locations
        if locationHistory.count > 100 {
            locationHistory = Array(locationHistory.suffix(100))
        }
        
        UserDefaults.standard.set(locationHistory, forKey: "locationHistory")
        print("✅ Location saved locally: \(location.coordinate)")
    }
    
    /// Determine activity type based on location data
    private func determineActivityType(from location: CLLocation) -> String {
        if location.speed < 0 {
            return "unknown"
        } else if location.speed < 1.0 { // Less than 1 m/s (3.6 km/h)
            return "stationary"
        } else if location.speed < 5.0 { // Less than 5 m/s (18 km/h)
            return "walking"
        } else if location.speed < 15.0 { // Less than 15 m/s (54 km/h)
            return "cycling"
        } else {
            return "driving"
        }
    }
    
    private func getCurrentUserID() -> String? {
        // TODO: Implement proper user ID retrieval when SupabaseManager integration is complete
        // For now, try to get from UserDefaults cache
        return UserDefaults.standard.string(forKey: "currentUserID")
    }
    
    // MARK: - Public Utility Methods
    
    func getLocationHistory() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: "locationHistory") as? [[String: Any]] ?? []
    }
    
    func clearLocationHistory() {
        UserDefaults.standard.removeObject(forKey: "locationHistory")
        print("✅ Location history cleared")
    }
    
    func getLastKnownLocation() -> CLLocation? {
        return currentLocation
    }
    
    func distanceFromCurrentLocation(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }
    
    /// Request a fresh location update (for auto-update functionality)
    func requestFreshLocation() {
        #if os(iOS)
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("📍 Location permission not granted")
            return
        }
        #endif
        
        manager.requestLocation()
    }
    
    /// Request user location manually (for UI actions)
    func requestUserLocationManually() {
        #if os(iOS)
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        #endif
        
        manager.startUpdatingLocation()
    }
}
