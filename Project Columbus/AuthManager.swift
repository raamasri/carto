//
//  AuthManager.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/17/25.
//

import Foundation
import Supabase
import LocalAuthentication
import Security
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = false
    @AppStorage("biometricPromptShown") private var biometricPromptShown: Bool = false
    @Published var appleSignInErrorMessage: String?
    
    init() {
        checkSession()
    }
    
    @Published var isLoggedIn = false
    @Published var currentUsername: String?
    @Published var currentUserID: String?
    @Published var currentUser: AppUser? = nil
    @Published var lastUsedPassword: String = ""

    func logIn(username: String, password: String) async -> Bool {
        do {
            try await AuthService.shared.login(email: username, password: password)
            self.currentUsername = username
            self.isLoggedIn = true
            if let user = try? await SupabaseManager.shared.client.auth.user() {
                self.currentUserID = user.id.uuidString
                await fetchCurrentUser()
            }
            self.lastUsedPassword = password
            if !biometricEnabled && !biometricPromptShown {
                biometricPromptShown = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    NotificationCenter.default.post(name: .showBiometricPrompt, object: nil)
                }
            }
            saveCredentialsToKeychain(username: username, password: password)
            return true
        } catch {
            self.isLoggedIn = false
            return false
        }
    }
    
    func signUp(email: String, password: String, username: String, fullName: String, phone: String) async throws {
        do {
        let response = try await AuthService.shared.signUp(email: email, password: password)
            
            let userId = response.user.id

            let insertData = UserInsert(id: userId.uuidString, username: username, email: email, phone: phone, full_name: fullName)
            _ = try await SupabaseManager.shared.client
                .from("users")
                .insert(insertData)
                .execute()
            
            self.isLoggedIn = true
            self.currentUsername = username
        } catch {
            self.isLoggedIn = false

            // Check for "account already exists" type of error
            let lowercasedMessage = error.localizedDescription.lowercased()
            if lowercasedMessage.contains("user already registered") || lowercasedMessage.contains("already exists") {
                throw NSError(domain: "", code: 409, userInfo: [NSLocalizedDescriptionKey: "An account with this email already exists."])
            }

            throw error
        }
    }
    
    func logOut() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                DispatchQueue.main.async {
                    self.currentUsername = nil
                    self.isLoggedIn = false
                    self.currentUserID = nil
                }
            } catch {
                // Handle logout error silently
            }
        }
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

            if let user = try? await SupabaseManager.shared.client.auth.user() {
                let existing: [UserInsert] = try await SupabaseManager.shared.client
                    .from("users")
                    .select("id")
                    .eq("id", value: user.id.uuidString)
                    .limit(1)
                    .execute()
                    .value

                if existing.isEmpty {
                    // Create new user with temporary username
                    let tempUsername = "user_\(Int.random(in: 1000...9999))"
                    let newUser = UserInsert(
                        id: user.id.uuidString,
                        username: tempUsername,
                        email: user.email ?? "",
                        phone: "",
                        full_name: user.userMetadata["full_name"] as? String ?? ""
                    )
                    _ = try await SupabaseManager.shared.client
                        .from("users")
                        .insert(newUser)
                        .execute()
                    
                    // Prompt UI to collect custom username
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .showUsernamePrompt, object: nil)
                    }
                }

                self.currentUsername = user.email
                self.currentUserID = user.id.uuidString
                await fetchCurrentUser()
            }

            return true
        } catch {
            let lowercasedMessage = error.localizedDescription.lowercased()
            if lowercasedMessage.contains("already registered") || lowercasedMessage.contains("already exists") {
                self.appleSignInErrorMessage = "An account with this email already exists. Try signing in with your original method."
            } else {
                self.appleSignInErrorMessage = "Apple Sign-In failed. Please try again."
            }

            self.isLoggedIn = false
            return false
        }
    }
    
    func checkSession() {
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                DispatchQueue.main.async {
                    self.isLoggedIn = !session.accessToken.isEmpty
                    self.currentUsername = session.user.email
                    self.currentUserID = session.user.id.uuidString
                }
                Task {
                    await self.fetchCurrentUser()
                }
            } catch {
                // Log error but don't expose sensitive session details
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                }
            }
        }
    }
    
    func authenticateWithBiometrics(successHandler: @escaping () -> Void, errorHandler: @escaping (String) -> Void) {
        guard biometricEnabled else {
            errorHandler("Biometric login is disabled in settings.")
            return
        }
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Log in with Face ID / Touch ID"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if let credentials = self.retrieveCredentialsFromKeychain() {
                        Task {
                            let success = await self.logIn(username: credentials.username, password: credentials.password)
                            if success {
                                successHandler()
                            } else {
                                errorHandler("Biometric login failed.")
                            }
                        }
                    } else {
                        errorHandler("No saved credentials found.")
                    }
                }
            }
        } else {
            errorHandler("Biometric authentication not available.")
        }
    }
    
    func autoLoginWithBiometricsIfEnabled(successHandler: @escaping () -> Void, errorHandler: @escaping (String) -> Void) {
        guard biometricEnabled else { return }
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to log in"

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        if let credentials = self.retrieveCredentialsFromKeychain() {
                            Task {
                                let success = await self.logIn(username: credentials.username, password: credentials.password)
                                if success {
                                    successHandler()
                                } else {
                                    errorHandler("Biometric auto-login failed.")
                                }
                            }
                        } else {
                            errorHandler("No saved credentials found.")
                        }
                    } else {
                        errorHandler("Biometric authentication failed.")
                    }
                }
            }
        }
    }
    
    func saveCredentialsToKeychain(username: String, password: String) {
        let credentialsData = "\(username):\(password)".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "carto.credentials",
            kSecValueData as String: credentialsData
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func retrieveCredentialsFromKeychain() -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "carto.credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let credentialString = String(data: data, encoding: .utf8),
           let separatorIndex = credentialString.firstIndex(of: ":") {
            let username = String(credentialString[..<separatorIndex])
            let password = String(credentialString[credentialString.index(after: separatorIndex)...])
            return (username, password)
        }
        return nil
    }
    
    func fetchCurrentUser() async {
        guard let id = currentUserID else { return }
        do {
            let response: [SelfUser] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("id", value: id)
                .limit(1)
                .execute()
                .value

            if let user = response.first {
                let appUser = AppUser(
                    id: user.id,
                    username: user.username,
                    full_name: user.full_name,
                    email: user.email,
                    bio: user.bio ?? "",
                    follower_count: user.follower_count,
                    following_count: user.following_count,
                    isFollowedByCurrentUser: false,
                    latitude: user.latitude,
                    longitude: user.longitude,
                    isCurrentUser: true,
                    avatarURL: user.avatarURL ?? ""
                )
                print("✅ currentUser fetched:", appUser.username)
                self.currentUser = appUser
            } else {
                print("⚠️ No user found with id:", id)
            }
        } catch {
            print("❌ Failed to fetch currentUser:", error)
        }
    }

    func deleteAccount(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                // Delete the user from Supabase auth
                try await SupabaseManager.shared.client.auth.admin.deleteUser(id: currentUserID ?? "")
                
                // Also remove user from 'users' table
                if let id = currentUserID {
                    _ = try await SupabaseManager.shared.client
                        .from("users")
                        .delete()
                        .eq("id", value: id)
                        .execute()
                }

                DispatchQueue.main.async {
                    self.currentUsername = nil
                    self.isLoggedIn = false
                    self.currentUserID = nil
                    completion(true)
                }
            } catch {
                print("❌ Failed to delete account:", error)
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
}

extension Notification.Name {
    static let showBiometricPrompt = Notification.Name("showBiometricPrompt")
    static let showUsernamePrompt = Notification.Name("showUsernamePrompt")
}
