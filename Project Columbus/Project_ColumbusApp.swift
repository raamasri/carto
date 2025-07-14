//
//  Project_ColumbusApp.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/16/25.
//
//  DESCRIPTION:
//  This file contains the main application entry point for Project Columbus (Carto),
//  a social map-sharing iOS app. It sets up the core app structure, initializes
//  key managers, and configures the environment objects that will be shared
//  throughout the application.
//
//  ARCHITECTURE:
//  - SwiftUI App lifecycle with @main entry point
//  - MVVM pattern with StateObject managers
//  - Environment object injection for global state
//  - SwiftData container for local data persistence
//  - Real-time location updates on app lifecycle events
//

import SwiftUI
import SwiftData

// MARK: - Main Application Structure

/**
 * Project_ColumbusApp
 * 
 * The main application structure that serves as the entry point for the entire app.
 * This class is responsible for:
 * - Initializing core application managers (auth, location, data)
 * - Setting up the SwiftData model container
 * - Managing app lifecycle events (launch, foreground, background)
 * - Providing global state through environment objects
 * - Handling authentication state changes
 * - Coordinating location updates with user login status
 */
@main
struct Project_ColumbusApp: App {
    
    // MARK: - Core Application Managers
    
    /// Central store for all pin-related data and operations
    /// Manages pins, lists, favorites, and database synchronization
    @StateObject var pinStore = PinStore()
    
    /// Handles user authentication, session management, and login state
    /// Supports email/password, Apple Sign-In, and biometric authentication
    @StateObject var authManager = AuthManager()
    
    /// Manages location services, permissions, and real-time location tracking
    /// Handles geofencing, location history, and privacy settings
    @StateObject var locationManager = AppLocationManager()

    // MARK: - Application Initialization
    
    /**
     * Initializes the application and performs startup tasks
     * Currently clears the image cache to ensure fresh image loading
     */
    init() {
        // Clear image cache on app launch to prevent stale images
        ImageCache.shared.clearCache()
    }

    // MARK: - SwiftData Configuration
    
    /**
     * Configures the SwiftData model container for local data persistence
     * Currently set up for future use - no active SwiftData models yet
     * Uses persistent storage (not in-memory) for data durability
     */
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Item.self removed - no SwiftData models currently
            // Future: Add SwiftData models here for local caching
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Scene Configuration
    
    /**
     * The main scene body that defines the app's UI structure
     * Sets up environment objects, lifecycle handlers, and navigation
     */
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject global state managers as environment objects
                .environmentObject(pinStore)
                .environmentObject(authManager)
                .environmentObject(locationManager)
                
                // Handle app launch lifecycle
                .onAppear {
                    Task {
                        // Check for existing user session on app launch
                        await authManager.checkSession()
                    }
                    // Update user location when app first launches
                    updateLocationOnAppLaunch()
                }
                
                // Handle app returning to foreground
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Update location when user returns to app
                    updateLocationOnAppLaunch()
                }
                
                // Handle authentication state changes
                .onReceive(authManager.$isLoggedIn) { isLoggedIn in
                    if isLoggedIn {
                        // User just logged in - refresh location and data
                        updateLocationOnAppLaunch()
                        
                        // Reload PinStore data after authentication
                        Task {
                            await pinStore.refresh()
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Location Management
    
    /**
     * Updates user location when app launches or becomes active
     * 
     * This function handles the complex process of updating the user's location
     * in the database when the app becomes active. It includes:
     * - Authentication checks to ensure user is logged in
     * - Location permission and availability checks
     * - Retry logic for location acquisition
     * - Asynchronous database updates
     * - Comprehensive error handling and logging
     */
    private func updateLocationOnAppLaunch() {
        Task {
            // Wait a moment for location manager to initialize
            // This prevents race conditions during app startup
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Ensure user is authenticated before updating location
            guard authManager.isLoggedIn,
                  let userID = authManager.currentUserID else {
                print("📍 Skipping auto-location update: user not logged in")
                return
            }
            
            // If location is not available yet, try to request it and wait a bit more
            if locationManager.currentLocation == nil {
                print("📍 Location not available yet, requesting location...")
                locationManager.requestFreshLocation()
                
                // Wait additional time for location to become available
                // This handles cases where location services are slow to respond
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            
            // Final check for location availability
            guard let location = locationManager.currentLocation else {
                print("📍 Skipping auto-location update: location not available after waiting")
                return
            }
            
            // Log the location update for debugging
            print("📍 Auto-updating user location on app launch...")
            print("📍 Current location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            // Update user location in the database
            await SupabaseManager.shared.updateUserLocation(
                userID: userID,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            print("📍 ✅ Auto-location update completed")
        }
    }
}
