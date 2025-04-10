//
//  pin.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/10/25.
//
// Pin.swift
import Foundation
import SwiftUI

struct Pin: Identifiable, Equatable {
    let id = UUID()
    var locationName: String
    var city: String
    var date: String
    var latitude: Double
    var longitude: Double
    var reaction: Reaction
}

enum Reaction: String, CaseIterable {
    case lovedIt = "Loved It"
    case wantToGo = "Want to Go"
}

// PinCollection.swift
struct PinCollection: Identifiable {
    let id = UUID()
    var name: String
    var pins: [Pin] = []
}
