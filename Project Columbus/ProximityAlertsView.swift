//
//  ProximityAlertsView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//
//  DESCRIPTION:
//  This file implements a comprehensive SwiftUI view for managing proximity alert
//  preferences in Project Columbus (Carto). It provides an intuitive interface
//  for configuring privacy settings, notification preferences, and social discovery options.
//
//  FEATURES:
//  - Privacy tier selection with visual indicators
//  - Availability status management
//  - Friend-specific permission controls
//  - Safe zone management
//  - Notification preferences
//  - Real-time proximity monitoring controls
//
//  ARCHITECTURE:
//  - SwiftUI declarative UI with @StateObject managers
//  - Comprehensive form-based settings interface
//  - Real-time validation and feedback
//  - Integrated privacy controls and explanations
//

import SwiftUI
import MapKit

struct ProximityAlertsView: View {
    @StateObject private var proximityManager = ProximityAlertManager.shared
    @StateObject private var privacyManager = ProximityPrivacyManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingFriendPermissions = false
    @State private var showingSafeZones = false
    @State private var showingAdvancedSettings = false
    @State private var showingLocationPermissionAlert = false
    @State private var showingPrivacyExplanation = false
    @State private var selectedTab: SettingsTab = .overview
    
    enum SettingsTab: String, CaseIterable {
        case overview = "Overview"
        case privacy = "Privacy"
        case notifications = "Notifications"
        case friends = "Friends"
        case advanced = "Advanced"
        
        var icon: String {
            switch self {
            case .overview: return "gauge"
            case .privacy: return "lock.shield"
            case .notifications: return "bell"
            case .friends: return "person.2"
            case .advanced: return "gearshape"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                OverviewTab()
                    .tabItem {
                        Label(SettingsTab.overview.rawValue, systemImage: SettingsTab.overview.icon)
                    }
                    .tag(SettingsTab.overview)
                
                PrivacyTab()
                    .tabItem {
                        Label(SettingsTab.privacy.rawValue, systemImage: SettingsTab.privacy.icon)
                    }
                    .tag(SettingsTab.privacy)
                
                NotificationsTab()
                    .tabItem {
                        Label(SettingsTab.notifications.rawValue, systemImage: SettingsTab.notifications.icon)
                    }
                    .tag(SettingsTab.notifications)
                
                FriendsTab()
                    .tabItem {
                        Label(SettingsTab.friends.rawValue, systemImage: SettingsTab.friends.icon)
                    }
                    .tag(SettingsTab.friends)
                
                AdvancedTab()
                    .tabItem {
                        Label(SettingsTab.advanced.rawValue, systemImage: SettingsTab.advanced.icon)
                    }
                    .tag(SettingsTab.advanced)
            }
            .navigationTitle("Proximity Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Location Permission Required", isPresented: $showingLocationPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Proximity alerts require location access. Please enable location permissions in Settings.")
        }
        .sheet(isPresented: $showingPrivacyExplanation) {
            PrivacyExplanationView()
        }
        .onAppear {
            loadSettings()
        }
    }
    
    // MARK: - Overview Tab
    
    @ViewBuilder
    private func OverviewTab() -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Status Card
                StatusCard()
                
                // Quick Settings
                QuickSettingsCard()
                
                // Current Activity
                CurrentActivityCard()
                
