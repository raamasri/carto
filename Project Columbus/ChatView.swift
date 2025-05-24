//
//  ChatView.swift
//  Project Columbus
//
//  Created by Assistant
//

import SwiftUI
import Foundation

struct ChatView: View {
    let conversation: Conversation
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [Message] = []
    @State private var newMessageText = ""
    @State private var isLoading = false
    @FocusState private var isMessageFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId.lowercased() == authManager.currentUserID?.lowercased()
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.count) { _, _ in
                    // Auto-scroll to bottom when new message arrives
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Scroll to bottom when view appears
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // Message input
            HStack(alignment: .bottom, spacing: 8) {
                // Text input container
                HStack(spacing: 8) {
                    TextField("Message", text: $newMessageText, axis: .vertical)
                        .focused($isMessageFieldFocused)
                        .lineLimit(1...4)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                }
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                       Color(.systemGray3) : 
                                       Color(red: 0.0, green: 0.48, blue: 1.0))
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 32, height: 32)
                        )
                }
                .disabled(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .scaleEffect(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: newMessageText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: -1)
            )
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            loadMessages()
        }
    }
    
    private func loadMessages() {
        isLoading = true
        
        Task {
            print("🔄 Loading messages for conversation: \(conversation.id.uuidString)")
            print("📊 Conversation participants: \(conversation.participants.count)")
            if let participants = conversation.participants as? [AppUser] {
                for participant in participants {
                    print("  - \(participant.full_name) (@\(participant.username)) ID: \(participant.id)")
                }
            }
            
            let loadedMessages = await SupabaseManager.shared.getConversationMessages(
                conversationId: conversation.id.uuidString
            )
            
            print("✅ Loaded \(loadedMessages.count) messages")
            print("🆔 Current user ID: \(authManager.currentUserID ?? "nil")")
            for message in loadedMessages {
                let isFromCurrentUser = message.senderId.lowercased() == authManager.currentUserID?.lowercased()
                print("  - From: \(message.senderId), Content: \(message.content), IsFromCurrentUser: \(isFromCurrentUser)")
            }
            
            await MainActor.run {
                self.messages = loadedMessages
                self.isLoading = false
            }
        }
    }
    
    private func sendMessage() {
        let content = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let currentUserID = authManager.currentUserID else { return }
        
        print("📤 Sending message to conversation: \(conversation.id.uuidString)")
        print("📤 From user: \(currentUserID)")
        print("📤 Content: \(content)")
        
        // Create new message for immediate UI update
        let optimisticMessage = Message(
            conversationId: conversation.id.uuidString,
            senderId: currentUserID,
            content: content
        )
        
        // Add to local messages immediately for responsive UI
        messages.append(optimisticMessage)
        newMessageText = ""
        
        // Send to Supabase
        Task {
            let success = await SupabaseManager.shared.sendMessage(
                conversationId: conversation.id.uuidString,
                content: content,
                messageType: .text
            )
            
            print("📤 Message send result: \(success ? "SUCCESS" : "FAILED")")
            
            if success {
                // Notify DirectMessagingView to refresh conversation list
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("ConversationUpdated"), object: nil)
                    print("📤 Posted ConversationUpdated notification")
                }
            } else {
                // If sending failed, remove the optimistic message and show error
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                        messages.remove(at: index)
                    }
                    // TODO: Show error alert to user
                }
            }
        }
    }
    

}

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 50)
                messageBubble
            } else {
                messageBubble
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
    
    private var messageBubble: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            HStack {
                if isFromCurrentUser {
                    Spacer()
                }
                
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isFromCurrentUser ? 
                                  Color(red: 0.0, green: 0.48, blue: 1.0) : // iOS blue
                                  Color(.systemGray5)
                            )
                    )

                
                if !isFromCurrentUser {
                    Spacer()
                }
            }
            
            HStack {
                if isFromCurrentUser {
                    Spacer()
                }
                
                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                
                if !isFromCurrentUser {
                    Spacer()
                }
            }
        }
    }
    

    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.createdAt)
    }
}



#Preview {
    NavigationView {
        ChatView(conversation: Conversation(
            participants: [
                AppUser(id: "1", username: "alice", full_name: "Alice Johnson", email: "alice@example.com", bio: nil, follower_count: 0, following_count: 0, isFollowedByCurrentUser: false, latitude: nil, longitude: nil, isCurrentUser: false, avatarURL: nil)
            ],
            lastMessage: Message(
                conversationId: "test",
                senderId: "1",
                content: "Hey there!"
            )
        ))
        .environmentObject(AuthManager())
    }
} 