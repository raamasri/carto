//
//  AuthManager.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/17/25.
//

import Foundation
import Supabase

class AuthManager: ObservableObject {
    @Published var isLoggedIn = false

    func logIn(username: String, password: String) async -> Bool {
        do {
            try await AuthService.shared.login(email: username, password: password)
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
    
    func checkSession() {
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                DispatchQueue.main.async {
                    self.isLoggedIn = (session != nil)
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
