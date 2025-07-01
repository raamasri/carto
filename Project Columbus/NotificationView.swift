//
//  NotificationView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/21/25.
//

import SwiftUI
import Helpers
import PostgREST

struct NotificationPayload: Decodable {
    let id: String
    let from_user_id: String
    let users: UserPayload
}

struct UserPayload: Decodable {
    let username: String
    let full_name: String
    let avatar_url: String
}

struct NotificationItem: Identifiable {
    let id: UUID
    let fromUserID: String
    let fromUsername: String
    let fromFullName: String
    let avatarURL: String
}

struct NotificationView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedTab: NotificationTab = .all
    @State private var showSettings = false
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""
    
    enum NotificationTab: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
        case follows = "Follows"
        case messages = "Messages"
        case activity = "Activity"
        
        var icon: String {
            switch self {
            case .all: return "bell"
            case .unread: return "bell.badge"
            case .follows: return "person.badge.plus"
            case .messages: return "message"
            case .activity: return "heart"
            }
        }
    }
    
    var filteredNotifications: [AppNotification] {
        let baseNotifications = notificationManager.notifications
        
        switch selectedTab {
        case .all:
            return baseNotifications
        case .unread:
            return baseNotifications.filter { !$0.isRead }
        case .follows:
            return baseNotifications.filter { $0.type == .follow }
        case .messages:
            return baseNotifications.filter { $0.type == .message }
        case .activity:
            return baseNotifications.filter { 
                $0.type == .like || $0.type == .comment || $0.type == .friendActivity 
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(NotificationTab.allCases, id: \.self) { tab in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.caption)
                                    Text(tab.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    // Badge for unread count
                                    if tab == .unread && notificationManager.unreadCount > 0 {
                                        Text("\(notificationManager.unreadCount)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedTab == tab ? 
                                    Color.blue.opacity(0.1) : 
                                    Color(.systemGray6)
                                )
                                .foregroundColor(
                                    selectedTab == tab ? .blue : .primary
                                )
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                Divider()
                
                // Notifications List
                if filteredNotifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: selectedTab.icon)
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text(emptyStateMessage)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(emptyStateSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredNotifications) { notification in
                            NotificationRowView(
                                notification: notification,
                                onTap: { handleNotificationTap(notification) },
                                onMarkRead: { notificationManager.markAsRead(notification.id) },
                                onDelete: { notificationManager.deleteNotification(notification.id) }
                            )
                        }
                        .onDelete(perform: deleteNotifications)
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await refreshNotifications()
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !filteredNotifications.isEmpty {
                        Button("Mark All Read") {
                            notificationManager.markAllAsRead()
                        }
                        .font(.caption)
                    }
                    
                    NavigationLink(destination: NotificationsHelpView()) {
                        Image(systemName: "questionmark.circle")
                    }
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await refreshNotifications()
                await requestNotificationPermission()
            }
        }
        .sheet(isPresented: $showSettings) {
            NotificationSettingsView()
                .environmentObject(notificationManager)
        }
        .alert("Notification", isPresented: $showConfirmation) {
            Button("OK") { }
        } message: {
            Text(confirmationMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var emptyStateMessage: String {
        switch selectedTab {
        case .all: return "No Notifications"
        case .unread: return "All Caught Up!"
        case .follows: return "No Follow Requests"
        case .messages: return "No Messages"
        case .activity: return "No Activity"
        }
    }
    
    private var emptyStateSubtitle: String {
        switch selectedTab {
        case .all: return "You'll see all your notifications here"
        case .unread: return "You've read all your notifications"
        case .follows: return "No one has requested to follow you yet"
        case .messages: return "No new messages from friends"
        case .activity: return "No likes or comments on your pins"
        }
    }
    
    // MARK: - Actions
    
    private func handleNotificationTap(_ notification: AppNotification) {
        // Mark as read
        if !notification.isRead {
            notificationManager.markAsRead(notification.id)
        }
        
        // Handle navigation based on notification type
        guard let actionData = notification.actionData,
              let action = actionData["action"] else {
            return
        }
        
        switch action {
        case "view_profile":
            if let userID = actionData["userID"] {
                // Navigate to user profile
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenProfile"),
                    object: userID
                )
            }
        case "view_pin":
            if let pinID = actionData["pinID"] {
                // Navigate to pin detail
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenPin"),
                    object: pinID
                )
            }
        case "open_chat":
            if let conversationID = actionData["conversationID"] {
                // Navigate to chat
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenConversation"),
                    object: conversationID
                )
            }
        case "view_list":
            if let listID = actionData["listID"] {
                // Navigate to list
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenList"),
                    object: listID
                )
            }
        default:
            break
        }
    }
    
    private func deleteNotifications(at offsets: IndexSet) {
        for index in offsets {
            let notification = filteredNotifications[index]
            notificationManager.deleteNotification(notification.id)
        }
    }
    
    private func refreshNotifications() async {
        // Fetch new notifications from server
        await fetchFollowRequests()
        await fetchOtherNotifications()
    }
    
    private func requestNotificationPermission() async {
        let granted = await notificationManager.requestPermission()
        if !granted {
            await MainActor.run {
                confirmationMessage = "Enable notifications in Settings to stay updated"
                showConfirmation = true
            }
        }
    }
    
    // MARK: - Legacy Support (for existing follow request functionality)
    
    private func fetchFollowRequests() async {
        guard let currentUserID = authManager.currentUserID else { return }
        
        do {
            // For now, we'll use sample data since the notifications table may not exist yet
            // In production, this would fetch from the database
            print("📱 NotificationView: Fetching follow requests for user \(currentUserID)")
            
            // TODO: Implement actual database query when notifications table is ready
            let rawData: [[String: Any]] = []
            
            for row in rawData {
                guard let id = row["id"] as? String,
                      let fromUserID = row["from_user_id"] as? String,
                      let users = row["users"] as? [String: Any],
                      let username = users["username"] as? String,
                      let fullName = users["full_name"] as? String else {
                    continue
                }
                
                let notification = AppNotification(
                    type: .follow,
                    title: "New Follower",
                    message: "\(username) wants to follow you",
                    priority: .normal,
                    actionData: ["action": "view_profile", "userID": fromUserID],
                    senderID: fromUserID
                )
                
                notificationManager.addNotification(notification)
            }
        } catch {
            print("❌ Failed to fetch follow requests: \(error)")
        }
    }
    
    private func fetchOtherNotifications() async {
        // Fetch other types of notifications from Supabase
        guard let currentUserID = authManager.currentUserID else { return }
        
        do {
            // For now, we'll use sample data since the notifications table may not exist yet
            // In production, this would fetch from the database
            print("📱 NotificationView: Fetching notifications for user \(currentUserID)")
            
            // TODO: Implement actual database query when notifications table is ready
            let rawData: [[String: Any]] = []
            
            for row in rawData {
                guard let id = row["id"] as? String,
                      let type = row["type"] as? String,
                      let title = row["title"] as? String,
                      let message = row["message"] as? String,
                      let createdAt = row["created_at"] as? String,
                      let isRead = row["is_read"] as? Bool else {
                    continue
                }
                
                // Parse the created_at timestamp
                let formatter = ISO8601DateFormatter()
                let timestamp = formatter.date(from: createdAt) ?? Date()
                
                // Parse optional fields
                let priority = row["priority"] as? String ?? "normal"
                let senderID = row["from_user_id"] as? String
                let relatedPinID = row["related_pin_id"] as? String
                let relatedListID = row["related_list_id"] as? String
                
                // Parse action data if present
                var actionData: [String: String]? = nil
                if let actionDataString = row["action_data"] as? String,
                   let data = actionDataString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    actionData = json
                }
                
                // Convert string type to NotificationType
                let notificationType = NotificationType(rawValue: type) ?? .system
                let notificationPriority = NotificationPriority(rawValue: priority) ?? .normal
                
                let notification = AppNotification(
                    id: UUID(uuidString: id) ?? UUID(),
                    type: notificationType,
                    title: title,
                    message: message,
                    timestamp: timestamp,
                    priority: notificationPriority,
                    isRead: isRead,
                    actionData: actionData,
                    senderID: senderID,
                    relatedPinID: relatedPinID,
                    relatedListID: relatedListID
                )
                
                notificationManager.addNotification(notification)
            }
            
            print("📱 NotificationView: Loaded \(rawData.count) notifications from database")
            
        } catch {
            print("❌ Failed to fetch notifications: \(error)")
            
            // Fallback to sample notifications in development
            #if DEBUG
            if notificationManager.notifications.isEmpty {
                addSampleNotifications()
            }
            #endif
        }
    }
    
    #if DEBUG
    private func addSampleNotifications() {
        let sampleNotifications = [
            AppNotification(
                type: .like,
                title: "Pin Liked",
                message: "John liked your pin at Central Park",
                priority: .normal,
                actionData: ["action": "view_pin", "pinID": "sample_pin_1"],
                senderID: "sample_user_1"
            ),
            AppNotification(
                type: .message,
                title: "New Message",
                message: "Sarah: Hey, check out this cool place!",
                priority: .high,
                actionData: ["action": "open_chat", "conversationID": "sample_conv_1"],
                senderID: "sample_user_2"
            ),
            AppNotification(
                type: .pinNearby,
                title: "Pin Nearby",
                message: "You're near Coffee Shop (0.2 miles away)",
                priority: .normal,
                actionData: ["action": "view_pin", "pinID": "sample_pin_2"]
            )
        ]
        
        for notification in sampleNotifications {
            notificationManager.addNotification(notification)
        }
    }
    #endif
}

