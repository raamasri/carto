//
//  PinStore.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/10/25.
//

import Foundation
import SwiftUI

class PinStore: ObservableObject {
    // All pins (master list)
    @Published var masterPins: [Pin] = []
    // Pins the user has marked as favorites
    @Published var favoritePins: [Pin] = []
    
    /// Adds a pin to the Favorites list if it isn’t already present.
    /// - Parameter pin: The `Pin` to add.
    func addToFavorites(_ pin: Pin) {
        guard !favoritePins.contains(where: { $0.id == pin.id }) else { return }
        favoritePins.append(pin)
    }
    
    /// Adds a pin to the specified list, creating the list if it doesn’t exist.
    /// - Parameters:
    ///   - pin: The `Pin` to save.
    ///   - listName: The name of the list/collection.
    func addPin(_ pin: Pin, to listName: String) {
        // Keep the master list updated
        if !masterPins.contains(where: { $0.id == pin.id }) {
            masterPins.append(pin)
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
    }

    // Named collections of pins (default 5 lists shown to the user)
    @Published var collections: [PinCollection] = [
        PinCollection(name: "Favorites", pins: []),
        PinCollection(name: "Coffee Shops", pins: []),
        PinCollection(name: "Restaurants", pins: []),
        PinCollection(name: "Bars", pins: []),
        PinCollection(name: "Shopping", pins: [])
    ]
    
    @MainActor
    func fetchPins() {
        // TODO: Replace this with real fetch logic from your database or API
        // Example:
        // await loadPins()
    }
}
