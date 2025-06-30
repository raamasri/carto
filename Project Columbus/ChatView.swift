//
//  ChatView.swift
//  Project Columbus
//
//  Created by Assistant
//

import SwiftUI
import Foundation
import PhotosUI
import CoreLocation

struct ChatView: View {
    let conversation: Conversation
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [Message] = []
    @State private var newMessageText = ""
    @State private var isLoading = false
    @State private var showImagePicker = false
    @State private var showLocationPicker = false
    @State private var showPinPicker = false
    @State private var selectedImage: PhotosPickerItem?
    @FocusState private var isMessageFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(messages) { message in
                            EnhancedMessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId.lowercased() == authManager.currentUserID?.lowercased(),
                                conversation: conversation
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // Message input with rich media support
            VStack(spacing: 8) {
                // Rich media buttons
                HStack(spacing: 16) {
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { showLocationPicker = true }) {
                        Image(systemName: "location")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { showPinPicker = true }) {
                        Image(systemName: "mappin")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Text input
                HStack(alignment: .bottom, spacing: 8) {
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
                .padding(.bottom, 12)
            }
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
            setupRealTimeSubscription()
        }
        .onDisappear {
            Task {
                await SupabaseManager.shared.unsubscribeFromRealTimeUpdates()
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedImage, matching: .images)
        .onChange(of: selectedImage) { _, newItem in
            if let newItem = newItem {
                handleImageSelection(newItem)
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationSharingView { latitude, longitude, locationName in
                sendLocationMessage(latitude: latitude, longitude: longitude, locationName: locationName)
                showLocationPicker = false
            }
        }
        .sheet(isPresented: $showPinPicker) {
            PinSharingView { pin in
                sendPinMessage(pin: pin)
                showPinPicker = false
            }
        }
    }
    
    private func setupRealTimeSubscription() {
        Task {
            await SupabaseManager.shared.subscribeToConversationMessages(
                conversationId: conversation.id.uuidString
            ) { newMessage in
                // Add new message if it's not already in the list
                if !messages.contains(where: { $0.id == newMessage.id }) {
                    messages.append(newMessage)
                    
                    // Mark as read if it's not from current user
                    if newMessage.senderId.lowercased() != authManager.currentUserID?.lowercased() {
                        Task {
                            await SupabaseManager.shared.markMessageAsRead(
                                conversationId: conversation.id.uuidString,
                                messageId: newMessage.id.uuidString
                            )
                        }
                    }
                }
            }
        }
    }
    
    private func loadMessages() {
        isLoading = true
        
        Task {
            let loadedMessages = await SupabaseManager.shared.getConversationMessages(
                conversationId: conversation.id.uuidString
            )
            
            await MainActor.run {
                self.messages = loadedMessages.map { message in
                    var updatedMessage = message
                    updatedMessage.status = .delivered // Set status for existing messages
                    return updatedMessage
                }
                self.isLoading = false
            }
        }
    }
    
    private func sendMessage() {
        let content = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let currentUserID = authManager.currentUserID else { return }
        
        // Create optimistic message
        var optimisticMessage = Message(
            conversationId: conversation.id.uuidString,
            senderId: currentUserID,
            content: content
        )
        optimisticMessage.status = .sending
        
        messages.append(optimisticMessage)
        newMessageText = ""
        
        // Send to Supabase
        Task {
            let success = await SupabaseManager.shared.sendMessage(
                conversationId: conversation.id.uuidString,
                content: content,
                messageType: .text
            )
            
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    if success {
                        messages[index].status = .sent
                    } else {
                        messages[index].status = .failed
                    }
                }
            }
            
            if success {
                await MainActor.run {
                    NotificationCenter.default.post(name: NSNotification.Name("ConversationUpdated"), object: nil)
                }
            }
        }
    }
    
    private func handleImageSelection(_ item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await sendImageMessage(imageData: data)
            }
        }
    }
    
    private func sendImageMessage(imageData: Data) async {
        guard let currentUserID = authManager.currentUserID else { return }
        
        // Create optimistic message
        var optimisticMessage = Message(
            conversationId: conversation.id.uuidString,
            senderId: currentUserID,
            content: "📷 Photo",
            messageType: .image
        )
        optimisticMessage.status = .sending
        
        await MainActor.run {
            messages.append(optimisticMessage)
        }
        
        // Send image
        let success = await SupabaseManager.shared.sendImageMessage(
            conversationId: conversation.id.uuidString,
            imageData: imageData
        )
        
        await MainActor.run {
            if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                messages[index].status = success ? .sent : .failed
            }
        }
    }
    
    private func sendLocationMessage(latitude: Double, longitude: Double, locationName: String?) {
        guard let currentUserID = authManager.currentUserID else { return }
        
        // Create optimistic message
        var optimisticMessage = Message(
            conversationId: conversation.id.uuidString,
            senderId: currentUserID,
            content: "📍 \(locationName ?? "Location")",
            messageType: .location
        )
        optimisticMessage.status = .sending
        
        messages.append(optimisticMessage)
        
        Task {
            let success = await SupabaseManager.shared.sendLocationMessage(
                conversationId: conversation.id.uuidString,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName
            )
            
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    messages[index].status = success ? .sent : .failed
                }
            }
        }
    }
    
    private func sendPinMessage(pin: Pin) {
        guard let currentUserID = authManager.currentUserID else { return }
        
        // Create optimistic message
        var optimisticMessage = Message(
            conversationId: conversation.id.uuidString,
            senderId: currentUserID,
            content: "📌 \(pin.locationName)",
            messageType: .pin
        )
        optimisticMessage.status = .sending
        
        messages.append(optimisticMessage)
        
        Task {
            let success = await SupabaseManager.shared.sendPinMessage(
                conversationId: conversation.id.uuidString,
                pin: pin
            )
            
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                    messages[index].status = success ? .sent : .failed
                }
            }
        }
    }
}

