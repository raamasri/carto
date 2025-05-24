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
    @State private var searchText = ""
    @State private var showNewMessageView = false
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                (conversation.lastMessage?.content.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading conversations...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
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
                    Button(action: { showNewMessageView = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showNewMessageView) {
                NewMessageView { selectedUsers in
                    createConversationWithUsers(selectedUsers)
                    showNewMessageView = false
                }
                .environmentObject(authManager)
            }
            .searchable(text: $searchText, prompt: "Search conversations")
        }
        .onAppear {
            loadConversations()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Messages Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a conversation with your friends to share pins and recommendations!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Start New Message") {
                showNewMessageView = true
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var conversationsList: some View {
        List(filteredConversations) { conversation in
            NavigationLink(destination: ChatView(conversation: conversation)) {
                ConversationRowView(conversation: conversation)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
        .refreshable {
            await loadConversationsAsync()
        }
    }
    
    private func loadConversations() {
        isLoading = true
        
        Task {
            let loadedConversations = await SupabaseManager.shared.getUserConversations()
            
            await MainActor.run {
                self.conversations = loadedConversations
                self.isLoading = false
            }
        }
    }
    
    private func loadConversationsAsync() async {
        let loadedConversations = await SupabaseManager.shared.getUserConversations()
        
        await MainActor.run {
            self.conversations = loadedConversations
        }
        }
    
    private func createConversationWithUsers(_ selectedUsers: [AppUser]) {
        guard !selectedUsers.isEmpty else { return }
        
        Task {
            let userIds = selectedUsers.map { $0.id }
            
            if selectedUsers.count == 1 {
                // Direct conversation
                if let conversationId = await SupabaseManager.shared.getOrCreateDirectConversation(with: userIds.first!) {
                    await MainActor.run {
                        // Find the conversation in our local list or create a new one
                        if let existingConversation = self.conversations.first(where: { $0.id.uuidString == conversationId }) {
                            // Navigate to existing conversation
                            print("Existing conversation found")
                        } else {
                            // Create a new conversation object and add it to our list
                            let newConversation = Conversation(
                                id: UUID(uuidString: conversationId) ?? UUID(),
                                participants: selectedUsers,
                                lastMessage: nil,
                                updatedAt: Date(),
                                unreadCount: 0,
                                title: selectedUsers.first?.full_name ?? "Direct Message"
                            )
                            self.conversations.insert(newConversation, at: 0)
                        }
                    }
                }
            } else {
                // Group conversation
                if let conversationId = await SupabaseManager.shared.createConversation(with: userIds, isGroup: true) {
                    await MainActor.run {
                        let groupTitle = selectedUsers.prefix(2).map { $0.full_name }.joined(separator: ", ") + (selectedUsers.count > 2 ? "..." : "")
                        let newConversation = Conversation(
                            id: UUID(uuidString: conversationId) ?? UUID(),
                            participants: selectedUsers,
                            lastMessage: nil,
                            updatedAt: Date(),
                            unreadCount: 0,
                            title: groupTitle
                        )
                        self.conversations.insert(newConversation, at: 0)
                    }
                }
            }
        }
    }
 
}

struct ConversationRowView: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            AsyncImage(url: URL(string: (conversation.participants.first as? AppUser)?.avatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // Conversation details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(conversation.timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(conversation.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(conversation.unreadCount)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NewMessageView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedUsers: Set<String> = []
    @State private var users: [AppUser] = []
    
    let onUsersSelected: ([AppUser]) -> Void
    
    var filteredUsers: [AppUser] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { user in
                user.full_name.localizedCaseInsensitiveContains(searchText) ||
                user.username.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Users list
                List(filteredUsers) { user in
                    Button(action: {
                        if selectedUsers.contains(user.id) {
                            selectedUsers.remove(user.id)
                        } else {
                            selectedUsers.insert(user.id)
                        }
                    }) {
                        HStack {
                            // Profile image
                            AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading) {
                                Text(user.full_name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedUsers.contains(user.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listStyle(.plain)
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        let selected = users.filter { selectedUsers.contains($0.id) }
                        onUsersSelected(selected)
                    }
                    .disabled(selectedUsers.isEmpty)
                }
            }
        }
        .onAppear {
            loadUsers()
        }
    }
    
    private func loadUsers() {
        Task {
            guard let currentUserID = authManager.currentUserID else { return }
            
            // Load users the current user is following
            let followingUsers = await SupabaseManager.shared.getFollowingUsers(for: currentUserID)
            
            await MainActor.run {
                self.users = followingUsers
            }
        }
    }
    
}

// Note: ChatView and MessageBubbleView are now in ChatView.swift
// Note: Data models are now in Models.swift 