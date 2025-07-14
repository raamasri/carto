//
//  AuthManager.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/17/25.
//
//  DESCRIPTION:
//  This file contains the main authentication management system for Project Columbus (Carto).
//  It handles user authentication, session management, biometric authentication, and secure
//  credential storage using keychain services.
//
//  FEATURES:
//  - Email/password authentication
//  - Apple Sign-In integration
//  - Biometric authentication (Face ID/Touch ID)
//  - Secure keychain credential storage
//  - Session management and auto-login
//  - User profile management
//  - End-to-end encryption key management
//  - Account deletion functionality
//
//  ARCHITECTURE:
//  - ObservableObject for reactive UI updates
//  - Async/await patterns for modern concurrency
//  - Keychain Services for secure storage
//  - LocalAuthentication for biometric security
//  - Supabase integration for backend authentication
//

import Foundation
import Supabase
import LocalAuthentication
import Security
import SwiftUI

// MARK: - Authentication Error Handling

/**
 * AuthError
 * 
 * Comprehensive error types for authentication operations.
 * These errors provide user-friendly messages and help with
 * proper error handling throughout the authentication flow.
 */
enum AuthError: LocalizedError {
    case accountAlreadyExists
    case invalidCredentials
    case networkError
    case biometricNotAvailable
    case biometricAuthenticationFailed
    case sessionExpired
    case unknown(String)
    
