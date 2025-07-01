//
//  NotificationManager.swift
//  Project Columbus copy
//
//  Created by Assistant on Date
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

// MARK: - Notification Types
enum NotificationType: String, CaseIterable, Codable {
    case follow = "follow"
    case like = "like"
    case comment = "comment"
    case message = "message"
    case pinNearby = "pin_nearby"
    case friendActivity = "friend_activity"
    case listInvite = "list_invite"
    case locationReminder = "location_reminder"
    case system = "system"
    
    var title: String {
        switch self {
        case .follow: return "New Follower"
        case .like: return "Pin Liked"
        case .comment: return "New Comment"
        case .message: return "New Message"
        case .pinNearby: return "Pin Nearby"
        case .friendActivity: return "Friend Activity"
        case .listInvite: return "List Invitation"
        case .locationReminder: return "Location Reminder"
        case .system: return "System Notification"
        }
    }
    
    var icon: String {
        switch self {
        case .follow: return "person.badge.plus"
        case .like: return "heart.fill"
        case .comment: return "bubble.left"
        case .message: return "message.fill"
        case .pinNearby: return "location.fill"
        case .friendActivity: return "person.2.fill"
        case .listInvite: return "list.bullet"
        case .locationReminder: return "bell.fill"
        case .system: return "gear"
        }
    }
    
    var color: Color {
        switch self {
        case .follow: return .blue
        case .like: return .red
        case .comment: return .green
        case .message: return .purple
        case .pinNearby: return .orange
        case .friendActivity: return .cyan
        case .listInvite: return .indigo
        case .locationReminder: return .yellow
        case .system: return .gray
        }
    }
}

// MARK: - Notification Priority
enum NotificationPriority: String, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var interruptionLevel: UNNotificationInterruptionLevel {
        switch self {
        case .low: return .passive
        case .normal: return .active
        case .high: return .timeSensitive
        case .urgent: return .critical
        }
    }
}

// MARK: - App Notification Model
struct AppNotification: Identifiable, Codable, Equatable {
    let id: UUID
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    let priority: NotificationPriority
    let isRead: Bool
    let actionData: [String: String]? // For deep linking and actions
    let senderID: String?
    let relatedPinID: String?
    let relatedListID: String?
    
    init(
        id: UUID = UUID(),
        type: NotificationType,
        title: String,
        message: String,
        timestamp: Date = Date(),
        priority: NotificationPriority = .normal,
        isRead: Bool = false,
        actionData: [String: String]? = nil,
        senderID: String? = nil,
        relatedPinID: String? = nil,
        relatedListID: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = timestamp
        self.priority = priority
        self.isRead = isRead
        self.actionData = actionData
        self.senderID = senderID
        self.relatedPinID = relatedPinID
        self.relatedListID = relatedListID
    }
}

// MARK: - Notification Settings
struct NotificationSettings: Codable {
    var pushNotificationsEnabled: Bool = true
    var followNotifications: Bool = true
    var likeNotifications: Bool = true
    var commentNotifications: Bool = true
    var messageNotifications: Bool = true
    var nearbyPinNotifications: Bool = true
    var friendActivityNotifications: Bool = true
    var listInviteNotifications: Bool = true
    var locationReminderNotifications: Bool = true
    var systemNotifications: Bool = true
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8)) ?? Date()
    var soundEnabled: Bool = true
    var badgeEnabled: Bool = true
    var previewEnabled: Bool = true
    
    func isTypeEnabled(_ type: NotificationType) -> Bool {
        switch type {
        case .follow: return followNotifications
        case .like: return likeNotifications
        case .comment: return commentNotifications
        case .message: return messageNotifications
        case .pinNearby: return nearbyPinNotifications
        case .friendActivity: return friendActivityNotifications
        case .listInvite: return listInviteNotifications
        case .locationReminder: return locationReminderNotifications
        case .system: return systemNotifications
        }
    }
}

