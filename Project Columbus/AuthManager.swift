//
//  AuthManager.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/17/25.
//

import Foundation
import Supabase

@MainActor
class AuthManager: ObservableObject {
      init() {
          checkSession()
      }
    @Published var isLoggedIn = false
    @Published var currentUsername: String?

    func logIn(username: String, password: String) async -> Bool {
        do {
            try await AuthService.shared.login(email: username, password: password)
            self.currentUsername = username
            self.isLoggedIn = true
            return true
        } catch {
            print("Login failed: \(error)")
            self.isLoggedIn = false
            return false
        }
    }

    func logOut() {
        isLoggedIn = false
    }
    
    @MainActor
    func signInWithApple() async -> Bool {
        do {
            // Launch Apple OAuth flow via Supabase
            try await SupabaseManager.shared.client.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: URL(string: "com.carto.signin://login-callback")
            )
            self.isLoggedIn = true
            return true
        } catch {
            print("Apple sign-in failed:", error)
            self.isLoggedIn = false
            return false
        }
    }
    
    func checkSession() {
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                DispatchQueue.main.async {
                    self.isLoggedIn = (session != nil)
                    self.currentUsername = session.user.email
                }
            } catch {
                print("Failed to check session: \(error)")
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                }
            }
        }
    }
}
