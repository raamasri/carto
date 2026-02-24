//
//  MessagingService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager - Messaging functions with Supabase Realtime
//

import Supabase
import Foundation
import UserNotifications

class MessagingService {
    private let client: SupabaseClient
    private var messageChannels: [String: RealtimeChannelV2] = [:]
    private var conversationChannels: [String: RealtimeChannelV2] = [:]
    private var messageObservationTasks: [String: Task<Void, Never>] = [:]
    private var conversationObservationTasks: [String: Task<Void, Never>] = [:]

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Conversations

    /// Get all conversations for the current user
    func getUserConversations() async -> [Conversation] {
        guard let session = try? await client.auth.session else { return [] }

        do {
            let conversationDetails: [ConversationDetailDB] = try await client
                .rpc("get_user_conversations", params: ["user_uuid": session.user.id])
                .execute()
                .value

            var conversations: [Conversation] = []

            for conversationDetail in conversationDetails {
                print("🔄 Processing conversation: \(conversationDetail.conversation_id)")
                print("  - Last message content: \(conversationDetail.last_message_content ?? "nil")")
                print("  - Last message sender: \(conversationDetail.last_message_sender_id ?? "nil")")
                print("  - Last message time: \(conversationDetail.last_message_created_at ?? "nil")")

                let participants = zip(zip(conversationDetail.participant_ids, conversationDetail.participant_usernames), conversationDetail.participant_full_names).map { (idUsername, fullName) in
                    let (id, username) = idUsername
                    return AppUser(
                        id: id,
                        username: username,
                        full_name: fullName,
                        email: nil,
                        bio: nil,
                        follower_count: 0,
                        following_count: 0,
                        isFollowedByCurrentUser: false,
                        latitude: nil,
                        longitude: nil,
                        isCurrentUser: false,
                        avatarURL: nil
                    )
                }

                let title: String
                if conversationDetail.is_group {
                    if let groupName = conversationDetail.conversation_name {
                        title = groupName
                    } else {
                        let names = participants.prefix(2).map { $0.full_name }
                        title = names.joined(separator: ", ") + (participants.count > 2 ? "..." : "")
                    }
                } else {
                    let currentUserId = session.user.id.uuidString.lowercased()
                    if let otherUser = participants.first(where: { $0.id.lowercased() != currentUserId }) {
                        title = otherUser.full_name
                    } else {
                        title = "Direct Message"
                    }
                }

                let conversation = conversationDetail.toConversation(with: participants, title: title)
                print("✅ Created conversation with title: '\(conversation.title)'")
                print("  - Last message: \(conversation.lastMessage?.content ?? "nil")")
                conversations.append(conversation)
            }

            return conversations
        } catch {
            print("❌ Failed to fetch user conversations: \(error)")
            return []
        }
    }

    /// Create a new conversation with specific users
    func createConversation(with userIds: [String], isGroup: Bool = false, name: String? = nil) async -> String? {
        guard let session = try? await client.auth.session else { return nil }

        do {
            var allParticipants = [session.user.id.uuidString]
            allParticipants.append(contentsOf: userIds)

            struct ConversationParams: Codable {
                let participant_ids: [String]
                let is_group_chat: Bool
                let conversation_name: String?
            }

            let params = ConversationParams(
                participant_ids: allParticipants,
                is_group_chat: isGroup,
                conversation_name: name
            )

            let conversationId: String = try await client
                .rpc("create_conversation", params: params)
                .execute()
                .value

            return conversationId
        } catch {
            print("❌ Failed to create conversation: \(error)")
            return nil
        }
    }

    /// Get or create a direct conversation between current user and another user
    func getOrCreateDirectConversation(with userId: String) async -> String? {
        guard let session = try? await client.auth.session else { return nil }

        print("🔄 Getting or creating conversation with user: \(userId)")
        print("  - Current user: \(session.user.id.uuidString)")

        let conversations = await getUserConversations()
        print("📊 Found \(conversations.count) existing conversations")

        for conversation in conversations {
            print("  - Checking conversation \(conversation.id.uuidString) with \(conversation.participants.count) participants")
            if conversation.participants.count == 2 {
                if let participants = conversation.participants as? [AppUser] {
                    let participantIds = participants.map { $0.id }
                    print("    - Participant IDs: \(participantIds)")
                    if participants.contains(where: { $0.id.lowercased() == userId.lowercased() }) {
                        print("✅ Found existing conversation: \(conversation.id.uuidString)")
                        return conversation.id.uuidString
                    }
                }
            }
        }

        print("🆕 No existing conversation found, creating new one")
        let newConversationId = await createConversation(with: [userId], isGroup: false)
        print("✅ Created new conversation: \(newConversationId ?? "FAILED")")
        return newConversationId
    }