                // Statistics
                StatisticsCard()
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func StatusCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: proximityManager.isActive ? "location.circle.fill" : "location.slash")
                    .foregroundColor(proximityManager.isActive ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Proximity Alerts")
                        .font(.headline)
                    Text(proximityManager.isActive ? "Active" : "Inactive")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { proximityManager.isActive },
                    set: { enabled in
                        if enabled {
                            proximityManager.startProximityMonitoring()
                        } else {
                            proximityManager.stopProximityMonitoring()
                        }
                    }
                ))
            }
            
            Divider()
            
            HStack {
                Image(systemName: privacyManager.settings.availabilityStatus.icon)
                    .foregroundColor(privacyManager.settings.availabilityStatus.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                        .font(.subheadline)
                    Text(privacyManager.settings.availabilityStatus.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text(privacyManager.settings.getPrivacySummary())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func QuickSettingsCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Settings")
                .font(.headline)
            
            HStack(spacing: 16) {
                Button(action: {
                    selectedTab = .privacy
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.shield")
                            .font(.title2)
                        Text("Privacy")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                
                Button(action: {
                    selectedTab = .notifications
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "bell")
                            .font(.title2)
                        Text("Notifications")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
                
                Button(action: {
                    selectedTab = .friends
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.title2)
                        Text("Friends")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
                
                Button(action: {
                    showingPrivacyExplanation = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.title2)
                        Text("Help")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func CurrentActivityCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Friends")
                    .font(.headline)
                
                Spacer()
                
                Text("Updated \(DateUtils.relativeTimeString(from: proximityManager.lastUpdateTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if proximityManager.nearbyFriends.isEmpty {
                Text("No friends nearby")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(proximityManager.nearbyFriends.prefix(3)) { friend in
                        FriendProximityRow(friend: friend)
                    }
                    
                    if proximityManager.nearbyFriends.count > 3 {
                        Text("And \(proximityManager.nearbyFriends.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func StatisticsCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)
            
            HStack {
                VStack(alignment: .center, spacing: 4) {
                    Text("\(proximityManager.nearbyFriends.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Nearby")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("\(proximityManager.locationActivities.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Activities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("\(privacyManager.settings.safeZones.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Safe Zones")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 50)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Privacy Tab
    
    @ViewBuilder
    private func PrivacyTab() -> some View {
        Form {
            Section("Location Sharing") {
                Toggle("Share Location for Proximity", isOn: $privacyManager.settings.isLocationSharingEnabled)
                    .onChange(of: privacyManager.settings.isLocationSharingEnabled) { enabled in
                        if enabled && locationManager.authorizationStatus != .authorizedWhenInUse && locationManager.authorizationStatus != .authorizedAlways {
                            showingLocationPermissionAlert = true
                            privacyManager.settings.isLocationSharingEnabled = false
                        }
                    }
                
                if privacyManager.settings.isLocationSharingEnabled {
                    Picker("Privacy Level", selection: $privacyManager.settings.locationPrivacyTier) {
                        ForEach(LocationPrivacyTier.allCases, id: \.self) { tier in
                            HStack {
                                Image(systemName: tier.icon)
                                    .foregroundColor(tier.color)
                                Text(tier.title)
                            }
                            .tag(tier)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Text(privacyManager.settings.locationPrivacyTier.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Availability") {
                Picker("Status", selection: $privacyManager.settings.availabilityStatus) {
                    ForEach(AvailabilityStatus.allCases, id: \.self) { status in
                        HStack {
                            Image(systemName: status.icon)
                                .foregroundColor(status.color)
                            Text(status.title)
                        }
                        .tag(status)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Text(privacyManager.settings.availabilityStatus.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if privacyManager.settings.availabilityStatus != .invisible {
                    TextField("Custom Status Message", text: $privacyManager.settings.customStatusMessage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            Section("Safe Zones") {
                Button("Manage Safe Zones") {
                    showingSafeZones = true
                }
                
                if !privacyManager.settings.safeZones.isEmpty {
                    ForEach(privacyManager.settings.safeZones.prefix(3)) { zone in
                        HStack {
                            Image(systemName: zone.isEnabled ? "location.circle.fill" : "location.circle")
                                .foregroundColor(zone.isEnabled ? .green : .gray)
                            Text(zone.name)
                            Spacer()
                            Text("\(Int(zone.radius))m")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("Data & Privacy") {
                Toggle("Share Location History", isOn: $privacyManager.settings.shareLocationHistory)
                Toggle("Share Visited Places", isOn: $privacyManager.settings.shareVisitedPlaces)
                Toggle("Allow Location Recommendations", isOn: $privacyManager.settings.allowLocationRecommendations)
                
                Stepper("Delete location data after \(privacyManager.settings.locationDataRetentionDays) days", value: $privacyManager.settings.locationDataRetentionDays, in: 1...365)
            }
        }
        .navigationTitle("Privacy Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSafeZones) {
            SafeZonesView(privacyManager: privacyManager)
        }
    }
    
    // MARK: - Notifications Tab
    
    @ViewBuilder
    private func NotificationsTab() -> some View {
        Form {
            Section("Proximity Notifications") {
                Toggle("Friend Nearby", isOn: $notificationManager.settings.friendNearbyNotifications)
                Toggle("Friend at Location", isOn: $notificationManager.settings.friendAtLocationNotifications)
                Toggle("Friend Activity", isOn: $notificationManager.settings.friendActivityAtLocationNotifications)
                Toggle("Friend Available", isOn: $notificationManager.settings.friendAvailableNearbyNotifications)
                Toggle("Location Recommendations", isOn: $notificationManager.settings.locationRecommendationNotifications)
                Toggle("Group Activity", isOn: $notificationManager.settings.groupActivityNotifications)
            }
            
            Section("Notification Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proximity Radius: \(Int(privacyManager.settings.proximityRadius))m")
                    Slider(value: $privacyManager.settings.proximityRadius, in: 100...5000, step: 100)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Notifications per Hour: \(privacyManager.settings.maxNotificationsPerHour)")
                    Slider(value: Binding(
                        get: { Double(privacyManager.settings.maxNotificationsPerHour) },
                        set: { privacyManager.settings.maxNotificationsPerHour = Int($0) }
                    ), in: 1...10, step: 1)
                }
                
                Toggle("Only Notify When Available", isOn: $privacyManager.settings.onlyAlertWhenAvailable)
            }
            
            Section("Quiet Hours") {
                Toggle("Enable Quiet Hours", isOn: $privacyManager.settings.quietHoursEnabled)
                
                if privacyManager.settings.quietHoursEnabled {
                    DatePicker("Start Time", selection: $privacyManager.settings.quietHoursStart, displayedComponents: .hourAndMinute)
                    DatePicker("End Time", selection: $privacyManager.settings.quietHoursEnd, displayedComponents: .hourAndMinute)
                }
            }
            
            Section("Sound & Alerts") {
                Toggle("Sound", isOn: $notificationManager.settings.soundEnabled)
                Toggle("Badge App Icon", isOn: $notificationManager.settings.badgeEnabled)
                Toggle("Show Previews", isOn: $notificationManager.settings.previewEnabled)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Friends Tab
    
    @ViewBuilder
    private func FriendsTab() -> some View {
        Form {
            Section("Friend Permissions") {
                Button("Manage Friend Permissions") {
                    showingFriendPermissions = true
                }
                
                if !privacyManager.settings.friendPermissions.isEmpty {
                    ForEach(privacyManager.settings.friendPermissions.prefix(5)) { permission in
                        FriendPermissionRow(permission: permission)
                    }
                }
            }
            
            Section("Default Permissions") {
                Toggle("Share Exact Location", isOn: $privacyManager.settings.defaultFriendPermission.canSeeExactLocation)
                Toggle("Share Availability", isOn: $privacyManager.settings.defaultFriendPermission.canSeeAvailability)
                Toggle("Allow Proximity Alerts", isOn: $privacyManager.settings.defaultFriendPermission.canSendProximityAlerts)
            }
            
            Section("Group Settings") {
                Toggle("Allow Group Proximity Alerts", isOn: $privacyManager.settings.allowGroupProximityAlerts)
            }
        }
        .navigationTitle("Friends")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFriendPermissions) {
            FriendPermissionsView(privacyManager: privacyManager)
        }
    }
    
    // MARK: - Advanced Tab
    
    @ViewBuilder
    private func AdvancedTab() -> some View {
        Form {
            Section("Background Processing") {
                Toggle("Background Location Sharing", isOn: $privacyManager.settings.allowBackgroundLocationSharing)
                
                Text("Allows proximity alerts to work when the app is in the background. May impact battery life.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Data Management") {
                Toggle("Auto-delete Location History", isOn: $privacyManager.settings.autoDeleteLocationHistory)
                Toggle("Share Location with Apps", isOn: $privacyManager.settings.shareLocationWithApps)
                Toggle("Allow Third-party Access", isOn: $privacyManager.settings.allowThirdPartyLocationAccess)
            }
            
            Section("Security") {
                Toggle("Require Explicit Consent", isOn: $privacyManager.settings.requireExplicitConsent)
                
                Text("Requires explicit permission for each new location sharing request.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Debug Information") {
                if proximityManager.isActive {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Update: \(DateUtils.displayDateFormatter.string(from: proximityManager.lastUpdateTime))")
                        Text("Nearby Friends: \(proximityManager.nearbyFriends.count)")
                        Text("Location Activities: \(proximityManager.locationActivities.count)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Helper Methods
    
    private func loadSettings() {
        // Settings are automatically loaded by the @StateObject managers
    }
    
    private func saveSettings() {
        Task {
            await notificationManager.saveSettings()
            privacyManager.updateSettings(privacyManager.settings)
            proximityManager.updateSettings(proximityManager.settings)
        }
    }
}

// MARK: - Supporting Views

struct FriendProximityRow: View {
    let friend: FriendProximityStatus
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: friend.friendAvatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.friendDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formatDistance(friend.distance))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if friend.isAvailable {
                Image(systemName: "circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return String(format: "%.0f m away", distance)
        } else {
            return String(format: "%.1f km away", distance / 1000)
        }
    }
}

struct FriendPermissionRow: View {
    let permission: FriendProximityPermission
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.friendUsername)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 12) {
                    Label("Location", systemImage: permission.canSeeExactLocation ? "location.fill" : "location.slash")
                        .font(.caption)
                        .foregroundColor(permission.canSeeExactLocation ? .green : .gray)
                    
                    Label("Status", systemImage: permission.canSeeAvailability ? "person.circle.fill" : "person.circle")
                        .font(.caption)
                        .foregroundColor(permission.canSeeAvailability ? .blue : .gray)
                    
                    Label("Alerts", systemImage: permission.canSendProximityAlerts ? "bell.fill" : "bell.slash")
                        .font(.caption)
                        .foregroundColor(permission.canSendProximityAlerts ? .orange : .gray)
                }
            }
            
            Spacer()
            
            Image(systemName: permission.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(permission.isEnabled ? .green : .gray)
        }
    }
}

// MARK: - Placeholder Views

struct SafeZonesView: View {
    @ObservedObject var privacyManager: ProximityPrivacyManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Safe Zones Management")
                .navigationTitle("Safe Zones")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct FriendPermissionsView: View {
    @ObservedObject var privacyManager: ProximityPrivacyManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Friend Permissions Management")
                .navigationTitle("Friend Permissions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct PrivacyExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy & Security")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Your location data is encrypted and only shared with friends you explicitly allow. You have complete control over who can see your location and when.")
                        .font(.body)
                    
                    // Add more privacy explanation content here
                }
                .padding()
            }
            .navigationTitle("Privacy Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProximityAlertsView()
        .environmentObject(AuthManager())
        .environmentObject(AppLocationManager())
        .environmentObject(SupabaseManager.shared)
} 