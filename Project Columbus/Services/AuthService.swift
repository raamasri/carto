//
//  AuthService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation
import CryptoKit

class AuthService {
    static let shared = AuthService(client: SupabaseManager.shared.client)
    
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    // MARK: - Email Auth
    
    func signUp(email: String, password: String) async throws -> AuthResponse {
        return try await client.auth.signUp(email: email, password: password)
    }
    
    func login(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }
    
    func logout() async throws {
        try await client.auth.signOut()
    }
    
    func getSupabaseUser() -> Supabase.User? {
        return client.auth.currentUser
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
    
    /// Gets the current authenticated user as AppUser
    func getCurrentUser() async throws -> AppUser {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
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
    
    // MARK: - Apple Sign In Crypto Helpers
    
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