    /// Human-readable error descriptions for user feedback
    var errorDescription: String? {
        switch self {
        case .accountAlreadyExists:
            return "An account with this email already exists."
        case .invalidCredentials:
            return "Invalid email or password."
        case .networkError:
            return "Network connection error. Please try again."
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device."
        case .biometricAuthenticationFailed:
            return "Biometric authentication failed."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Authentication Manager

/**
 * AuthManager
 * 
 * The central authentication manager that handles all user authentication operations.
 * This class provides a unified interface for login, signup, session management,
 * and biometric authentication while maintaining secure credential storage.
 * 
 * RESPONSIBILITIES:
 * - User authentication (email/password, Apple Sign-In)
 * - Session management and persistence
 * - Biometric authentication setup and usage
 * - Secure credential storage in keychain
 * - User profile management
 * - Encryption key management for secure messaging
 * - Account deletion and cleanup
 * 
 * SECURITY FEATURES:
 * - Keychain-based credential storage
 * - Biometric authentication integration
 * - Session validation and refresh
 * - Secure password handling
 * - End-to-end encryption key management
 */
@MainActor
class AuthManager: ObservableObject {
    
    // MARK: - Persistent Settings
    
    /// Controls whether biometric authentication is enabled
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = false
    
    /// Tracks whether the biometric setup prompt has been shown
    @AppStorage("biometricPromptShown") private var biometricPromptShown: Bool = false
    
    // MARK: - Published Properties
    
    /// Current user login state
    @Published var isLoggedIn = false
    
    /// Current user's username/email
    @Published var currentUsername: String?
    
    /// Current user's unique identifier
    @Published var currentUserID: String?
    
    /// Complete user profile information
    @Published var currentUser: AppUser? = nil
    
    /// Last used password for biometric authentication
    @Published var lastUsedPassword: String = ""
    
    /// Error message for Apple Sign-In failures
    @Published var appleSignInErrorMessage: String?
    
    // MARK: - Initialization
    
    /**
     * Initializes the authentication manager and checks for existing sessions
     * This ensures the app starts with the correct authentication state
     */
    init() {
        Task {
            await checkSession()
        }
    }
    
    // MARK: - Email/Password Authentication
    
    /**
     * Authenticates user with email and password
     * 
     * @param username User's email address
     * @param password User's password
     * @return Boolean indicating login success
     * 
     * This method handles the complete login flow including:
     * - Supabase authentication
     * - Session establishment
     * - User profile fetching
     * - Biometric setup prompting
     * - Secure credential storage
     */
    func logIn(username: String, password: String) async -> Bool {
        do {
            // Authenticate with Supabase
            try await AuthService.shared.login(email: username, password: password)
            
            // Update authentication state
            self.currentUsername = username
            self.isLoggedIn = true
            
            // Fetch user information
            if let user = try? await SupabaseManager.shared.client.auth.user() {
                self.currentUserID = user.id.uuidString
                await fetchCurrentUser()
            }
            
            // Store password for biometric authentication
            self.lastUsedPassword = password
            
            // Prompt for biometric setup if not already configured
            if !biometricEnabled && !biometricPromptShown {
                biometricPromptShown = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    NotificationCenter.default.post(name: .showBiometricPrompt, object: nil)
                }
            }
            
            // Securely store credentials for biometric authentication
            saveCredentialsToKeychain(username: username, password: password)
            return true
        } catch {
            self.isLoggedIn = false
            return false
        }
    }
    
    /**
     * Creates a new user account with email and password
     * 
     * @param email User's email address
     * @param password User's chosen password
     * @param username Desired username
     * @param fullName User's full name
     * @param phone User's phone number
     * @throws AuthError for various signup failures
     * 
     * This method handles the complete signup process including:
     * - Supabase user creation
     * - User profile database insertion
     * - Account existence validation
     * - Error handling and user feedback
     */
    func signUp(email: String, password: String, username: String, fullName: String, phone: String) async throws {
        do {
            // Create user in Supabase Auth
            let response = try await AuthService.shared.signUp(email: email, password: password)
            let userId = response.user.id

            // Insert user profile into database
            let insertData = UserInsert(id: userId.uuidString, username: username, email: email, phone: phone, full_name: fullName)
            _ = try await SupabaseManager.shared.client
                .from("users")
                .insert(insertData)
                .execute()
            
            // Update authentication state
            self.isLoggedIn = true
            self.currentUsername = username
        } catch {
            self.isLoggedIn = false

            // Handle account already exists error
            let lowercasedMessage = error.localizedDescription.lowercased()
            if lowercasedMessage.contains("user already registered") || lowercasedMessage.contains("already exists") {
                throw AuthError.accountAlreadyExists
            }

            throw error
        }
    }
    
    // MARK: - Session Management
    
    /**
     * Logs out the current user and cleans up session data
     * 
     * This method handles:
     * - Supabase session termination
     * - Local state cleanup
     * - Error handling for logout failures
     */
    func logOut() async {
        do {
            // Sign out from Supabase
            try await SupabaseManager.shared.client.auth.signOut()
            
            // Clear authentication state
            await MainActor.run {
                self.currentUsername = nil
                self.isLoggedIn = false
                self.currentUserID = nil
            }
        } catch {
            // Handle logout error silently but still clear state
            await MainActor.run {
                self.currentUsername = nil
                self.isLoggedIn = false
                self.currentUserID = nil
            }
        }
    }
    
    /**
     * Checks for existing authentication session on app launch
     * 
     * This method validates stored sessions and restores user state
     * if a valid session exists, providing seamless app experience
     */
    func checkSession() async {
        do {
            // Check for existing Supabase session
            let session = try await SupabaseManager.shared.client.auth.session
            
            // Update authentication state
            await MainActor.run {
                self.isLoggedIn = !session.accessToken.isEmpty
                self.currentUsername = session.user.email
                self.currentUserID = session.user.id.uuidString
            }
            
            // Fetch complete user profile
            await fetchCurrentUser()
        } catch {
            // Session invalid or expired - reset to logged out state
            await MainActor.run {
                self.isLoggedIn = false
            }
        }
    }
    
    // MARK: - Apple Sign-In Integration
    
    /**
     * Handles Apple Sign-In authentication flow
     * 
     * @return Boolean indicating signin success
     * 
     * This method manages the complete Apple Sign-In process:
     * - OAuth flow initiation
     * - User creation for new accounts
     * - Username prompt for new users
     * - Error handling and user feedback
     */
    @MainActor
    func signInWithApple() async -> Bool {
        do {
            // Launch Apple OAuth flow via Supabase
            try await SupabaseManager.shared.client.auth.signInWithOAuth(
                provider: .apple,
                redirectTo: URL(string: "com.carto.signin://login-callback")
            )
            self.isLoggedIn = true

            // Handle new user creation
            if let user = try? await SupabaseManager.shared.client.auth.user() {
                // Check if user already exists in database
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
                    
                    // Insert user profile
                    _ = try await SupabaseManager.shared.client
                        .from("users")
                        .insert(newUser)
                        .execute()
                    
                    // Prompt UI to collect custom username
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .showUsernamePrompt, object: nil)
                    }
                }

                // Update authentication state
                self.currentUsername = user.email
                self.currentUserID = user.id.uuidString
                await fetchCurrentUser()
            }

            return true
        } catch {
            // Handle Apple Sign-In errors
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
    
    // MARK: - Biometric Authentication
    
    /**
     * Authenticates user using biometric authentication (Face ID/Touch ID)
     * 
     * @param successHandler Callback for successful authentication
     * @param errorHandler Callback for authentication failures with error message
     * 
     * This method handles:
     * - Biometric availability checking
     * - Biometric prompt presentation
     * - Credential retrieval from keychain
     * - Automatic login with stored credentials
     */
    func authenticateWithBiometrics(successHandler: @escaping () -> Void, errorHandler: @escaping (String) -> Void) {
        // Check if biometric authentication is enabled
        guard biometricEnabled else {
            errorHandler("Biometric login is disabled in settings.")
            return
        }
        
        let context = LAContext()
        var error: NSError?

        // Check biometric availability
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Log in with Face ID / Touch ID"

            // Present biometric prompt
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if let credentials = self.retrieveCredentialsFromKeychain() {
                        // Authenticate with stored credentials
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
    
    /**
     * Automatically attempts biometric login if enabled
     * 
     * @param successHandler Callback for successful authentication
     * @param errorHandler Callback for authentication failures with error message
     * 
     * This method provides seamless auto-login functionality for users
     * who have enabled biometric authentication
     */
    func autoLoginWithBiometricsIfEnabled(successHandler: @escaping () -> Void, errorHandler: @escaping (String) -> Void) {
        // Only proceed if biometric authentication is enabled
        guard biometricEnabled else { return }
        
        let context = LAContext()
        var error: NSError?

        // Check biometric availability
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to log in"

            // Present biometric prompt
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        if let credentials = self.retrieveCredentialsFromKeychain() {
                            // Authenticate with stored credentials
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
    
    // MARK: - Keychain Operations
    
    /**
     * Securely stores user credentials in keychain for biometric authentication
     * 
     * @param username User's email/username
     * @param password User's password
     * 
     * This method provides secure credential storage using iOS keychain services
     * with proper data encryption and access control
     */
    func saveCredentialsToKeychain(username: String, password: String) {
        let credentialsData = "\(username):\(password)".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "carto.credentials", // TODO: Use AppConstants.Keychain.credentialsKey
            kSecValueData as String: credentialsData
        ]
        
        // Delete existing credentials and save new ones
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    /**
     * Retrieves stored credentials from keychain for biometric authentication
     * 
     * @return Optional tuple containing username and password
     * 
     * This method safely retrieves and decrypts stored credentials
     * while handling potential keychain access errors
     */
    func retrieveCredentialsFromKeychain() -> (username: String, password: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "carto.credentials", // TODO: Use AppConstants.Keychain.credentialsKey
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
    
    // MARK: - User Profile Management
    
    /**
     * Fetches and updates the current user's profile information
     * 
     * This method retrieves complete user profile data from the database
     * and updates the local user object for UI consumption
     */
    func fetchCurrentUser() async {
        guard let id = currentUserID else { return }
        
        do {
            // Fetch user profile from database
            let response: [SelfUser] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("id", value: id)
                .limit(1)
                .execute()
                .value

            if let user = response.first {
                // Convert to AppUser object
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
                
                // Initialize encryption keys for secure messaging
                await initializeEncryptionKeys()
            } else {
                print("⚠️ No user found with id:", id)
            }
        } catch {
            print("❌ Failed to fetch currentUser:", error)
        }
    }
    
    // MARK: - Encryption Key Management
    
    /**
     * Initializes encryption keys for the current user
     * 
     * This method sets up end-to-end encryption capabilities by:
     * - Generating a new key pair if none exists
     * - Storing the private key locally in keychain
     * - Storing the public key on the server
     * - Enabling secure messaging functionality
     */
    private func initializeEncryptionKeys() async {
        guard let userID = currentUserID else { return }
        
        do {
            // Check if user already has encryption keys
            if let _ = try? EncryptionManager.shared.retrievePrivateKey(for: userID) {
                print("✅ [Encryption] User already has encryption keys")
                return
            }
            
            // Generate new key pair
            let keyPair = try EncryptionManager.shared.generateUserKeyPair()
            
            // Store private key locally
            try EncryptionManager.shared.storePrivateKey(keyPair.privateKey, for: userID)
            
            // Store public key on server
            let publicKeyString = EncryptionManager.shared.publicKeyToString(keyPair.publicKey)
            try await SupabaseManager.shared.storeUserPublicKey(userID: userID, publicKey: publicKeyString)
            
            print("✅ [Encryption] Generated and stored encryption keys for user")
        } catch {
            print("❌ [Encryption] Failed to initialize encryption keys: \(error)")
        }
    }
    
    /**
     * Retrieves the current user's public key for encryption operations
     * 
     * @return Optional string containing the public key
     * 
     * This method provides access to the user's public key for
     * encrypting messages and other secure operations
     */
    func getCurrentUserPublicKey() -> String? {
        guard let userID = currentUserID else { return nil }
        
        do {
            let privateKey = try EncryptionManager.shared.retrievePrivateKey(for: userID)
            return EncryptionManager.shared.publicKeyToString(privateKey.publicKey)
        } catch {
            print("❌ [Encryption] Failed to retrieve user's public key: \(error)")
            return nil
        }
    }

    // MARK: - Account Management
    
    /**
     * Deletes the current user's account and all associated data
     * 
     * @param completion Callback with success/failure status
     * 
     * This method handles complete account deletion including:
     * - Supabase authentication removal
     * - User profile database cleanup
     * - Local state cleanup
     * - Error handling and user feedback
     */
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

                // Clear authentication state
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

// MARK: - Notification Extensions

/**
 * Custom notification names for authentication events
 * These notifications enable decoupled communication between
 * authentication components and UI elements
 */
extension Notification.Name {
    /// Notification to show biometric setup prompt
    static let showBiometricPrompt = Notification.Name("showBiometricPrompt")
    
    /// Notification to show username selection prompt
    static let showUsernamePrompt = Notification.Name("showUsernamePrompt")
}
