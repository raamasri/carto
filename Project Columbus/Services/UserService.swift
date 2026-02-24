//
//  UserService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation

class UserService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
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
            
            struct FollowResponse: Codable {
                let following_id: String
            }
            
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
            
            struct CountResult: Codable {
                let count: Int
            }
            
            let followerCount: Int
            do {
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
            
            let followingCount: Int
            do {
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
            
            let selfFollowCount: Int
            do {
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
            
            return AppUser(
                id: basicUser.id,
                username: basicUser.username,
                full_name: basicUser.full_name,
                email: basicUser.email,
                bio: basicUser.bio,
                follower_count: max(0, followerCount - selfFollowCount),
                following_count: max(0, followingCount - selfFollowCount),
                isFollowedByCurrentUser: false,
                latitude: basicUser.latitude,
                longitude: basicUser.longitude,
                isCurrentUser: false,
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
    
    /// Fetch user with friends and friend groups for location sharing
    func fetchUserWithFriends(userId: String) async throws -> AppUser {
        let basicUser: BasicUser = try await client
            .from("users")
            .select("*")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        let friendGroups: [FriendGroupDB] = try await client
            .from("friend_groups")
            .select("*")
            .eq("user_id", value: userId)
            .execute()
            .value
        
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
        
        var appUser = basicUser.toAppUser()
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
        
        let publicKey = try? await getUserPublicKey(userID: userId)
        
        var appUser = basicUser.toAppUser()
        return appUser
    }
    
    // MARK: - Private Helpers
    
    /// Get blocked users
    private func getBlockedUsers() async -> [AppUser] {
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
    
    /// Retrieve user's public key for end-to-end encryption
    private func getUserPublicKey(userID: String) async throws -> String? {
        let response: [UserPublicKeyDB] = try await client
            .from("user_public_keys")
            .select("public_key")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value
        
        return response.first?.public_key
    }
}
