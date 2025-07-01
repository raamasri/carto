//
//  SupabaseManager.swift
//  Project Columbus
//
//  Created by raama srivatsan on 4/17/25.
//

import Supabase
import Foundation
import CryptoKit
import SwiftUI
import UserNotifications

// MARK: - Legacy Database Models (to be removed after migration)
struct PinCollectionDB: Codable {
    let id: String?
    let name: String
    let user_id: String
    let created_at: String
}

struct PinCollectionItemDB: Codable {
    let collection_id: String
    let pin_id: String
    let created_at: String
}

struct FollowDB: Codable {
    let follower_id: String
    let following_id: String
    let created_at: String
    
    enum CodingKeys: String, CodingKey {
        case follower_id
        case following_id
        case created_at
    }
}

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    let baseURL: URL
    
    let client: SupabaseClient

    private init() {
        // Load credentials from secure configuration
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: configPath),
              let urlString = config["SupabaseURL"] as? String,
              let key = config["SupabaseKey"] as? String,
              let supabaseUrl = URL(string: urlString) else {
            fatalError("Failed to load Supabase configuration. Please ensure Config.plist exists with SupabaseURL and SupabaseKey.")
        }
        
        self.baseURL = supabaseUrl
        
        self.client = SupabaseClient(
            supabaseURL: supabaseUrl,
            supabaseKey: key
        )
    }

    // MARK: - Apple Sign In Integration
    
    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        return try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
    }

    // MARK: - Lists Management (NEW SCHEMA)
    
    /// Creates a new list for the user
    func createList(name: String) async throws -> String {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let list = ["user_id": session.user.id.uuidString, "name": name]
        
        let response: [ListDB] = try await client
            .from("lists")
            .insert(list)
            .select()
            .execute()
            .value
        
        return response.first?.id ?? ""
    }
    
    /// Fetches all lists for the current user
    func getUserLists() async -> [PinList] {
        print("📱 SupabaseManager: getUserLists() called")
        
        guard let session = try? await client.auth.session else { 
            print("❌ SupabaseManager: No session available in getUserLists()")
            return [] 
        }
        
        print("📱 SupabaseManager: Session found, user ID: \(session.user.id.uuidString)")
        
        do {
            let listsDB: [ListDB] = try await client
                .from("lists")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
                .value
            
            print("📱 SupabaseManager: Found \(listsDB.count) lists in database")
            
            var lists: [PinList] = []
            
            // Fetch pins for each list
            for listDB in listsDB {
                print("📱 SupabaseManager: Processing list: \(listDB.name)")
                let pins = await getPinsForList(listId: listDB.id)
                print("📱 SupabaseManager: List '\(listDB.name)' has \(pins.count) pins")
                let list = listDB.toPinList(pins: pins)
                lists.append(list)
            }
            
            print("📱 SupabaseManager: Returning \(lists.count) lists")
            return lists
        } catch {
            print("❌ Failed to fetch lists: \(error)")
            return []
        }
    }
    
    /// Fetches all lists for a specific user
    func getUserLists(for userID: String) async -> [PinList] {
        do {
            let listsDB: [ListDB] = try await client
                .from("lists")
                .select("*")
                .eq("user_id", value: userID)
                .execute()
                .value
            
            var lists: [PinList] = []
            
            // Fetch pins for each list
            for listDB in listsDB {
                let pins = await getPinsForList(listId: listDB.id)
                let list = listDB.toPinList(pins: pins)
                lists.append(list)
            }
            
            return lists
        } catch {
            print("❌ Failed to fetch lists for user \(userID): \(error)")
            return []
        }
    }
    
    /// Deletes a list
    func deleteList(listId: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            _ = try await client
                .from("lists")
                .delete()
                .eq("id", value: listId)
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to delete list: \(error)")
            return false
        }
    }

    // MARK: - Pins Management (NEW SCHEMA)
    
    /// Creates a new pin in the database
    func createPin(pin: Pin) async throws -> String {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let pinInsert = pin.toPinDB(userId: session.user.id.uuidString)
        
        let response: [PinDB] = try await client
            .from("pins")
            .insert(pinInsert)
            .select()
            .execute()
            .value
        
        return response.first?.id ?? ""
    }
    
    /// Fetches pins for a specific list
    func getPinsForList(listId: String) async -> [Pin] {
        do {
            let listPins: [ListPinDB] = try await client
                .from("list_pins")
                .select("*")
                .eq("list_id", value: listId)
                .execute()
                .value
            
            let pinIds = listPins.map { $0.pin_id }
            if pinIds.isEmpty { return [] }
            
            let pinsDB: [PinDB] = try await client
                .from("pins")
                .select("*")
                .in("id", value: pinIds)
                .execute()
                .value
            
            return pinsDB.map { $0.toPin() }
        } catch {
            print("❌ Failed to fetch pins for list: \(error)")
            return []
        }
    }
    
    /// Fetches all pins for the current user
    func getAllUserPins() async -> [Pin] {
        guard let session = try? await client.auth.session else { return [] }
        
        do {
            let pinsDB: [PinDB] = try await client
                .from("pins")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
                .value
            
            return pinsDB.map { $0.toPin() }
        } catch {
            print("❌ Failed to fetch user pins: \(error)")
            return []
        }
    }
    
    /// Checks if a pin exists in the database (by coordinates and location name)
    func findExistingPin(pin: Pin) async -> String? {
        guard let session = try? await client.auth.session else { return nil }
        
        do {
            let existingPins: [PinDB] = try await client
                .from("pins")
                .select("id")
                .eq("user_id", value: session.user.id.uuidString)
                .eq("location_name", value: pin.locationName)
                .eq("latitude", value: pin.latitude)
                .eq("longitude", value: pin.longitude)
                .limit(1)
                .execute()
                .value
            
            return existingPins.first?.id
        } catch {
            print("❌ Failed to find existing pin: \(error)")
            return nil
        }
    }

    // MARK: - List-Pin Associations (NEW SCHEMA)
    
    /// Adds a pin to a list by listId (creates pin if it doesn't exist)
    func addPinToListById(pin: Pin, listId: String) async -> Bool {
        do {
            // Find or create the pin
            var pinId = await findExistingPin(pin: pin)
            if pinId == nil {
                pinId = try await createPin(pin: pin)
            }
            guard let finalPinId = pinId else { return false }
            // Check if already associated
            if await isPinInList(pinId: finalPinId, listId: listId) {
                print("ℹ️ Pin already in list with id '", listId, "'")
                return true
            }
            // Create association
            let listPin = ["list_id": listId, "pin_id": finalPinId]
            _ = try await client
                .from("list_pins")
                .insert(listPin)
                .execute()
            return true
        } catch {
            print("❌ Failed to add pin to list by id: \(error)")
            return false
        }
    }

    /// Removes a pin from a list by listId
    func removePinFromListById(pin: Pin, listId: String) async -> Bool {
        do {
            let pinId = await findExistingPin(pin: pin)
            guard let finalPinId = pinId else { return false }
            _ = try await client
                .from("list_pins")
                .delete()
                .eq("list_id", value: listId)
                .eq("pin_id", value: finalPinId)
                .execute()
            return true
        } catch {
            print("❌ Failed to remove pin from list by id: \(error)")
            return false
        }
    }
    
    /// Checks if a pin is already in a list
    private func isPinInList(pinId: String, listId: String) async -> Bool {
        do {
            let existing: [ListPinDB] = try await client
                .from("list_pins")
                .select("*")
                .eq("list_id", value: listId)
                .eq("pin_id", value: pinId)
                .limit(1)
                .execute()
                .value
            
            return !existing.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Private List Helpers
    
    private func getOrCreateList(name: String) async throws -> String {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Try to find existing list
        let existing: [ListDB] = try await client
            .from("lists")
            .select("id")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("name", value: name)
            .limit(1)
            .execute()
            .value
        
        if let existingList = existing.first {
            return existingList.id
        }
        
        // Create new list if it doesn't exist
        return try await createList(name: name)
    }

    // MARK: - Legacy Collections Management (DEPRECATED - For backward compatibility)
    
    /// Creates a new collection for the user (DEPRECATED)
    @available(*, deprecated, message: "Use createList(name:) instead")
    func createCollection(name: String) async throws -> String {
        return try await createList(name: name)
    }
    
    /// Fetches all collections for the current user (DEPRECATED)
    @available(*, deprecated, message: "Use getUserLists() instead")
    func getUserCollections() async -> [PinList] {
        return await getUserLists()
    }
    
    /// Adds a pin to a specific collection (DEPRECATED)
    @available(*, deprecated, message: "Use addPinToList(pin:listName:) instead")
    func addPinToCollection(pin: Pin, collectionName: String) async -> Bool {
        return await addPinToList(pin: pin, listName: collectionName)
    }
    
    /// Removes a pin from a collection (DEPRECATED)
    @available(*, deprecated, message: "Use removePinFromList(pin:listName:) instead")
    func removePinFromCollection(pin: Pin, collectionName: String) async -> Bool {
        return await removePinFromList(pin: pin, listName: collectionName)
    }

    // MARK: - User Management
    
    /// Check if username is available
    func isUsernameAvailable(username: String) async -> Bool {
        do {
            let existing: [AppUser] = try await client
                .from("users")
                .select("id")
                .eq("username", value: username)
                .limit(1)
                .execute()
                .value
            
            return existing.isEmpty
        } catch {
            print("❌ Failed to check username availability: \(error)")
            return false
        }
    }
    
    /// Get following users
    func getFollowingUsers(for userID: String) async -> [AppUser] {
        do {
            print("🔄 SupabaseManager: Getting following users for \(userID)")
            
            // Create a simple struct for the response
            struct FollowResponse: Codable {
                let following_id: String
            }
            
            // Get the follow relationships where the user is the follower
            let follows: [FollowResponse] = try await client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: userID)
                .execute()
                .value
            
            print("📊 Found \(follows.count) follow relationships")
            
            let followingIds = follows.map { $0.following_id }
            if followingIds.isEmpty { 
                print("❌ No following relationships found")
                return [] 
            }
            
            print("👥 Getting user details for IDs: \(followingIds)")
            
            // Get the user details for all following users
            let basicUsers: [BasicUser] = try await client
                .from("users")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .in("id", value: followingIds)
                .execute()
                .value
            
            let followingUsers = basicUsers.map { $0.toAppUser(currentUserID: userID) }
            
            print("✅ Retrieved \(followingUsers.count) following users")
            for user in followingUsers {
                print("  - \(user.full_name) (@\(user.username)) ID: \(user.id)")
            }
            
            return followingUsers
        } catch {
            print("❌ Failed to fetch following users: \(error)")
            return []
        }
    }
    
    /// Fetch all users (excluding blocked users)
    func fetchAllUsers() async throws -> [AppUser] {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let basicUsers: [BasicUser] = try await client
            .from("users")
            .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
            .execute()
            .value
        
        // Filter out blocked users
        let blockedUsers = await getBlockedUsers()
        let blockedIds = Set(blockedUsers.map { $0.id })
        
        return basicUsers
            .filter { !blockedIds.contains($0.id) }
            .map { $0.toAppUser(currentUserID: session.user.id.uuidString) }
    }
    
    /// Update user location
    func updateUserLocation(userID: String, latitude: Double, longitude: Double) async {
        do {
            _ = try await client
                .from("users")
                .update(["latitude": latitude, "longitude": longitude])
                .eq("id", value: userID)
                .execute()
        } catch {
            print("❌ Failed to update user location: \(error)")
        }
    }
    
    /// Fetch user profile
    func fetchUserProfile(userID: String) async -> AppUser? {
        do {
            let basicUser: BasicUser = try await client
                .from("users")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            
            return basicUser.toAppUser()
        } catch {
            print("❌ Failed to fetch user profile: \(error)")
            return nil
        }
    }
    
    /// Update user profile
    func updateUserProfile(userID: String, username: String, fullName: String, email: String, bio: String, avatarURL: String) async throws {
        _ = try await client
            .from("users")
            .update([
                "username": username,
                "full_name": fullName,
                "email": email,
                "bio": bio,
                "avatar_url": avatarURL
            ])
            .eq("id", value: userID)
            .execute()
    }
    
    /// Follow a user
    func followUser(followingID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            let follow = FollowDB(
                follower_id: session.user.id.uuidString,
                following_id: followingID.uuidString,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            _ = try await client
                .from("follows")
                .insert(follow)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to follow user: \(error)")
            return false
        }
    }
    
    /// Unfollow a user
    func unfollowUser(followingID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            _ = try await client
                .from("follows")
                .delete()
                .eq("follower_id", value: session.user.id.uuidString)
                .eq("following_id", value: followingID.uuidString)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to unfollow user: \(error)")
            return false
        }
    }
    
    /// Check if following a user
    func isFollowing(userID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            let follows: [FollowDB] = try await client
                .from("follows")
                .select("*")
                .eq("follower_id", value: session.user.id.uuidString)
                .eq("following_id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value
            
            return !follows.isEmpty
        } catch {
            print("❌ Failed to check follow status: \(error)")
            return false
        }
    }
    
    /// Toggle follow status for a user by their string ID, returning true if now following.
    func toggleFollowForUser(with userID: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }

        guard let targetUUID = UUID(uuidString: userID) else { return false }

        let isCurrentlyFollowing = await isFollowing(userID: targetUUID)

        if isCurrentlyFollowing {
            return await unfollowUser(followingID: targetUUID)
        } else {
            return await followUser(followingID: targetUUID)
        }
    }
    
    /// Check if a follow request has been sent to a user
    func hasFollowRequestSent(to userID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            // Check if there's an active follow request notification
            struct NotificationCheck: Codable {
                let id: String
            }
            
            let notifications: [NotificationCheck] = try await client
                .from("notifications")
                .select("id")
                .eq("user_id", value: userID.uuidString)
                .eq("from_user_id", value: session.user.id.uuidString)
                .eq("type", value: "follow_request")
                .eq("is_read", value: false)
                .limit(1)
                .execute()
                .value
            
            return !notifications.isEmpty
        } catch {
            print("❌ Failed to check follow request status: \(error)")
            return false
        }
    }
    
    /// Get followers for a user
    func getFollowers(for userID: String) async throws -> [AppUser] {
        do {
            // Get the follow relationships where the target user is being followed
            let follows: [FollowDB] = try await client
                .from("follows")
                .select("follower_id")
                .eq("following_id", value: userID)
                .execute()
                .value
            
            let followerIds = follows.map { $0.follower_id }
            if followerIds.isEmpty { return [] }
            
            // Get the user details for all followers
            let basicUsers: [BasicUser] = try await client
                .from("users")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .in("id", value: followerIds)
                .execute()
                .value
            
            return basicUsers.map { $0.toAppUser() }
        } catch {
            print("❌ Failed to fetch followers: \(error)")
            return []
        }
    }

    /// Search for users by username or full name
    func searchUsers(query: String) async -> [AppUser] {
        do {
            let searchTerm = query.replacingOccurrences(of: "@", with: "").lowercased()
            
            let basicUsers: [BasicUser] = try await client
                .from("user_search_view")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .or("username.ilike.%\(searchTerm)%,full_name.ilike.%\(searchTerm)%")
                .limit(20)
                .execute()
                .value
            
            return basicUsers.map { $0.toAppUser() }
        } catch {
            print("❌ Failed to search users: \(error)")
            // Fallback to regular users table if view doesn't exist
            do {
                let searchTerm = query.replacingOccurrences(of: "@", with: "").lowercased()
                
                let basicUsers: [BasicUser] = try await client
                    .from("users")
                    .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                    .or("username.ilike.%\(searchTerm)%,full_name.ilike.%\(searchTerm)%")
                    .limit(20)
                    .execute()
                    .value
                
                return basicUsers.map { $0.toAppUser() }
            } catch {
                print("❌ Failed to search users (fallback): \(error)")
                return []
            }
        }
    }
    
    /// Get public pins from all users for discovery feed
    func getPublicPins(limit: Int = 50) async -> [Pin] {
        do {
            let pinsDB: [PinDB] = try await client
                .from("pins")
                .select("*")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            return pinsDB.map { $0.toPin() }
        } catch {
            print("❌ Failed to fetch public pins: \(error)")
            return []
        }
    }
    
    /// Get pins from users that the current user follows
    func getFeedPins(for userID: String, limit: Int = 50) async -> [Pin] {
        do {
            // First get the users that this user follows
            let followingUsers = await getFollowingUsers(for: userID)
            let followingIds = followingUsers.map { $0.id }
            
            if followingIds.isEmpty { return [] }
            
            // Get pins from those users
            let pinsDB: [PinDB] = try await client
                .from("pins")
                .select("*")
                .in("user_id", value: followingIds)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            return pinsDB.map { $0.toPin() }
        } catch {
            print("❌ Failed to fetch feed pins: \(error)")
            return []
        }
    }

    @available(*, deprecated, message: "Use addPinToListById(pin:listId:) instead")
    func addPinToList(pin: Pin, listName: String) async -> Bool {
        let lists = await getUserLists()
        if let list = lists.first(where: { $0.name.lowercased() == listName.lowercased() }) {
            return await addPinToListById(pin: pin, listId: list.id.uuidString)
        }
        return false
    }

    @available(*, deprecated, message: "Use removePinFromListById(pin:listId:) instead")
    func removePinFromList(pin: Pin, listName: String) async -> Bool {
        let lists = await getUserLists()
        if let list = lists.first(where: { $0.name.lowercased() == listName.lowercased() }) {
            return await removePinFromListById(pin: pin, listId: list.id.uuidString)
        }
        return false
    }

    // MARK: - Enhanced Notification Management
    
    /// Send a follow request notification
    func sendFollowRequestNotification(to userID: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            // Create a proper codable structure for the notification
            struct FollowRequestNotificationData: Codable {
                let user_id: String
                let from_user_id: String
                let type: String
            }
            
            let notificationData = FollowRequestNotificationData(
                user_id: userID,
                from_user_id: session.user.id.uuidString,
                type: "follow_request"
            )
            
            _ = try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to send follow request notification: \(error)")
            return false
        }
    }
    
    /// Send a pin recommendation notification
    func sendPinRecommendationNotification(pinID: String, to userID: String, message: String? = nil) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            // Create a proper codable structure for the notification
            struct NotificationData: Codable {
                let user_id: String
                let from_user_id: String
                let type: String
                let pin_id: String
                let message: String?
            }
            
            let notificationData = NotificationData(
                user_id: userID,
                from_user_id: session.user.id.uuidString,
                type: "pin_recommendation",
                pin_id: pinID,
                message: message
            )
            
            _ = try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to send pin recommendation notification: \(error)")
            return false
        }
    }
    
    /// Mark notification as read
    func markNotificationAsRead(notificationID: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            // Create a proper codable structure for the update
            struct NotificationUpdate: Codable {
                let is_read: Bool
            }
            
            let updateData = NotificationUpdate(is_read: true)
            
            _ = try await client
                .from("notifications")
                .update(updateData)
                .eq("id", value: notificationID)
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to mark notification as read: \(error)")
            return false
        }
    }
    
    /// Get unread notification count
    func getUnreadNotificationCount() async -> Int {
        guard let session = try? await client.auth.session else { return 0 }
        
        do {
            let count: Int = try await client
                .from("notifications")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: session.user.id.uuidString)
                .eq("is_read", value: false)
                .execute()
                .count ?? 0
            
            return count
        } catch {
            print("❌ Failed to get unread notification count: \(error)")
            return 0
        }
    }
    
    // MARK: - User Blocking & Reporting
    
    /// Block a user
    func blockUser(userID: String, reason: String? = nil) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct BlockData: Codable {
                let blocker_id: String
                let blocked_id: String
                let reason: String?
                let block_type: String
            }
            
            let blockData = BlockData(
                blocker_id: session.user.id.uuidString,
                blocked_id: userID,
                reason: reason,
                block_type: "block"
            )
            
            _ = try await client
                .from("user_blocks")
                .insert(blockData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to block user: \(error)")
            return false
        }
    }
    
    /// Report a user
    func reportUser(userID: String, reason: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct ReportData: Codable {
                let blocker_id: String
                let blocked_id: String
                let reason: String
                let block_type: String
            }
            
            let reportData = ReportData(
                blocker_id: session.user.id.uuidString,
                blocked_id: userID,
                reason: reason,
                block_type: "report"
            )
            
            _ = try await client
                .from("user_blocks")
                .insert(reportData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to report user: \(error)")
            return false
        }
    }
    
    /// Unblock a user
    func unblockUser(userID: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            _ = try await client
                .from("user_blocks")
                .delete()
                .eq("blocker_id", value: session.user.id.uuidString)
                .eq("blocked_id", value: userID)
                .eq("block_type", value: "block")
                .execute()
            
            return true
        } catch {
            print("❌ Failed to unblock user: \(error)")
            return false
        }
    }
    
    /// Check if a user is blocked
    func isUserBlocked(userID: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct BlockCheck: Codable {
                let id: String
            }
            
            let blocks: [BlockCheck] = try await client
                .from("user_blocks")
                .select("id")
                .eq("blocker_id", value: session.user.id.uuidString)
                .eq("blocked_id", value: userID)
                .eq("block_type", value: "block")
                .limit(1)
                .execute()
                .value
            
            return !blocks.isEmpty
        } catch {
            print("❌ Failed to check block status: \(error)")
            return false
        }
    }
    
    /// Get blocked users
    func getBlockedUsers() async -> [AppUser] {
        guard let session = try? await client.auth.session else { return [] }
        
        do {
            struct BlockedUserData: Codable {
                let blocked_id: String
                let users: BasicUser
            }
            
            let blockedData: [BlockedUserData] = try await client
                .from("user_blocks")
                .select("blocked_id, users!user_blocks_blocked_id_fkey(id, username, full_name, email, bio, latitude, longitude, avatar_url)")
                .eq("blocker_id", value: session.user.id.uuidString)
                .eq("block_type", value: "block")
                .execute()
                .value
            
            return blockedData.map { $0.users.toAppUser() }
        } catch {
            print("❌ Failed to fetch blocked users: \(error)")
            return []
        }
    }
    
    // MARK: - Messaging Functions
    
    /// Get all conversations for the current user
    func getUserConversations() async -> [Conversation] {
        guard let session = try? await client.auth.session else { return [] }
        
        do {
            // Call our custom function to get conversations with details
            let conversationDetails: [ConversationDetailDB] = try await client
                .rpc("get_user_conversations", params: ["user_uuid": session.user.id])
                .execute()
                .value
            
            var conversations: [Conversation] = []
            
            // Convert each conversation detail to Conversation object
            for conversationDetail in conversationDetails {
                print("🔄 Processing conversation: \(conversationDetail.conversation_id)")
                print("  - Last message content: \(conversationDetail.last_message_content ?? "nil")")
                print("  - Last message sender: \(conversationDetail.last_message_sender_id ?? "nil")")
                print("  - Last message time: \(conversationDetail.last_message_created_at ?? "nil")")
                
                // Create AppUser objects for participants
                let participants = zip(zip(conversationDetail.participant_ids, conversationDetail.participant_usernames), conversationDetail.participant_full_names).map { (idUsername, fullName) in
                    let (id, username) = idUsername
                    return AppUser(
                        id: id,
                        username: username,
                        full_name: fullName,
                        email: nil,
                        bio: nil,
                        follower_count: 0,
                        following_count: 0,
                        isFollowedByCurrentUser: false,
                        latitude: nil,
                        longitude: nil,
                        isCurrentUser: false,
                        avatarURL: nil
                    )
                }
                
                // Create conversation title
                let title: String
                if conversationDetail.is_group {
                    if let groupName = conversationDetail.conversation_name {
                        title = groupName
                    } else {
                        let names = participants.prefix(2).map { $0.full_name }
                        title = names.joined(separator: ", ") + (participants.count > 2 ? "..." : "")
                    }
                } else {
                    // Direct conversation - show the other person's name (not current user)
                    let currentUserId = session.user.id.uuidString.lowercased()
                    if let otherUser = participants.first(where: { $0.id.lowercased() != currentUserId }) {
                        title = otherUser.full_name
                    } else {
                        title = "Direct Message"
                    }
                }
                
                // Convert to Conversation object
                let conversation = conversationDetail.toConversation(with: participants, title: title)
                print("✅ Created conversation with title: '\(conversation.title)'")
                print("  - Last message: \(conversation.lastMessage?.content ?? "nil")")
                conversations.append(conversation)
            }
            
            return conversations
        } catch {
            print("❌ Failed to fetch user conversations: \(error)")
            return []
        }
    }
    
    /// Get messages for a specific conversation
    func getConversationMessages(conversationId: String, limit: Int = 50, offset: Int = 0) async -> [Message] {
        guard let session = try? await client.auth.session else { 
            print("❌ No session found for getting messages")
            return [] 
        }
        
        print("📥 SupabaseManager: Getting messages for conversation: \(conversationId)")
        print("  - Requesting user: \(session.user.id.uuidString)")
        
        do {
            // Create parameters with proper typing
            struct MessageParams: Codable {
                let conversation_uuid: String
                let requesting_user_id: String
                let limit_count: Int
                let offset_count: Int
            }
            
            let params = MessageParams(
                conversation_uuid: conversationId,
                requesting_user_id: session.user.id.uuidString,
                limit_count: limit,
                offset_count: offset
            )
            
            // Call our custom function to get messages
            let messageDetails: [MessageDetailDB] = try await client
                .rpc("get_conversation_messages", params: params)
                .execute()
                .value
            
            print("📥 SupabaseManager: Retrieved \(messageDetails.count) message details")
            for detail in messageDetails {
                print("  - Message from \(detail.sender_id): \(detail.content)")
            }
            
            return messageDetails.map { messageDetail in
                var message = messageDetail.toMessage()
                message = Message(
                    id: message.id,
                    conversationId: conversationId,
                    senderId: message.senderId,
                    content: message.content,
                    createdAt: message.createdAt,
                    messageType: message.messageType
                )
                return message
            }
        } catch {
            print("❌ Failed to fetch conversation messages: \(error)")
            return []
        }
    }
    
    /// Send a message to a conversation
    func sendMessage(conversationId: String, content: String, messageType: MessageType = .text) async -> Bool {
        guard let session = try? await client.auth.session else { 
            print("❌ No session found for sending message")
            return false 
        }
        
        print("📤 SupabaseManager: Sending message")
        print("  - Conversation ID: \(conversationId)")
        print("  - Sender ID: \(session.user.id.uuidString)")
        print("  - Content: \(content)")
        print("  - Type: \(messageType.rawValue)")
        
        do {
            // Call our custom function to send message
            let messageId: String = try await client
                .rpc("send_message", params: [
                    "conversation_uuid": conversationId,
                    "sender_uuid": session.user.id.uuidString,
                    "message_content": content,
                    "msg_type": messageType.rawValue
                ])
                .execute()
                .value
            
            print("✅ SupabaseManager: Message sent with ID: \(messageId)")
            return !messageId.isEmpty
        } catch {
            print("❌ Failed to send message: \(error)")
            return false
        }
    }
    
    /// Create a new conversation with specific users
    func createConversation(with userIds: [String], isGroup: Bool = false, name: String? = nil) async -> String? {
        guard let session = try? await client.auth.session else { return nil }
        
        do {
            // Include current user in participants
            var allParticipants = [session.user.id.uuidString]
            allParticipants.append(contentsOf: userIds)
            
            // Create parameters with proper typing
            struct ConversationParams: Codable {
                let participant_ids: [String]
                let is_group_chat: Bool
                let conversation_name: String?
            }
            
            let params = ConversationParams(
                participant_ids: allParticipants,
                is_group_chat: isGroup,
                conversation_name: name
            )
            
            // Call our custom function to create conversation
            let conversationId: String = try await client
                .rpc("create_conversation", params: params)
                .execute()
                .value
            
            return conversationId
        } catch {
            print("❌ Failed to create conversation: \(error)")
            return nil
        }
    }
    
    /// Mark a conversation as read
    func markConversationAsRead(conversationId: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            // Create parameters with proper typing
            struct MarkReadParams: Codable {
                let conversation_uuid: String
                let user_uuid: String
            }
            
            let params = MarkReadParams(
                conversation_uuid: conversationId,
                user_uuid: session.user.id.uuidString
            )
            
            // Call our custom function to mark conversation as read
            try await client
                .rpc("mark_conversation_read", params: params)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to mark conversation as read: \(error)")
            return false
        }
    }
    
    /// Get or create a direct conversation between current user and another user
    func getOrCreateDirectConversation(with userId: String) async -> String? {
        guard let session = try? await client.auth.session else { return nil }
        
        print("🔄 Getting or creating conversation with user: \(userId)")
        print("  - Current user: \(session.user.id.uuidString)")
        
        // First, try to find existing conversation
        let conversations = await getUserConversations()
        print("📊 Found \(conversations.count) existing conversations")
        
        // Look for a direct conversation (2 participants) with this user
        for conversation in conversations {
            print("  - Checking conversation \(conversation.id.uuidString) with \(conversation.participants.count) participants")
            if conversation.participants.count == 2 {
                // Check if this user is in the conversation
                if let participants = conversation.participants as? [AppUser] {
                    let participantIds = participants.map { $0.id }
                    print("    - Participant IDs: \(participantIds)")
                    if participants.contains(where: { $0.id.lowercased() == userId.lowercased() }) {
                        print("✅ Found existing conversation: \(conversation.id.uuidString)")
                        return conversation.id.uuidString
                    }
                }
            }
        }
        
        print("🆕 No existing conversation found, creating new one")
        // If no existing conversation found, create a new one
        let newConversationId = await createConversation(with: [userId], isGroup: false)
        print("✅ Created new conversation: \(newConversationId ?? "FAILED")")
        return newConversationId
    }

    // MARK: - Real-time Messaging
    
    /// Subscribe to real-time message updates for a conversation
    func subscribeToConversationMessages(conversationId: String, onMessageReceived: @escaping (Message) -> Void) async {
        print("🔔 Real-time messaging subscription placeholder for conversation: \(conversationId)")
        // TODO: Implement real-time subscriptions with updated Supabase API
        // For now, we'll rely on periodic polling or manual refresh
    }
    
    /// Subscribe to conversation list updates for a user
    func subscribeToUserConversations(userId: String, onConversationUpdate: @escaping () -> Void) async {
        print("🔔 Real-time conversation updates placeholder for user: \(userId)")
        // TODO: Implement real-time subscriptions with updated Supabase API
        // For now, we'll rely on periodic polling or manual refresh
    }
    
    /// Unsubscribe from real-time updates
    func unsubscribeFromRealTimeUpdates() async {
        print("🔕 Unsubscribing from all real-time updates")
        await client.removeAllChannels()
    }
    
    /// Mark message as read and update read status
    func markMessageAsRead(conversationId: String, messageId: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            let _: String = try await client
                .rpc("mark_message_as_read", params: [
                    "conversation_uuid": conversationId,
                    "user_uuid": session.user.id.uuidString,
                    "message_uuid": messageId
                ])
                .execute()
                .value
            
            print("✅ Marked message as read: \(messageId)")
            return true
        } catch {
            print("❌ Failed to mark message as read: \(error)")
            return false
        }
    }
    
    /// Get message read status for a conversation
    func getMessageReadStatus(conversationId: String, messageId: String) async -> [String] {
        do {
            let readByUserIds: [String] = try await client
                .rpc("get_message_read_status", params: [
                    "conversation_uuid": conversationId,
                    "message_uuid": messageId
                ])
                .execute()
                .value
            
            return readByUserIds
        } catch {
            print("❌ Failed to get message read status: \(error)")
            return []
        }
    }
    
    // MARK: - Rich Media Messaging
    
    /// Upload image for messaging and return URL
    func uploadMessageImage(_ imageData: Data, conversationId: String) async -> String? {
        let fileName = "message_\(UUID().uuidString).jpg"
        let filePath = "message-images/\(conversationId)/\(fileName)"
        
        do {
            try await client.storage
                .from("message-images")
                .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg"))
            
            let response = try client.storage
                .from("message-images")
                .getPublicURL(path: filePath)
            
            print("✅ Message image uploaded: \(response.absoluteString)")
            return response.absoluteString
        } catch {
            print("❌ Failed to upload message image: \(error)")
            return nil
        }
    }
    
    /// Send image message
    func sendImageMessage(conversationId: String, imageData: Data, caption: String? = nil) async -> Bool {
        guard let imageURL = await uploadMessageImage(imageData, conversationId: conversationId) else {
            return false
        }
        
        let content = caption ?? imageURL
        let messageType: MessageType = .image
        
        return await sendMessage(conversationId: conversationId, content: content, messageType: messageType)
    }
    
    /// Send location message
    func sendLocationMessage(conversationId: String, latitude: Double, longitude: Double, locationName: String? = nil) async -> Bool {
        let locationData: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "name": locationName ?? "Shared Location"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: locationData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return false
        }
        
        return await sendMessage(conversationId: conversationId, content: jsonString, messageType: .location)
    }
    
    /// Send pin message (share a pin from the app)
    func sendPinMessage(conversationId: String, pin: Pin) async -> Bool {
        let pinData: [String: Any] = [
            "id": pin.id.uuidString,
            "locationName": pin.locationName,
            "city": pin.city,
            "latitude": pin.latitude,
            "longitude": pin.longitude,
            "reaction": pin.reaction.rawValue,
            "reviewText": pin.reviewText ?? "",
            "starRating": pin.starRating ?? 0,
            "authorHandle": pin.authorHandle
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: pinData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return false
        }
        
        return await sendMessage(conversationId: conversationId, content: jsonString, messageType: .pin)
    }
    
    // MARK: - Notification Support
    
    /// Request notification permissions
    func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            print(granted ? "✅ Notification permissions granted" : "❌ Notification permissions denied")
            return granted
        } catch {
            print("❌ Failed to request notification permissions: \(error)")
            return false
        }
    }
    
    /// Send local notification for new message
    func sendMessageNotification(message: Message, conversationTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = conversationTitle
        content.body = message.displayContent
        content.sound = .default
        content.badge = 1
        
        // Add conversation ID to userInfo for handling tap
        content.userInfo = [
            "conversationId": message.conversationId,
            "messageId": message.id.uuidString
        ]
        
        let request = UNNotificationRequest(
            identifier: message.id.uuidString,
            content: content,
            trigger: nil // Immediate delivery
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("✅ Message notification sent")
            }
        }
    }
    
    /// Clear notifications for a conversation
    func clearNotifications(conversationId: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.compactMap { request in
                if let userInfo = request.content.userInfo as? [String: Any],
                   let notificationConversationId = userInfo["conversationId"] as? String,
                   notificationConversationId == conversationId {
                    return request.identifier
                }
                return nil
            }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        }
    }
}

