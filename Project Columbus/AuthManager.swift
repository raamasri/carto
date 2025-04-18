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
    
    init() {
        checkSession()
    }
    
    @Published var isLoggedIn = false
    @Published var currentUsername: String?
    @Published var lastUsedPassword: String = ""

    func logIn(username: String, password: String) async -> Bool {
        do {
            try await AuthService.shared.login(email: username, password: password)
            self.currentUsername = username
            self.isLoggedIn = true
            self.lastUsedPassword = password
            if !biometricEnabled && !biometricPromptShown {
                biometricPromptShown = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NotificationCenter.default.post(name: .showBiometricPrompt, object: nil)
                }
            }
            saveCredentialsToKeychain(username: username, password: password)
            return true
        } catch {
            print("Login failed: \(error)")
            self.isLoggedIn = false
            return false
        }
    }

    func logOut() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                DispatchQueue.main.async {
                    self.currentUsername = nil
                    self.isLoggedIn = false
                }
            } catch {
                print("Failed to log out:", error)
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
}

extension Notification.Name {
    static let showBiometricPrompt = Notification.Name("showBiometricPrompt")
}
