//
//  SupabaseManager.swift
//  Project Columbus
//
//  Created by raama srivatsan on 4/17/25.
//

import Supabase
import Foundation
import CryptoKit

class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let supabaseUrl = URL(string: "https://rthgzxorsccgeztwaxnt.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0aGd6eG9yc2NjZ2V6dHdheG50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ4NTYyNTMsImV4cCI6MjA2MDQzMjI1M30.mbXmJTsBIMHdlL_lcSAX0Zd87YH-_jDkWb8H6W1wW6I"

        self.client = SupabaseClient(
            supabaseURL: supabaseUrl,
            supabaseKey: supabaseKey
        )
    }
    
    func getCurrentUsername() async -> String? {
        do {
            let session = try await client.auth.session
            let userId = session.user.id

            struct UserResponse: Decodable {
                let username: String
            }

            let user: UserResponse = try await client
                .from("users")
                .select("username")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            return user.username
        } catch {
            print("Error fetching username: \(error)")
        }

        return nil
    }
    
    /// Signs up a new user and creates their profile record
    func signUp(username: String, email: String, password: String) async throws -> Session {
        // 1. Create the auth user
        let authResponse = try await client.auth.signUp(email: email, password: password)
        guard let session = authResponse.session else {
            throw NSError(domain: "SupabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Sign-up failed"])
        }
        let user = authResponse.user

        // 2. Check for existing user
        struct ExistingUserResponse: Decodable {
            let id: String
        }

        let existingRows: [ExistingUserResponse] = try await client
            .from("users")
            .select("id")
            .eq("id", value: user.id.uuidString)
            .limit(1)
            .execute()
            .value
        if !existingRows.isEmpty {
            print("User already exists in users table, skipping insert.")
        } else {
            // 3. Insert into your public users table
            _ = try await client
                .from("users")
                .insert([
                    "id": user.id.uuidString,
                    "username": username,
                    "email": email
                ])
                .execute()
        }

        return session
    }
    
    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        let response = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        
        let session = response
    
        let userId = response.user.id.uuidString
        struct ExistingUserResponse: Decodable {
            let id: String
        }

        let existing: [ExistingUserResponse] = try await client
            .from("users")
            .select("id")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value

        if existing.isEmpty {
            _ = try await client
                .from("users")
                .insert([
                    "id": userId,
                    "username": "new_user_\(Int.random(in: 1000...9999))",
                    "email": response.user.email ?? ""
                ])
                .execute()
        }
    
        return session
    }

    func searchUsers(byUsername username: String) async -> [AppUser] {
        do {
            struct SupabaseUser: Decodable {
                let id: String
                let username: String
                let full_name: String
                let email: String
                let bio: String?
                let follower_count: Int
                let following_count: Int
                let isFollowedByCurrentUser: Bool
                let latitude: Double?
                let longitude: Double?
            }
            
            let users: [SupabaseUser] = try await client
                .from("users")
                .select("id, username, full_name, email, bio, follower_count, following_count, isFollowedByCurrentUser, latitude, longitude")
                .filter("username", operator: "ilike", value: "%\(username)%")
                .execute()
                .value
            
            return users.map { user in
                AppUser(
                    id: user.id,
                    username: user.username,
                    full_name: user.full_name,
                    email: user.email,
                    bio: user.bio ?? "",
                    follower_count: user.follower_count,
                    following_count: user.following_count,
                    isFollowedByCurrentUser: user.isFollowedByCurrentUser,
                    latitude: user.latitude ?? 0.0,
                    longitude: user.longitude ?? 0.0
                )
            }
        } catch {
            print("Error searching users: \(error)")
            return []
        }
    }

    func fetchUserProfile(userID: String) async -> AppUser? {
        do {
            struct SupabaseUser: Decodable {
                let id: String
                let username: String
                let full_name: String
                let email: String
                let bio: String?
                let follower_count: Int
                let following_count: Int
                let isFollowedByCurrentUser: Bool
                let latitude: Double?
                let longitude: Double?
            }
 
            let users: [SupabaseUser] = try await client
                .from("users")
                .select("id, username, full_name, email, bio, follower_count, following_count, latitude, longitude")
                .eq("id", value: userID)
                .execute()
                .value
 
            guard let user = users.first else { return nil }
 
            return AppUser(
                id: user.id,
                username: user.username,
                full_name: user.full_name,
                email: user.email,
                bio: user.bio ?? "",
                follower_count: user.follower_count,
                following_count: user.following_count,
                isFollowedByCurrentUser: user.isFollowedByCurrentUser,
                latitude: user.latitude ?? 0.0,
                longitude: user.longitude ?? 0.0
            )
        } catch {
            print("Error fetching user profile: \(error)")
            return nil
        }
    }

    func fetchAllUsers() async throws -> [AppUser] {
        struct SupabaseUser: Decodable {
            let id: String
            let username: String
            let full_name: String
            let email: String
            let bio: String?
            let follower_count: Int
            let following_count: Int
            let latitude: Double?
            let longitude: Double?
        }

        let users: [SupabaseUser] = try await client
            .from("users")
            .select("id, username, full_name, email, bio, follower_count, following_count, latitude, longitude")
            .execute()
            .value

        return users.map { user in
            AppUser(
                id: user.id,
                username: user.username,
                full_name: user.full_name,
                email: user.email,
                bio: user.bio ?? "",
                follower_count: user.follower_count,
                following_count: user.following_count,
                isFollowedByCurrentUser: false,
                latitude: user.latitude ?? 0.0,
                longitude: user.longitude ?? 0.0
            )
        }
    }

    /// Updates the user's profile fields on the backend.
    func updateUserProfile(userID: String, fullName: String, email: String, bio: String) async throws {
        let response = try await client
            .from("users")
            .update([
                "full_name": fullName,
                "email": email,
                "bio": bio
            ])
            .eq("id", value: userID)
            .execute()
        print("Supabase updateUserProfile response:", response)
    }
    
    func updateUserLocation(userID: String, latitude: Double, longitude: Double) async {
        do {
            let _ = try await client
                .from("users")
                .update([
                    "latitude": latitude,
                    "longitude": longitude
                ])
                .eq("id", value: userID)
                .execute()
            print("Successfully updated location.")
        } catch {
            print("Error updating user location: \(error)")
        }
    }
}

