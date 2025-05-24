//
//  DirectMessagingView.swift
//  Project Columbus
//
//  Created by Assistant
//

import SwiftUI
import Foundation

struct DirectMessagingView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var conversations: [Conversation] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading conversations...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "message.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("No messages yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start a conversation by sending a pin to a friend!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Conversations list
                    List(conversations) { conversation in
                        NavigationLink(destination: ChatView(conversation: conversation)) {
                            ConversationRowView(conversation: conversation)
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: Add compose new message functionality
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .onAppear {
            loadConversations()
        }
    }
    
    private func loadConversations() {
        isLoading = true
        // TODO: Load conversations from Supabase
        // For now, using mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            conversations = mockConversations
            isLoading = false
        }
    }
}

// MARK: - Supporting Views

struct ConversationRowView: View {
    let conversation: Conversation
    
    var body: some View {
        HStack {
            // Profile picture
            AsyncImage(url: URL(string: conversation.otherUser.avatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUser.full_name.isEmpty ? "@\(conversation.otherUser.username)" : conversation.otherUser.full_name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(conversation.lastMessage.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(conversation.lastMessage.preview)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if conversation.unreadCount > 0 {
                Text("\(conversation.unreadCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChatView: View {
    let conversation: Conversation
    @State private var messages: [Message] = []
    @State private var newMessageText = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubbleView(message: message)
                        }
                    }
                    .padding()
                }
                .onAppear {
                    loadMessages()
                }
            }
            
            // Message input
            HStack {
                TextField("Type a message...", text: $newMessageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    sendMessage()
                }
                .disabled(newMessageText.trim().isEmpty)
            }
            .padding()
        }
        .navigationTitle(conversation.otherUser.username)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadMessages() {
        // TODO: Load messages from Supabase
        messages = mockMessages
    }
    
    private func sendMessage() {
        guard !newMessageText.trim().isEmpty else { return }
        
        // TODO: Send message via Supabase
        let message = Message(
            id: UUID().uuidString,
            senderId: "current_user_id", // Replace with actual current user ID
            text: newMessageText,
            timestamp: Date(),
            type: .text
        )
        
        messages.append(message)
        newMessageText = ""
    }
}

struct MessageBubbleView: View {
    let message: Message
    
    var isFromCurrentUser: Bool {
        // TODO: Compare with actual current user ID
        return message.senderId == "current_user_id"
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading) {
                Text(message.text)
                    .padding()
                    .background(isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }
}

// MARK: - Data Models

struct Conversation: Identifiable, Codable {
    let id: String
    let otherUser: AppUser
    let lastMessage: MessagePreview
    let unreadCount: Int
}

struct MessagePreview: Codable {
    let preview: String
    let timestamp: Date
}

struct Message: Identifiable, Codable {
    let id: String
    let senderId: String
    let text: String
    let timestamp: Date
    let type: MessageType
}

enum MessageType: String, Codable {
    case text
    case pin
    case image
}

// MARK: - Mock Data (Remove when implementing real data)

private let mockConversations: [Conversation] = [
    Conversation(
        id: "1",
        otherUser: AppUser(
            id: "user1",
            username: "alice_travels",
            full_name: "Alice Johnson",
            email: nil,
            bio: nil,
            follower_count: 45,
            following_count: 67,
            isFollowedByCurrentUser: true,
            latitude: nil,
            longitude: nil,
            isCurrentUser: false,
            avatarURL: nil
        ),
        lastMessage: MessagePreview(
            preview: "That coffee shop you recommended was amazing! ☕️",
            timestamp: Date().addingTimeInterval(-3600)
        ),
        unreadCount: 2
    ),
    Conversation(
        id: "2",
        otherUser: AppUser(
            id: "user2",
            username: "foodie_explorer",
            full_name: "Bob Chen",
            email: nil,
            bio: nil,
            follower_count: 128,
            following_count: 89,
            isFollowedByCurrentUser: true,
            latitude: nil,
            longitude: nil,
            isCurrentUser: false,
            avatarURL: nil
        ),
        lastMessage: MessagePreview(
            preview: "Check out this new restaurant I found!",
            timestamp: Date().addingTimeInterval(-7200)
        ),
        unreadCount: 0
    )
]

private let mockMessages: [Message] = [
    Message(
        id: "1",
        senderId: "user1",
        text: "Hey! How was your trip to that café?",
        timestamp: Date().addingTimeInterval(-7200),
        type: .text
    ),
    Message(
        id: "2",
        senderId: "current_user_id",
        text: "It was incredible! The matcha latte was perfect ☕️",
        timestamp: Date().addingTimeInterval(-7000),
        type: .text
    ),
    Message(
        id: "3",
        senderId: "user1",
        text: "I knew you'd love it! That's my go-to spot",
        timestamp: Date().addingTimeInterval(-6800),
        type: .text
    )
]

// MARK: - String Extension

extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 