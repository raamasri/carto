//
//  PinStore.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/10/25.
//

import Foundation
import SwiftUI

@MainActor
class PinStore: ObservableObject {
    // All pins (master list)
    @Published var masterPins: [Pin] = []
    // Pins the user has marked as favorites
    @Published var favoritePins: [Pin] = []
    @Published var isLoading: Bool = false
    // @Published var lastError: AppError?
    
    // Named collections of pins (default 5 lists shown to the user)
    @Published var collections: [PinCollection] = [
        PinCollection(name: "Favorites", pins: []),
        PinCollection(name: "Coffee Shops", pins: []),
        PinCollection(name: "Restaurants", pins: []),
        PinCollection(name: "Bars", pins: []),
        PinCollection(name: "Shopping", pins: [])
    ]
    
    // TODO: Re-enable when infrastructure is properly integrated
    // private let dataManager = DataManager.shared
    // private let errorManager = ErrorManager()
    
    /// Adds a pin to the Favorites list if it isn't already present.
    /// - Parameter pin: The `Pin` to add.
    func addToFavorites(_ pin: Pin) {
        guard !favoritePins.contains(where: { $0.id == pin.id }) else { return }
        favoritePins.append(pin)
        
        // TODO: Re-enable when DataManager is integrated
        // Task {
        //     await dataManager.savePinOffline(pin)
        // }
    }
    
    /// Adds a pin to the specified list, creating the list if it doesn't exist.
    /// - Parameters:
    ///   - pin: The `Pin` to save.
    ///   - listName: The name of the list/collection.
    func addPin(_ pin: Pin, to listName: String) {
        // Keep the master list updated
        if !masterPins.contains(where: { $0.id == pin.id }) {
            masterPins.append(pin)
        }
        
        // Special handling for Favorites
        if listName == "Favorites" {
            addToFavorites(pin)
            return
        }
        
        // Check if the collection already exists
        if let index = collections.firstIndex(where: { $0.name == listName }) {
            // Append only if the pin is not already present
            if !collections[index].pins.contains(where: { $0.id == pin.id }) {
                collections[index].pins.append(pin)
            }
        } else {
            // Create a new collection with the pin
            collections.append(PinCollection(name: listName, pins: [pin]))
        }
        
        // TODO: Re-enable when DataManager is integrated
        // Task {
        //     await dataManager.savePinOffline(pin)
        // }
    }
    
    func removePin(_ pin: Pin, from listName: String) {
        if listName == "Favorites" {
            favoritePins.removeAll { $0.id == pin.id }
        }
        
        if let index = collections.firstIndex(where: { $0.name == listName }) {
            collections[index].pins.removeAll { $0.id == pin.id }
        }
        
        // Remove from master list if not in any collection
        let isInAnyCollection = collections.contains { collection in
            collection.pins.contains { $0.id == pin.id }
        }
        let isInFavorites = favoritePins.contains { $0.id == pin.id }
        
        if !isInAnyCollection && !isInFavorites {
            masterPins.removeAll { $0.id == pin.id }
        }
    }
    
    func fetchPins() async {
        isLoading = true
        // lastError = nil
        
        // TODO: Replace with real fetch logic from your database or API
        // Example:
        // await loadPins()
        
        isLoading = false
    }
    
    // TODO: Implement when DataManager is integrated
    // func searchPins(query: String) async -> [Pin] {
    //     guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    //         return masterPins
    //     }
    //     return await dataManager.searchPins(query: query)
    // }
}
