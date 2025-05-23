//
//  SettingsView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/16/25.
//
import SwiftUI
import MapKit
import Combine
import Foundation

struct SettingsView: View {
    @Environment(\.presentationMode) var dismiss
    @AppStorage("themePreference") private var themePreference: String = "Auto"
    @AppStorage("selectedMapType") private var selectedMapType: String = "Standard"
    @AppStorage("biometricEnabled") private var biometricEnabled: Bool = UserDefaults.standard.bool(forKey: "biometricEnabled")
    
    // Phase 1 Settings - Core User Settings
    @AppStorage("isPrivateAccount") private var isPrivateAccount: Bool = false
    @AppStorage("showMyLocation") private var showMyLocation: Bool = true
    @AppStorage("showReactions") private var showReactions: Bool = true
    @AppStorage("useCellularData") private var useCellularData: Bool = true
    
    // Notification Settings
    @AppStorage("friendActivityNotifications") private var friendActivityNotifications: Bool = true
    @AppStorage("nearbyPinsNotifications") private var nearbyPinsNotifications: Bool = true
    @AppStorage("newFollowersNotifications") private var newFollowersNotifications: Bool = false
    @AppStorage("eventRemindersNotifications") private var eventRemindersNotifications: Bool = true
    @AppStorage("productUpdatesNotifications") private var productUpdatesNotifications: Bool = false
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager
    @EnvironmentObject var pinStore: PinStore
    
    @State private var showDeleteConfirmation = false
    @State private var deletionResultMessage: IdentifiableString? = nil
    @State private var isUpdatingPrivacy = false
    @State private var showClearCacheAlert = false
    @State private var isClearingCache = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    NavigationLink("Edit Profile", destination: 
                        ProfileEditView()
                            .environmentObject(authManager)
                    )
                    NavigationLink("Change Password", destination: 
                        ChangePasswordView()
                            .environmentObject(authManager)
                    )
                    NavigationLink("Connected Accounts", destination: Text("Connected Accounts Placeholder"))
                    
                    HStack {
                        Toggle("Private Account", isOn: $isPrivateAccount)
                            .onChange(of: isPrivateAccount) { oldValue, newValue in
                                handlePrivateAccountToggle(newValue)
                            }
                        if isUpdatingPrivacy {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                
                Section(header: Text("Map Preferences")) {
                    Picker("Map Type", selection: $selectedMapType) {
                        Text("Standard").tag("Standard")
                        Text("Satellite").tag("Satellite")
                        Text("Hybrid").tag("Hybrid")
                    }
                    
                    Toggle("Show My Location", isOn: $showMyLocation)
                        .onChange(of: showMyLocation) { oldValue, newValue in
                            handleLocationToggle(newValue)
                        }
                    
                    Toggle("Show Reactions", isOn: $showReactions)
                        .onChange(of: showReactions) { oldValue, newValue in
                            // This will trigger UI updates in the map views
                            pinStore.objectWillChange.send()
                        }
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Friend Activity", isOn: $friendActivityNotifications)
                    Toggle("Nearby Pins", isOn: $nearbyPinsNotifications)
                    Toggle("New Followers", isOn: $newFollowersNotifications)
                    Toggle("Event Reminders", isOn: $eventRemindersNotifications)
                    Toggle("Product Updates", isOn: $productUpdatesNotifications)
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $themePreference) {
                        Text("Auto").tag("Auto")
                        Text("Light").tag("Light")
                        Text("Dark").tag("Dark")
                    }
                }
                
                Section(header: Text("Data & Storage")) {
                    Toggle("Use Cellular Data", isOn: $useCellularData)
                        .onChange(of: useCellularData) { oldValue, newValue in
                            // This can be used by network managers to decide connection policy
                            print("📱 Cellular data usage preference: \(newValue ? "enabled" : "disabled")")
                        }
                    
                    Button("Clear Cache") {
                        showClearCacheAlert = true
                    }
                    .disabled(isClearingCache)
                    .alert("Clear Cache", isPresented: $showClearCacheAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Clear", role: .destructive) {
                            clearCache()
                        }
                    } message: {
                        Text("This will clear cached images and temporary data. This may improve performance if you're experiencing issues.")
                    }
                }
                
                Section(header: Text("About")) {
                    NavigationLink("Help & Support", destination: Text("Help Placeholder"))
                    NavigationLink("Privacy Policy", destination: Text("Privacy Placeholder"))
                    NavigationLink("Terms of Use", destination: Text("Terms Placeholder"))
                    Text("App Version 0.50.0 ©2025 Carto Inc.")
                        .foregroundColor(.gray)
                }
                
