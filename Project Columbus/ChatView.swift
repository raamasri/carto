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
                    LazyVStack(spacing: 8) {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId == authManager.currentUserID
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .onChange(of: messages.count) { _, _ in
                    // Auto-scroll to bottom when new message arrives
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input
            HStack(spacing: 12) {
                // Text input
                HStack {
                    TextField("Message...", text: $newMessageText, axis: .vertical)
                        .focused($isMessageFieldFocused)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .background(Color(.systemGray6))
                .cornerRadius(20)
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)
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
            let loadedMessages = await SupabaseManager.shared.getConversationMessages(
                conversationId: conversation.id.uuidString
            )
            
            await MainActor.run {
                self.messages = loadedMessages
                self.isLoading = false
            }
        }
    }
    
    private func sendMessage() {
        let content = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let currentUserID = authManager.currentUserID else { return }
        
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
            
            if !success {
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
        HStack {
            if isFromCurrentUser {
                Spacer()
                messageBubble
                    .background(Color.blue)
                    .foregroundColor(.white)
            } else {
                messageBubble
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                Spacer()
            }
        }
    }
    
    private var messageBubble: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                .cornerRadius(18)
                .foregroundColor(isFromCurrentUser ? .white : .primary)
            
            Text(timeString)
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isFromCurrentUser ? .trailing : .leading)
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