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
        guard let session = try? await client.auth.session else { return [] }
        
        do {
            let listsDB: [ListDB] = try await client
                .from("lists")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
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
            print("❌ Failed to fetch lists: \(error)")
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
            // Get the follow relationships where the user is the follower
            let follows: [FollowDB] = try await client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: userID)
                .execute()
                .value
            
            let followingIds = follows.map { $0.following_id }
            if followingIds.isEmpty { return [] }
            
            // Get the user details for all following users
            let followingUsers: [AppUser] = try await client
                .from("users")
                .select("*")
                .in("id", value: followingIds)
                .execute()
                .value
            
            return followingUsers
        } catch {
            print("❌ Failed to fetch following users: \(error)")
            return []
        }
    }
    
    /// Fetch all users
    func fetchAllUsers() async throws -> [AppUser] {
        return try await client
            .from("users")
            .select("*")
            .execute()
            .value
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
            let user: AppUser = try await client
                .from("users")
                .select("*")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            
            return user
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
            // For now, return false since we don't have a follow_requests table
            // This would need to be implemented when the follow request system is added
            return false
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
            let followers: [AppUser] = try await client
                .from("users")
                .select("*")
                .in("id", value: followerIds)
                .execute()
                .value
            
            return followers
        } catch {
            print("❌ Failed to fetch followers: \(error)")
            return []
        }
    }

    /// Search for users by username or full name
    func searchUsers(query: String) async -> [AppUser] {
        do {
            let searchTerm = query.replacingOccurrences(of: "@", with: "").lowercased()
            
            let users: [AppUser] = try await client
                .from("users")
                .select("*")
                .or("username.ilike.%\(searchTerm)%,full_name.ilike.%\(searchTerm)%")
                .limit(20)
                .execute()
                .value
            
            return users
        } catch {
            print("❌ Failed to search users: \(error)")
            return []
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