import CryptoKit

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

    
    
    // MARK: - Follow Logic

    func followUser(followingID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        let followerID = session.user.id

        let result = try? await client
            .from("follows")
            .insert([
                "follower_id": followerID.uuidString,
                "following_id": followingID.uuidString
            ])
            .execute()

        return result != nil
    }

    func unfollowUser(followingID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        let followerID = session.user.id

        let result = try? await client
            .from("follows")
            .delete()
            .eq("follower_id", value: followerID.uuidString)
            .eq("following_id", value: followingID.uuidString)
            .execute()

        return result != nil
    }

    func getFollowers(of userID: UUID) async -> [UUID] {
        let result = try? await client
            .from("follows")
            .select("follower_id")
            .eq("following_id", value: userID.uuidString)
            .execute()

        guard let rows = result?.value as? [[String: Any]] else { return [] }
        return rows.compactMap { UUID(uuidString: $0["follower_id"] as? String ?? "") }
    }

    func getFollowing(for userID: UUID) async -> [UUID] {
        let result = try? await client
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: userID.uuidString)
            .execute()

        guard let rows = result?.value as? [[String: Any]] else { return [] }
        return rows.compactMap { UUID(uuidString: $0["following_id"] as? String ?? "") }
    }

    func isFollowing(userID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        let followerID = session.user.id

        let result = try? await client
            .from("follows")
            .select("id")
            .eq("follower_id", value: followerID.uuidString)
            .eq("following_id", value: userID.uuidString)
            .limit(1)
            .execute()

        guard let rows = result?.value as? [[String: Any]] else { return false }
        return !rows.isEmpty
    }
    
    /// Toggles follow status for a user by their string ID, returning true if now following.
    func toggleFollowStatus(targetUserID: String) async -> Bool {
        guard let uuid = UUID(uuidString: targetUserID) else { return false }
        if await isFollowing(userID: uuid) {
            // Currently following, so unfollow
            let didUnfollow = await unfollowUser(followingID: uuid)
            return !didUnfollow
        } else {
            // Not following yet, so follow
            let didFollow = await followUser(followingID: uuid)
            return didFollow
        }
    }
}
