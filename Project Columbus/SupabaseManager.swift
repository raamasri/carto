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
    let baseURL: URL
    
    let client: SupabaseClient

    private init() {
        let supabaseUrl = URL(string: "https://rthgzxorsccgeztwaxnt.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0aGd6eG9yc2NjZ2V6dHdheG50Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ4NTYyNTMsImV4cCI6MjA2MDQzMjI1M30.mbXmJTsBIMHdlL_lcSAX0Zd87YH-_jDkWb8H6W1wW6I"
        
        self.baseURL = supabaseUrl
        
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
            let session = try await client.auth.session
            let currentUserID = session.user.id.uuidString

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
                .filter("username", operator: "ilike", value: "%\(username)%")
                .execute()
                .value

            let followingIDs = await getFollowing(for: session.user.id)

            return users.map { user in
                AppUser(
                    id: user.id,
                    username: user.username,
                    full_name: user.full_name,
                    email: user.email,
                    bio: user.bio ?? "",
                    follower_count: user.follower_count,
                    following_count: user.following_count,
                    isFollowedByCurrentUser: followingIDs.contains(UUID(uuidString: user.id) ?? UUID()),
                    latitude: user.latitude ?? 0.0,
                    longitude: user.longitude ?? 0.0,
                    isCurrentUser: user.id.lowercased() == currentUserID.lowercased(),
                    avatarURL: ""
                )
            }
        } catch {
            print("Error searching users: \(error)")
            return []
        }
    }

    func fetchUserProfile(userID: String) async -> AppUser? {
        do {
            let session = try await client.auth.session
            let currentUserID = session.user.id.uuidString
            struct SupabaseUser: Decodable {
                let id: String
                let username: String
                let full_name: String?
                let email: String
                let bio: String?
                let follower_count: Int
                let following_count: Int
                let latitude: Double?
                let longitude: Double?
                let avatar_url: String?
            }

            let users: [SupabaseUser] = try await client
                .from("users")
                .select("id, username, full_name, email, bio, follower_count, following_count, latitude, longitude, avatar_url")
                .eq("id", value: userID)
                .execute()
                .value

            guard let user = users.first else { return nil }

            let isFollowing = await isFollowing(userID: UUID(uuidString: user.id) ?? UUID())

            return AppUser(
                id: user.id,
                username: user.username,
                full_name: user.full_name ?? "",
                email: user.email,
                bio: user.bio ?? "",
                follower_count: user.follower_count,
                following_count: user.following_count,
                isFollowedByCurrentUser: isFollowing,
                latitude: user.latitude ?? 0.0,
                longitude: user.longitude ?? 0.0,
                isCurrentUser: user.id.lowercased() == currentUserID.lowercased(),
                avatarURL: user.avatar_url ?? ""
            )
        } catch {
            print("Error fetching user profile: \(error)")
            return nil
        }
    }

    func fetchAllUsers() async throws -> [AppUser] {
        let session = try await client.auth.session
        let currentUserID = session.user.id.uuidString

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

        let followingIDs = await getFollowing(for: session.user.id)

        print("📦 fetchAllUsers: fetched \(users.count) users from Supabase")
        
        for user in users {
            print("🔍 User: \(user.username), lat: \(String(describing: user.latitude)), lon: \(String(describing: user.longitude)), id: \(user.id)")
        }
        
        let filteredUsers = users
            .filter { $0.id.lowercased() != currentUserID.lowercased() }
        
        print("✅ Returning \(filteredUsers.count) users after filtering current user")
        
        return filteredUsers.map { user in
            AppUser(
                id: user.id,
                username: user.username,
                full_name: user.full_name,
                email: user.email,
                bio: user.bio ?? "",
                follower_count: user.follower_count,
                following_count: user.following_count,
                isFollowedByCurrentUser: followingIDs.contains(UUID(uuidString: user.id) ?? UUID()),
                latitude: user.latitude ?? 0.0,
                longitude: user.longitude ?? 0.0,
                isCurrentUser: false,
                avatarURL: ""
            )
        }
    }

    /// Updates the user's profile fields on the backend.
    /// Updates the user's profile fields on the backend.
    func updateUserProfile(
        userID: String,
        username: String,
        fullName: String,
        email: String,
        bio: String,
        avatarURL: String?
    ) async throws {
        // Debug: check if a profile row exists before update
        let existingProfile = await fetchUserProfile(userID: userID)
        print("Supabase existing profile before update:", existingProfile as Any)
        print("Sending bio:", bio)
        
        if existingProfile == nil {
            // Insert a new profile row since none exists
            let insertResponse = try await client
                .from("users")
                .insert([
                    "id": userID,
                    "username": username,
                    "full_name": fullName,
                    "email": email,
                    "bio": bio,
                    "avatar_url": avatarURL ?? ""
                ])
                .execute()
            print("Supabase insertUserProfile response:", insertResponse)
        } else {
            // Existing row: perform update
            let response = try await client
                .from("users")
                .update([
                    "username": username,
                    "full_name": fullName,
                    "email": email,
                    "bio": bio,
                    "avatar_url": avatarURL ?? ""
                ])
                .eq("id", value: userID)
                .execute()
            print("Supabase updateUserProfile response:", response)
        }
    }
    func getFollowers(for userID: String) async -> [AppUser] {
        do {
            let response: PostgrestResponse<[AppUser]> = try await client.rpc("get_followers", params: ["target_user_id": userID]).execute()
            return decodeAppUsers(from: response)
        } catch {
            print("Error fetching followers: \(error)")
            return []
        }
    }

    func getFollowingUsers(for userID: String) async -> [AppUser] {
        do {
            let response: PostgrestResponse<[AppUser]> = try await client.rpc("get_following", params: ["user_id": userID]).execute()
            return decodeAppUsers(from: response)
        } catch {
            print("Error fetching following users: \(error)")
            return []
        }
    }

    private func decodeAppUsers(from response: PostgrestResponse<[AppUser]>) -> [AppUser] {
        return (try? response.value) ?? []
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
    
    func uploadProfileImage(_ imageData: Data, for userID: String) async throws -> URL {
        let fileName = "\(userID)-avatar.jpg"
        print("Uploading profile image with fileName: \(fileName)")

        let session = try await client.auth.session
        let currentUserID = session.user.id.uuidString
        print("Current authenticated user ID: \(currentUserID)")
        print("Target user ID for upload: \(userID)")

        let uploadOptions = FileOptions(
            contentType: "image/jpeg",
            upsert: true,
            metadata: ["owner": AnyJSON.string(currentUserID)]
        )
        print("Upload options: \(uploadOptions)")
        print("🔍 Uploading avatar with fileName:", fileName)
        print("🔍 Upload options metadata:", uploadOptions.metadata)

        do {
            let uploadResponse = try await client.storage
                .from("profile-images")
                .upload(
                    fileName,
                    data: imageData,
                    options: uploadOptions
                )
            print("✅ Upload succeeded:", uploadResponse)
        } catch let storageError as StorageError {
            print("❌ StorageError uploading avatar - statusCode:", storageError.statusCode ?? "nil",
                  "message:", storageError.message ?? "nil",
                  "error:", storageError.error ?? "nil")
            throw storageError
        } catch {
            print("❌ Unexpected error uploading avatar:", error)
            throw error
        }

        // Build public URL
        let urlString = "https://rthgzxorsccgeztwaxnt.supabase.co/storage/v1/object/public/profile-images/\(fileName)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        print("Generated public URL: \(url)")
        return url
    }
}
