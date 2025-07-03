//
//  AppUser.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/19/25.
//
import Supabase
import Foundation
import CoreLocation

struct AppUser: Identifiable, Codable {
    var id: String
    var username: String
    var full_name: String
    var email: String?
    var bio: String?
    var follower_count: Int
    var following_count: Int
    var isFollowedByCurrentUser: Bool
    let latitude: Double?
    let longitude: Double?
    let isCurrentUser: Bool
    let avatarURL: String?

    var location: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case full_name
        case email
        case bio
        case follower_count
        case following_count
        case isFollowedByCurrentUser
        case latitude
        case longitude
        case isCurrentUser
        case avatarURL = "avatar_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        full_name = try container.decode(String.self, forKey: .full_name)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        follower_count = try container.decodeIfPresent(Int.self, forKey: .follower_count) ?? 0
        following_count = try container.decodeIfPresent(Int.self, forKey: .following_count) ?? 0
        isFollowedByCurrentUser = try container.decodeIfPresent(Bool.self, forKey: .isFollowedByCurrentUser) ?? false
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        isCurrentUser = try container.decodeIfPresent(Bool.self, forKey: .isCurrentUser) ?? false
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
    }

    init(
        id: String,
        username: String,
        full_name: String,
        email: String?,
        bio: String?,
        follower_count: Int,
        following_count: Int,
        isFollowedByCurrentUser: Bool,
        latitude: Double?,
        longitude: Double?,
        isCurrentUser: Bool,
        avatarURL: String?
    ) {
        self.id = id
        self.username = username
        self.full_name = full_name
        self.email = email
        self.bio = bio
        self.follower_count = follower_count
        self.following_count = following_count
        self.isFollowedByCurrentUser = isFollowedByCurrentUser
        self.latitude = latitude
        self.longitude = longitude
        self.isCurrentUser = isCurrentUser
        self.avatarURL = avatarURL
    }
}

struct SelfUser: Codable {
    var id: String
    var username: String
    var full_name: String
    var email: String
    var bio: String?
    var follower_count: Int
    var following_count: Int
    var latitude: Double?
    var longitude: Double?
    var avatarURL: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case full_name
        case email
        case bio
        case follower_count
        case following_count
        case latitude
        case longitude
        case avatarURL = "avatar_url"
    }
}

// Basic user structure for database responses without computed fields
struct BasicUser: Codable {
    let id: String
    let username: String
    let full_name: String
    let email: String?
    let bio: String?
    let latitude: Double?
    let longitude: Double?
    let avatar_url: String?
    
    func toAppUser(currentUserID: String? = nil) -> AppUser {
        return AppUser(
            id: id,
            username: username,
            full_name: full_name,
            email: email,
            bio: bio,
            follower_count: 0, // Will be set separately if needed
            following_count: 0, // Will be set separately if needed
            isFollowedByCurrentUser: false, // Will be set separately if needed
            latitude: latitude,
            longitude: longitude,
            isCurrentUser: id == currentUserID,
            avatarURL: avatar_url
        )
    }
}