                Section(header: Text("Security")) {
                    Toggle("Enable Face ID Login", isOn: $biometricEnabled)
                    .onChange(of: biometricEnabled) { _, newValue in
                            if newValue {
                                authManager.authenticateWithBiometrics(successHandler: {
                                    authManager.saveCredentialsToKeychain(
                                        username: authManager.currentUsername ?? "",
                                        password: authManager.lastUsedPassword
                                    )
                                }, errorHandler: { error in
                                    biometricEnabled = false
                                })
                            }
                        }
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Account")
                            Spacer()
                        }
                    }
                    .alert(isPresented: $showDeleteConfirmation) {
                        Alert(
                            title: Text("Are you sure?"),
                            message: Text("This will permanently delete your account."),
                            primaryButton: .destructive(Text("Delete")) {
                                deleteAccount()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                    Button(role: .destructive) {
                        performLogout()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss.wrappedValue.dismiss()
                    }
                }
            }
            .alert(item: $deletionResultMessage) { message in
                Alert(title: Text(message.value))
            }
        }
    }
    
    // MARK: - Private Account Integration
    private func handlePrivateAccountToggle(_ isPrivate: Bool) {
        guard authManager.isLoggedIn, let userID = authManager.currentUserID else { return }
        
        isUpdatingPrivacy = true
        
        Task {
            do {
                _ = try await SupabaseManager.shared.client
                    .from("users")
                    .update(["is_private": isPrivate])
                    .eq("id", value: userID)
                    .execute()
                
                print("✅ Privacy setting updated: \(isPrivate ? "private" : "public")")
            } catch {
                print("❌ Failed to update privacy setting: \(error)")
                // Revert the toggle on failure
                await MainActor.run {
                    isPrivateAccount = !isPrivate
                }
            }
            
            await MainActor.run {
                isUpdatingPrivacy = false
            }
        }
    }
    
    // MARK: - Location Integration
    private func handleLocationToggle(_ enabled: Bool) {
        if enabled {
            locationManager.requestUserLocationManually()
        } else {
            // Stop location updates when disabled
            print("🗺️ Location display disabled")
        }
    }
    
    // MARK: - Cache Management
    private func clearCache() {
        isClearingCache = true
        
        // Clear image cache synchronously
        ImageCache.shared.clearCache()
        
        // Clear URLSession cache
        URLCache.shared.removeAllCachedResponses()
        
        // Clear UserDefaults cache keys if any
        let cacheKeys = ["cachedPins", "cachedUsers", "lastSyncTimestamp"]
        for key in cacheKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        isClearingCache = false
        deletionResultMessage = IdentifiableString(value: "Cache cleared successfully")
        
        print("🧹 Cache cleared successfully")
    }
    
    private func performLogout() {
        authManager.logOut()
    }
    
    private func deleteAccount() {
        authManager.deleteAccount { success in
            if success {
                deletionResultMessage = IdentifiableString(value: "Account successfully deleted.")
                performLogout()
            } else {
                deletionResultMessage = IdentifiableString(value: "Failed to delete account. Please try again.")
            }
        }
    }
}

// MARK: - Settings Access Extensions
extension UserDefaults {
    static var showMyLocation: Bool {
        standard.bool(forKey: "showMyLocation")
    }
    
    static var showReactions: Bool {
        standard.bool(forKey: "showReactions")
    }
    
    static var useCellularData: Bool {
        standard.bool(forKey: "useCellularData")
    }
    
    static var isPrivateAccount: Bool {
        standard.bool(forKey: "isPrivateAccount")
    }
}

// Parent view that provides the AuthManager environment object to SettingsView
struct ParentView: View {
    @StateObject var authManager = AuthManager()
    
    init() {
        UserDefaults.standard.register(defaults: [
            "biometricEnabled": false,
            "showMyLocation": true,
            "showReactions": true,
            "useCellularData": true,
            "isPrivateAccount": false,
            "friendActivityNotifications": true,
            "nearbyPinsNotifications": true,
            "newFollowersNotifications": false,
            "eventRemindersNotifications": true,
            "productUpdatesNotifications": false
        ])
    }
    
    var body: some View {
        SettingsView()
            .environmentObject(authManager)
            .preferredColorScheme(.dark)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ParentView()
    }
}

struct IdentifiableString: Identifiable {
    var id: String { value }
    let value: String
}
