//
//  Project_ColumbusApp.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/16/25.
//

import SwiftUI
import SwiftData

@main
struct Project_ColumbusApp: App {
    @StateObject var pinStore = PinStore()
    @StateObject var authManager = AuthManager()
    @StateObject var locationManager = AppLocationManager()

    init() {
        ImageCache.shared.clearCache()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Item.self removed - no SwiftData models currently
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pinStore)
                .environmentObject(authManager)
                .environmentObject(locationManager)
                .onAppear {
                    Task {
                        await authManager.checkSession()
                    }
                    updateLocationOnAppLaunch()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    updateLocationOnAppLaunch()
                }
                .onReceive(authManager.$isLoggedIn) { isLoggedIn in
                    if isLoggedIn {
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
    
    /// Update user location when app launches or becomes active
    private func updateLocationOnAppLaunch() {
        Task {
            // Wait a moment for location manager to initialize
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            guard authManager.isLoggedIn,
                  let userID = authManager.currentUserID else {
                print("📍 Skipping auto-location update: user not logged in")
                return
            }
            
            // If location is not available yet, try to request it and wait a bit more
            if locationManager.currentLocation == nil {
                print("📍 Location not available yet, requesting location...")
                locationManager.requestFreshLocation()
                
                // Wait a bit more for location to become available
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }
            
            guard let location = locationManager.currentLocation else {
                print("📍 Skipping auto-location update: location not available after waiting")
                return
            }
            
            print("📍 Auto-updating user location on app launch...")
            print("📍 Current location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
            await SupabaseManager.shared.updateUserLocation(
                userID: userID,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            print("📍 ✅ Auto-location update completed")
        }
    }
}