    // MARK: - Messages

    /// Get messages for a specific conversation
    func getConversationMessages(conversationId: String, limit: Int = 50, offset: Int = 0) async -> [Message] {
        guard let session = try? await client.auth.session else {
            print("❌ No session found for getting messages")
            return []
        }

        print("📥 MessagingService: Getting messages for conversation: \(conversationId)")
        print("  - Requesting user: \(session.user.id.uuidString)")

        do {
            struct MessageParams: Codable {
                let conversation_uuid: String
                let requesting_user_id: String
                let limit_count: Int
                let offset_count: Int
            }

            let params = MessageParams(
                conversation_uuid: conversationId,
                requesting_user_id: session.user.id.uuidString,
                limit_count: limit,
                offset_count: offset
            )

            let messageDetails: [MessageDetailDB] = try await client
                .rpc("get_conversation_messages", params: params)
                .execute()
                .value

            print("📥 MessagingService: Retrieved \(messageDetails.count) message details")
            for detail in messageDetails {
                print("  - Message from \(detail.sender_id): \(detail.content)")
            }

            return messageDetails.map { messageDetail in
                var message = messageDetail.toMessage()
                message = Message(
                    id: message.id,
                    conversationId: conversationId,
                    senderId: message.senderId,
                    content: message.content,
                    createdAt: message.createdAt,
                    messageType: message.messageType
                )
                return message
            }
        } catch {
            print("❌ Failed to fetch conversation messages: \(error)")
            return []
        }
    }

    /// Send a message to a conversation
    func sendMessage(conversationId: String, content: String, messageType: MessageType = .text) async -> Bool {
        guard let session = try? await client.auth.session else {
            print("❌ No session found for sending message")
            return false
        }

        print("📤 MessagingService: Sending message")
        print("  - Conversation ID: \(conversationId)")
        print("  - Sender ID: \(session.user.id.uuidString)")
        print("  - Content: \(content)")
        print("  - Type: \(messageType.rawValue)")

        do {
            let messageId: String = try await client
                .rpc("send_message", params: [
                    "conversation_uuid": conversationId,
                    "sender_uuid": session.user.id.uuidString,
                    "message_content": content,
                    "msg_type": messageType.rawValue
                ])
                .execute()
                .value

            print("✅ MessagingService: Message sent with ID: \(messageId)")
            return !messageId.isEmpty
        } catch {
            print("❌ Failed to send message: \(error)")
            return false
        }
    }

    /// Mark a conversation as read
    func markConversationAsRead(conversationId: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }

