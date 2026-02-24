//
//  SocialService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation

class SocialService {
    private let client: SupabaseClient
    private let pinService: PinService
    
    init(client: SupabaseClient) {
        self.client = client
        self.pinService = PinService(client: client)
    }
    
    // MARK: - Follow Management
    
    /// Follow a user
    func followUser(followingID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            let follow = FollowDB(
                follower_id: session.user.id.uuidString,
                following_id: followingID.uuidString,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            _ = try await client
                .from("follows")
                .insert(follow)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to follow user: \(error)")
            return false
        }
    }
    
    /// Unfollow a user
    func unfollowUser(followingID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            _ = try await client
                .from("follows")
                .delete()
                .eq("follower_id", value: session.user.id.uuidString)
                .eq("following_id", value: followingID.uuidString)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to unfollow user: \(error)")
            return false
        }
    }
    
    /// Check if following a user
    func isFollowing(userID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            let follows: [FollowDB] = try await client
                .from("follows")
                .select("*")
                .eq("follower_id", value: session.user.id.uuidString)
                .eq("following_id", value: userID.uuidString)
                .limit(1)
                .execute()
                .value
            
            return !follows.isEmpty
        } catch {
            print("❌ Failed to check follow status: \(error)")
            return false
        }
    }
    
    /// Toggle follow status for a user by their string ID, returning true if now following.
    func toggleFollowForUser(with userID: String) async -> Bool {
        guard (try? await client.auth.session) != nil else { return false }
        guard let targetUUID = UUID(uuidString: userID) else { return false }
        
        let isCurrentlyFollowing = await isFollowing(userID: targetUUID)
        
        if isCurrentlyFollowing {
            _ = await unfollowUser(followingID: targetUUID)
            return false
        } else {
            return await followUser(followingID: targetUUID)
        }
    }
    
    /// Check if a follow request has been sent to a user
    func hasFollowRequestSent(to userID: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct NotificationCheck: Codable {
                let id: String
            }
            
            let notifications: [NotificationCheck] = try await client
                .from("notifications")
                .select("id")
                .eq("user_id", value: userID.uuidString)
                .eq("from_user_id", value: session.user.id.uuidString)
                .eq("type", value: "follow_request")
                .eq("is_read", value: false)
                .limit(1)
                .execute()
                .value
            
            return !notifications.isEmpty
        } catch {
            print("❌ Failed to check follow request status: \(error)")
            return false
        }
    }
    
    /// Get followers for a user
    func getFollowers(for userID: String) async throws -> [AppUser] {
        do {
            struct FollowerResponse: Codable {
                let follower_id: String
            }
            let follows: [FollowerResponse] = try await client
                .from("follows")
                .select("follower_id")
                .eq("following_id", value: userID)
                .execute()
                .value
            
            let followerIds = follows.map { $0.follower_id }
            if followerIds.isEmpty { return [] }
            
            let basicUsers: [BasicUser] = try await client
                .from("users")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .in("id", values: followerIds)
                .execute()
                .value
            
            return basicUsers.map { $0.toAppUser() }
        } catch {
            print("❌ Failed to fetch followers: \(error)")
            return []
        }
    }
    
    // MARK: - Notifications
    
    /// Send a follow request notification
    func sendFollowRequestNotification(to userID: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct FollowRequestNotificationData: Codable {
                let user_id: String
                let from_user_id: String
                let type: String
            }
            
            let notificationData = FollowRequestNotificationData(
                user_id: userID,
                from_user_id: session.user.id.uuidString,
                type: "follow_request"
            )
            
            _ = try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to send follow request notification: \(error)")
            return false
        }
    }
    
    /// Send a pin recommendation notification
    func sendPinRecommendationNotification(pinID: String, to userID: String, message: String? = nil) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct NotificationData: Codable {
                let user_id: String
                let from_user_id: String
                let type: String
                let pin_id: String
                let message: String?
            }
            
            let notificationData = NotificationData(
                user_id: userID,
                from_user_id: session.user.id.uuidString,
                type: "pin_recommendation",
                pin_id: pinID,
                message: message
            )
            
            _ = try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to send pin recommendation notification: \(error)")
            return false
        }
    }
    
    /// Mark notification as read
    func markNotificationAsRead(notificationID: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct NotificationUpdate: Codable {
                let is_read: Bool
            }
            
            _ = try await client
                .from("notifications")
                .update(NotificationUpdate(is_read: true))
                .eq("id", value: notificationID)
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to mark notification as read: \(error)")
            return false
        }
    }
    
    /// Create a like notification
    func createLikeNotification(to userID: String, from fromUserID: String, pinID: String, pinName: String) async -> Bool {
        do {
            struct LikeNotificationData: Codable {
                let user_id: String
                let type: String
                let title: String
                let message: String
                let from_user_id: String
                let related_pin_id: String
                let action_data: String
                let priority: String
            }
            
            let actionData = ["action": "view_pin", "pinID": pinID]
            let actionDataString = try JSONSerialization.data(withJSONObject: actionData)
            let actionDataJSON = String(data: actionDataString, encoding: .utf8) ?? "{}"
            
            let notificationData = LikeNotificationData(
                user_id: userID,
                type: "like",
                title: "Pin Liked",
                message: "Someone liked your pin at \(pinName)",
                from_user_id: fromUserID,
                related_pin_id: pinID,
                action_data: actionDataJSON,
                priority: "normal"
            )
            
            try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to create like notification: \(error)")
            return false
        }
    }
    
    /// Create a comment notification
    func createCommentNotification(to userID: String, from fromUserID: String, pinID: String, pinName: String, comment: String) async -> Bool {
        do {
            struct CommentNotificationData: Codable {
                let user_id: String
                let type: String
                let title: String
                let message: String
                let from_user_id: String
                let related_pin_id: String
                let action_data: String
                let priority: String
            }
            
            let actionData = ["action": "view_pin", "pinID": pinID]
            let actionDataString = try JSONSerialization.data(withJSONObject: actionData)
            let actionDataJSON = String(data: actionDataString, encoding: .utf8) ?? "{}"
            
            let notificationData = CommentNotificationData(
                user_id: userID,
                type: "comment",
                title: "New Comment",
                message: "Someone commented on your pin at \(pinName): \(comment)",
                from_user_id: fromUserID,
                related_pin_id: pinID,
                action_data: actionDataJSON,
                priority: "normal"
            )
            
            try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to create comment notification: \(error)")
            return false
        }
    }
    
    /// Create a message notification
    func createMessageNotification(to userID: String, from fromUserID: String, conversationID: String, messagePreview: String) async -> Bool {
        do {
            struct MessageNotificationData: Codable {
                let user_id: String
                let type: String
                let title: String
                let message: String
                let from_user_id: String
                let action_data: String
                let priority: String
            }
            
            let actionData = ["action": "open_chat", "conversationID": conversationID]
            let actionDataString = try JSONSerialization.data(withJSONObject: actionData)
            let actionDataJSON = String(data: actionDataString, encoding: .utf8) ?? "{}"
            
            let notificationData = MessageNotificationData(
                user_id: userID,
                type: "message",
                title: "New Message",
                message: messagePreview,
                from_user_id: fromUserID,
                action_data: actionDataJSON,
                priority: "high"
            )
            
            try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to create message notification: \(error)")
            return false
        }
    }
    
    /// Create a list invitation notification
    func createListInviteNotification(to userID: String, from fromUserID: String, listID: String, listName: String) async -> Bool {
        do {
            struct ListInviteNotificationData: Codable {
                let user_id: String
                let type: String
                let title: String
                let message: String
                let from_user_id: String
                let related_list_id: String
                let action_data: String
                let priority: String
            }
            
            let actionData = ["action": "view_list", "listID": listID]
            let actionDataString = try JSONSerialization.data(withJSONObject: actionData)
            let actionDataJSON = String(data: actionDataString, encoding: .utf8) ?? "{}"
            
            let notificationData = ListInviteNotificationData(
                user_id: userID,
                type: "list_invite",
                title: "List Invitation",
                message: "You've been invited to collaborate on \(listName)",
                from_user_id: fromUserID,
                related_list_id: listID,
                action_data: actionDataJSON,
                priority: "normal"
            )
            
            try await client
                .from("notifications")
                .insert(notificationData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to create list invite notification: \(error)")
            return false
        }
    }
    
    /// Get unread notification count
    func getUnreadNotificationCount() async -> Int {
        guard let session = try? await client.auth.session else { return 0 }
        
        do {
            let count: Int = try await client
                .from("notifications")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: session.user.id.uuidString)
                .eq("is_read", value: false)
                .execute()
                .count ?? 0
            
            return count
        } catch {
            print("❌ Failed to get unread notification count: \(error)")
            return 0
        }
    }
    
    // MARK: - User Blocking & Reporting
    
    /// Block a user
    func blockUser(userID: String, reason: String? = nil) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct BlockData: Codable {
                let blocker_id: String
                let blocked_id: String
                let reason: String?
                let block_type: String
            }
            
            let blockData = BlockData(
                blocker_id: session.user.id.uuidString,
                blocked_id: userID,
                reason: reason,
                block_type: "block"
            )
            
            _ = try await client
                .from("user_blocks")
                .insert(blockData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to block user: \(error)")
            return false
        }
    }
    
    /// Report a user
    func reportUser(userID: String, reason: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct ReportData: Codable {
                let blocker_id: String
                let blocked_id: String
                let reason: String
                let block_type: String
            }
            
            let reportData = ReportData(
                blocker_id: session.user.id.uuidString,
                blocked_id: userID,
                reason: reason,
                block_type: "report"
            )
            
            _ = try await client
                .from("user_blocks")
                .insert(reportData)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to report user: \(error)")
            return false
        }
    }
    
    /// Unblock a user
    func unblockUser(userID: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            _ = try await client
                .from("user_blocks")
                .delete()
                .eq("blocker_id", value: session.user.id.uuidString)
                .eq("blocked_id", value: userID)
                .eq("block_type", value: "block")
                .execute()
            
            return true
        } catch {
            print("❌ Failed to unblock user: \(error)")
            return false
        }
    }
    
    /// Check if a user is blocked
    func isUserBlocked(userID: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            struct BlockCheck: Codable {
                let id: String
            }
            
            let blocks: [BlockCheck] = try await client
                .from("user_blocks")
                .select("id")
                .eq("blocker_id", value: session.user.id.uuidString)
                .eq("blocked_id", value: userID)
                .eq("block_type", value: "block")
                .limit(1)
                .execute()
                .value
            
            return !blocks.isEmpty
        } catch {
            print("❌ Failed to check block status: \(error)")
            return false
        }
    }
    
    /// Get blocked users
    func getBlockedUsers() async -> [AppUser] {
        guard let session = try? await client.auth.session else { return [] }
        
        do {
            struct BlockedUserData: Codable {
                let blocked_id: String
                let users: BasicUser
            }
            
            let blockedData: [BlockedUserData] = try await client
                .from("user_blocks")
                .select("blocked_id, users!user_blocks_blocked_id_fkey(id, username, full_name, email, bio, latitude, longitude, avatar_url)")
                .eq("blocker_id", value: session.user.id.uuidString)
                .eq("block_type", value: "block")
                .execute()
                .value
            
            return blockedData.map { $0.users.toAppUser() }
        } catch {
            print("❌ Failed to fetch blocked users: \(error)")
            return []
        }
    }
    
    // MARK: - Friend Activity Feed
    
    /// Create friend activity entry (simple variant)
    func createFriendActivity(activityType: FriendActivityType, relatedPinId: UUID? = nil, locationName: String? = nil, description: String) async {
        guard let session = try? await client.auth.session else { return }
        guard let currentUser = try? await getCurrentUserProfile() else { return }
        
        do {
            struct ActivityData: Codable {
                let id: String
                let user_id: String
                let username: String
                let user_avatar_url: String?
                let activity_type: String
                let related_pin_id: String?
                let location_name: String?
                let description: String
                let created_at: String
            }
            
            let activityData = ActivityData(
                id: UUID().uuidString,
                user_id: session.user.id.uuidString,
                username: currentUser.username,
                user_avatar_url: currentUser.avatarURL,
                activity_type: activityType.rawValue,
                related_pin_id: relatedPinId?.uuidString,
                location_name: locationName,
                description: description,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            _ = try await client
                .from("friend_activities")
                .insert(activityData)
                .execute()
        } catch {
            print("❌ Failed to create friend activity: \(error)")
        }
    }
    
    /// Create friend activity entry (extended variant with metadata)
    func createFriendActivity(
        activityType: FriendActivityType,
        relatedPinId: UUID? = nil,
        relatedListId: UUID? = nil,
        relatedUserId: UUID? = nil,
        locationName: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        description: String,
        metadata: [String: Any] = [:]
    ) async throws {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        guard let currentUser = try? await getCurrentUserProfile() else {
            throw NSError(domain: "User", code: 404, userInfo: [NSLocalizedDescriptionKey: "Current user not found"])
        }
        
        do {
            struct ActivityInsert: Codable {
                let id: String
                let user_id: String
                let username: String
                let user_avatar_url: String?
                let activity_type: String
                let related_pin_id: String?
                let related_list_id: String?
                let related_user_id: String?
                let location_name: String?
                let location_latitude: Double?
                let location_longitude: Double?
                let description: String
                let metadata: String
                let created_at: String
                let is_visible: Bool
            }
            
            let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)
            let metadataString = String(data: metadataJSON, encoding: .utf8) ?? "{}"
            
            let activityInsert = ActivityInsert(
                id: UUID().uuidString,
                user_id: session.user.id.uuidString,
                username: currentUser.username,
                user_avatar_url: currentUser.avatarURL,
                activity_type: activityType.rawValue,
                related_pin_id: relatedPinId?.uuidString,
                related_list_id: relatedListId?.uuidString,
                related_user_id: relatedUserId?.uuidString,
                location_name: locationName,
                location_latitude: locationLatitude,
                location_longitude: locationLongitude,
                description: description,
                metadata: metadataString,
                created_at: ISO8601DateFormatter().string(from: Date()),
                is_visible: true
            )
            
            try await client
                .from("friend_activities")
                .insert(activityInsert)
                .execute()
            
            print("✅ [Activity Feed] Created activity: \(activityType.rawValue)")
            
            try await trackUserInteraction(
                type: "activity_created",
                targetPinId: relatedPinId,
                targetUserId: relatedUserId,
                locationName: locationName,
                locationLatitude: locationLatitude,
                locationLongitude: locationLongitude,
                value: 1.0,
                metadata: metadata
            )
            
        } catch {
            print("❌ [Activity Feed] Failed to create activity: \(error)")
            throw error
        }
    }
    
    /// Get friend activity feed (simple variant)
    func getFriendActivityFeed(for userId: String, limit: Int = 50) async -> [FriendActivity] {
        do {
            let followingUsers = await getFollowingUsers(for: userId)
            let followingIds = followingUsers.map { $0.id }
            
            if followingIds.isEmpty { return [] }
            
            let activitiesDB: [FriendActivityDB] = try await client
                .from("friend_activities")
                .select("*")
                .in("user_id", values: followingIds)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            var activities: [FriendActivity] = []
            for activityDB in activitiesDB {
                var relatedPin: Pin? = nil
                if let pinIdString = activityDB.related_pin_id,
                   let pinId = UUID(uuidString: pinIdString) {
                    relatedPin = await pinService.getPinById(pinId)
                }
                
                activities.append(activityDB.toFriendActivity(relatedPin: relatedPin))
            }
            
            return activities
        } catch {
            print("❌ Failed to get friend activity feed: \(error)")
            return []
        }
    }
    
    /// Get real-time friend activity feed with subscriptions and pagination
    func getFriendActivityFeedPaginated(for userId: String, limit: Int = 50, offset: Int = 0) async throws -> [FriendActivity] {
        do {
            struct ActivityDB: Codable {
                let id: String
                let user_id: String
                let username: String
                let user_avatar_url: String?
                let activity_type: String
                let related_pin_id: String?
                let related_list_id: String?
                let related_user_id: String?
                let location_name: String?
                let location_latitude: Double?
                let location_longitude: Double?
                let description: String
                let metadata: String
                let created_at: String
                let is_visible: Bool
            }
            
            let followingUsers = await getFollowingUsers(for: userId)
            let followingIds = followingUsers.map { $0.id }
            
            let subscriptions: [ActivityFeedSubscriptionDB] = try await client
                .from("activity_feed_subscriptions")
                .select("publisher_user_id")
                .eq("subscriber_user_id", value: userId)
                .eq("is_active", value: true)
                .execute()
                .value
            
            let subscribedUserIds = subscriptions.map { $0.publisher_user_id }
            let allUserIds = Array(Set(followingIds + subscribedUserIds))
            
            if allUserIds.isEmpty { return [] }
            
            let activitiesDB: [ActivityDB] = try await client
                .from("friend_activities")
                .select("*")
                .in("user_id", values: allUserIds)
                .eq("is_visible", value: true)
                .order("created_at", ascending: false)
                .limit(limit)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
            
            var activities: [FriendActivity] = []
            for activityDB in activitiesDB {
                var relatedPin: Pin? = nil
                if let pinIdString = activityDB.related_pin_id,
                   let pinId = UUID(uuidString: pinIdString) {
                    relatedPin = await pinService.getPinById(pinId)
                }
                
                var relatedUser: AppUser? = nil
                if let userIdString = activityDB.related_user_id {
                    relatedUser = await getUserById(userIdString)
                }
                _ = relatedUser
                
                _ = parseMetadata(activityDB.metadata)
                
                let activity = FriendActivity(
                    id: UUID(uuidString: activityDB.id) ?? UUID(),
                    userId: activityDB.user_id,
                    username: activityDB.username,
                    userAvatarURL: activityDB.user_avatar_url,
                    activityType: FriendActivityType(rawValue: activityDB.activity_type) ?? .visitedPlace,
                    relatedPinId: activityDB.related_pin_id != nil ? UUID(uuidString: activityDB.related_pin_id!) : nil,
                    relatedPin: relatedPin,
                    locationName: activityDB.location_name,
                    description: activityDB.description,
                    createdAt: ISO8601DateFormatter().date(from: activityDB.created_at) ?? Date()
                )
                
                activities.append(activity)
            }
            
            return activities
        } catch {
            print("❌ [Activity Feed] Failed to get feed: \(error)")
            throw error
        }
    }
    
    /// Get friend recommendations based on activity
    func getFriendRecommendations(for userId: String, limit: Int = 20) async -> [FriendRecommendation] {
        do {
            let followingUsers = await getFollowingUsers(for: userId)
            let followingIds = followingUsers.map { $0.id }
            
            if followingIds.isEmpty { return [] }
            
            let friendPins: [PinDB] = try await client
                .from("pins")
                .select("*")
                .in("user_id", values: followingIds)
                .gte("star_rating", value: 4.0)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            
            var locationGroups: [String: [PinDB]] = [:]
            for pin in friendPins {
                let key = "\(pin.location_name)_\(pin.latitude)_\(pin.longitude)"
                locationGroups[key, default: []].append(pin)
            }
            
            var recommendations: [FriendRecommendation] = []
            
            for (_, pins) in locationGroups {
                guard pins.count >= 2 else { continue }
                
                let averageRating = pins.compactMap { $0.star_rating }.reduce(0, +) / Double(pins.count)
                let friendIds = pins.map { $0.user_id }
                let friendUsernames = followingUsers.filter { friendIds.contains($0.id) }.map { $0.username }
                let recentVisits = pins.compactMap { ISO8601DateFormatter().date(from: $0.created_at) }
                
                let confidence = min(1.0, Double(pins.count) / 5.0)
                let reasonText = "\(pins.count) friends visited and rated it \(String(format: "%.1f", averageRating)) stars"
                
                if let firstPin = pins.first {
                    let recommendation = FriendRecommendation(
                        recommendedPlace: firstPin.toPin(),
                        recommendingFriendIds: friendIds,
                        recommendingFriendUsernames: friendUsernames,
                        averageRating: averageRating,
                        totalVisits: pins.count,
                        recentVisits: recentVisits,
                        reasonText: reasonText,
                        confidence: confidence
                    )
                    recommendations.append(recommendation)
                }
            }
            
            let sortedRecommendations = recommendations
                .sorted { $0.confidence > $1.confidence }
                .prefix(limit)
            
            try await storeRecommendations(Array(sortedRecommendations), for: userId)
            
            return Array(sortedRecommendations)
            
        } catch {
            print("❌ [Recommendations] Failed to generate recommendations: \(error)")
            return []
        }
    }
    
    // MARK: - Activity Feed Subscriptions
    
    /// Subscribe to a user's activity feed
    func subscribeToActivityFeed(publisherUserId: String, subscriptionType: String = "following") async throws {
        guard let session = try? await client.auth.session else { return }
        
        struct SubscriptionInsert: Codable {
            let subscriber_user_id: String
            let publisher_user_id: String
            let subscription_type: String
            let activity_types: [String]
            let is_active: Bool
            let created_at: String
        }
        
        let subscription = SubscriptionInsert(
            subscriber_user_id: session.user.id.uuidString,
            publisher_user_id: publisherUserId,
            subscription_type: subscriptionType,
            activity_types: FriendActivityType.allCases.map { $0.rawValue },
            is_active: true,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("activity_feed_subscriptions")
            .upsert(subscription)
            .execute()
        
        print("✅ [Activity Feed] Subscribed to user: \(publisherUserId)")
    }
    
    /// Unsubscribe from a user's activity feed
    func unsubscribeFromActivityFeed(publisherUserId: String) async throws {
        guard let session = try? await client.auth.session else { return }
        
        try await client
            .from("activity_feed_subscriptions")
            .update(["is_active": false])
            .eq("subscriber_user_id", value: session.user.id.uuidString)
            .eq("publisher_user_id", value: publisherUserId)
            .execute()
        
        print("✅ [Activity Feed] Unsubscribed from user: \(publisherUserId)")
    }
    
    // MARK: - Recommendation Engine
    
    /// Generate personalized place recommendations
    func generatePlaceRecommendations(for userId: String, limit: Int = 20) async throws -> [FriendRecommendation] {
        do {
            _ = try await getUserPreferences(userId: userId)
            
            let followingUsers = await getFollowingUsers(for: userId)
            let followingIds = followingUsers.map { $0.id }
            
            if followingIds.isEmpty {
                return try await generateTrendingRecommendations(for: userId, limit: limit)
            }
            
            let friendPins: [PinDB] = try await client
                .from("pins")
                .select("*")
                .in("user_id", values: followingIds)
                .gte("star_rating", value: 4.0)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            
            var locationGroups: [String: [PinDB]] = [:]
            for pin in friendPins {
                let key = "\(pin.location_name)_\(pin.latitude)_\(pin.longitude)"
                locationGroups[key, default: []].append(pin)
            }
            
            var recommendations: [FriendRecommendation] = []
            
            for (_, pins) in locationGroups {
                guard let firstPin = pins.first else { continue }
                
                let averageRating = pins.compactMap { $0.star_rating }.reduce(0, +) / Double(pins.count)
                let totalVisits = pins.count
                let recentVisits = pins.compactMap { ISO8601DateFormatter().date(from: $0.created_at) }
                    .filter { $0.timeIntervalSinceNow > -30 * 24 * 60 * 60 }
                
                let endorsingFriendIds = Array(Set(pins.map { $0.user_id }))
                let endorsingFriendUsernames = await getFriendUsernames(for: endorsingFriendIds)
                
                let friendEndorsements = endorsingFriendIds.count
                let recencyBonus = recentVisits.isEmpty ? 0.0 : 0.2
                let popularityBonus = totalVisits > 3 ? 0.1 : 0.0
                let ratingBonus = averageRating >= 4.5 ? 0.1 : 0.0
                
                let baseConfidence = min(Double(friendEndorsements) * 0.2, 0.8)
                let confidence = min(baseConfidence + recencyBonus + popularityBonus + ratingBonus, 1.0)
                
                let reasonText = generateReasoningText(
                    friendCount: friendEndorsements,
                    averageRating: averageRating,
                    totalVisits: totalVisits,
                    recentVisits: recentVisits.count
                )
                
                let recommendation = FriendRecommendation(
                    recommendedPlace: firstPin.toPin(),
                    recommendingFriendIds: endorsingFriendIds,
                    recommendingFriendUsernames: endorsingFriendUsernames,
                    averageRating: averageRating,
                    totalVisits: totalVisits,
                    recentVisits: recentVisits,
                    reasonText: reasonText,
                    confidence: confidence
                )
                recommendations.append(recommendation)
            }
            
            let sortedRecommendations = recommendations
                .sorted { $0.confidence > $1.confidence }
                .prefix(limit)
            
            try await storeRecommendations(Array(sortedRecommendations), for: userId)
            
            return Array(sortedRecommendations)
            
        } catch {
            print("❌ [Recommendations] Failed to generate recommendations: \(error)")
            throw error
        }
    }
    
    private func getUserPreferences(userId: String) async throws -> UserPreferences {
        struct UserPreferencesDB: Codable {
            let id: String
            let user_id: String
            let preferred_categories: [String]
            let favorite_cuisines: [String]
            let activity_types: [String]
            let price_range_min: Int
            let price_range_max: Int
            let distance_preference_km: Double
            let time_preferences: String
            let avoid_categories: [String]
            let recommendation_frequency: String
            let created_at: String
            let updated_at: String
        }
        
        do {
            let preferencesDB: UserPreferencesDB = try await client
                .from("user_preferences")
                .select("*")
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            
            return UserPreferences(
                userId: userId,
                preferredCategories: preferencesDB.preferred_categories,
                favoriteCuisines: preferencesDB.favorite_cuisines,
                activityTypes: preferencesDB.activity_types,
                priceRangeMin: preferencesDB.price_range_min,
                priceRangeMax: preferencesDB.price_range_max,
                distancePreferenceKm: preferencesDB.distance_preference_km,
                avoidCategories: preferencesDB.avoid_categories,
                recommendationFrequency: preferencesDB.recommendation_frequency
            )
        } catch {
            return try await createDefaultUserPreferences(userId: userId)
        }
    }
    
    private func createDefaultUserPreferences(userId: String) async throws -> UserPreferences {
        struct UserPreferencesInsert: Codable {
            let user_id: String
            let preferred_categories: [String]
            let favorite_cuisines: [String]
            let activity_types: [String]
            let price_range_min: Int
            let price_range_max: Int
            let distance_preference_km: Double
            let time_preferences: String
            let avoid_categories: [String]
            let recommendation_frequency: String
            let created_at: String
            let updated_at: String
        }
        
        let defaultPreferences = UserPreferencesInsert(
            user_id: userId,
            preferred_categories: ["restaurants", "cafes", "parks"],
            favorite_cuisines: [],
            activity_types: ["outdoor", "indoor"],
            price_range_min: 1,
            price_range_max: 4,
            distance_preference_km: 10.0,
            time_preferences: "{}",
            avoid_categories: [],
            recommendation_frequency: "daily",
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("user_preferences")
            .insert(defaultPreferences)
            .execute()
        
        return UserPreferences(
            userId: userId,
            preferredCategories: defaultPreferences.preferred_categories,
            favoriteCuisines: defaultPreferences.favorite_cuisines,
            activityTypes: defaultPreferences.activity_types,
            priceRangeMin: defaultPreferences.price_range_min,
            priceRangeMax: defaultPreferences.price_range_max,
            distancePreferenceKm: defaultPreferences.distance_preference_km,
            avoidCategories: defaultPreferences.avoid_categories,
            recommendationFrequency: defaultPreferences.recommendation_frequency
        )
    }
    
    private func generateTrendingRecommendations(for userId: String, limit: Int) async throws -> [FriendRecommendation] {
        let trendingPins: [PinDB] = try await client
            .from("pins")
            .select("*")
            .gte("star_rating", value: 4.0)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return trendingPins.map { pin in
            FriendRecommendation(
                recommendedPlace: pin.toPin(),
                recommendingFriendIds: [],
                recommendingFriendUsernames: [],
                averageRating: pin.star_rating ?? 0.0,
                totalVisits: 1,
                recentVisits: [ISO8601DateFormatter().date(from: pin.created_at) ?? Date()],
                reasonText: "Trending place with high ratings",
                confidence: 0.6
            )
        }
    }
    
    private func getFriendUsernames(for userIds: [String]) async -> [String] {
        do {
            let users: [BasicUser] = try await client
                .from("users")
                .select("username")
                .in("id", values: userIds)
                .execute()
                .value
            
            return users.map { $0.username }
        } catch {
            print("❌ Failed to get friend usernames: \(error)")
            return []
        }
    }
    
    private func generateReasoningText(
        friendCount: Int,
        averageRating: Double,
        totalVisits: Int,
        recentVisits: Int
    ) -> String {
        var reasons: [String] = []
        
        if friendCount == 1 {
            reasons.append("1 friend visited this place")
        } else if friendCount > 1 {
            reasons.append("\(friendCount) friends visited this place")
        }
        
        if averageRating >= 4.5 {
            reasons.append("excellent rating (\(String(format: "%.1f", averageRating))★)")
        } else if averageRating >= 4.0 {
            reasons.append("great rating (\(String(format: "%.1f", averageRating))★)")
        }
        
        if recentVisits > 0 {
            reasons.append("recently visited")
        }
        
        if totalVisits > 3 {
            reasons.append("popular among friends")
        }
        
        return reasons.isEmpty ? "Recommended for you" : reasons.joined(separator: ", ")
    }
    
    private func storeRecommendations(_ recommendations: [FriendRecommendation], for userId: String) async throws {
        struct RecommendationInsert: Codable {
            let id: String
            let user_id: String
            let recommended_pin_id: String?
            let location_name: String
            let location_latitude: Double
            let location_longitude: Double
            let city: String?
            let category: String?
            let subcategory: String?
            let recommendation_type: String
            let confidence_score: Double
            let reasoning: String
            let friend_endorsements: Int
            let endorsing_friend_ids: [String]
            let endorsing_friend_usernames: [String]
            let average_friend_rating: Double?
            let total_friend_visits: Int
            let is_trending: Bool
            let is_nearby: Bool
            let distance_km: Double?
            let predicted_rating: Double?
            let features: String
            let created_at: String
            let expires_at: String
        }
        
        let inserts = recommendations.map { rec in
            RecommendationInsert(
                id: UUID().uuidString,
                user_id: userId,
                recommended_pin_id: rec.recommendedPlace.id.uuidString,
                location_name: rec.recommendedPlace.locationName,
                location_latitude: rec.recommendedPlace.latitude,
                location_longitude: rec.recommendedPlace.longitude,
                city: rec.recommendedPlace.city,
                category: "restaurant",
                subcategory: nil,
                recommendation_type: "friend_based",
                confidence_score: rec.confidence,
                reasoning: rec.reasonText,
                friend_endorsements: rec.recommendingFriendIds.count,
                endorsing_friend_ids: rec.recommendingFriendIds,
                endorsing_friend_usernames: rec.recommendingFriendUsernames,
                average_friend_rating: rec.averageRating,
                total_friend_visits: rec.totalVisits,
                is_trending: false,
                is_nearby: false,
                distance_km: nil,
                predicted_rating: rec.averageRating,
                features: "{}",
                created_at: ISO8601DateFormatter().string(from: Date()),
                expires_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 60 * 60))
            )
        }
        
        try await client
            .from("place_recommendations")
            .insert(inserts)
            .execute()
    }
    
    /// Track user interactions for ML learning
    func trackUserInteraction(
        type: String,
        targetPinId: UUID? = nil,
        targetRecommendationId: UUID? = nil,
        targetUserId: UUID? = nil,
        locationName: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        value: Double = 1.0,
        metadata: [String: Any] = [:]
    ) async throws {
        guard let session = try? await client.auth.session else { return }
        
        struct InteractionInsert: Codable {
            let id: String
            let user_id: String
            let interaction_type: String
            let target_pin_id: String?
            let target_recommendation_id: String?
            let target_user_id: String?
            let location_name: String?
            let location_latitude: Double?
            let location_longitude: Double?
            let interaction_value: Double
            let metadata: String
            let created_at: String
        }
        
        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)
        let metadataString = String(data: metadataJSON, encoding: .utf8) ?? "{}"
        
        let interaction = InteractionInsert(
            id: UUID().uuidString,
            user_id: session.user.id.uuidString,
            interaction_type: type,
            target_pin_id: targetPinId?.uuidString,
            target_recommendation_id: targetRecommendationId?.uuidString,
            target_user_id: targetUserId?.uuidString,
            location_name: locationName,
            location_latitude: locationLatitude,
            location_longitude: locationLongitude,
            interaction_value: value,
            metadata: metadataString,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("user_interactions")
            .insert(interaction)
            .execute()
        
        print("✅ [ML] Tracked interaction: \(type)")
    }
    
    /// Update recommendation interaction (viewed, saved, dismissed)
    func updateRecommendationInteraction(
        recommendationId: UUID,
        isViewed: Bool? = nil,
        isSaved: Bool? = nil,
        isDismissed: Bool? = nil
    ) async throws {
        struct RecommendationUpdate: Codable {
            let is_viewed: Bool?
            let is_saved: Bool?
            let is_dismissed: Bool?
        }
        
        let updates = RecommendationUpdate(
            is_viewed: isViewed,
            is_saved: isSaved,
            is_dismissed: isDismissed
        )
        
        try await client
            .from("place_recommendations")
            .update(updates)
            .eq("id", value: recommendationId.uuidString)
            .execute()
        
        let interactionType = isDismissed == true ? "recommendation_dismiss" :
                             isSaved == true ? "recommendation_save" : "recommendation_view"
        
        try await trackUserInteraction(
            type: interactionType,
            targetRecommendationId: recommendationId,
            value: isDismissed == true ? -1.0 : 1.0
        )
    }
    
    // MARK: - Activity Reactions
    
    /// Add reaction to an activity
    func addActivityReaction(activityId: UUID, reactionType: ReactionType) async throws {
        guard let userId = try? await client.auth.session.user.id.uuidString else { return }
        
        let reactionData = [
            "activity_id": activityId.uuidString,
            "user_id": userId,
            "reaction_type": reactionType.rawValue
        ]
        
        _ = try await client
            .from("activity_reactions")
            .upsert(reactionData, onConflict: "activity_id,user_id")
            .execute()
    }
    
    // MARK: - Private Helpers
    
    private func getFollowingUsers(for userID: String) async -> [AppUser] {
        do {
            struct FollowResponse: Codable {
                let following_id: String
            }
            
            let follows: [FollowResponse] = try await client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: userID)
                .execute()
                .value
            
            let followingIds = follows.map { $0.following_id }
            if followingIds.isEmpty { return [] }
            
            let basicUsers: [BasicUser] = try await client
                .from("users")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .in("id", values: followingIds)
                .execute()
                .value
            
            return basicUsers.map { $0.toAppUser(currentUserID: userID) }
        } catch {
            print("❌ Failed to fetch following users: \(error)")
            return []
        }
    }
    
    private func getCurrentUserProfile() async throws -> AppUser {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let basicUser: BasicUser = try await client
            .from("users")
            .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
            .eq("id", value: session.user.id.uuidString)
            .single()
            .execute()
            .value
        
        return basicUser.toAppUser(currentUserID: session.user.id.uuidString)
    }
    
    private func getUserById(_ userId: String) async -> AppUser? {
        do {
            let basicUser: BasicUser = try await client
                .from("users")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            return basicUser.toAppUser()
        } catch {
            print("❌ Failed to get user by ID: \(error)")
            return nil
        }
    }
    
    private func parseMetadata(_ metadataString: String) -> [String: Any] {
        guard let data = metadataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }
}
