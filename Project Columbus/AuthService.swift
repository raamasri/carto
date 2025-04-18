//
//  AuthService.swift
//  Project Columbus
//
//  Created by raama srivatsan on 4/17/25.
//
import Supabase


class AuthService {
    static let shared = AuthService()
    private let client = SupabaseManager.shared.client

    func signUp(email: String, password: String) async throws -> AuthResponse {
        return try await client.auth.signUp(email: email, password: password)
    }

    func login(email: String, password: String) async throws {
        _ = try await client.auth.signIn(email: email, password: password)
    }

    func logout() async throws {
        try await client.auth.signOut()
    }

    func getCurrentUser() -> Supabase.User? {
        return client.auth.currentUser
    }
}
