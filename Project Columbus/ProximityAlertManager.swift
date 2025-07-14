//
//  ProximityAlertManager.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import Foundation
import CoreLocation
import Combine
import UserNotifications

// MARK: - Proximity Alert Types

/**
 * ProximityAlertType
 * 
 * Defines the different types of proximity alerts that can be triggered
 * when friends are nearby or when there's social activity at locations.
 */
enum ProximityAlertType: String, CaseIterable, Codable {
    case friendNearby = "friend_nearby"
    case friendAtLocation = "friend_at_location"
    case friendActivityAtLocation = "friend_activity_at_location"
    case friendAvailableNearby = "friend_available_nearby"
    case locationRecommendation = "location_recommendation"
    case groupActivity = "group_activity"
    
    var displayName: String {
        switch self {
        case .friendNearby:
            return "Friend Nearby"
        case .friendAtLocation:
            return "Friend at Location"
        case .friendActivityAtLocation:
            return "Friend Activity at Location"
        case .friendAvailableNearby:
            return "Friend Available Nearby"
        case .locationRecommendation:
            return "Location Recommendation"
        case .groupActivity:
            return "Group Activity"
        }
    }
}

// MARK: - Data Models

/**
 * FriendProximityStatus
 * 
 * Represents the current proximity status of a friend, including their
 * location, distance, and availability for social interaction.
 */
struct FriendProximityStatus: Identifiable, Codable {
    let id = UUID()
    let friendID: String
    let friendUsername: String
    let friendDisplayName: String
    let friendAvatarURL: String?
    let latitude: Double
    let longitude: Double
    let distance: Double // Distance in meters
    let lastSeen: Date
    let isAvailable: Bool
    let availabilityStatus: String
    let locationName: String?
    let locationDescription: String?
    
    var distanceFormatted: String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

/**
 * LocationActivityContext
 * 
 * Provides social context about activity at a specific location,
 * including recent visits by friends and social engagement metrics.
 */
struct LocationActivityContext: Identifiable, Codable {
    let id = UUID()
    let locationID: String
    let locationName: String
    let latitude: Double
    let longitude: Double
    let friendsVisitedRecently: [String] // Friend usernames
    let totalRecentVisits: Int
    let lastActivityDate: Date
    let socialScore: Double // 0.0 to 1.0 rating of social activity
    let recommendationText: String?
    let activityType: String // "visited", "reviewed", "shared", etc.
    
    var activityDescription: String {
        let count = friendsVisitedRecently.count
        if count == 0 {
            return "No recent friend activity"
        } else if count == 1 {
            return "\(friendsVisitedRecently[0]) was here recently"
        } else if count == 2 {
            return "\(friendsVisitedRecently[0]) and \(friendsVisitedRecently[1]) were here recently"
        } else {
            return "\(friendsVisitedRecently[0]), \(friendsVisitedRecently[1]) and \(count - 2) others were here recently"
        }
    }
}

/**
 * ProximityAlertSettings
 * 
 * Configuration settings for proximity alerts, including enabled types,
 * radius settings, and notification preferences.
 */
struct ProximityAlertSettings: Codable {
    var isEnabled: Bool = true
    var alertRadius: Double = 500.0 // meters
    var enabledAlertTypes: Set<ProximityAlertType> = Set(ProximityAlertType.allCases)
    var notificationThrottleMinutes: Int = 30
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    var backgroundProcessingEnabled: Bool = true
    var onlyNotifyWhenAvailable: Bool = true
    var minimumFriendDistance: Double = 50.0 // meters
    var maximumFriendDistance: Double = 2000.0 // meters
    
    func isAlertTypeEnabled(_ type: ProximityAlertType) -> Bool {
        return isEnabled && enabledAlertTypes.contains(type)
    }
    
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
}

// MARK: - Proximity Alert Manager

/**
 * ProximityAlertManager
 * 
 * Core manager class that handles proximity detection, friend monitoring,
 * and social context analysis for location-based notifications.
 */
class ProximityAlertManager: NSObject, ObservableObject {
    static let shared = ProximityAlertManager()
    
    // MARK: - Published Properties
    
    @Published var settings: ProximityAlertSettings = ProximityAlertSettings()
    @Published var nearbyFriends: [FriendProximityStatus] = []
    @Published var locationActivities: [LocationActivityContext] = []
    @Published var isActive: Bool = false
    @Published var lastUpdateTime: Date = Date()
    
    // MARK: - Private Properties
    
    private var proximityTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastNotificationTimes: [String: Date] = [:]
    private var isBackgroundMode: Bool = false
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupNotificationObservers()
        loadSettings()
    }
    
    deinit {
        stopProximityMonitoring()
    }
    
    // MARK: - Public Methods
    
    /**
     * Starts proximity monitoring with the current settings
     */
    func startProximityMonitoring() {
        guard settings.isEnabled else { return }
        
        isActive = true
        startProximityTimer()
        
        print("✅ ProximityAlertManager: Started proximity monitoring")
    }
    
    /**
     * Stops proximity monitoring and cleans up resources
     */
    func stopProximityMonitoring() {
        isActive = false
        proximityTimer?.invalidate()
        proximityTimer = nil
        
        print("⏹️ ProximityAlertManager: Stopped proximity monitoring")
    }
    
    /**
     * Updates proximity alert settings
     */
    func updateSettings(_ newSettings: ProximityAlertSettings) {
        settings = newSettings
        saveSettings()
        
        if settings.isEnabled && !isActive {
            startProximityMonitoring()
        } else if !settings.isEnabled && isActive {
            stopProximityMonitoring()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: NSNotification.Name("UIApplicationWillEnterForegroundNotification"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: NSNotification.Name("UIApplicationDidEnterBackgroundNotification"),
            object: nil
        )
    }
    
    @objc private func appWillEnterForeground() {
        isBackgroundMode = false
        if settings.isEnabled {
            startProximityMonitoring()
        }
    }
    
    @objc private func appDidEnterBackground() {
        isBackgroundMode = true
        if settings.backgroundProcessingEnabled {
            // Reduce frequency in background
            startProximityTimer(interval: 300) // 5 minutes
        } else {
            stopProximityMonitoring()
        }
    }
    
    private func startProximityTimer(interval: TimeInterval = 30) {
        proximityTimer?.invalidate()
        proximityTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.checkProximityAlerts()
            }
        }
    }
    
    private func checkProximityAlerts() async {
        // Simplified implementation - in a real app this would:
        // 1. Get current location
        // 2. Query nearby friends from database
        // 3. Check for location activities
        // 4. Generate appropriate notifications
        
        lastUpdateTime = Date()
        print("🔍 ProximityAlertManager: Checking proximity alerts...")
    }
    
    private func loadSettings() {
        // Load settings from UserDefaults or other persistence
        // For now, use defaults
    }
    
    private func saveSettings() {
        // Save settings to UserDefaults or other persistence
        // For now, do nothing
    }
} 