        do {
            struct MarkReadParams: Codable {
                let conversation_uuid: String
                let user_uuid: String
            }

            let params = MarkReadParams(
                conversation_uuid: conversationId,
                user_uuid: session.user.id.uuidString
            )

            try await client
                .rpc("mark_conversation_read", params: params)
                .execute()

            return true
        } catch {
            print("❌ Failed to mark conversation as read: \(error)")
            return false
        }
    }

    /// Mark message as read and update read status
    func markMessageAsRead(conversationId: String, messageId: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }

        do {
            let _: String = try await client
                .rpc("mark_message_as_read", params: [
                    "conversation_uuid": conversationId,
                    "user_uuid": session.user.id.uuidString,
                    "message_uuid": messageId
                ])
                .execute()
                .value

            print("✅ Marked message as read: \(messageId)")
            return true
        } catch {
            print("❌ Failed to mark message as read: \(error)")
            return false
        }
    }

    /// Get message read status for a conversation
    func getMessageReadStatus(conversationId: String, messageId: String) async -> [String] {
        do {
            let readByUserIds: [String] = try await client
                .rpc("get_message_read_status", params: [
                    "conversation_uuid": conversationId,
                    "message_uuid": messageId
                ])
                .execute()
                .value

            return readByUserIds
        } catch {
            print("❌ Failed to get message read status: \(error)")
            return []
        }
    }

    // MARK: - Real-time Messaging (Supabase Realtime)

    /// Subscribe to real-time message updates for a conversation
    func subscribeToConversationMessages(conversationId: String, onMessageReceived: @escaping (Message) -> Void) async {
        print("🔔 Setting up Supabase Realtime messaging for conversation: \(conversationId)")

        await unsubscribeFromConversation(conversationId: conversationId)

        let channel = client.channel("messages:\(conversationId)")
        messageChannels[conversationId] = channel

        let changes = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("conversation_id", value: conversationId)
        )

        await channel.subscribe()

        let task = Task {
            for await change in changes {
                do {
                    let messageDB = try change.decodeRecord(as: MessageDB.self, decoder: JSONDecoder())
                    var message = messageDB.toMessage()
                    message = Message(
                        id: message.id,
                        conversationId: conversationId,
                        senderId: message.senderId,
                        content: message.content,
                        createdAt: message.createdAt,
                        messageType: message.messageType
                    )
                    await MainActor.run {
                        onMessageReceived(message)
                    }
                } catch {
                    print("❌ Failed to decode realtime message: \(error)")
                }
            }
        }
        messageObservationTasks[conversationId] = task
    }

    /// Subscribe to conversation list updates for a user
    func subscribeToUserConversations(userId: String, onConversationUpdate: @escaping () -> Void) async {
        print("🔔 Setting up Supabase Realtime conversation updates for user: \(userId)")

        await unsubscribeFromUserConversations(userId: userId)

        let channel = client.channel("user_conversations:\(userId)")
        conversationChannels[userId] = channel

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "conversation_participants",
            filter: .eq("user_id", value: userId)
        )

        await channel.subscribe()

        let task = Task {
            for await _ in changes {
                await MainActor.run {
                    onConversationUpdate()
                }
            }
        }
        conversationObservationTasks[userId] = task
    }

    /// Unsubscribe from all real-time updates
    func unsubscribeFromRealTimeUpdates() async {
        print("🔕 Unsubscribing from all real-time updates")

        for (conversationId, channel) in messageChannels {
            await client.removeChannel(channel)
            messageObservationTasks[conversationId]?.cancel()
            messageObservationTasks.removeValue(forKey: conversationId)
        }
        messageChannels.removeAll()

        for (userId, channel) in conversationChannels {
            await client.removeChannel(channel)
            conversationObservationTasks[userId]?.cancel()
            conversationObservationTasks.removeValue(forKey: userId)
        }
        conversationChannels.removeAll()
    }

    /// Unsubscribe from specific conversation
    func unsubscribeFromConversation(conversationId: String) async {
        print("🔕 Unsubscribing from conversation: \(conversationId)")
        if let channel = messageChannels[conversationId] {
            await client.removeChannel(channel)
            messageChannels.removeValue(forKey: conversationId)
            messageObservationTasks[conversationId]?.cancel()
            messageObservationTasks.removeValue(forKey: conversationId)
        }
    }

    /// Unsubscribe from user conversations
    func unsubscribeFromUserConversations(userId: String) async {
        print("🔕 Unsubscribing from user conversations: \(userId)")
        if let channel = conversationChannels[userId] {
            await client.removeChannel(channel)
            conversationChannels.removeValue(forKey: userId)
            conversationObservationTasks[userId]?.cancel()
            conversationObservationTasks.removeValue(forKey: userId)
        }
    }

    // MARK: - Rich Media Messaging

    /// Upload image for messaging and return URL
    func uploadMessageImage(_ imageData: Data, conversationId: String) async -> String? {
        let fileName = "message_\(UUID().uuidString).jpg"
        let filePath = "message-images/\(conversationId)/\(fileName)"

        do {
            try await client.storage
                .from("message-images")
                .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg"))

            let response = try client.storage
                .from("message-images")
                .getPublicURL(path: filePath)

            print("✅ Message image uploaded: \(response.absoluteString)")
            return response.absoluteString
        } catch {
            print("❌ Failed to upload message image: \(error)")
            return nil
        }
    }

    /// Send image message
    func sendImageMessage(conversationId: String, imageData: Data, caption: String? = nil) async -> Bool {
        guard let imageURL = await uploadMessageImage(imageData, conversationId: conversationId) else {
            return false
        }

        let content = caption ?? imageURL
        let messageType: MessageType = .image

        return await sendMessage(conversationId: conversationId, content: content, messageType: messageType)
    }

    /// Send location message
    func sendLocationMessage(conversationId: String, latitude: Double, longitude: Double, locationName: String? = nil) async -> Bool {
        let locationData: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "name": locationName ?? "Shared Location"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: locationData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return false
        }

        return await sendMessage(conversationId: conversationId, content: jsonString, messageType: .location)
    }

    /// Send pin message (share a pin from the app)
    func sendPinMessage(conversationId: String, pin: Pin) async -> Bool {
        let pinData: [String: Any] = [
            "id": pin.id.uuidString,
            "locationName": pin.locationName,
            "city": pin.city,
            "latitude": pin.latitude,
            "longitude": pin.longitude,
            "reaction": pin.reaction.rawValue,
            "reviewText": pin.reviewText ?? "",
            "starRating": pin.starRating ?? 0,
            "authorHandle": pin.authorHandle
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: pinData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return false
        }

        return await sendMessage(conversationId: conversationId, content: jsonString, messageType: .pin)
    }

    // MARK: - Notification Support

    /// Request notification permissions
    func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            print(granted ? "✅ Notification permissions granted" : "❌ Notification permissions denied")
            return granted
        } catch {
            print("❌ Failed to request notification permissions: \(error)")
            return false
        }
    }

    /// Send local notification for new message
    func sendMessageNotification(message: Message, conversationTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = conversationTitle
        content.body = message.displayContent
        content.sound = .default
        content.badge = 1

        content.userInfo = [
            "conversationId": message.conversationId,
            "messageId": message.id.uuidString
        ]

        let request = UNNotificationRequest(
            identifier: message.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("✅ Message notification sent")
            }
        }
    }

    /// Clear notifications for a conversation
    func clearNotifications(conversationId: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.compactMap { request -> String? in
                if let userInfo = request.content.userInfo as? [String: Any],
                   let notificationConversationId = userInfo["conversationId"] as? String,
                   notificationConversationId == conversationId {
                    return request.identifier
                }
                return nil
            }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        }
    }

    // MARK: - Encrypted Messaging

    /// Retrieve user's public key for end-to-end encryption
    func getUserPublicKey(userID: String) async throws -> String? {
        let response: [UserPublicKeyDB] = try await client
            .from("user_public_keys")
            .select("public_key")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value

        return response.first?.public_key
    }

    /// Send encrypted message
    func sendEncryptedMessage(
        conversationId: String,
        senderId: String,
        recipientId: String,
        content: String,
        messageType: MessageType = .text
    ) async throws -> String {
        guard let recipientPublicKeyString = try await getUserPublicKey(userID: recipientId) else {
            throw EncryptionError.invalidKey("Recipient public key not found")
        }

        guard let senderPrivateKey = try? EncryptionManager.shared.retrievePrivateKey(for: senderId) else {
            throw EncryptionError.invalidKey("Sender private key not found")
        }

        let recipientPublicKey = try EncryptionManager.shared.stringToPublicKey(recipientPublicKeyString)

        let encryptedMessage = try EncryptionManager.shared.encryptMessage(
            content,
            senderPrivateKey: senderPrivateKey,
            recipientPublicKey: recipientPublicKey
        )

        let messageId = UUID().uuidString
        let messageInsert = MessageInsert(
            id: messageId,
            conversation_id: conversationId,
            sender_id: senderId,
            content: "",
            message_type: messageType.rawValue,
            is_encrypted: true,
            encrypted_content: encryptedMessage.ciphertext,
            encryption_nonce: encryptedMessage.nonce,
            encryption_tag: encryptedMessage.tag
        )

        try await client
            .from("messages")
            .insert(messageInsert)
            .execute()

        print("✅ [Encryption] Encrypted message sent")
        return messageId
    }

    /// Decrypt message for current user
    func decryptMessage(_ message: Message, currentUserId: String) async throws -> String {
        guard message.isEncrypted,
              let encryptedContent = message.encryptedContent,
              let nonce = message.encryptionNonce,
              let tag = message.encryptionTag else {
            return message.content
        }

        let currentUserPrivateKey = try EncryptionManager.shared.retrievePrivateKey(for: currentUserId)

        guard let senderPublicKeyString = try await getUserPublicKey(userID: message.senderId) else {
            throw EncryptionError.invalidKey("Sender public key not found")
        }

        let senderPublicKey = try EncryptionManager.shared.stringToPublicKey(senderPublicKeyString)

        let encryptedMessage = EncryptedMessage(
            ciphertext: encryptedContent,
            nonce: nonce,
            tag: tag
        )

        return try EncryptionManager.shared.decryptMessage(
            encryptedMessage,
            recipientPrivateKey: currentUserPrivateKey,
            senderPublicKey: senderPublicKey
        )
    }
}
