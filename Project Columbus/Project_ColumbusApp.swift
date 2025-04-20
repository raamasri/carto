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

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
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
                    authManager.checkSession()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
