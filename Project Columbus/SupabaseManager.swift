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
import os.log

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
    
    // MARK: - User Management
    
    /// Gets the current authenticated user's ID
    func getCurrentUserID() async -> UUID? {
        guard let session = try? await client.auth.session else { 
            return nil 
        }
        return UUID(uuidString: session.user.id.uuidString)
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
                .in("id", values: pinIds)
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
            // Create a simple response struct to avoid decoding issues
            struct PinIdResponse: Codable {
                let id: String
            }
            
            let existingPins: [PinIdResponse] = try await client
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
                .in("id", values: followingIds)
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
            
            // Calculate follower count
            let followerCount: Int
            do {
                struct CountResult: Codable {
                    let count: Int
                }
                
                let followerResult: CountResult = try await client
                    .from("follows")
                    .select("count", count: .exact)
                    .eq("following_id", value: userID)
                    .single()
                    .execute()
                    .value
                followerCount = followerResult.count
            } catch {
                print("❌ Failed to get follower count: \(error)")
                followerCount = 0
            }
            
            // Calculate following count  
            let followingCount: Int
            do {
                struct CountResult: Codable {
                    let count: Int
                }
                
                let followingResult: CountResult = try await client
                    .from("follows")
                    .select("count", count: .exact)
                    .eq("follower_id", value: userID)
                    .single()
                    .execute()
                    .value
                followingCount = followingResult.count
            } catch {
                print("❌ Failed to get following count: \(error)")
                followingCount = 0
            }
            
            // Filter out self-follows from counts
            let selfFollowCount: Int
            do {
                struct CountResult: Codable {
                    let count: Int
                }
                
                let selfFollowResult: CountResult = try await client
                    .from("follows")
                    .select("count", count: .exact)
                    .eq("follower_id", value: userID)
                    .eq("following_id", value: userID)
                    .single()
                    .execute()
                    .value
                selfFollowCount = selfFollowResult.count
            } catch {
                selfFollowCount = 0
            }
            
            // Create AppUser with calculated counts (subtract self-follows)
            return AppUser(
                id: basicUser.id,
                username: basicUser.username,
                full_name: basicUser.full_name,
                email: basicUser.email,
                bio: basicUser.bio,
                follower_count: max(0, followerCount - selfFollowCount),
                following_count: max(0, followingCount - selfFollowCount),
                isFollowedByCurrentUser: false, // Will be set separately if needed
                latitude: basicUser.latitude,
                longitude: basicUser.longitude,
                isCurrentUser: false, // Will be set separately if needed
                avatarURL: basicUser.avatar_url
            )
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
        guard (try? await client.auth.session) != nil else { return false }

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
            // Use a lightweight struct for decoding
            struct FollowerResponse: Codable {
                let follower_id: String
            }
            // Get the follow relationships where the target user is being followed
            let follows: [FollowerResponse] = try await client
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
                .in("id", values: followerIds)
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
                .in("user_id", values: followingIds)
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
    
    /// Create a like notification
    func createLikeNotification(to userID: String, from fromUserID: String, pinID: String, pinName: String) async -> Bool {
        do {
            struct LikeNotificationData: Codable {
                let user_id: String
                let type: String
                let title: String
                let message: String
                let from_user_id: String
                let related_pin_id: String
                let action_data: String
                let priority: String
            }
            
            let actionData = ["action": "view_pin", "pinID": pinID]
            let actionDataString = try JSONSerialization.data(withJSONObject: actionData)
            let actionDataJSON = String(data: actionDataString, encoding: .utf8) ?? "{}"
            
            let notificationData = LikeNotificationData(
                user_id: userID,
                type: "like",
                title: "Pin Liked",
                message: "Someone liked your pin at \(pinName)",
                from_user_id: fromUserID,
                related_pin_id: pinID,
                action_data: actionDataJSON,
                priority: "normal"
            )
            
            try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to create like notification: \(error)")
            return false
        }
    }
    
    /// Create a comment notification
    func createCommentNotification(to userID: String, from fromUserID: String, pinID: String, pinName: String, comment: String) async -> Bool {
        do {
            struct CommentNotificationData: Codable {
                let user_id: String
                let type: String
                let title: String
                let message: String
                let from_user_id: String
                let related_pin_id: String
                let action_data: String
                let priority: String
            }
            
            let actionData = ["action": "view_pin", "pinID": pinID]
            let actionDataString = try JSONSerialization.data(withJSONObject: actionData)
            let actionDataJSON = String(data: actionDataString, encoding: .utf8) ?? "{}"
            
            let notificationData = CommentNotificationData(
                user_id: userID,
                type: "comment",
                title: "New Comment",
                message: "Someone commented on your pin at \(pinName): \(comment)",
                from_user_id: fromUserID,
                related_pin_id: pinID,
                action_data: actionDataJSON,
                priority: "normal"
            )
            
            try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to create comment notification: \(error)")
            return false
        }
    }
    
    /// Create a message notification
    func createMessageNotification(to userID: String, from fromUserID: String, conversationID: String, messagePreview: String) async -> Bool {
        do {
            struct MessageNotificationData: Codable {
                let user_id: String
                let type: String
                let title: String
                let message: String
                let from_user_id: String
                let action_data: String
                let priority: String
            }
            
            let actionData = ["action": "open_chat", "conversationID": conversationID]
            let actionDataString = try JSONSerialization.data(withJSONObject: actionData)
            let actionDataJSON = String(data: actionDataString, encoding: .utf8) ?? "{}"
            
            let notificationData = MessageNotificationData(
                user_id: userID,
                type: "message",
                title: "New Message",
                message: messagePreview,
                from_user_id: fromUserID,
                action_data: actionDataJSON,
                priority: "high"
            )
            
            try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to create message notification: \(error)")
            return false
        }
    }
    
    /// Create a list invitation notification
    func createListInviteNotification(to userID: String, from fromUserID: String, listID: String, listName: String) async -> Bool {
        do {
            struct ListInviteNotificationData: Codable {
                let user_id: String
                let type: String
                let title: String
                let message: String
                let from_user_id: String
                let related_list_id: String
                let action_data: String
                let priority: String
            }
            
            let actionData = ["action": "view_list", "listID": listID]
            let actionDataString = try JSONSerialization.data(withJSONObject: actionData)
            let actionDataJSON = String(data: actionDataString, encoding: .utf8) ?? "{}"
            
            let notificationData = ListInviteNotificationData(
                user_id: userID,
                type: "list_invite",
                title: "List Invitation",
                message: "You've been invited to collaborate on \(listName)",
                from_user_id: fromUserID,
                related_list_id: listID,
                action_data: actionDataJSON,
                priority: "normal"
            )
            
            try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to create list invite notification: \(error)")
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
        print("🔔 Setting up real-time messaging subscription for conversation: \(conversationId)")
        
        // TODO: Update to newer Supabase Realtime API syntax
        // For now, fall back to polling until API is updated
        print("⚠️ Real-time messaging temporarily disabled, using polling fallback")
        await startMessagePolling(conversationId: conversationId, onMessageReceived: onMessageReceived)
    }
    
    /// Subscribe to conversation list updates for a user
    func subscribeToUserConversations(userId: String, onConversationUpdate: @escaping () -> Void) async {
        print("🔔 Setting up real-time conversation updates for user: \(userId)")
        
        // TODO: Update to newer Supabase Realtime API syntax
        // For now, fall back to polling until API is updated
        print("⚠️ Real-time conversation updates temporarily disabled, using polling fallback")
        await startConversationPolling(userId: userId, onConversationUpdate: onConversationUpdate)
    }
    
    /// Fallback polling mechanism for messages when real-time fails
    private func startMessagePolling(conversationId: String, onMessageReceived: @escaping (Message) -> Void) async {
        print("🔄 Starting message polling fallback for conversation: \(conversationId)")
        
        // Use actor to handle concurrent access to lastMessageTime
        actor MessageTimeTracker {
            private var lastMessageTime: Date = Date()
            
            func updateLastMessageTime(to newTime: Date) {
                lastMessageTime = max(lastMessageTime, newTime)
            }
            
            func getLastMessageTime() -> Date {
                return lastMessageTime
            }
        }
        
        let timeTracker = MessageTimeTracker()
        
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            Task {
                let lastTime = await timeTracker.getLastMessageTime()
                let newMessages = await self.getMessagesAfter(conversationId: conversationId, after: lastTime)
                for message in newMessages {
                    onMessageReceived(message)
                    await timeTracker.updateLastMessageTime(to: message.createdAt)
                }
            }
        }
    }
    
    /// Fallback polling mechanism for conversations when real-time fails
    private func startConversationPolling(userId: String, onConversationUpdate: @escaping () -> Void) async {
        print("🔄 Starting conversation polling fallback for user: \(userId)")
        
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { timer in
            Task {
                onConversationUpdate()
            }
        }
    }
    
    /// Helper method to get messages after a specific timestamp
    private func getMessagesAfter(conversationId: String, after: Date) async -> [Message] {
        do {
            let afterString = ISO8601DateFormatter().string(from: after)
            let messagesDB: [MessageDB] = try await client
                .from("messages")
                .select("*")
                .eq("conversation_id", value: conversationId)
                .gt("created_at", value: afterString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            return messagesDB.map { $0.toMessage() }
        } catch {
            print("❌ Failed to fetch messages after timestamp: \(error)")
            return []
        }
    }
    
    /// Unsubscribe from real-time updates
    func unsubscribeFromRealTimeUpdates() async {
        print("🔕 Unsubscribing from all real-time updates")
        // TODO: Update to newer Supabase API
        // await client.removeAllChannels()
    }
    
    /// Unsubscribe from specific conversation
    func unsubscribeFromConversation(conversationId: String) async {
        print("🔕 Unsubscribing from conversation: \(conversationId)")
        // TODO: Update to newer Supabase API
        // let channelName = "conversation:\(conversationId)"
        // if let channel = client.getChannels().first(where: { $0.topic == channelName }) {
        //     await channel.unsubscribe()
        // }
    }
    
    /// Unsubscribe from user conversations
    func unsubscribeFromUserConversations(userId: String) async {
        print("🔕 Unsubscribing from user conversations: \(userId)")
        // TODO: Update to newer Supabase API
        // let channelName = "user_conversations:\(userId)"
        // if let channel = client.getChannels().first(where: { $0.topic == channelName }) {
        //     await channel.unsubscribe()
        // }
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

    /// Delete an image from storage
    func deleteImage(from bucket: String, path: String) async throws {
        _ = try await client.storage
            .from(bucket)
            .remove(paths: [path])
    }
    
    // MARK: - Social Features - Comments
    
    /// Add a comment to a pin
    func addComment(pinId: UUID, content: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        guard let currentUser = try? await getCurrentUserProfile() else { return false }
        
        do {
            struct CommentData: Codable {
                let id: String
                let pin_id: String
                let user_id: String
                let username: String
                let user_avatar_url: String?
                let content: String
                let created_at: String
                let likes_count: Int
            }
            
            let commentData = CommentData(
                id: UUID().uuidString,
                pin_id: pinId.uuidString,
                user_id: session.user.id.uuidString,
                username: currentUser.username,
                user_avatar_url: currentUser.avatarURL,
                content: content,
                created_at: ISO8601DateFormatter().string(from: Date()),
                likes_count: 0
            )
            
            _ = try await client
                .from("pin_comments")
                .insert(commentData)
                .execute()
            
            // Create friend activity
            await createFriendActivity(
                activityType: .commentedOnPin,
                relatedPinId: pinId,
                description: "commented on a pin"
            )
            
            return true
        } catch {
            print("❌ Failed to add comment: \(error)")
            return false
        }
    }
    
    /// Get comments for a pin
    func getComments(for pinId: UUID, currentUserId: String) async -> [PinComment] {
        do {
            let commentsDB: [PinCommentDB] = try await client
                .from("pin_comments")
                .select("*")
                .eq("pin_id", value: pinId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            // Check which comments are liked by current user
            var comments: [PinComment] = []
            for commentDB in commentsDB {
                let isLiked = await isCommentLikedByUser(commentId: commentDB.id, userId: currentUserId)
                comments.append(commentDB.toPinComment(isLikedByCurrentUser: isLiked))
            }
            
            return comments
        } catch {
            print("❌ Failed to get comments: \(error)")
            return []
        }
    }
    
    /// Like/unlike a comment
    func toggleCommentLike(commentId: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            let userId = session.user.id.uuidString
            
            // Check if already liked
            let existing: [CommentLikeDB] = try await client
                .from("comment_likes")
                .select("*")
                .eq("comment_id", value: commentId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if existing.isEmpty {
                // Add like
                struct LikeData: Codable {
                    let id: String
                    let comment_id: String
                    let user_id: String
                    let created_at: String
                }
                
                let likeData = LikeData(
                    id: UUID().uuidString,
                    comment_id: commentId,
                    user_id: userId,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("comment_likes")
                    .insert(likeData)
                    .execute()
            } else {
                // Remove like
                _ = try await client
                    .from("comment_likes")
                    .delete()
                    .eq("comment_id", value: commentId)
                    .eq("user_id", value: userId)
                    .execute()
            }
            
            return true
        } catch {
            print("❌ Failed to toggle comment like: \(error)")
            return false
        }
    }
    
    /// Check if comment is liked by user
    private func isCommentLikedByUser(commentId: String, userId: String) async -> Bool {
        do {
            let likes: [CommentLikeDB] = try await client
                .from("comment_likes")
                .select("*")
                .eq("comment_id", value: commentId)
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            
            return !likes.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Social Features - Reactions
    
    /// Add/update reaction to a pin
    func addReaction(pinId: UUID, reactionType: PinReactionType) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        guard let currentUser = try? await getCurrentUserProfile() else { return false }
        
        do {
            let userId = session.user.id.uuidString
            
            // Check if user already reacted to this pin
            let existing: [PinReactionDB] = try await client
                .from("pin_reactions")
                .select("*")
                .eq("pin_id", value: pinId.uuidString)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if existing.isEmpty {
                // Add new reaction
                struct ReactionData: Codable {
                    let id: String
                    let pin_id: String
                    let user_id: String
                    let username: String
                    let user_avatar_url: String?
                    let reaction_type: String
                    let created_at: String
                }
                
                let reactionData = ReactionData(
                    id: UUID().uuidString,
                    pin_id: pinId.uuidString,
                    user_id: userId,
                    username: currentUser.username,
                    user_avatar_url: currentUser.avatarURL,
                    reaction_type: reactionType.rawValue,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("pin_reactions")
                    .insert(reactionData)
                    .execute()
                
                // Create friend activity
                await createFriendActivity(
                    activityType: .reactedToPin,
                    relatedPinId: pinId,
                    description: "reacted to a pin with \(reactionType.emoji)"
                )
            } else {
                // Update existing reaction
                _ = try await client
                    .from("pin_reactions")
                    .update(["reaction_type": reactionType.rawValue])
                    .eq("pin_id", value: pinId.uuidString)
                    .eq("user_id", value: userId)
                    .execute()
            }
            
            return true
        } catch {
            print("❌ Failed to add reaction: \(error)")
            return false
        }
    }
    
    /// Remove reaction from a pin
    func removeReaction(pinId: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            _ = try await client
                .from("pin_reactions")
                .delete()
                .eq("pin_id", value: pinId.uuidString)
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to remove reaction: \(error)")
            return false
        }
    }
    
    /// Get reactions for a pin
    func getReactions(for pinId: UUID) async -> [PinReaction] {
        do {
            let reactionsDB: [PinReactionDB] = try await client
                .from("pin_reactions")
                .select("*")
                .eq("pin_id", value: pinId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return reactionsDB.map { $0.toPinReaction() }
        } catch {
            print("❌ Failed to get reactions: \(error)")
            return []
        }
    }
    
    // MARK: - Social Features - Friend Activity Feed
    
    /// Create friend activity entry
    func createFriendActivity(activityType: FriendActivityType, relatedPinId: UUID? = nil, locationName: String? = nil, description: String) async {
        guard let session = try? await client.auth.session else { return }
        guard let currentUser = try? await getCurrentUserProfile() else { return }
        
        do {
            struct ActivityData: Codable {
                let id: String
                let user_id: String
                let username: String
                let user_avatar_url: String?
                let activity_type: String
                let related_pin_id: String?
                let location_name: String?
                let description: String
                let created_at: String
            }
            
            let activityData = ActivityData(
                id: UUID().uuidString,
                user_id: session.user.id.uuidString,
                username: currentUser.username,
                user_avatar_url: currentUser.avatarURL,
                activity_type: activityType.rawValue,
                related_pin_id: relatedPinId?.uuidString,
                location_name: locationName,
                description: description,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            _ = try await client
                .from("friend_activities")
                .insert(activityData)
                .execute()
        } catch {
            print("❌ Failed to create friend activity: \(error)")
        }
    }
    
    /// Get friend activity feed
    func getFriendActivityFeed(for userId: String, limit: Int = 50) async -> [FriendActivity] {
        do {
            // Get users that this user follows
            let followingUsers = await getFollowingUsers(for: userId)
            let followingIds = followingUsers.map { $0.id }
            
            if followingIds.isEmpty { return [] }
            
            // Get activities from followed users
            let activitiesDB: [FriendActivityDB] = try await client
                .from("friend_activities")
                .select("*")
                .in("user_id", values: followingIds)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            // Convert to FriendActivity objects and fetch related pins if needed
            var activities: [FriendActivity] = []
            for activityDB in activitiesDB {
                var relatedPin: Pin? = nil
                if let pinIdString = activityDB.related_pin_id,
                   let pinId = UUID(uuidString: pinIdString) {
                    relatedPin = await getPinById(pinId)
                }
                
                activities.append(activityDB.toFriendActivity(relatedPin: relatedPin))
            }
            
            return activities
        } catch {
            print("❌ Failed to get friend activity feed: \(error)")
            return []
        }
    }
    
    /// Get a single pin by ID
    private func getPinById(_ pinId: UUID) async -> Pin? {
        do {
            let pinDB: PinDB = try await client
                .from("pins")
                .select("*")
                .eq("id", value: pinId.uuidString)
                .single()
                .execute()
                .value
            
            return pinDB.toPin()
        } catch {
            print("❌ Failed to get pin by ID: \(error)")
            return nil
        }
    }
    
    // MARK: - Social Features - Friend Recommendations
    
    /// Get friend recommendations based on activity
    func getFriendRecommendations(for userId: String, limit: Int = 20) async -> [FriendRecommendation] {
        do {
            // Get user's following list
            let followingUsers = await getFollowingUsers(for: userId)
            let followingIds = followingUsers.map { $0.id }
            
            if followingIds.isEmpty { return [] }
            
            // Get pins that friends have rated highly (4+ stars)
            let friendPins: [PinDB] = try await client
                .from("pins")
                .select("*")
                .in("user_id", values: followingIds)
                .gte("star_rating", value: 4.0)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            
            // Group pins by location and calculate recommendations
            var locationGroups: [String: [PinDB]] = [:]
            for pin in friendPins {
                let key = "\(pin.location_name)_\(pin.latitude)_\(pin.longitude)"
                locationGroups[key, default: []].append(pin)
            }
            
            var recommendations: [FriendRecommendation] = []
            
            for (_, pins) in locationGroups {
                guard pins.count >= 2 else { continue } // Need at least 2 friends to recommend
                
                let averageRating = pins.compactMap { $0.star_rating }.reduce(0, +) / Double(pins.count)
                let friendIds = pins.map { $0.user_id }
                let friendUsernames = followingUsers.filter { friendIds.contains($0.id) }.map { $0.username }
                let recentVisits = pins.compactMap { ISO8601DateFormatter().date(from: $0.created_at) }
                
                let confidence = min(1.0, Double(pins.count) / 5.0) // Higher confidence with more visits
                let reasonText = "\(pins.count) friends visited and rated it \(String(format: "%.1f", averageRating)) stars"
                
                if let firstPin = pins.first {
                    let recommendation = FriendRecommendation(
                        recommendedPlace: firstPin.toPin(),
                        recommendingFriendIds: friendIds,
                        recommendingFriendUsernames: friendUsernames,
                        averageRating: averageRating,
                        totalVisits: pins.count,
                        recentVisits: recentVisits,
                        reasonText: reasonText,
                        confidence: confidence
                    )
                    recommendations.append(recommendation)
                }
            }
            
            // Sort by confidence and rating
            recommendations.sort { $0.confidence * $0.averageRating > $1.confidence * $1.averageRating }
            
            return Array(recommendations.prefix(limit))
        } catch {
            print("❌ Failed to get friend recommendations: \(error)")
            return []
        }
    }
    
    /// Get current user profile (helper method)
    private func getCurrentUserProfile() async throws -> AppUser {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let basicUser: BasicUser = try await client
            .from("users")
            .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
            .eq("id", value: session.user.id.uuidString)
            .single()
            .execute()
            .value
        
        return basicUser.toAppUser(currentUserID: session.user.id.uuidString)
    }

    // MARK: - Image Storage Extension
    
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
    
    // MARK: - Video Content Management
    
    /// Upload video file to storage
    func uploadVideo(_ videoData: Data, for videoID: String) async throws -> String {
        let fileName = "\(videoID)_\(Date().timeIntervalSince1970).mp4"
        let path = "videos/\(fileName)"
        
        do {
            _ = try await client.storage
                .from("videos")
                .upload(path, data: videoData)
            
            print("✅ Video uploaded successfully: \(path)")
            
            // Get public URL
            let publicURL = try client.storage
                .from("videos")
                .getPublicURL(path: path)
            
            return publicURL.absoluteString
        } catch {
            print("❌ Failed to upload video: \(error)")
            throw error
        }
    }
    
    /// Upload video thumbnail
    func uploadVideoThumbnail(_ imageData: Data, for videoID: String) async throws -> String {
        let fileName = "\(videoID)_thumbnail_\(Date().timeIntervalSince1970).jpg"
        let path = "video-thumbnails/\(fileName)"
        
        return try await uploadImage(imageData, to: "video-thumbnails", path: path)
    }
    
    /// Create a new video post
    func createVideoContent(_ video: VideoContent) async throws -> VideoContent {
        do {
            let videoContentDB = video.toVideoContentDB()
            
            let insertedVideo: [VideoContentDB] = try await client
                .from("video_content")
                .insert(videoContentDB)
                .select()
                .execute()
                .value
            
            guard let insertedVideoData = insertedVideo.first else {
                throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create video content"])
            }
            
            print("✅ Video content created successfully: \(insertedVideoData.id)")
            return insertedVideoData.toVideoContent()
        } catch {
            print("❌ Failed to create video content: \(error)")
            throw error
        }
    }
    
    /// Get video feed based on filter
    func getVideoFeed(filter: VideoFeedFilter, userID: String, limit: Int = 20, offset: Int = 0) async throws -> [VideoContent] {
        do {
                    // Build query based on feed type
        let videos: [VideoContentDB] = try await {
            switch filter {
            case .following:
                // Get videos from users the current user follows
                let followingUsers = await getFollowingUsers(for: userID)
                let followingUserIds = followingUsers.map { $0.id }
                if !followingUserIds.isEmpty {
                    // Use the first following user for now - limitation of simple queries
                    return try await client
                        .from("video_content")
                        .select("*")
                        .eq("author_id", value: followingUserIds.first!)
                        .order("created_at", ascending: false)
                        .range(from: offset, to: offset + limit - 1)
                        .execute()
                        .value
                } else {
                    // If not following anyone, return empty array
                    return []
                }
            case .trending:
                // Get trending videos (high engagement in last 24 hours)
                return try await client
                    .from("video_content")
                    .select("*")
                    .order("likes_count", ascending: false)
                    .order("views_count", ascending: false)
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + limit - 1)
                    .execute()
                    .value
            case .nearby:
                // Get videos with location data (would need user's current location)
                // For now, we'll just return all videos - in production you'd filter by location
                return try await client
                    .from("video_content")
                    .select("*")
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + limit - 1)
                    .execute()
                    .value
            case .saved:
                // Get user's saved/bookmarked videos
                let savedVideoIds = await getSavedVideoIds(for: userID)
                if !savedVideoIds.isEmpty {
                    // Use the first saved video ID for now - limitation of simple queries
                    return try await client
                        .from("video_content")
                        .select("*")
                        .eq("id", value: savedVideoIds.first!)
                        .order("created_at", ascending: false)
                        .range(from: offset, to: offset + limit - 1)
                        .execute()
                        .value
                } else {
                    return []
                }
            case .forYou:
                // Default feed - mix of popular and recent content
                return try await client
                    .from("video_content")
                    .select("*")
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + limit - 1)
                    .execute()
                    .value
            }
                }()
            
            // Convert to VideoContent and check if liked by current user
            var videoContents: [VideoContent] = []
            for videoDB in videos {
                let isLiked = await isVideoLikedByUser(videoId: videoDB.id, userId: userID)
                let isBookmarked = await isVideoBookmarkedByUser(videoId: videoDB.id, userId: userID)
                let videoContent = videoDB.toVideoContent(isLikedByCurrentUser: isLiked, isBookmarkedByCurrentUser: isBookmarked)
                videoContents.append(videoContent)
            }
            
            print("✅ Retrieved \(videoContents.count) videos for \(filter.rawValue) feed")
            return videoContents
        } catch {
            print("❌ Failed to get video feed: \(error)")
            throw error
        }
    }
    
    /// Get specific video by ID
    func getVideo(id: String, userID: String) async throws -> VideoContent? {
        do {
            let videos: [VideoContentDB] = try await client
                .from("video_content")
                .select("*")
                .eq("id", value: id)
                .execute()
                .value
            
            guard let videoDB = videos.first else { return nil }
            
            let isLiked = await isVideoLikedByUser(videoId: id, userId: userID)
            let isBookmarked = await isVideoBookmarkedByUser(videoId: id, userId: userID)
            
            return videoDB.toVideoContent(isLikedByCurrentUser: isLiked, isBookmarkedByCurrentUser: isBookmarked)
        } catch {
            print("❌ Failed to get video: \(error)")
            throw error
        }
    }
    
    /// Like/unlike a video
    func toggleVideoLike(videoId: String, userId: String, username: String, userAvatarURL: String?) async -> Bool {
        do {
            // Check if already liked
            let existingLikes: [VideoLikeDB] = try await client
                .from("video_likes")
                .select("*")
                .eq("video_id", value: videoId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if let existingLike = existingLikes.first {
                // Unlike the video
                _ = try await client
                    .from("video_likes")
                    .delete()
                    .eq("id", value: existingLike.id)
                    .execute()
                
                // Decrement likes count
                _ = try await client
                    .from("video_content")
                    .update(["likes_count": "likes_count - 1"])
                    .eq("id", value: videoId)
                    .execute()
                
                print("✅ Video unliked: \(videoId)")
                return false
            } else {
                // Like the video
                let videoLike = VideoLikeDB(
                    id: UUID().uuidString,
                    video_id: videoId,
                    user_id: userId,
                    username: username,
                    user_avatar_url: userAvatarURL,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("video_likes")
                    .insert(videoLike)
                    .execute()
                
                // Increment likes count
                _ = try await client
                    .from("video_content")
                    .update(["likes_count": "likes_count + 1"])
                    .eq("id", value: videoId)
                    .execute()
                
                print("✅ Video liked: \(videoId)")
                return true
            }
        } catch {
            print("❌ Failed to toggle video like: \(error)")
            return false
        }
    }
    
    /// Check if video is liked by user
    func isVideoLikedByUser(videoId: String, userId: String) async -> Bool {
        do {
            let likes: [VideoLikeDB] = try await client
                .from("video_likes")
                .select("id")
                .eq("video_id", value: videoId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            return !likes.isEmpty
        } catch {
            print("❌ Failed to check video like status: \(error)")
            return false
        }
    }
    
    /// Bookmark/unbookmark a video
    func toggleVideoBookmark(videoId: String, userId: String) async -> Bool {
        do {
            // Check if already bookmarked
            let existingBookmarks: [VideoBookmarkDB] = try await client
                .from("video_bookmarks")
                .select("*")
                .eq("video_id", value: videoId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if let existingBookmark = existingBookmarks.first {
                // Remove bookmark
                _ = try await client
                    .from("video_bookmarks")
                    .delete()
                    .eq("id", value: existingBookmark.id)
                    .execute()
                
                print("✅ Video unbookmarked: \(videoId)")
                return false
            } else {
                // Add bookmark
                let bookmark = VideoBookmarkDB(
                    id: UUID().uuidString,
                    video_id: videoId,
                    user_id: userId,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("video_bookmarks")
                    .insert(bookmark)
                    .execute()
                
                print("✅ Video bookmarked: \(videoId)")
                return true
            }
        } catch {
            print("❌ Failed to toggle video bookmark: \(error)")
            return false
        }
    }
    
    /// Check if video is bookmarked by user
    func isVideoBookmarkedByUser(videoId: String, userId: String) async -> Bool {
        do {
            let bookmarks: [VideoBookmarkDB] = try await client
                .from("video_bookmarks")
                .select("id")
                .eq("video_id", value: videoId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            return !bookmarks.isEmpty
        } catch {
            print("❌ Failed to check video bookmark status: \(error)")
            return false
        }
    }
    
    /// Get saved video IDs for user
    private func getSavedVideoIds(for userId: String) async -> [String] {
        do {
            let bookmarks: [VideoBookmarkDB] = try await client
                .from("video_bookmarks")
                .select("video_id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            return bookmarks.map { $0.video_id }
        } catch {
            print("❌ Failed to get saved video IDs: \(error)")
            return []
        }
    }
    
    /// Record video view
    func recordVideoView(videoId: String, userId: String, watchDuration: TimeInterval) async {
        do {
            // Record the view
            let view = VideoViewDB(
                id: UUID().uuidString,
                video_id: videoId,
                user_id: userId,
                watch_duration: watchDuration,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            _ = try await client
                .from("video_views")
                .insert(view)
                .execute()
            
            // Increment views count
            _ = try await client
                .from("video_content")
                .update(["views_count": "views_count + 1"])
                .eq("id", value: videoId)
                .execute()
            
            print("✅ Video view recorded: \(videoId)")
        } catch {
            print("❌ Failed to record video view: \(error)")
        }
    }
    
    /// Add comment to video
    func addVideoComment(videoId: String, authorId: String, authorUsername: String, authorAvatarURL: String?, content: String, parentCommentId: String? = nil) async throws -> VideoComment {
        do {
            let commentDB = VideoCommentDB(
                id: UUID().uuidString,
                video_id: videoId,
                author_id: authorId,
                author_username: authorUsername,
                author_avatar_url: authorAvatarURL,
                content: content,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: nil,
                parent_comment_id: parentCommentId,
                likes_count: 0,
                replies_count: 0
            )
            
            let insertedComments: [VideoCommentDB] = try await client
                .from("video_comments")
                .insert(commentDB)
                .select()
                .execute()
                .value
            
            guard let insertedComment = insertedComments.first else {
                throw NSError(domain: "CommentError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to add comment"])
            }
            
            // Increment comments count on video
            _ = try await client
                .from("video_content")
                .update(["comments_count": "comments_count + 1"])
                .eq("id", value: videoId)
                .execute()
            
            // If this is a reply, increment replies count on parent comment
            if let parentId = parentCommentId {
                _ = try await client
                    .from("video_comments")
                    .update(["replies_count": "replies_count + 1"])
                    .eq("id", value: parentId)
                    .execute()
            }
            
            print("✅ Comment added to video: \(videoId)")
            return insertedComment.toVideoComment()
        } catch {
            print("❌ Failed to add video comment: \(error)")
            throw error
        }
    }
    
    /// Get comments for video
    func getVideoComments(videoId: String, userId: String, limit: Int = 50, offset: Int = 0) async throws -> [VideoComment] {
        do {
            let commentsDB: [VideoCommentDB] = try await client
                .from("video_comments")
                .select("*")
                .eq("video_id", value: videoId)
                .is("parent_comment_id", value: nil) // Only top-level comments
                .order("created_at", ascending: true)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
            
            // Convert to VideoComment and check if liked by current user
            var comments: [VideoComment] = []
            for commentDB in commentsDB {
                let isLiked = await isCommentLikedByUser(commentId: commentDB.id, userId: userId)
                let comment = commentDB.toVideoComment(isLikedByCurrentUser: isLiked)
                comments.append(comment)
            }
            
            print("✅ Retrieved \(comments.count) comments for video: \(videoId)")
            return comments
        } catch {
            print("❌ Failed to get video comments: \(error)")
            throw error
        }
    }
    
    /// Get replies for a comment
    func getCommentReplies(commentId: String, userId: String, limit: Int = 20) async throws -> [VideoComment] {
        do {
            let repliesDB: [VideoCommentDB] = try await client
                .from("video_comments")
                .select("*")
                .eq("parent_comment_id", value: commentId)
                .order("created_at", ascending: true)
                .limit(limit)
                .execute()
                .value
            
            // Convert to VideoComment and check if liked by current user
            var replies: [VideoComment] = []
            for replyDB in repliesDB {
                let isLiked = await isCommentLikedByUser(commentId: replyDB.id, userId: userId)
                let reply = replyDB.toVideoComment(isLikedByCurrentUser: isLiked)
                replies.append(reply)
            }
            
            print("✅ Retrieved \(replies.count) replies for comment: \(commentId)")
            return replies
        } catch {
            print("❌ Failed to get comment replies: \(error)")
            throw error
        }
    }
    
    /// Like/unlike a comment
    func toggleCommentLike(commentId: String, userId: String) async -> Bool {
        do {
            // Check if already liked
            let existingLikes: [VideoCommentLikeDB] = try await client
                .from("video_comment_likes")
                .select("*")
                .eq("comment_id", value: commentId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if !existingLikes.isEmpty {
                // Unlike the comment
                _ = try await client
                    .from("video_comment_likes")
                    .delete()
                    .eq("comment_id", value: commentId)
                    .eq("user_id", value: userId)
                    .execute()
                
                // Decrement likes count
                _ = try await client
                    .from("video_comments")
                    .update(["likes_count": "likes_count - 1"])
                    .eq("id", value: commentId)
                    .execute()
                
                print("✅ Comment unliked: \(commentId)")
                return false
            } else {
                // Like the comment
                let like = VideoCommentLikeDB(
                    id: UUID().uuidString,
                    comment_id: commentId,
                    user_id: userId,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("video_comment_likes")
                    .insert(like)
                    .execute()
                
                // Increment likes count
                _ = try await client
                    .from("video_comments")
                    .update(["likes_count": "likes_count + 1"])
                    .eq("id", value: commentId)
                    .execute()
                
                print("✅ Comment liked: \(commentId)")
                return true
            }
        } catch {
            print("❌ Failed to toggle comment like: \(error)")
            return false
        }
    }
    

    
    /// Share video (increment share count)
    func shareVideo(videoId: String) async {
        do {
            _ = try await client
                .from("video_content")
                .update(["shares_count": "shares_count + 1"])
                .eq("id", value: videoId)
                .execute()
            
            print("✅ Video share count incremented: \(videoId)")
        } catch {
            print("❌ Failed to increment video share count: \(error)")
        }
    }
    
    /// Delete video (only by owner)
    func deleteVideo(videoId: String, userId: String) async -> Bool {
        do {
            // Verify ownership
            let videos: [VideoContentDB] = try await client
                .from("video_content")
                .select("author_id")
                .eq("id", value: videoId)
                .execute()
                .value
            
            guard let video = videos.first, video.author_id == userId else {
                print("❌ User not authorized to delete video: \(videoId)")
                return false
            }
            
            // Delete video content
            _ = try await client
                .from("video_content")
                .delete()
                .eq("id", value: videoId)
                .execute()
            
            print("✅ Video deleted: \(videoId)")
            return true
        } catch {
            print("❌ Failed to delete video: \(error)")
            return false
        }
    }
    
    /// Get user's videos
    func getUserVideos(userId: String, limit: Int = 20, offset: Int = 0) async throws -> [VideoContent] {
        do {
            let videos: [VideoContentDB] = try await client
                .from("video_content")
                .select("*")
                .eq("author_id", value: userId)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
            
            let videoContents = videos.map { $0.toVideoContent() }
            print("✅ Retrieved \(videoContents.count) videos for user: \(userId)")
            return videoContents
        } catch {
            print("❌ Failed to get user videos: \(error)")
            throw error
        }
    }

    // MARK: - Location Privacy Management
    
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
        
        // Use upsert to insert or update
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
            // Return default settings if none found
            return LocationPrivacySettings(userID: userID)
        }
    }
    
    /// Check if a user is following another user
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
    
    /// Check if a user can see another user's location based on privacy settings
    func canUserSeeLocation(viewerID: String, targetUserID: String) async -> Bool {
        // User can always see their own location
        if viewerID == targetUserID {
            return true
        }
        
        guard let privacySettings = await loadLocationPrivacySettings(for: targetUserID) else {
            return false // Default to no access if settings can't be loaded
        }
        
        // Check public sharing first (highest precedence)
        if privacySettings.shareLocationPublicly {
            return true
        }
        
        // Check follower sharing
        if privacySettings.shareLocationWithFollowers {
            let isFollowing = await isUserFollowing(followerID: viewerID, followeeID: targetUserID)
            if isFollowing {
                return true
            }
        }
        
        // Check friend sharing (mutual following)
        if privacySettings.shareLocationWithFriends {
            let areMutualFriends = await areMutualFriends(user1: viewerID, user2: targetUserID)
            if areMutualFriends {
                return true
            }
        }
        
        return false // No access granted
    }
    
    /// Check if users are mutual friends (follow each other)
    private func areMutualFriends(user1: String, user2: String) async -> Bool {
        let user1FollowsUser2 = await isUserFollowing(followerID: user1, followeeID: user2)
        let user2FollowsUser1 = await isUserFollowing(followerID: user2, followeeID: user1)
        return user1FollowsUser2 && user2FollowsUser1
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
            // Add random offset within ~1km radius
            let latOffset = Double.random(in: -0.009...0.009) // ~1km in degrees
            let lonOffset = Double.random(in: -0.009...0.009)
            return (latitude + latOffset, longitude + lonOffset, nil)
            
        case .cityOnly:
            // Return only city name, no coordinates
            return (nil, nil, getCityName(latitude: latitude, longitude: longitude))
            
        case .hidden:
            return (nil, nil, nil)
        }
    }
    
    /// Get city name from coordinates (simplified - in practice would use reverse geocoding)
    private func getCityName(latitude: Double, longitude: Double) -> String {
        // This is a simplified implementation
        // In practice, you'd use CLGeocoder for reverse geocoding
        return "City" // Placeholder
    }
    
    /// Save location history entry with privacy controls
    func saveLocationHistory(
        userID: String,
        latitude: Double,
        longitude: Double,
        locationName: String?,
        activityType: String = "unknown"
    ) async throws {
        // Check if user allows location history
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
            country: "US", // Simplified
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

// MARK: - Deep Linking Support
extension SupabaseManager {
    /// Get user by username for deep linking
    func getUserByUsername(_ username: String) async throws -> AppUser {
        let basicUser: BasicUser = try await client
            .from("users")
            .select("*")
            .eq("username", value: username)
            .single()
            .execute()
            .value
        
        return basicUser.toAppUser()
    }
}

// MARK: - Encryption Support
extension SupabaseManager {
    /// Store user's public key for end-to-end encryption
    func storeUserPublicKey(userID: String, publicKey: String) async throws {
        let insert = UserPublicKeyDB(
            user_id: userID,
            public_key: publicKey,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        // Use upsert to handle key updates
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
    
    /// Send encrypted message
    func sendEncryptedMessage(
        conversationId: String,
        senderId: String,
        recipientId: String,
        content: String,
        messageType: MessageType = .text
    ) async throws -> String {
        // Get recipient's public key
        guard let recipientPublicKeyString = try await getUserPublicKey(userID: recipientId) else {
            throw EncryptionError.invalidKey("Recipient public key not found")
        }
        
        // Get sender's private key
        guard let senderPrivateKey = try? EncryptionManager.shared.retrievePrivateKey(for: senderId) else {
            throw EncryptionError.invalidKey("Sender private key not found")
        }
        
        // Convert recipient's public key string to key object
        let recipientPublicKey = try EncryptionManager.shared.stringToPublicKey(recipientPublicKeyString)
        
        // Encrypt the message
        let encryptedMessage = try EncryptionManager.shared.encryptMessage(
            content,
            senderPrivateKey: senderPrivateKey,
            recipientPublicKey: recipientPublicKey
        )
        
        // Store encrypted message in database
        let messageId = UUID().uuidString
        let messageInsert = MessageInsert(
            id: messageId,
            conversation_id: conversationId,
            sender_id: senderId,
            content: "", // Empty content for encrypted messages
            message_type: messageType.rawValue,
            is_encrypted: true,
            encrypted_content: encryptedMessage.ciphertext,
            encryption_nonce: encryptedMessage.nonce,
            encryption_tag: encryptedMessage.tag
        )
        
        try await client
            .from("messages")
            .insert(messageInsert)
            .execute()
        
        print("✅ [Encryption] Encrypted message sent")
        return messageId
    }
    
    /// Decrypt message for current user
    func decryptMessage(_ message: Message, currentUserId: String) async throws -> String {
        guard message.isEncrypted,
              let encryptedContent = message.encryptedContent,
              let nonce = message.encryptionNonce,
              let tag = message.encryptionTag else {
            // Return original content if not encrypted
            return message.content
        }
        
        // Get current user's private key
        let currentUserPrivateKey = try EncryptionManager.shared.retrievePrivateKey(for: currentUserId)
        
        // Get sender's public key
        guard let senderPublicKeyString = try await getUserPublicKey(userID: message.senderId) else {
            throw EncryptionError.invalidKey("Sender public key not found")
        }
        
        let senderPublicKey = try EncryptionManager.shared.stringToPublicKey(senderPublicKeyString)
        
        // Decrypt the message
        let encryptedMessage = EncryptedMessage(
            ciphertext: encryptedContent,
            nonce: nonce,
            tag: tag
        )
        
        return try EncryptionManager.shared.decryptMessage(
            encryptedMessage,
            recipientPrivateKey: currentUserPrivateKey,
            senderPublicKey: senderPublicKey
        )
    }
}

// MARK: - Encrypted Location Sharing
extension SupabaseManager {
    /// Share encrypted locations with friends
    func shareEncryptedLocations(_ encryptedLocations: [EncryptedLocation]) async throws {
        let locationInserts = encryptedLocations.map { location in
            SharedLocationDB(
                id: location.id.uuidString,
                created_at: ISO8601DateFormatter().string(from: Date()),
                sender_user_id: location.senderId.uuidString,
                recipient_user_id: location.recipientId.uuidString,
                ciphertext: location.encryptedData,
                nonce: "", // Extract from encrypted data
                tag: "", // Extract from encrypted data
                expires_at: ISO8601DateFormatter().string(from: location.expiresAt)
            )
        }
        
        try await client
            .from("shared_locations")
            .insert(locationInserts)
            .execute()
        
        print("✅ [Encryption] Shared \(encryptedLocations.count) encrypted locations")
    }
    
    /// Fetch user with friends and friend groups for location sharing
    func fetchUserWithFriends(userId: String) async throws -> AppUser {
        // First get the basic user
        let basicUser: BasicUser = try await client
            .from("users")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        // Get user's friend groups
        let friendGroups: [FriendGroupDB] = try await client
            .from("friend_groups")
            .select("*")
            .eq("user_id", value: userId)
            .execute()
            .value
        
        // Get friends from friend group members
        var friendIds: Set<String> = []
        for group in friendGroups {
            let members: [FriendGroupMemberDB] = try await client
                .from("friend_group_members")
                .select("*")
                .eq("group_id", value: group.id)
                .execute()
                .value
            
            for member in members {
                if member.member_user_id != userId {
                    friendIds.insert(member.member_user_id)
                }
            }
        }
        
        // Get friend user details
        var friends: [AppUser] = []
        if !friendIds.isEmpty {
            let friendUsers: [BasicUser] = try await client
                .from("users")
                .select("*")
                .in("id", values: Array(friendIds))
                .execute()
                .value
            
            friends = friendUsers.map { $0.toAppUser() }
        }
        
        // Convert to AppUser and add friend group info
        var appUser = basicUser.toAppUser()
        // Note: AppUser doesn't have friends or friend_groups properties in the current model
        // This functionality would need to be added to the AppUser model
        
        return appUser
    }
    
    /// Get user profile with public key
    func getUserProfile(with userId: String) async throws -> AppUser? {
        let basicUser: BasicUser = try await client
            .from("users")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        // Get user's public key
        let publicKey = try? await getUserPublicKey(userID: userId)
        
        var appUser = basicUser.toAppUser()
        // Note: AppUser doesn't have publicKeyString property in the current model
        // This functionality would need to be added to the AppUser model
        
        return appUser
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
}