// MARK: - Notification Manager
@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount: Int = 0
    @Published var settings: NotificationSettings = NotificationSettings()
    @Published var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    private let userNotificationCenter = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    // Local storage keys
    private let notificationsKey = "stored_notifications"
    private let settingsKey = "notification_settings"
    private let badgeCountKey = "notification_badge_count"
    
    override init() {
        super.init()
        setupNotificationCenter()
        loadStoredNotifications()
        loadSettings()
        Task {
            await checkPermissionStatus()
        }
    }
    
    // MARK: - Setup
    private func setupNotificationCenter() {
        userNotificationCenter.delegate = self
        
        // Setup notification categories with actions
        setupNotificationCategories()
        
        print("🔔 NotificationManager: Initialized")
    }
    
    private func setupNotificationCategories() {
        // Follow notification actions
        let followAcceptAction = UNNotificationAction(
            identifier: "FOLLOW_ACCEPT",
            title: "Accept",
            options: [.foreground]
        )
        let followDeclineAction = UNNotificationAction(
            identifier: "FOLLOW_DECLINE",
            title: "Decline",
            options: []
        )
        let followCategory = UNNotificationCategory(
            identifier: "FOLLOW_REQUEST",
            actions: [followAcceptAction, followDeclineAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Message notification actions
        let messageReplyAction = UNNotificationAction(
            identifier: "MESSAGE_REPLY",
            title: "Reply",
            options: [.foreground]
        )
        let messageMarkReadAction = UNNotificationAction(
            identifier: "MESSAGE_MARK_READ",
            title: "Mark as Read",
            options: []
        )
        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE",
            actions: [messageReplyAction, messageMarkReadAction],
            intentIdentifiers: [],
            options: []
        )
        
        // List invite actions
        let listAcceptAction = UNNotificationAction(
            identifier: "LIST_ACCEPT",
            title: "Accept",
            options: [.foreground]
        )
        let listDeclineAction = UNNotificationAction(
            identifier: "LIST_DECLINE",
            title: "Decline",
            options: []
        )
        let listCategory = UNNotificationCategory(
            identifier: "LIST_INVITE",
            actions: [listAcceptAction, listDeclineAction],
            intentIdentifiers: [],
            options: []
        )
        
        userNotificationCenter.setNotificationCategories([
            followCategory,
            messageCategory,
            listCategory
        ])
    }
    
    // MARK: - Permission Management
    func requestPermission() async -> Bool {
        do {
            let granted = try await userNotificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound, .provisional, .criticalAlert]
            )
            
            await checkPermissionStatus()
            
            if granted {
                await registerForRemoteNotifications()
                print("✅ NotificationManager: Permission granted")
            } else {
                print("❌ NotificationManager: Permission denied")
            }
            
            return granted
        } catch {
            print("❌ NotificationManager: Permission request failed: \(error)")
            return false
        }
    }
    
    private func checkPermissionStatus() async {
        let settings = await userNotificationCenter.notificationSettings()
        permissionStatus = settings.authorizationStatus
    }
    
    private func registerForRemoteNotifications() async {
        guard permissionStatus == .authorized || permissionStatus == .provisional else {
            return
        }
        
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Local Notifications
    func scheduleLocalNotification(_ notification: AppNotification) {
        guard settings.isTypeEnabled(notification.type) else {
            print("🔕 NotificationManager: Notification type \(notification.type) is disabled")
            return
        }
        
        // Check quiet hours
        if settings.quietHoursEnabled && isInQuietHours() {
            print("🔕 NotificationManager: In quiet hours, notification delayed")
            scheduleForAfterQuietHours(notification)
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = settings.soundEnabled ? .default : nil
        content.badge = settings.badgeEnabled ? NSNumber(value: unreadCount + 1) : nil
        
        // Add custom data
        var userInfo: [String: Any] = [
            "notificationID": notification.id.uuidString,
            "type": notification.type.rawValue,
            "timestamp": notification.timestamp.timeIntervalSince1970
        ]
        
        if let actionData = notification.actionData {
            userInfo["actionData"] = actionData
        }
        
        if let senderID = notification.senderID {
            userInfo["senderID"] = senderID
        }
        
        content.userInfo = userInfo
        
        // Set category for actions
        switch notification.type {
        case .follow:
            content.categoryIdentifier = "FOLLOW_REQUEST"
        case .message:
            content.categoryIdentifier = "MESSAGE"
        case .listInvite:
            content.categoryIdentifier = "LIST_INVITE"
        default:
            break
        }
        
        // Set interruption level based on priority
        content.interruptionLevel = notification.priority.interruptionLevel
        
        // Schedule immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        userNotificationCenter.add(request) { error in
            if let error = error {
                print("❌ NotificationManager: Failed to schedule notification: \(error)")
            } else {
                print("✅ NotificationManager: Scheduled notification: \(notification.title)")
            }
        }
    }
    
    private func isInQuietHours() -> Bool {
        guard settings.quietHoursEnabled else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentTime = calendar.dateComponents([.hour, .minute], from: now)
        let startTime = calendar.dateComponents([.hour, .minute], from: settings.quietHoursStart)
        let endTime = calendar.dateComponents([.hour, .minute], from: settings.quietHoursEnd)
        
        let currentMinutes = (currentTime.hour ?? 0) * 60 + (currentTime.minute ?? 0)
        let startMinutes = (startTime.hour ?? 0) * 60 + (startTime.minute ?? 0)
        let endMinutes = (endTime.hour ?? 0) * 60 + (endTime.minute ?? 0)
        
        if startMinutes <= endMinutes {
            // Same day quiet hours
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
        } else {
            // Overnight quiet hours
            return currentMinutes >= startMinutes || currentMinutes <= endMinutes
        }
    }
    
    private func scheduleForAfterQuietHours(_ notification: AppNotification) {
        let calendar = Calendar.current
        let endTime = calendar.dateComponents([.hour, .minute], from: settings.quietHoursEnd)
        
        var nextDay = calendar.startOfDay(for: Date())
        if let endHour = endTime.hour, let endMinute = endTime.minute {
            nextDay = calendar.date(byAdding: .day, value: 1, to: nextDay) ?? nextDay
            nextDay = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: nextDay) ?? nextDay
        }
        
        let timeInterval = nextDay.timeIntervalSinceNow
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = settings.soundEnabled ? .default : nil
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(notification.id.uuidString)_delayed",
            content: content,
            trigger: trigger
        )
        
        userNotificationCenter.add(request)
    }
    
    // MARK: - Notification Management
    func addNotification(_ notification: AppNotification) {
        notifications.insert(notification, at: 0)
        
        if !notification.isRead {
            unreadCount += 1
        }
        
        saveNotifications()
        updateBadgeCount()
        
        // Schedule local notification if app is in background
        if UIApplication.shared.applicationState != .active {
            scheduleLocalNotification(notification)
        }
        
        print("📱 NotificationManager: Added notification: \(notification.title)")
    }
    
    func markAsRead(_ notificationID: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == notificationID }) else {
            return
        }
        
        if !notifications[index].isRead {
            var updatedNotification = notifications[index]
            updatedNotification = AppNotification(
                id: updatedNotification.id,
                type: updatedNotification.type,
                title: updatedNotification.title,
                message: updatedNotification.message,
                timestamp: updatedNotification.timestamp,
                priority: updatedNotification.priority,
                isRead: true,
                actionData: updatedNotification.actionData,
                senderID: updatedNotification.senderID,
                relatedPinID: updatedNotification.relatedPinID,
                relatedListID: updatedNotification.relatedListID
            )
            
            notifications[index] = updatedNotification
            unreadCount = max(0, unreadCount - 1)
            
            saveNotifications()
            updateBadgeCount()
        }
    }
    
    func markAllAsRead() {
        notifications = notifications.map { notification in
            AppNotification(
                id: notification.id,
                type: notification.type,
                title: notification.title,
                message: notification.message,
                timestamp: notification.timestamp,
                priority: notification.priority,
                isRead: true,
                actionData: notification.actionData,
                senderID: notification.senderID,
                relatedPinID: notification.relatedPinID,
                relatedListID: notification.relatedListID
            )
        }
        
        unreadCount = 0
        saveNotifications()
        updateBadgeCount()
    }
    
    func deleteNotification(_ notificationID: UUID) {
        if let index = notifications.firstIndex(where: { $0.id == notificationID }) {
            let notification = notifications[index]
            notifications.remove(at: index)
            
            if !notification.isRead {
                unreadCount = max(0, unreadCount - 1)
            }
            
            saveNotifications()
            updateBadgeCount()
            
            // Remove from notification center
            userNotificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationID.uuidString])
            userNotificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationID.uuidString])
        }
    }
    
    func clearAllNotifications() {
        notifications.removeAll()
        unreadCount = 0
        saveNotifications()
        updateBadgeCount()
        
        // Clear all from notification center
        userNotificationCenter.removeAllPendingNotificationRequests()
        userNotificationCenter.removeAllDeliveredNotifications()
    }
    
    // MARK: - Badge Management
    private func updateBadgeCount() {
        UIApplication.shared.applicationIconBadgeNumber = settings.badgeEnabled ? unreadCount : 0
        UserDefaults.standard.set(unreadCount, forKey: badgeCountKey)
    }
    
    // MARK: - Storage
    private func saveNotifications() {
        do {
            let data = try JSONEncoder().encode(notifications)
            UserDefaults.standard.set(data, forKey: notificationsKey)
        } catch {
            print("❌ NotificationManager: Failed to save notifications: \(error)")
        }
    }
    
    private func loadStoredNotifications() {
        guard let data = UserDefaults.standard.data(forKey: notificationsKey) else {
            return
        }
        
        do {
            notifications = try JSONDecoder().decode([AppNotification].self, from: data)
            unreadCount = notifications.filter { !$0.isRead }.count
            updateBadgeCount()
            print("📱 NotificationManager: Loaded \(notifications.count) stored notifications")
        } catch {
            print("❌ NotificationManager: Failed to load notifications: \(error)")
            notifications = []
        }
    }
    
    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            return
        }
        
        do {
            settings = try JSONDecoder().decode(NotificationSettings.self, from: data)
            print("⚙️ NotificationManager: Loaded notification settings")
        } catch {
            print("❌ NotificationManager: Failed to load settings: \(error)")
            settings = NotificationSettings()
        }
    }
    
    func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(data, forKey: settingsKey)
            print("⚙️ NotificationManager: Settings saved")
        } catch {
            print("❌ NotificationManager: Failed to save settings: \(error)")
        }
    }
    
    // MARK: - Convenience Methods
    func createFollowNotification(from user: String, userID: String) {
        let notification = AppNotification(
            type: .follow,
            title: "New Follower",
            message: "\(user) started following you",
            priority: .normal,
            actionData: ["action": "view_profile", "userID": userID],
            senderID: userID
        )
        addNotification(notification)
    }
    
    func createLikeNotification(from user: String, pinName: String, userID: String, pinID: String) {
        let notification = AppNotification(
            type: .like,
            title: "Pin Liked",
            message: "\(user) liked your pin at \(pinName)",
            priority: .normal,
            actionData: ["action": "view_pin", "pinID": pinID],
            senderID: userID,
            relatedPinID: pinID
        )
        addNotification(notification)
    }
    
    func createMessageNotification(from user: String, preview: String, userID: String, conversationID: String) {
        let notification = AppNotification(
            type: .message,
            title: "New Message",
            message: "\(user): \(preview)",
            priority: .high,
            actionData: ["action": "open_chat", "conversationID": conversationID],
            senderID: userID
        )
        addNotification(notification)
    }
    
    func createNearbyPinNotification(pinName: String, distance: String, pinID: String) {
        let notification = AppNotification(
            type: .pinNearby,
            title: "Pin Nearby",
            message: "You're near \(pinName) (\(distance) away)",
            priority: .normal,
            actionData: ["action": "view_pin", "pinID": pinID],
            relatedPinID: pinID
        )
        addNotification(notification)
    }
    
    func createListInviteNotification(from user: String, listName: String, userID: String, listID: String) {
        let notification = AppNotification(
            type: .listInvite,
            title: "List Invitation",
            message: "\(user) invited you to collaborate on \(listName)",
            priority: .normal,
            actionData: ["action": "view_list", "listID": listID],
            senderID: userID,
            relatedListID: listID
        )
        addNotification(notification)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Handle notification actions
        switch response.actionIdentifier {
        case "FOLLOW_ACCEPT":
            handleFollowAction(userInfo: userInfo, accept: true)
        case "FOLLOW_DECLINE":
            handleFollowAction(userInfo: userInfo, accept: false)
        case "MESSAGE_REPLY":
            handleMessageReply(userInfo: userInfo)
        case "MESSAGE_MARK_READ":
            handleMessageMarkRead(userInfo: userInfo)
        case "LIST_ACCEPT":
            handleListInviteAction(userInfo: userInfo, accept: true)
        case "LIST_DECLINE":
            handleListInviteAction(userInfo: userInfo, accept: false)
        case UNNotificationDefaultActionIdentifier:
            handleDefaultAction(userInfo: userInfo)
        default:
            break
        }
        
        completionHandler()
    }
    
    nonisolated private func handleFollowAction(userInfo: [AnyHashable: Any], accept: Bool) {
        guard let userID = userInfo["senderID"] as? String else { return }
        
        Task {
            if accept {
                // Accept follow request logic
                print("✅ NotificationManager: Accepted follow request from \(userID)")
            } else {
                // Decline follow request logic
                print("❌ NotificationManager: Declined follow request from \(userID)")
            }
        }
    }
    
    nonisolated private func handleMessageReply(userInfo: [AnyHashable: Any]) {
        guard let conversationID = userInfo["conversationID"] as? String else { return }
        
        // Open message reply interface
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenConversation"),
            object: conversationID
        )
    }
    
    nonisolated private func handleMessageMarkRead(userInfo: [AnyHashable: Any]) {
        guard let notificationID = userInfo["notificationID"] as? String,
              let uuid = UUID(uuidString: notificationID) else { return }
        
        Task { @MainActor in
            markAsRead(uuid)
        }
    }
    
    nonisolated private func handleListInviteAction(userInfo: [AnyHashable: Any], accept: Bool) {
        guard let listID = userInfo["listID"] as? String else { return }
        
        Task {
            if accept {
                // Accept list invitation logic
                print("✅ NotificationManager: Accepted list invitation for \(listID)")
            } else {
                // Decline list invitation logic
                print("❌ NotificationManager: Declined list invitation for \(listID)")
            }
        }
    }
    
    nonisolated private func handleDefaultAction(userInfo: [AnyHashable: Any]) {
        guard let actionData = userInfo["actionData"] as? [String: String],
              let action = actionData["action"] else { return }
        
        switch action {
        case "view_profile":
            if let userID = actionData["userID"] {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenProfile"),
                    object: userID
                )
            }
        case "view_pin":
            if let pinID = actionData["pinID"] {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenPin"),
                    object: pinID
                )
            }
        case "open_chat":
            if let conversationID = actionData["conversationID"] {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenConversation"),
                    object: conversationID
                )
            }
        case "view_list":
            if let listID = actionData["listID"] {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenList"),
                    object: listID
                )
            }
        default:
            break
        }
    }
} 