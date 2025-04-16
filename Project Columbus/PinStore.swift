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
        guard !favoritePins.contains(where: { $0.latitude == pin.latitude &&
                                               $0.longitude == pin.longitude }) else { return }
        favoritePins.append(pin)
    }

    // Named collections of pins (e.g., "Europe 25", "Pizza Tour")
    @Published var collections: [PinCollection] = [
        PinCollection(name: "Favorites", pins: []),
        PinCollection(name: "San Francisco", pins: []),
        PinCollection(name: "Europe 25", pins: [])
    ]
}
