//
//  LocationManager.swift
//  Project Columbus
//
//  Created by raama srivatsan on 4/15/25.
//
//  DESCRIPTION:
//  This file contains the main location management system for Project Columbus (Carto).
//  It handles all location-related functionality including GPS tracking, location history,
//  permission management, and background location updates.
//
//  FEATURES:
//  - Real-time location tracking with configurable accuracy
//  - Location history storage with privacy controls
//  - Background location monitoring for enhanced features
//  - Activity type detection (walking, cycling, driving)
//  - Distance calculations and utilities
//  - Integration with notification system
//  - Comprehensive permission handling
//
//  ARCHITECTURE:
//  - ObservableObject for reactive UI updates
//  - CLLocationManagerDelegate for location events
//  - Local caching with future database integration
//  - Privacy-first design with user controls
//  - Efficient battery usage with smart filtering
//

import CoreLocation
import Combine
import MapKit
import UserNotifications
import Foundation

// MARK: - Location Manager Implementation

/**
 * AppLocationManager
 * 
 * A comprehensive location management system that handles all location-related
 * functionality for the Project Columbus app. This class provides real-time
 * location tracking, history management, and privacy controls.
 * 
 * KEY FEATURES:
 * - Real-time location updates with configurable accuracy
 * - Location history storage with user privacy controls
 * - Background location monitoring for enhanced features
 * - Activity type detection based on speed analysis
 * - Distance calculations and location utilities
 * - Notification permissions for location-based alerts
 * - Comprehensive authorization status handling
 * 
 * PRIVACY CONSIDERATIONS:
 * - User-controlled location history enable/disable
 * - Minimum update intervals to preserve battery
 * - Distance thresholds to avoid excessive updates
 * - Local storage with future secure database integration
 * 
 * PERFORMANCE OPTIMIZATIONS:
 * - Smart filtering based on time and distance
 * - Efficient delegate patterns for location updates
 * - Background monitoring for significant location changes
 * - Caching strategies for quick location access
 */
class AppLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - Core Location Manager
    
    /// The underlying CLLocationManager instance
    private let manager = CLLocationManager()
    
    // MARK: - Published Properties
    
    /// Current location coordinate for UI binding
    @Published var location: CLLocationCoordinate2D? = nil
    
    /// Complete current location object with metadata
    @Published var currentLocation: CLLocation?
    
    /// Current authorization status for location services
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    /// User preference for location history tracking
    @Published var isLocationHistoryEnabled: Bool = UserDefaults.standard.bool(forKey: "locationHistoryEnabled")
    
    // MARK: - Computed Properties
    
    /**
     * Map region centered on current location
     * 
     * This computed property provides a properly configured map region
     * for UI display, with a fallback to San Francisco if no location is available.
     */
    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
    
    // MARK: - Location Tracking Configuration
    
    /// Whether location tracking is currently active
    private var isTracking: Bool = false
    
    /// Timestamp of the last location update to prevent excessive updates
    private var lastLocationUpdate: Date = Date()
    
    /// Minimum time interval between location updates (30 seconds)
    private let minimumUpdateInterval: TimeInterval = 30
    
    /// Minimum distance threshold for location updates (10 meters)
    private let minimumDistanceThreshold: CLLocationDistance = 10

    // MARK: - Initialization
    
    /**
     * Initializes the location manager with optimal configuration
     * 
     * This initializer sets up the location manager with appropriate
     * accuracy settings, distance filters, and notification permissions.
     */
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = minimumDistanceThreshold
        
        // Request notification permissions for location-based alerts
        requestNotificationPermissions()
    }
    
    // MARK: - Permission Management
    
    /**
     * Requests location permission from the user
     * 
     * This method initiates the location permission request flow,
     * which will trigger the authorization status delegate callback.
     */
    func requestLocationPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Location Tracking Control
    
    /**
     * Starts location tracking with proper permission checking
     * 
     * This method begins location updates if permissions are granted,
     * and includes background monitoring for significant location changes.
     */
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
    
    /**
     * Stops all location tracking activities
     * 
     * This method halts both regular location updates and background
     * monitoring to conserve battery when tracking is not needed.
     */
    func stopLocationUpdates() {
        isTracking = false
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }
    
    // MARK: - Location History Management
    
    /**
     * Enables location history tracking with user consent
     * 
     * This method activates location history storage and starts
     * location tracking if not already active.
     */
    func enableLocationHistory() {
        isLocationHistoryEnabled = true
        UserDefaults.standard.set(true, forKey: "locationHistoryEnabled")
        
        if !isTracking {
            startLocationUpdates()
        }
    }
    
    /**
     * Disables location history tracking
     * 
     * This method stops location history storage while preserving
     * current location functionality for app features.
     */
    func disableLocationHistory() {
        isLocationHistoryEnabled = false
        UserDefaults.standard.set(false, forKey: "locationHistoryEnabled")
    }
    
    // MARK: - CLLocationManagerDelegate Implementation

    /**
     * Handles location updates from the system
     * 
     * This delegate method processes new location data, updates published
     * properties, and saves to location history if enabled.
     * 
     * @param manager The location manager providing the update
     * @param locations Array of location objects (uses the last/most recent)
     */
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Update published properties on main thread for UI binding
        DispatchQueue.main.async {
            self.location = location.coordinate
            self.currentLocation = location
        }
        
        // Save to location history if user has enabled this feature
        if isLocationHistoryEnabled {
            saveLocationToHistory(location)
        }
    }
    
    /**
     * Handles authorization status changes
     * 
     * This delegate method responds to permission changes and automatically
     * starts or stops location tracking based on the new status.
     * 
     * @param manager The location manager reporting the status change
     * @param status The new authorization status
     */
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            #if os(iOS)
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                // Start tracking if location history is enabled
                if self.isLocationHistoryEnabled {
                    self.startLocationUpdates()
                }
            case .denied, .restricted:
                // Stop tracking if permissions are revoked
                self.stopLocationUpdates()
            case .notDetermined:
                break
            @unknown default:
                break
            }
            #endif
        }
    }
    
    /**
     * Handles location manager errors
     * 
     * This delegate method logs location-related errors for debugging
     * and troubleshooting purposes.
     * 
     * @param manager The location manager that encountered an error
     * @param error The error that occurred
     */
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error)")
    }
    
    // MARK: - Private Utility Methods
    
    /**
     * Requests notification permissions for location-based alerts
     * 
     * This method sets up notification permissions that may be used
     * for location-based features like geofencing or arrival alerts.
     */
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
            } else {
                print("✅ Notification permissions granted: \(granted)")
            }
        }
    }
    
    /**
     * Saves location data to history with intelligent filtering
     * 
     * This method implements smart filtering to avoid excessive location
     * storage while maintaining useful location history data.
     * 
     * @param location The location object to save
     */
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
    
    /**
     * Saves location data to local storage as backup/cache
     * 
     * This method provides local storage for location data with
     * comprehensive metadata and automatic history management.
     * 
     * @param location The location object to save
     * @param timestamp The timestamp for this location entry
     */
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
        
        // Keep only last 100 locations to manage storage
        if locationHistory.count > 100 {
            locationHistory = Array(locationHistory.suffix(100))
        }
        
        UserDefaults.standard.set(locationHistory, forKey: "locationHistory")
        print("✅ Location saved locally: \(location.coordinate)")
    }
    
    /**
     * Determines activity type based on location speed data
     * 
     * This method analyzes location speed to classify user activity,
     * which can be useful for context-aware features.
     * 
     * @param location The location object containing speed data
     * @return String representing the detected activity type
     */
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
    
    /**
     * Retrieves the current user ID for location history association
     * 
     * This method provides user ID retrieval with a temporary
     * implementation until full authentication integration is complete.
     * 
     * @return Optional user ID string
     */
    private func getCurrentUserID() -> String? {
        // TODO: Implement proper user ID retrieval when SupabaseManager integration is complete
        // For now, try to get from UserDefaults cache
        return UserDefaults.standard.string(forKey: "currentUserID")
    }
    
    // MARK: - Public Utility Methods
    
    /**
     * Retrieves the complete location history from local storage
     * 
     * This method provides access to the locally stored location history
     * for display in UI components or analysis purposes.
     * 
     * @return Array of location data dictionaries
     */
    func getLocationHistory() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: "locationHistory") as? [[String: Any]] ?? []
    }
    
    /**
     * Clears all stored location history data
     * 
     * This method removes all location history from local storage,
     * typically used when users want to reset their location data.
     */
    func clearLocationHistory() {
        UserDefaults.standard.removeObject(forKey: "locationHistory")
        print("✅ Location history cleared")
    }
    
    /**
     * Retrieves the last known location
     * 
     * This method provides quick access to the most recent location
     * data for use in app features that need current position.
     * 
     * @return Optional CLLocation object
     */
    func getLastKnownLocation() -> CLLocation? {
        return currentLocation
    }
    
    /**
     * Calculates distance from current location to a target coordinate
     * 
     * This method computes the straight-line distance between the
     * current location and a specified coordinate.
     * 
     * @param coordinate The target coordinate for distance calculation
     * @return Optional distance in meters
     */
    func distanceFromCurrentLocation(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }
    
    /**
     * Requests a fresh location update for automatic features
     * 
     * This method triggers a one-time location update, typically used
     * for app launch or background refresh scenarios.
     */
    func requestFreshLocation() {
        #if os(iOS)
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("📍 Location permission not granted")
            return
        }
        #endif
        
        manager.requestLocation()
    }
    
    /**
     * Requests user location manually for UI-triggered actions
     * 
     * This method initiates location updates in response to user actions,
     * such as tapping a "locate me" button in the interface.
     */
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
