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

    // Named collections of pins (e.g., "Europe 25", "Pizza Tour")
    @Published var collections: [PinCollection] = [
        PinCollection(name: "Favorites"),
        PinCollection(name: "San Francisco"),
        PinCollection(name: "Europe 25")
    ]
}
