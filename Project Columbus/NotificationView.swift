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
    @State private var isLoading = false
    
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
                if isLoading {
                    ProgressView("Loading notifications...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredNotifications.isEmpty {
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
                                onMarkRead: { markNotificationAsRead(notification) },
                                onDelete: { deleteNotification(notification) }
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
                            markAllNotificationsAsRead()
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
                await loadNotifications()
                await requestNotificationPermission()
            }
        }
        .sheet(isPresented: $showSettings) {
            NotificationSettingsView()
                .environmentObject(notificationManager)
                .environmentObject(authManager)
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
            markNotificationAsRead(notification)
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
            deleteNotification(notification)
        }
    }
    
    private func deleteNotification(_ notification: AppNotification) {
        Task {
            // Delete from database
            await deleteNotificationFromDatabase(notification.id.uuidString)
            
            // Remove from local state
            await MainActor.run {
                notificationManager.deleteNotification(notification.id)
            }
        }
    }
    
    private func markNotificationAsRead(_ notification: AppNotification) {
        Task {
            // Update in database
            let success = await SupabaseManager.shared.markNotificationAsRead(notificationID: notification.id.uuidString)
            
            if success {
                await MainActor.run {
                    notificationManager.markAsRead(notification.id)
                }
            }
        }
    }
    
    private func markAllNotificationsAsRead() {
        Task {
            let unreadNotifications = filteredNotifications.filter { !$0.isRead }
            
            for notification in unreadNotifications {
                await SupabaseManager.shared.markNotificationAsRead(notificationID: notification.id.uuidString)
            }
            
            await MainActor.run {
                notificationManager.markAllAsRead()
            }
        }
    }
    
    private func loadNotifications() async {
        guard let currentUserID = authManager.currentUserID else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        await fetchNotificationsFromDatabase(userID: currentUserID)
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func refreshNotifications() async {
        await loadNotifications()
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
    
    // MARK: - Database Operations
    
    private func fetchNotificationsFromDatabase(userID: String) async {
        do {
            // Clear existing notifications
            await MainActor.run {
                notificationManager.clearAllNotifications()
            }
            
            // Fetch from database
            struct NotificationDB: Codable {
                let id: String
                let user_id: String
                let type: String
                let title: String
                let message: String
                let created_at: String
                let is_read: Bool
                let priority: String?
                let from_user_id: String?
                let related_pin_id: String?
                let related_list_id: String?
                let action_data: String?
            }
            
            let notifications: [NotificationDB] = try await SupabaseManager.shared.client
                .from("notifications")
                .select()
                .eq("user_id", value: userID)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            
            print("📱 NotificationView: Loaded \(notifications.count) notifications from database")
            
            for dbNotification in notifications {
                // Parse the created_at timestamp
                let formatter = ISO8601DateFormatter()
                let timestamp = formatter.date(from: dbNotification.created_at) ?? Date()
                
                // Parse optional fields
                let priority = NotificationPriority(rawValue: dbNotification.priority ?? "normal") ?? .normal
                
                // Parse action data if present
                var actionData: [String: String]? = nil
                if let actionDataString = dbNotification.action_data,
                   let data = actionDataString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    actionData = json
                }
                
                // Convert string type to NotificationType
                let notificationType = NotificationType(rawValue: dbNotification.type) ?? .system
                
                let notification = AppNotification(
                    id: UUID(uuidString: dbNotification.id) ?? UUID(),
                    type: notificationType,
                    title: dbNotification.title,
                    message: dbNotification.message,
                    timestamp: timestamp,
                    priority: priority,
                    isRead: dbNotification.is_read,
                    actionData: actionData,
                    senderID: dbNotification.from_user_id,
                    relatedPinID: dbNotification.related_pin_id,
                    relatedListID: dbNotification.related_list_id
                )
                
                await MainActor.run {
                    notificationManager.addNotification(notification)
                }
            }
            
        } catch {
            print("❌ Failed to fetch notifications: \(error)")
        }
    }
    
    private func deleteNotificationFromDatabase(_ notificationID: String) async {
        do {
            try await SupabaseManager.shared.client
                .from("notifications")
                .delete()
                .eq("id", value: notificationID)
                .execute()
            
            print("✅ Deleted notification from database: \(notificationID)")
        } catch {
            print("❌ Failed to delete notification: \(error)")
        }
    }
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
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingSystemSettings = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Push Notifications") {
                    HStack {
                        Toggle("Enable Push Notifications", isOn: $notificationManager.settings.pushNotificationsEnabled)
                    }
                    .onChange(of: notificationManager.settings.pushNotificationsEnabled) { enabled in
                        if enabled {
                            Task {
                                let granted = await notificationManager.requestPermission()
                                if !granted {
                                    await MainActor.run {
                                        notificationManager.settings.pushNotificationsEnabled = false
                                        showingSystemSettings = true
                                    }
                                }
                            }
                        }
                    }
                    
                    if notificationManager.settings.pushNotificationsEnabled {
                        Toggle("Sound", isOn: $notificationManager.settings.soundEnabled)
                        Toggle("Badge", isOn: $notificationManager.settings.badgeEnabled)
                        Toggle("Show Previews", isOn: $notificationManager.settings.previewEnabled)
                    }
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
                        Task {
                            await clearAllNotifications()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            await notificationManager.saveSettings()
                        }
                        dismiss()
                    }
                }
            }
        }
        .alert("Enable Notifications", isPresented: $showingSystemSettings) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To receive notifications, please enable them in your device Settings.")
        }
    }
    
    private func clearAllNotifications() async {
        // Clear from local storage
        await MainActor.run {
            notificationManager.clearAllNotifications()
        }
        
        // Clear from database if user is logged in
        if let currentUserID = authManager.currentUserID {
            do {
                try await SupabaseManager.shared.client
                    .from("notifications")
                    .delete()
                    .eq("user_id", value: currentUserID)
                    .execute()
                
                print("✅ Cleared all notifications from database")
            } catch {
                print("❌ Failed to clear notifications from database: \(error)")
            }
        }
    }
}
