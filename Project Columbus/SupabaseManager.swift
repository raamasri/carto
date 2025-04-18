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
}
