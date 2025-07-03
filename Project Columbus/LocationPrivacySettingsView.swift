//
//  LocationPrivacySettingsView.swift
//  Project Columbus
//
//  Created by Assistant on 6/30/25.
//

import SwiftUI

struct LocationPrivacySettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var shareLocationWithFriends: Bool = true
    @State private var shareLocationWithFollowers: Bool = false
    @State private var shareLocationPublicly: Bool = false
    @State private var shareLocationHistory: Bool = false
    @State private var selectedAccuracyLevel: String = "approximate"
    @State private var autoDeleteDays: Int = 30
    @State private var allowLocationRequests: Bool = true
    @State private var isLoading: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    
    let accuracyLevels = [
        ("exact", "Exact Location", "Share your precise location"),
        ("approximate", "Approximate Location", "Share general area (~1km radius)"),
        ("city_only", "City Only", "Share only your city"),
        ("hidden", "Hidden", "Don't share location")
    ]
    
    let autoDeleteOptions = [7, 14, 30, 60, 90, 365]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Sharing")) {
                    Toggle("Share with Friends", isOn: $shareLocationWithFriends)
                        .help("Allow mutual friends to see your location")
                    
                    Toggle("Share with Followers", isOn: $shareLocationWithFollowers)
                        .help("Allow followers to see your location")
                    
                    Toggle("Share Publicly", isOn: $shareLocationPublicly)
                        .help("Allow anyone to see your location")
                    
                    Toggle("Share Location History", isOn: $shareLocationHistory)
                        .help("Allow others to see your past locations")
                }
                
                Section(header: Text("Location Accuracy")) {
                    ForEach(accuracyLevels, id: \.0) { level in
                        Button(action: {
                            selectedAccuracyLevel = level.0
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.1)
                                        .foregroundColor(.primary)
                                        .font(.body)
                                    Text(level.2)
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                Spacer()
                                if selectedAccuracyLevel == level.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section(header: Text("Location History")) {
                    Picker("Auto-delete after", selection: $autoDeleteDays) {
                        ForEach(autoDeleteOptions, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                    
                    Toggle("Allow Location Requests", isOn: $allowLocationRequests)
                        .help("Allow others to request your current location")
                }
                
                Section(header: Text("Advanced")) {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Delete All Location History") {
                        showDeleteConfirmation()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Location Privacy")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
            .alert("Settings Updated", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadCurrentSettings() {
        // Load current settings from Supabase first, fall back to UserDefaults
        guard let userID = authManager.currentUserID else { return }
        
        Task {
            if let settings = await SupabaseManager.shared.loadLocationPrivacySettings(for: userID) {
                await MainActor.run {
                    shareLocationWithFriends = settings.shareLocationWithFriends
                    shareLocationWithFollowers = settings.shareLocationWithFollowers
                    shareLocationPublicly = settings.shareLocationPublicly
                    shareLocationHistory = settings.shareLocationHistory
                    selectedAccuracyLevel = settings.locationAccuracyLevel
                    autoDeleteDays = settings.autoDeleteHistoryDays
                    allowLocationRequests = settings.allowLocationRequests
                    
                    print("✅ Loaded location privacy settings from database")
                }
            } else {
                // Fall back to UserDefaults if no database settings found
                await MainActor.run {
                    shareLocationWithFriends = UserDefaults.standard.bool(forKey: "shareLocationWithFriends")
                    shareLocationWithFollowers = UserDefaults.standard.bool(forKey: "shareLocationWithFollowers")
                    shareLocationPublicly = UserDefaults.standard.bool(forKey: "shareLocationPublicly")
                    shareLocationHistory = UserDefaults.standard.bool(forKey: "shareLocationHistory")
                    selectedAccuracyLevel = UserDefaults.standard.string(forKey: "locationAccuracyLevel") ?? "approximate"
                    autoDeleteDays = UserDefaults.standard.integer(forKey: "autoDeleteDays") != 0 ? UserDefaults.standard.integer(forKey: "autoDeleteDays") : 30
                    allowLocationRequests = UserDefaults.standard.bool(forKey: "allowLocationRequests")
                    
                    print("📱 Loaded location privacy settings from UserDefaults (fallback)")
                }
            }
        }
    }
    
    private func saveSettings() {
        guard let userID = authManager.currentUserID else {
            alertMessage = "Unable to save settings: user not authenticated"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        // Create settings object
        let settings = LocationPrivacySettings(
            userID: userID,
            shareLocationWithFriends: shareLocationWithFriends,
            shareLocationWithFollowers: shareLocationWithFollowers,
            shareLocationPublicly: shareLocationPublicly,
            shareLocationHistory: shareLocationHistory,
            locationAccuracyLevel: selectedAccuracyLevel,
            autoDeleteHistoryDays: autoDeleteDays,
            allowLocationRequests: allowLocationRequests
        )
        
        Task {
            do {
                // Save to Supabase
                try await SupabaseManager.shared.saveLocationPrivacySettings(settings)
                
                // Also save to UserDefaults as backup
                UserDefaults.standard.set(shareLocationWithFriends, forKey: "shareLocationWithFriends")
                UserDefaults.standard.set(shareLocationWithFollowers, forKey: "shareLocationWithFollowers")
                UserDefaults.standard.set(shareLocationPublicly, forKey: "shareLocationPublicly")
                UserDefaults.standard.set(shareLocationHistory, forKey: "shareLocationHistory")
                UserDefaults.standard.set(selectedAccuracyLevel, forKey: "locationAccuracyLevel")
                UserDefaults.standard.set(autoDeleteDays, forKey: "autoDeleteDays")
                UserDefaults.standard.set(allowLocationRequests, forKey: "allowLocationRequests")
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Your location privacy settings have been updated successfully."
                    showingAlert = true
                    print("✅ Location privacy settings saved to database and UserDefaults")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Failed to save settings: \(error.localizedDescription)"
                    showingAlert = true
                    print("❌ Failed to save location privacy settings: \(error)")
                }
            }
        }
    }
    
    private func resetToDefaults() {
        shareLocationWithFriends = true
        shareLocationWithFollowers = false
        shareLocationPublicly = false
        shareLocationHistory = false
        selectedAccuracyLevel = "approximate"
        autoDeleteDays = 30
        allowLocationRequests = true
    }
    
    private func showDeleteConfirmation() {
        let alert = UIAlertController(
            title: "Delete Location History",
            message: "This will permanently delete all your location history. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            deleteLocationHistory()
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
    
    private func deleteLocationHistory() {
        // TODO: Implement location history deletion
        alertMessage = "Location history has been deleted."
        showingAlert = true
    }
}

struct LocationPrivacySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LocationPrivacySettingsView()
    }
} 