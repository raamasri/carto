//
//  ProximityPrivacySettings.swift
//  Project Columbus
//
//  Created by Assistant on Date
//
//  DESCRIPTION:
//  This file implements comprehensive privacy settings for proximity alerts
//  in Project Columbus (Carto). It provides granular user controls for
//  location sharing, proximity detection, and social discovery features.
//
//  FEATURES:
//  - Granular privacy controls for location sharing
//  - Friend group-based proximity permissions
//  - Availability status management
//  - Notification preferences with privacy tiers
//  - Geofencing and safe zones
//  - Activity visibility controls
//
//  ARCHITECTURE:
//  - Privacy-first design with explicit consent
//  - Hierarchical permission system
//  - User-controlled data sharing
//  - Secure storage of privacy preferences
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Privacy Tiers

/**
 * LocationPrivacyTier
 * 
 * Defines different levels of location privacy for proximity alerts.
 */
enum LocationPrivacyTier: String, CaseIterable, Codable {
    case disabled = "disabled"
    case friendsOnly = "friends_only"
    case selectFriends = "select_friends"
    case publicSharing = "public"
    
    var title: String {
        switch self {
        case .disabled: return "Disabled"
        case .friendsOnly: return "Friends Only"
        case .selectFriends: return "Select Friends"
        case .publicSharing: return "Public"
        }
    }
    
    var description: String {
        switch self {
        case .disabled: return "Don't share location for proximity alerts"
        case .friendsOnly: return "Share with all friends you follow"
        case .selectFriends: return "Share with selected friends only"
        case .publicSharing: return "Share with all users (not recommended)"
        }
    }
    
    var icon: String {
        switch self {
        case .disabled: return "location.slash"
        case .friendsOnly: return "person.2.fill"
        case .selectFriends: return "person.crop.circle.badge.plus"
        case .publicSharing: return "globe"
        }
    }
    
    var color: Color {
        switch self {
        case .disabled: return .gray
        case .friendsOnly: return .blue
        case .selectFriends: return .green
        case .publicSharing: return .orange
        }
    }
}

// MARK: - Availability Status

/**
 * AvailabilityStatus
 * 
 * Represents user's availability for social interactions.
 */
enum AvailabilityStatus: String, CaseIterable, Codable {
    case available = "available"
    case busy = "busy"
    case doNotDisturb = "do_not_disturb"
    case invisible = "invisible"
    
    var title: String {
        switch self {
        case .available: return "Available"
        case .busy: return "Busy"
        case .doNotDisturb: return "Do Not Disturb"
        case .invisible: return "Invisible"
        }
    }
    
    var description: String {
        switch self {
        case .available: return "Open to meeting up"
        case .busy: return "Notifications OK, but may not respond"
        case .doNotDisturb: return "Important notifications only"
        case .invisible: return "Don't show in proximity alerts"
        }
    }
    
    var icon: String {
        switch self {
        case .available: return "person.circle.fill"
        case .busy: return "person.badge.clock"
        case .doNotDisturb: return "bell.slash"
        case .invisible: return "eye.slash"
        }
    }
    
    var color: Color {
        switch self {
        case .available: return .green
        case .busy: return .orange
        case .doNotDisturb: return .red
        case .invisible: return .gray
        }
    }
}

// MARK: - Safe Zone

/**
 * SafeZone
 * 
 * Represents a geographical area where proximity alerts are disabled.
 */
struct SafeZone: Identifiable, Codable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let radius: Double // in meters
    let isEnabled: Bool
    let createdAt: Date
    
    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, radius: Double, isEnabled: Bool = true, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }
    
    func contains(location: CLLocation) -> Bool {
        let zoneLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: zoneLocation) <= radius
    }
}

// MARK: - Friend Permission

/**
 * FriendProximityPermission
 * 
 * Represents proximity sharing permissions for a specific friend.
 */
struct FriendProximityPermission: Identifiable, Codable {
    let id: UUID
    let friendId: String
    let friendUsername: String
    let isEnabled: Bool
    var canSeeExactLocation: Bool
    var canSeeAvailability: Bool
    var canSendProximityAlerts: Bool
    let lastUpdated: Date
    
