//
//  ProximityService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation
import CoreLocation

// MARK: - Location Social Context Model

struct LocationSocialContext {
    let locationName: String
    let latitude: Double
    let longitude: Double
    let totalVisits: Int
    let uniqueVisitors: Int
    let averageRating: Double
    let recentActivity: [FriendActivity]
    let friendsCurrentlyHere: [AppUser]
    let lastVisit: Date?
    let topReviews: [String]
    
    var socialScore: Double {
        var score = 0.0
        
        let recentVisits = recentActivity.filter { $0.createdAt.timeIntervalSinceNow > -604800 }
        score += Double(recentVisits.count) * 0.3
        
        if averageRating > 0 {
            score += averageRating * 0.4
        }
        
        score += Double(uniqueVisitors) * 0.2
        score += Double(friendsCurrentlyHere.count) * 0.1
        
        return score
    }
    
    var recommendationText: String {
        if friendsCurrentlyHere.count > 0 {
            return "\(friendsCurrentlyHere.count) friend\(friendsCurrentlyHere.count == 1 ? "" : "s") \(friendsCurrentlyHere.count == 1 ? "is" : "are") here now"
        } else if !recentActivity.isEmpty {
            return "\(recentActivity.count) friend\(recentActivity.count == 1 ? "" : "s") visited recently"
        } else if averageRating > 0 {
            return String(format: "%.1f star rating from friends", averageRating)
        } else {
            return "Popular with your friends"
        }
    }
}

// MARK: - ProximityService