struct EnhancedMessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let conversation: Conversation
    
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
                
                // Message content based on type
                messageContentView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isFromCurrentUser ? 
                                  Color(red: 0.0, green: 0.48, blue: 1.0) : 
                                  Color(.systemGray5)
                            )
                    )
                
                if !isFromCurrentUser {
                    Spacer()
                }
            }
            
            // Message metadata
            HStack(spacing: 4) {
                if isFromCurrentUser {
                    Spacer()
                    
                    // Status indicator for sent messages
                    statusIndicator
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
    
    @ViewBuilder
    private var messageContentView: some View {
        switch message.messageType {
        case .text:
            Text(message.content)
                .font(.body)
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                
        case .image:
            VStack(alignment: .leading, spacing: 8) {
                // Image placeholder or actual image
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray4))
                    .frame(width: 200, height: 150)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Photo")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
                
                if !message.content.isEmpty && message.content != "📷 Photo" {
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                }
            }
            
        case .location:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(isFromCurrentUser ? .white : .blue)
                    Text("Location")
                        .font(.headline)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                }
                
                // Location preview
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray4))
                    .frame(width: 200, height: 100)
                    .overlay(
                        VStack {
                            Image(systemName: "map")
                                .font(.title)
                                .foregroundColor(.gray)
                            Text("Tap to view")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
                
                if let locationData = parseLocationData() {
                    Text(locationData.name)
                        .font(.subheadline)
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.9) : .secondary)
                }
            }
            
        case .pin:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(isFromCurrentUser ? .white : .red)
                    Text("Pin Shared")
                        .font(.headline)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                }
                
                if let pinData = parsePinData() {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pinData.locationName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                        
                        Text(pinData.city)
                            .font(.caption)
                            .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .secondary)
                        
                        HStack {
                            Text(pinData.reaction)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(isFromCurrentUser ? .white.opacity(0.2) : Color(.systemGray6))
                                )
                                .foregroundColor(isFromCurrentUser ? .white : .primary)
                            
                            if pinData.starRating > 0 {
                                HStack(spacing: 2) {
                                    ForEach(0..<Int(pinData.starRating), id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.caption2)
                                            .foregroundColor(isFromCurrentUser ? .white : .yellow)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch message.status {
        case .sending:
            ProgressView()
                .scaleEffect(0.6)
                .tint(.secondary)
                
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.secondary)
                
        case .delivered:
            HStack(spacing: -2) {
                Image(systemName: "checkmark")
                    .font(.caption2)
                Image(systemName: "checkmark")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
            
        case .read:
            HStack(spacing: -2) {
                Image(systemName: "checkmark")
                    .font(.caption2)
                Image(systemName: "checkmark")
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.caption2)
                .foregroundColor(.red)
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: message.createdAt)
    }
    
    private func parseLocationData() -> MessageLocationData? {
        guard let data = message.content.data(using: .utf8),
              let locationDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let latitude = locationDict["latitude"] as? Double,
              let longitude = locationDict["longitude"] as? Double,
              let name = locationDict["name"] as? String else {
            return nil
        }
        
        return MessageLocationData(latitude: latitude, longitude: longitude, name: name)
    }
    
    private func parsePinData() -> MessagePinData? {
        guard let data = message.content.data(using: .utf8),
              let pinDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = pinDict["id"] as? String,
              let locationName = pinDict["locationName"] as? String,
              let city = pinDict["city"] as? String,
              let latitude = pinDict["latitude"] as? Double,
              let longitude = pinDict["longitude"] as? Double,
              let reaction = pinDict["reaction"] as? String,
              let reviewText = pinDict["reviewText"] as? String,
              let starRating = pinDict["starRating"] as? Double,
              let authorHandle = pinDict["authorHandle"] as? String else {
            return nil
        }
        
        return MessagePinData(
            id: id,
            locationName: locationName,
            city: city,
            latitude: latitude,
            longitude: longitude,
            reaction: reaction,
            reviewText: reviewText,
            starRating: starRating,
            authorHandle: authorHandle
        )
    }
}

// Helper views for rich media sharing
struct LocationSharingView: View {
    let onLocationSelected: (Double, Double, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Share Location")
                    .font(.title2)
                    .padding()
                
                Button("Share Current Location") {
                    // For demo purposes - in real app, would use LocationManager
                    onLocationSelected(37.7749, -122.4194, "San Francisco")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct PinSharingView: View {
    let onPinSelected: (Pin) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Share Pin")
                    .font(.title2)
                    .padding()
                
                Text("Select a pin from your collection to share")
                    .foregroundColor(.secondary)
                    .padding()
                
                // In real app, would show user's pins
                Button("Share Demo Pin") {
                    let demoPin = Pin(
                        locationName: "Golden Gate Bridge",
                        city: "San Francisco",
                        date: "2024-01-15",
                        latitude: 37.8199,
                        longitude: -122.4783,
                        reaction: .lovedIt,
                        reviewText: "Amazing views!",
                        mediaURLs: nil,
                        mentionedFriends: [],
                        starRating: 5.0,
                        distance: nil,
                        authorHandle: "@demo",
                        createdAt: Date(),
                        tripName: nil
                    )
                    onPinSelected(demoPin)
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .navigationTitle("Share Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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