    init(id: UUID = UUID(), friendId: String, friendUsername: String, isEnabled: Bool = true, canSeeExactLocation: Bool = true, canSeeAvailability: Bool = true, canSendProximityAlerts: Bool = true, lastUpdated: Date = Date()) {
        self.id = id
        self.friendId = friendId
        self.friendUsername = friendUsername
        self.isEnabled = isEnabled
        self.canSeeExactLocation = canSeeExactLocation
        self.canSeeAvailability = canSeeAvailability
        self.canSendProximityAlerts = canSendProximityAlerts
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Comprehensive Privacy Settings

/**
 * ProximityPrivacySettings
 * 
 * Comprehensive privacy settings for proximity alerts with granular controls.
 */
struct ProximityPrivacySettings: Codable {
    // Core Privacy Settings
    var isLocationSharingEnabled: Bool = false
    var locationPrivacyTier: LocationPrivacyTier = .disabled
    var availabilityStatus: AvailabilityStatus = .available
    var customStatusMessage: String = ""
    
    // Proximity Alert Settings
    var proximityRadius: Double = 500 // meters
    var minProximityRadius: Double = 100 // minimum 100m
    var maxProximityRadius: Double = 5000 // maximum 5km
    var onlyAlertWhenAvailable: Bool = true
    var allowBackgroundLocationSharing: Bool = false
    
    // Friend Permissions
    var friendPermissions: [FriendProximityPermission] = []
    var defaultFriendPermission: FriendProximityPermission = FriendProximityPermission(
        friendId: "default",
        friendUsername: "default",
        isEnabled: true,
        canSeeExactLocation: false,
        canSeeAvailability: true,
        canSendProximityAlerts: true
    )
    
    // Safe Zones
    var safeZones: [SafeZone] = []
    var automaticSafeZones: Bool = true // Auto-create safe zones for home, work
    
    // Activity Visibility
    var shareLocationHistory: Bool = false
    var shareVisitedPlaces: Bool = true
    var shareActivityFeed: Bool = true
    var allowLocationRecommendations: Bool = true
    
    // Notification Controls
    var notificationRadius: Double = 1000 // meters
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()
    var maxNotificationsPerHour: Int = 3
    
    // Data Retention
    var locationDataRetentionDays: Int = 30
    var autoDeleteLocationHistory: Bool = true
    var shareLocationWithApps: Bool = false
    
    // Advanced Settings
    var allowGroupProximityAlerts: Bool = true
    var allowLocationBasedRecommendations: Bool = true
    var allowThirdPartyLocationAccess: Bool = false
    var requireExplicitConsent: Bool = true
    
    // MARK: - Helper Methods
    
    /**
     * Check if location sharing is allowed with a specific friend
     */
    func canShareLocationWith(friendId: String) -> Bool {
        guard isLocationSharingEnabled else { return false }
        
        switch locationPrivacyTier {
        case .disabled:
            return false
        case .publicSharing:
            return true
        case .friendsOnly:
            return true // Would need to check if they're actually friends
        case .selectFriends:
            return friendPermissions.first(where: { $0.friendId == friendId })?.isEnabled ?? false
        }
    }
    
    /**
     * Check if current location is in a safe zone
     */
    func isInSafeZone(location: CLLocation) -> Bool {
        return safeZones.first(where: { $0.isEnabled && $0.contains(location: location) }) != nil
    }
    
    /**
     * Check if proximity alerts should be active based on availability
     */
    func shouldShowProximityAlerts() -> Bool {
        switch availabilityStatus {
        case .available:
            return true
        case .busy:
            return !onlyAlertWhenAvailable
        case .doNotDisturb:
            return false
        case .invisible:
            return false
        }
    }
    
    /**
     * Get friend permission for a specific friend
     */
    func getFriendPermission(friendId: String) -> FriendProximityPermission {
        return friendPermissions.first(where: { $0.friendId == friendId }) ?? defaultFriendPermission
    }
    
    /**
     * Update friend permission
     */
    mutating func updateFriendPermission(_ permission: FriendProximityPermission) {
        if let index = friendPermissions.firstIndex(where: { $0.friendId == permission.friendId }) {
            friendPermissions[index] = permission
        } else {
            friendPermissions.append(permission)
        }
    }
    
    /**
     * Add a safe zone
     */
    mutating func addSafeZone(_ safeZone: SafeZone) {
        safeZones.append(safeZone)
    }
    
    /**
     * Remove a safe zone
     */
    mutating func removeSafeZone(id: UUID) {
        safeZones.removeAll { $0.id == id }
    }
    
    /**
     * Check if in quiet hours
     */
    func isInQuietHours() -> Bool {
        guard quietHoursEnabled else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)
        let startTime = calendar.dateComponents([.hour, .minute], from: quietHoursStart)
        let endTime = calendar.dateComponents([.hour, .minute], from: quietHoursEnd)
        
        let currentMinutes = (currentTime.hour ?? 0) * 60 + (currentTime.minute ?? 0)
        let startMinutes = (startTime.hour ?? 0) * 60 + (startTime.minute ?? 0)
        let endMinutes = (endTime.hour ?? 0) * 60 + (endTime.minute ?? 0)
        
        if startMinutes <= endMinutes {
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
    
    /**
     * Validate settings for consistency
     */
    func validateSettings() -> [String] {
        var errors: [String] = []
        
        if proximityRadius < minProximityRadius {
            errors.append("Proximity radius cannot be less than \(minProximityRadius)m")
        }
        
        if proximityRadius > maxProximityRadius {
            errors.append("Proximity radius cannot be more than \(maxProximityRadius)m")
        }
        
        if notificationRadius < proximityRadius {
            errors.append("Notification radius should be at least equal to proximity radius")
        }
        
        if locationDataRetentionDays < 1 {
            errors.append("Location data retention must be at least 1 day")
        }
        
        if locationDataRetentionDays > 365 {
            errors.append("Location data retention cannot exceed 365 days")
        }
        
        if maxNotificationsPerHour < 1 {
            errors.append("Must allow at least 1 notification per hour")
        }
        
        if maxNotificationsPerHour > 10 {
            errors.append("Cannot exceed 10 notifications per hour")
        }
        
        return errors
    }
    
    /**
     * Get privacy summary for display
     */
    func getPrivacySummary() -> String {
        if !isLocationSharingEnabled {
            return "Location sharing disabled"
        }
        
        var summary = "Sharing with \(locationPrivacyTier.title.lowercased())"
        
        if availabilityStatus != .available {
            summary += " • Status: \(availabilityStatus.title)"
        }
        
        if safeZones.count > 0 {
            summary += " • \(safeZones.count) safe zone\(safeZones.count == 1 ? "" : "s")"
        }
        
        return summary
    }
}

// MARK: - Default Safe Zones

extension ProximityPrivacySettings {
    /**
     * Create default safe zones for common locations
     */
    static func createDefaultSafeZones() -> [SafeZone] {
        // These would typically be populated from user's location history
        // or common locations like home, work, etc.
        return [
            SafeZone(
                name: "Home",
                latitude: 0.0,
                longitude: 0.0,
                radius: 200,
                isEnabled: true
            ),
            SafeZone(
                name: "Work",
                latitude: 0.0,
                longitude: 0.0,
                radius: 100,
                isEnabled: true
            )
        ]
    }
}

// MARK: - Privacy Manager

/**
 * ProximityPrivacyManager
 * 
 * Manages privacy settings and provides validation and storage.
 */
class ProximityPrivacyManager: ObservableObject {
    @Published var settings: ProximityPrivacySettings = ProximityPrivacySettings()
    
    private let storageKey = "proximity_privacy_settings"
    
    init() {
        loadSettings()
    }
    
    func updateSettings(_ newSettings: ProximityPrivacySettings) {
        let errors = newSettings.validateSettings()
        guard errors.isEmpty else {
            print("❌ ProximityPrivacyManager: Invalid settings: \(errors)")
            return
        }
        
        settings = newSettings
        saveSettings()
    }
    
    func updateAvailabilityStatus(_ status: AvailabilityStatus) {
        settings.availabilityStatus = status
        saveSettings()
    }
    
    func updateCustomStatusMessage(_ message: String) {
        settings.customStatusMessage = message
        saveSettings()
    }
    
    func addFriendPermission(_ permission: FriendProximityPermission) {
        settings.updateFriendPermission(permission)
        saveSettings()
    }
    
    func removeFriendPermission(friendId: String) {
        settings.friendPermissions.removeAll { $0.friendId == friendId }
        saveSettings()
    }
    
    func addSafeZone(_ safeZone: SafeZone) {
        settings.addSafeZone(safeZone)
        saveSettings()
    }
    
    func removeSafeZone(id: UUID) {
        settings.removeSafeZone(id: id)
        saveSettings()
    }
    
    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("⚙️ ProximityPrivacyManager: Settings saved")
        } catch {
            print("❌ ProximityPrivacyManager: Failed to save settings: \(error)")
        }
    }
    
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            settings = ProximityPrivacySettings()
            return
        }
        
        do {
            settings = try JSONDecoder().decode(ProximityPrivacySettings.self, from: data)
            print("⚙️ ProximityPrivacyManager: Settings loaded")
        } catch {
            print("❌ ProximityPrivacyManager: Failed to load settings: \(error)")
            settings = ProximityPrivacySettings()
        }
    }
} 