// MARK: - Notification Row View

struct NotificationRowView: View {
    let notification: AppNotification
    let onTap: () -> Void
    let onMarkRead: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: notification.type.icon)
                    .font(.title2)
                    .foregroundColor(notification.type.color)
                    .frame(width: 32, height: 32)
                    .background(notification.type.color.opacity(0.1))
                    .clipShape(Circle())
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(timeAgoString(from: notification.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(notification.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Priority indicator
                    if notification.priority == .high || notification.priority == .urgent {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(notification.priority == .urgent ? .red : .orange)
                            Text(notification.priority.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(notification.priority == .urgent ? .red : .orange)
                        }
                    }
                }
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive, action: onDelete)
            
            if !notification.isRead {
                Button("Mark Read", action: onMarkRead)
                    .tint(.blue)
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Push Notifications") {
                    Toggle("Enable Push Notifications", isOn: $notificationManager.settings.pushNotificationsEnabled)
                    Toggle("Sound", isOn: $notificationManager.settings.soundEnabled)
                    Toggle("Badge", isOn: $notificationManager.settings.badgeEnabled)
                    Toggle("Show Previews", isOn: $notificationManager.settings.previewEnabled)
                }
                
                Section("Notification Types") {
                    Toggle("Follow Requests", isOn: $notificationManager.settings.followNotifications)
                    Toggle("Likes", isOn: $notificationManager.settings.likeNotifications)
                    Toggle("Comments", isOn: $notificationManager.settings.commentNotifications)
                    Toggle("Messages", isOn: $notificationManager.settings.messageNotifications)
                    Toggle("Nearby Pins", isOn: $notificationManager.settings.nearbyPinNotifications)
                    Toggle("Friend Activity", isOn: $notificationManager.settings.friendActivityNotifications)
                    Toggle("List Invitations", isOn: $notificationManager.settings.listInviteNotifications)
                    Toggle("Location Reminders", isOn: $notificationManager.settings.locationReminderNotifications)
                    Toggle("System Notifications", isOn: $notificationManager.settings.systemNotifications)
                }
                
                Section("Quiet Hours") {
                    Toggle("Enable Quiet Hours", isOn: $notificationManager.settings.quietHoursEnabled)
                    
                    if notificationManager.settings.quietHoursEnabled {
                        DatePicker("Start Time", selection: $notificationManager.settings.quietHoursStart, displayedComponents: .hourAndMinute)
                        DatePicker("End Time", selection: $notificationManager.settings.quietHoursEnd, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("Actions") {
                    Button("Clear All Notifications") {
                        notificationManager.clearAllNotifications()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        notificationManager.saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }
}