class ProximityService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Get pins near a specific location
    func getPinsNearLocation(latitude: Double, longitude: Double, radius: Double) async -> [Pin] {
        do {
            let radiusInDegrees = radius / 111000.0
            let minLat = latitude - radiusInDegrees
            let maxLat = latitude + radiusInDegrees
            let minLon = longitude - radiusInDegrees
            let maxLon = longitude + radiusInDegrees
            
            let pins: [PinDB] = try await client
                .from("pins")
                .select("*")
                .gte("latitude", value: minLat)
                .lte("latitude", value: maxLat)
                .gte("longitude", value: minLon)
                .lte("longitude", value: maxLon)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            
            var nearbyPins: [Pin] = []
            for pinDB in pins {
                let pinLocation = CLLocation(latitude: pinDB.latitude, longitude: pinDB.longitude)
                let searchLocation = CLLocation(latitude: latitude, longitude: longitude)
                let distance = pinLocation.distance(from: searchLocation)
                
                if distance <= radius {
                    nearbyPins.append(pinDB.toPin())
                }
            }
            
            return nearbyPins
        } catch {
            print("❌ Failed to get pins near location: \(error)")
            return []
        }
    }
    
    /// Get friend activity near a location
    func getFriendActivityNearLocation(latitude: Double, longitude: Double, radius: Double, since: Date) async -> [FriendActivity] {
        do {
            guard let session = try? await client.auth.session else { return [] }
            let currentUserID = session.user.id.uuidString
            
            let followingUsers = await getFollowingUsers(for: currentUserID)
            let followingIds = followingUsers.map { $0.id }
            
            if followingIds.isEmpty {
                return []
            }
            
            let nearbyPins = await getPinsNearLocation(latitude: latitude, longitude: longitude, radius: radius)
            let friendPins = nearbyPins.filter { pin in
                followingIds.contains(pin.authorHandle)
            }
            
            let recentPins = friendPins.filter { pin in
                pin.createdAt >= since
            }
            
            var activities: [FriendActivity] = []
            for pin in recentPins {
                let activity = FriendActivity(
                    userId: pin.authorHandle,
                    username: pin.authorHandle,
                    userAvatarURL: nil,
                    activityType: .visitedPlace,
                    relatedPinId: pin.id,
                    relatedPin: pin,
                    locationName: pin.locationName,
                    description: "\(pin.authorHandle) visited \(pin.locationName)",
                    createdAt: pin.createdAt
                )
                activities.append(activity)
            }
            
            return activities.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("❌ Failed to get friend activity near location: \(error)")
            return []
        }
    }
    
    /// Get friends currently at a location
    func getFriendsAtLocation(latitude: Double, longitude: Double, radius: Double) async -> [AppUser] {
        do {
            guard let session = try? await client.auth.session else { return [] }
            let currentUserID = session.user.id.uuidString
            
            let followingUsers = await getFollowingUsers(for: currentUserID)
            var friendsAtLocation: [AppUser] = []
            
            for friend in followingUsers {
                guard let friendLat = friend.latitude,
                      let friendLng = friend.longitude else {
                    continue
                }
                
                let friendLocation = CLLocation(latitude: friendLat, longitude: friendLng)
                let targetLocation = CLLocation(latitude: latitude, longitude: longitude)
                let distance = friendLocation.distance(from: targetLocation)
                
                if distance <= radius {
                    friendsAtLocation.append(friend)
                }
            }
            
            return friendsAtLocation.sorted { friend1, friend2 in
                guard let lat1 = friend1.latitude, let lng1 = friend1.longitude,
                      let lat2 = friend2.latitude, let lng2 = friend2.longitude else {
                    return false
                }
                
                let loc1 = CLLocation(latitude: lat1, longitude: lng1)
                let loc2 = CLLocation(latitude: lat2, longitude: lng2)
                let target = CLLocation(latitude: latitude, longitude: longitude)
                
                return target.distance(from: loc1) < target.distance(from: loc2)
            }
        } catch {
            print("❌ Failed to get friends at location: \(error)")
            return []
        }
    }
    
    /// Get social context for a location
    func getLocationSocialContext(latitude: Double, longitude: Double, radius: Double = 100) async -> LocationSocialContext {
        do {
            let nearbyPins = await getPinsNearLocation(latitude: latitude, longitude: longitude, radius: radius)
            
            let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let recentActivity = await getFriendActivityNearLocation(latitude: latitude, longitude: longitude, radius: radius, since: lastWeek)
            
            let friendsAtLocation = await getFriendsAtLocation(latitude: latitude, longitude: longitude, radius: radius)
            
            let totalVisits = nearbyPins.count
            let uniqueVisitors = Set(nearbyPins.map { $0.authorHandle }).count
            let averageRating = nearbyPins.compactMap { $0.starRating }.isEmpty ? 0.0 :
                nearbyPins.compactMap { $0.starRating }.reduce(0, +) / Double(nearbyPins.compactMap { $0.starRating }.count)
            
            let locationName = nearbyPins.first?.locationName ?? "Unknown Location"
            
            return LocationSocialContext(
                locationName: locationName,
                latitude: latitude,
                longitude: longitude,
                totalVisits: totalVisits,
                uniqueVisitors: uniqueVisitors,
                averageRating: averageRating,
                recentActivity: recentActivity,
                friendsCurrentlyHere: friendsAtLocation,
                lastVisit: nearbyPins.first?.createdAt,
                topReviews: nearbyPins.compactMap { $0.reviewText }.prefix(3).map { String($0) }
            )
        } catch {
            print("❌ Failed to get location social context: \(error)")
            return LocationSocialContext(
                locationName: "Unknown Location",
                latitude: latitude,
                longitude: longitude,
                totalVisits: 0,
                uniqueVisitors: 0,
                averageRating: 0.0,
                recentActivity: [],
                friendsCurrentlyHere: [],
                lastVisit: nil,
                topReviews: []
            )
        }
    }
    
    /// Create a proximity alert notification
    func createProximityNotification(to userID: String, from fromUserID: String, alertType: String, locationName: String?, distance: Double, additionalContext: [String: Any]? = nil) async -> Bool {
        do {
            let distanceString = distance < 1000 ? String(format: "%.0f m", distance) : String(format: "%.1f km", distance / 1000)
            
            var message = ""
            var title = ""
            
            switch alertType {
            case "friend_nearby":
                title = "Friend Nearby"
                message = "is \(distanceString) away"
            case "friend_at_location":
                title = "Friend at Location"
                message = "is at \(locationName ?? "a location you've been to")"
            case "friend_activity":
                title = "Friend Activity"
                message = "and others have been to \(locationName ?? "a nearby location") recently"
            default:
                title = "Proximity Alert"
                message = "is nearby"
            }
            
            var actionData: [String: Any] = [
                "action": "view_friend_location",
                "friendId": fromUserID,
                "alertType": alertType,
                "distance": distance
            ]
            
            if let locationName = locationName {
                actionData["locationName"] = locationName
            }
            
            if let additionalContext = additionalContext {
                actionData = actionData.merging(additionalContext) { (_, new) in new }
            }
            
            let actionDataString = try JSONSerialization.data(withJSONObject: actionData)
            let actionDataJSON = String(data: actionDataString, encoding: .utf8) ?? "{}"
            
            struct ProximityNotificationData: Codable {
                let user_id: String
                let type: String
                let title: String
                let message: String
                let from_user_id: String
                let action_data: String
                let priority: String
                let created_at: String
            }
            
            let notificationData = ProximityNotificationData(
                user_id: userID,
                type: alertType,
                title: title,
                message: message,
                from_user_id: fromUserID,
                action_data: actionDataJSON,
                priority: "normal",
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to create proximity notification: \(error)")
            return false
        }
    }
    
    /// Update user's current location for proximity alerts
    func updateUserLocationForProximity(latitude: Double, longitude: Double, isAvailable: Bool = true) async -> Bool {
        do {
            guard let session = try? await client.auth.session else { return false }
            let currentUserID = session.user.id.uuidString
            
            try await client
                .from("users")
                .update([
                    "latitude": latitude,
                    "longitude": longitude,
                    "last_active": Date().timeIntervalSince1970
                ])
                .eq("id", value: currentUserID)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to update user location for proximity: \(error)")
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    private func getFollowingUsers(for userID: String) async -> [AppUser] {
        do {
            struct FollowResponse: Codable {
                let following_id: String
            }
            
            let follows: [FollowResponse] = try await client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: userID)
                .execute()
                .value
            
            let followingIds = follows.map { $0.following_id }
            if followingIds.isEmpty { return [] }
            
            let basicUsers: [BasicUser] = try await client
                .from("users")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .in("id", values: followingIds)
                .execute()
                .value
            
            return basicUsers.map { $0.toAppUser(currentUserID: userID) }
        } catch {
            print("❌ Failed to fetch following users: \(error)")
            return []
        }
    }
}
