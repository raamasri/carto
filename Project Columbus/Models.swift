//
//  Models.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//
import Foundation
import CoreLocation

// MARK: - Reaction Enum
enum Reaction: String, CaseIterable {
    case lovedIt = "Loved It"
    case wantToGo = "Want to Go"
}

// MARK: - Pin Model
struct Pin: Identifiable, Equatable {
    let id = UUID()
    let locationName: String
    let city: String
    let date: String
    let latitude: Double
    let longitude: Double
    let reaction: Reaction
}

// MARK: - Pin Collection
struct PinCollection: Identifiable {
    let id = UUID()
    let name: String
    var pins: [Pin]
}

// MARK: - User Model
struct User: Identifiable {
    let id: UUID
    var username: String
    let isPrivate: Bool
    var followers: [UUID]
    var following: [UUID]
    var followRequests: [UUID]
    var collections: [PinCollection] = []
    var favoriteSpots: [Pin] = []
    var activityFeed: [Pin] = []
}
