//
//  SupabaseManager.swift
//  Project Columbus
//
//  Created by raama srivatsan on 4/17/25.
//

import Supabase
import Foundation
import CryptoKit

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

    /// Checks if a follow request exists between the current user and a target user
    func hasFollowRequestSent(to userID: UUID) async -> Bool {
        do {
            // Define a simple decodable struct for the notification response
            struct NotificationResponse: Decodable {
                let id: UUID
            }
            guard let session = try? await client.auth.session else { return false }
            let currentUserID = session.user.id.uuidString.lowercased()

            // Execute and capture raw response for debugging
            let resp: PostgrestResponse<[NotificationResponse]> = try await client
                .from("notifications")
                .select("id")
                .eq("user_id", value: userID.uuidString.lowercased())
                .eq("from_user_id", value: currentUserID)
                .eq("type", value: "follow_request")
                .limit(1)
                .execute()

            // Extract decoded value
            let notifications = resp.value
            return !notifications.isEmpty
        } catch {
            print("Error checking follow request: \(error)")
            return false
        }
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
            // Log error silently in production
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
        
        let filteredUsers = users
            .filter { $0.id.lowercased() != currentUserID.lowercased() }
        
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
        let existingProfile = await fetchUserProfile(userID: userID)
        
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
        } else {
            // Existing row: perform update
            _ = try await client
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
        }
    }
    func getFollowers(for userID: String) async -> [AppUser] {
        do {
            let session = try await client.auth.session
            let currentUserID = session.user.id.uuidString

            let response: PostgrestResponse<[AppUser]> = try await client
                .rpc("get_followers_with_status", params: [
                    "current_user_id": currentUserID,
                    "viewed_user_id": userID
                ])
                .execute()

            return decodeAppUsers(from: response)
        } catch {
            return []
        }
    }

    func getFollowingUsers(for userID: String) async -> [AppUser] {
        do {
            let session = try await client.auth.session
            let currentUserID = session.user.id.uuidString

            let response: PostgrestResponse<[AppUser]> = try await client
                .rpc("get_following_users_with_status", params: [
                    "current_user_id": currentUserID,
                    "viewed_user_id": userID
                ])
                .execute()

            return decodeAppUsers(from: response)
        } catch {
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
        } catch {
            // Handle error silently
        }
    }

    /// Checks if a username is available (not already taken)
    func isUsernameAvailable(username: String) async -> Bool {
        do {
            let result: [[String: String]] = try await client
                .from("users")
                .select("id")
                .eq("username", value: username)
                .limit(1)
                .execute()
                .value
            return result.isEmpty
        } catch {
            print("Error checking username availability: \(error)")
            return false // Assume not available on error
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

        do {
            let rpcResponse: PostgrestResponse<Void> = try await client
                .rpc("rpc_follow_and_notify", params: [
                    "p_follower": followerID.uuidString,
                    "p_following": followingID.uuidString
                ])
                .execute()

            print("🚀 rpc_follow_and_notify response:", rpcResponse)
            return true
        } catch {
            print("❌ rpc_follow_and_notify failed:", error)
            return false
        }
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
        print("🔍 Upload options metadata:", uploadOptions.metadata!)

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
