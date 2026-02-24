//
//  LocationPrivacyService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation

class LocationPrivacyService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Save location privacy settings to database
    func saveLocationPrivacySettings(_ settings: LocationPrivacySettings) async throws {
        guard (try? await client.auth.session) != nil else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let insert = LocationPrivacySettingsInsert(
            user_id: settings.userID,
            share_location_with_friends: settings.shareLocationWithFriends,
            share_location_with_followers: settings.shareLocationWithFollowers,
            share_location_publicly: settings.shareLocationPublicly,
            share_location_history: settings.shareLocationHistory,
            location_accuracy_level: settings.locationAccuracyLevel,
            auto_delete_history_days: settings.autoDeleteHistoryDays,
            allow_location_requests: settings.allowLocationRequests
        )
        
        try await client
            .from("location_privacy_settings")
            .upsert(insert)
            .execute()
        
        print("✅ Location privacy settings saved to database")
    }
    
    /// Load location privacy settings from database
    func loadLocationPrivacySettings(for userID: String) async -> LocationPrivacySettings? {
        do {
            let settings: LocationPrivacySettings = try await client
                .from("location_privacy_settings")
                .select("*")
                .eq("user_id", value: userID)
                .single()
                .execute()
                .value
            
            return settings
        } catch {
            print("❌ Failed to load location privacy settings: \(error)")
            return LocationPrivacySettings(userID: userID)
        }
    }
    
    /// Check if a user can see another user's location based on privacy settings
    func canUserSeeLocation(viewerID: String, targetUserID: String) async -> Bool {
        if viewerID == targetUserID {
            return true
        }
        
        guard let privacySettings = await loadLocationPrivacySettings(for: targetUserID) else {
            return false
        }
        
        if privacySettings.shareLocationPublicly {
            return true
        }
        
        if privacySettings.shareLocationWithFollowers {
            let isFollowing = await isUserFollowing(followerID: viewerID, followeeID: targetUserID)
            if isFollowing {
                return true
            }
        }
        
        if privacySettings.shareLocationWithFriends {
            let areMutualFriends = await areMutualFriends(user1: viewerID, user2: targetUserID)
            if areMutualFriends {
                return true
            }
        }
        
        return false
    }
    
    /// Apply location accuracy level to coordinates
    func applyLocationAccuracy(
        latitude: Double,
        longitude: Double,
        accuracyLevel: LocationAccuracyLevel
    ) -> (latitude: Double?, longitude: Double?, locationName: String?) {
        switch accuracyLevel {
        case .exact:
            return (latitude, longitude, nil)
            
        case .approximate:
            let latOffset = Double.random(in: -0.009...0.009)
            let lonOffset = Double.random(in: -0.009...0.009)
            return (latitude + latOffset, longitude + lonOffset, nil)
            
        case .cityOnly:
            return (nil, nil, getCityName(latitude: latitude, longitude: longitude))
            
        case .hidden:
            return (nil, nil, nil)
        }
    }
    
    /// Save location history entry with privacy controls
    func saveLocationHistory(
        userID: String,
        latitude: Double,
        longitude: Double,
        locationName: String?,
        activityType: String = "unknown"
    ) async throws {
        guard let privacySettings = await loadLocationPrivacySettings(for: userID),
              privacySettings.shareLocationHistory else {
            print("📍 Location history disabled for user")
            return
        }
        
        let insert = LocationHistoryInsert(
            user_id: userID,
            latitude: latitude,
            longitude: longitude,
            accuracy: nil,
            altitude: nil,
            speed: nil,
            heading: nil,
            location_name: locationName,
            city: getCityName(latitude: latitude, longitude: longitude),
            country: "US",
            is_manual: false,
            activity_type: activityType
        )
        
        try await client
            .from("location_history")
            .insert(insert)
            .execute()
        
        print("✅ Location history saved")
    }
    
    /// Delete old location history based on auto-delete settings
    func cleanupLocationHistory(for userID: String) async {
        guard let privacySettings = await loadLocationPrivacySettings(for: userID) else {
            return
        }
        
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -privacySettings.autoDeleteHistoryDays,
            to: Date()
        ) ?? Date()
        
        do {
            try await client
                .from("location_history")
                .delete()
                .eq("user_id", value: userID)
                .lt("created_at", value: ISO8601DateFormatter().string(from: cutoffDate))
                .execute()
            
            print("✅ Old location history cleaned up")
        } catch {
            print("❌ Failed to cleanup location history: \(error)")
        }
    }
    
    /// Store user's public key for end-to-end encryption
    func storeUserPublicKey(userID: String, publicKey: String) async throws {
        let insert = UserPublicKeyDB(
            user_id: userID,
            public_key: publicKey,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("user_public_keys")
            .upsert(insert)
            .execute()
        
        print("✅ [Encryption] Public key stored for user: \(userID)")
    }
    
    /// Retrieve user's public key for end-to-end encryption
    func getUserPublicKey(userID: String) async throws -> String? {
        let response: [UserPublicKeyDB] = try await client
            .from("user_public_keys")
            .select("public_key")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value
        
        return response.first?.public_key
    }
    
    /// Share encrypted locations with friends
    func shareEncryptedLocations(_ encryptedLocations: [EncryptedLocation]) async throws {
        let locationInserts = encryptedLocations.map { location in
            SharedLocationDB(
                id: location.id.uuidString,
                created_at: ISO8601DateFormatter().string(from: Date()),
                sender_user_id: location.senderId.uuidString,
                recipient_user_id: location.recipientId.uuidString,
                ciphertext: location.encryptedData,
                nonce: "",
                tag: "",
                expires_at: ISO8601DateFormatter().string(from: location.expiresAt)
            )
        }
        
        try await client
            .from("shared_locations")
            .insert(locationInserts)
            .execute()
        
        print("✅ [Encryption] Shared \(encryptedLocations.count) encrypted locations")
    }
    
    /// Create a friend group
    func createFriendGroup(name: String, userId: String, sharingTier: SharingTier) async throws -> FriendGroup {
        let groupId = UUID().uuidString
        let groupInsert = FriendGroupDB(
            id: groupId,
            user_id: userId,
            name: name,
            sharing_tier: sharingTier.rawValue,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("friend_groups")
            .insert(groupInsert)
            .execute()
        
        return groupInsert.toFriendGroup()
    }
    
    /// Add member to friend group
    func addMemberToFriendGroup(groupId: String, memberUserId: String) async throws {
        let memberInsert = FriendGroupMemberDB(
            group_id: groupId,
            member_user_id: memberUserId,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("friend_group_members")
            .insert(memberInsert)
            .execute()
    }
    
    /// Get active shared locations for a user
    func getActiveSharedLocations(for userId: String) async throws -> [SharedLocation] {
        let sharedLocationDBs: [SharedLocationDB] = try await client
            .from("shared_locations")
            .select("*")
            .eq("recipient_user_id", value: userId)
            .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
            .execute()
            .value
        
        return sharedLocationDBs.map { $0.toSharedLocation() }
    }
    
    /// Get friend groups for a user
    func getFriendGroups(for userId: String) async throws -> [FriendGroup] {
        let friendGroupDBs: [FriendGroupDB] = try await client
            .from("friend_groups")
            .select("*")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        var friendGroups: [FriendGroup] = []
        
        for groupDB in friendGroupDBs {
            let members: [FriendGroupMemberDB] = try await client
                .from("friend_group_members")
                .select("*")
                .eq("group_id", value: groupDB.id)
                .execute()
                .value
            
            var friendGroup = groupDB.toFriendGroup()
            friendGroup.memberIds = members.map { UUID(uuidString: $0.member_user_id) ?? UUID() }
            friendGroups.append(friendGroup)
        }
        
        return friendGroups
    }
    
    // MARK: - Private Helpers
    
    private func isUserFollowing(followerID: String, followeeID: String) async -> Bool {
        do {
            let follows: [FollowDB] = try await client
                .from("follows")
                .select("*")
                .eq("follower_id", value: followerID)
                .eq("following_id", value: followeeID)
                .limit(1)
                .execute()
                .value
            
            return !follows.isEmpty
        } catch {
            print("❌ Failed to check follow status: \(error)")
            return false
        }
    }
    
    private func areMutualFriends(user1: String, user2: String) async -> Bool {
        let user1FollowsUser2 = await isUserFollowing(followerID: user1, followeeID: user2)
        let user2FollowsUser1 = await isUserFollowing(followerID: user2, followeeID: user1)
        return user1FollowsUser2 && user2FollowsUser1
    }
    
    private func getCityName(latitude: Double, longitude: Double) -> String {
        return "City"
    }
}
