//
//  AppUser.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/19/25.
//
import Supabase
import Foundation
import CoreLocation

struct AppUser: Identifiable {
    var id: String
    var username: String
    var full_name: String
    var email: String
    var bio: String
    var follower_count: Int
    var following_count: Int
    var isFollowedByCurrentUser: Bool
    let latitude: Double?
    let longitude: Double?
    //new backend driven flag
    let isCurrentUser: Bool
    let avatarURL: String  
    var location: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