// MARK: - Apple Sign In Crypto Helper Extension

extension SupabaseManager {
    func generateNonce(length: Int = 32) -> String {
        let charset: Array<Character> =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Image Storage Extension

extension SupabaseManager {
    
    /// Upload an image to Supabase Storage
    func uploadImage(_ imageData: Data, to bucket: String, path: String) async throws -> String {
        try await client.storage
            .from(bucket)
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        // Get the public URL for the uploaded image
        return try client.storage
            .from(bucket)
            .getPublicURL(path: path)
            .absoluteString
    }
    
    /// Upload profile image
    func uploadProfileImage(_ imageData: Data, for userID: String) async throws -> String {
        let fileName = "\(userID)_\(Date().timeIntervalSince1970).jpg"
        let path = "profile-images/\(fileName)"
        
        return try await uploadImage(imageData, to: "profile-images", path: path)
    }
    
    /// Upload pin media image
    func uploadPinImage(_ imageData: Data, for pinID: String) async throws -> String {
        let fileName = "\(pinID)_\(Date().timeIntervalSince1970).jpg"
        let path = "pin-images/\(fileName)"
        
        return try await uploadImage(imageData, to: "pin-images", path: path)
    }
    
    /// Delete an image from storage
    func deleteImage(from bucket: String, path: String) async throws {
        _ = try await client.storage
            .from(bucket)
            .remove(paths: [path])
    }
}

// MARK: - Location Features Extension (Temporarily Disabled)

/*
extension SupabaseManager {
    
    // MARK: - Location History (Placeholder Implementation)
    
    /// Save location to history
    func saveLocationToHistory(
        userID: String,
        latitude: Double,
        longitude: Double,
        accuracy: Double? = nil,
        altitude: Double? = nil,
        speed: Double? = nil,
        heading: Double? = nil,
        locationName: String? = nil,
        city: String? = nil,
        country: String? = nil,
        isManual: Bool = false,
        activityType: String? = nil
    ) async -> Bool {
        // TODO: Implement location history when database is ready
        print("✅ Location saved to history (placeholder)")
        return true
    }
    
    /// Get user's location history
    func getLocationHistory(
        userID: String,
        limit: Int = 100,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async throws -> [LocationHistoryEntry] {
        // TODO: Implement when database is ready
        return []
    }
    
    /// Delete location history older than specified days
    func cleanupLocationHistory(userID: String, olderThanDays: Int) async -> Bool {
        do {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
            let cutoffString = ISO8601DateFormatter().string(from: cutoffDate)
            
            _ = try await client
                .from("location_history")
                .delete()
                .eq("user_id", value: userID)
                .lt("created_at", value: cutoffString)
                .execute()
            
            print("✅ Location history cleaned up (older than \(olderThanDays) days)")
            return true
        } catch {
            print("❌ Failed to cleanup location history: \(error)")
            return false
        }
    }
    
    /// Delete all location history for user
    func deleteAllLocationHistory(userID: String) async -> Bool {
        do {
            _ = try await client
                .from("location_history")
                .delete()
                .eq("user_id", value: userID)
                .execute()
            
            print("✅ All location history deleted")
            return true
        } catch {
            print("❌ Failed to delete location history: \(error)")
            return false
        }
    }
    
    // MARK: - Geofencing
    
    /// Create a geofence
    func createGeofence(
        userID: String,
        name: String,
        description: String? = nil,
        latitude: Double,
        longitude: Double,
        radius: Double,
        notificationType: String = "both"
    ) async -> Bool {
        do {
            let geofenceData = GeofenceInsert(
                user_id: userID,
                name: name,
                description: description,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                notification_type: notificationType
            )
            
            _ = try await client
                .from("geofences")
                .insert(geofenceData)
                .execute()
            
            print("✅ Geofence created: \(name)")
            return true
        } catch {
            print("❌ Failed to create geofence: \(error)")
            return false
        }
    }
    
    /// Get user's geofences
    func getUserGeofences(userID: String) async throws -> [Geofence] {
        let response = try await client
            .from("geofences")
            .select()
            .eq("user_id", value: userID)
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .execute()
        
        return try JSONDecoder().decode([Geofence].self, from: response.data)
    }
    
    /// Update geofence
    func updateGeofence(
        geofenceID: String,
        name: String? = nil,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        radius: Double? = nil,
        isActive: Bool? = nil,
        notificationType: String? = nil
    ) async -> Bool {
        do {
            var updateData: [String: Any] = [:]
            
            if let name = name { updateData["name"] = name }
            if let description = description { updateData["description"] = description }
            if let latitude = latitude { updateData["latitude"] = latitude }
            if let longitude = longitude { updateData["longitude"] = longitude }
            if let radius = radius { updateData["radius"] = radius }
            if let isActive = isActive { updateData["is_active"] = isActive }
            if let notificationType = notificationType { updateData["notification_type"] = notificationType }
            
            _ = try await client
                .from("geofences")
                .update(updateData)
                .eq("id", value: geofenceID)
                .execute()
            
            print("✅ Geofence updated")
            return true
        } catch {
            print("❌ Failed to update geofence: \(error)")
            return false
        }
    }
    
    /// Delete geofence
    func deleteGeofence(geofenceID: String) async -> Bool {
        do {
            _ = try await client
                .from("geofences")
                .delete()
                .eq("id", value: geofenceID)
                .execute()
            
            print("✅ Geofence deleted")
            return true
        } catch {
            print("❌ Failed to delete geofence: \(error)")
            return false
        }
    }
    
    /// Record geofence event (enter/exit)
    func recordGeofenceEvent(
        userID: String,
        geofenceID: String,
        eventType: String,
        latitude: Double,
        longitude: Double
    ) async -> Bool {
        do {
            let eventData: [String: Any] = [
                "user_id": userID,
                "geofence_id": geofenceID,
                "event_type": eventType,
                "latitude": latitude,
                "longitude": longitude
            ]
            
            _ = try await client
                .from("geofence_events")
                .insert(eventData)
                .execute()
            
            print("✅ Geofence event recorded: \(eventType)")
            return true
        } catch {
            print("❌ Failed to record geofence event: \(error)")
            return false
        }
    }
    
    /// Get geofence events
    func getGeofenceEvents(userID: String, limit: Int = 50) async throws -> [GeofenceEvent] {
        let response = try await client
            .from("geofence_events")
            .select("""
                *,
                geofences (
                    name,
                    description
                )
            """)
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
        
        return try JSONDecoder().decode([GeofenceEvent].self, from: response.data)
    }
    
    // MARK: - Location Privacy Settings
    
    /// Get user's location privacy settings
    func getLocationPrivacySettings(userID: String) async throws -> LocationPrivacySettings {
        let response = try await client
            .from("location_privacy_settings")
            .select()
            .eq("user_id", value: userID)
            .execute()
        
        let settings = try JSONDecoder().decode([LocationPrivacySettings].self, from: response.data)
        
        if let existing = settings.first {
            return existing
        } else {
            // Create default settings if none exist
            let defaultSettings = LocationPrivacySettings(
                userID: userID,
                shareLocationWithFriends: true,
                shareLocationWithFollowers: false,
                shareLocationPublicly: false,
                shareLocationHistory: false,
                locationAccuracyLevel: "approximate",
                autoDeleteHistoryDays: 30,
                allowLocationRequests: true
            )
            
            _ = await createLocationPrivacySettings(settings: defaultSettings)
            return defaultSettings
        }
    }
    
    /// Create location privacy settings
    func createLocationPrivacySettings(settings: LocationPrivacySettings) async -> Bool {
        do {
            let settingsData: [String: Any] = [
                "user_id": settings.userID,
                "share_location_with_friends": settings.shareLocationWithFriends,
                "share_location_with_followers": settings.shareLocationWithFollowers,
                "share_location_publicly": settings.shareLocationPublicly,
                "share_location_history": settings.shareLocationHistory,
                "location_accuracy_level": settings.locationAccuracyLevel,
                "auto_delete_history_days": settings.autoDeleteHistoryDays,
                "allow_location_requests": settings.allowLocationRequests
            ]
            
            _ = try await client
                .from("location_privacy_settings")
                .insert(settingsData)
                .execute()
            
            print("✅ Location privacy settings created")
            return true
        } catch {
            print("❌ Failed to create location privacy settings: \(error)")
            return false
        }
    }
    
    /// Update location privacy settings
    func updateLocationPrivacySettings(
        userID: String,
        shareLocationWithFriends: Bool? = nil,
        shareLocationWithFollowers: Bool? = nil,
        shareLocationPublicly: Bool? = nil,
        shareLocationHistory: Bool? = nil,
        locationAccuracyLevel: String? = nil,
        autoDeleteHistoryDays: Int? = nil,
        allowLocationRequests: Bool? = nil
    ) async -> Bool {
        do {
            var updateData: [String: Any] = [:]
            
            if let shareLocationWithFriends = shareLocationWithFriends {
                updateData["share_location_with_friends"] = shareLocationWithFriends
            }
            if let shareLocationWithFollowers = shareLocationWithFollowers {
                updateData["share_location_with_followers"] = shareLocationWithFollowers
            }
            if let shareLocationPublicly = shareLocationPublicly {
                updateData["share_location_publicly"] = shareLocationPublicly
            }
            if let shareLocationHistory = shareLocationHistory {
                updateData["share_location_history"] = shareLocationHistory
            }
            if let locationAccuracyLevel = locationAccuracyLevel {
                updateData["location_accuracy_level"] = locationAccuracyLevel
            }
            if let autoDeleteHistoryDays = autoDeleteHistoryDays {
                updateData["auto_delete_history_days"] = autoDeleteHistoryDays
            }
            if let allowLocationRequests = allowLocationRequests {
                updateData["allow_location_requests"] = allowLocationRequests
            }
            
            _ = try await client
                .from("location_privacy_settings")
                .update(updateData)
                .eq("user_id", value: userID)
                .execute()
            
            print("✅ Location privacy settings updated")
            return true
        } catch {
            print("❌ Failed to update location privacy settings: \(error)")
            return false
        }
    }
    
    /// Check if user allows location sharing with another user
    func canShareLocationWith(userID: String, targetUserID: String) async -> Bool {
        do {
            // Get privacy settings
            let settings = try await getLocationPrivacySettings(userID: userID)
            
            // Check if public sharing is enabled
            if settings.shareLocationPublicly {
                return true
            }
            
            // Check if they're friends and friend sharing is enabled
            if settings.shareLocationWithFriends {
                let isFollowing = try await checkIfFollowing(followerID: targetUserID, followingID: userID)
                let isFollowedBy = try await checkIfFollowing(followerID: userID, followingID: targetUserID)
                
                if isFollowing && isFollowedBy {
                    return true // Mutual follow = friends
                }
            }
            
            // Check if follower sharing is enabled
            if settings.shareLocationWithFollowers {
                let isFollowedBy = try await checkIfFollowing(followerID: targetUserID, followingID: userID)
                return isFollowedBy
            }
            
            return false
        } catch {
            print("❌ Failed to check location sharing permissions: \(error)")
            return false
        }
    }
}
*/
