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
            // Messages list with iMessage-style layout
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            let showTimestamp = shouldShowTimestamp(for: message, at: index)
                            let showAvatar = shouldShowAvatar(for: message, at: index)
                            
                            VStack(spacing: 4) {
                                if showTimestamp {
                                    TimestampView(date: message.createdAt)
                                        .padding(.vertical, 8)
                                }
                                
                                iMessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: message.senderId.lowercased() == authManager.currentUserID?.lowercased(),
                                    showAvatar: showAvatar,
                                    conversation: conversation
                                )
                            }
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
            
            // iMessage-style input area
            iMessageInputView()
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .background(Color(.systemBackground))
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
    
    // MARK: - iMessage-style Input View
    @ViewBuilder
    private func iMessageInputView() -> some View {
        VStack(spacing: 0) {
            // Divider
            Divider()
                .background(Color(.systemGray4))
            
            VStack(spacing: 12) {
                // Media buttons row
                HStack(spacing: 20) {
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { showLocationPicker = true }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    
                    Button(action: { showPinPicker = true }) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Text input area
                HStack(alignment: .bottom, spacing: 8) {
                    // Text field container
                    HStack(spacing: 8) {
                        TextField("iMessage", text: $newMessageText, axis: .vertical)
                            .focused($isMessageFieldFocused)
                            .lineLimit(1...6)
                            .font(.body)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color(.systemGray5), lineWidth: 1)
                            )
                    }
                    
                    // Send button - iMessage style
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
                                          Color(.systemGray3) : 
                                          Color.blue)
                            )
                    }
                    .disabled(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .scaleEffect(newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: newMessageText.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Helper Functions
    private func shouldShowTimestamp(for message: Message, at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previousMessage = messages[index - 1]
        let timeDifference = message.createdAt.timeIntervalSince(previousMessage.createdAt)
        return timeDifference > 300 // Show timestamp if more than 5 minutes apart
    }
    
    private func shouldShowAvatar(for message: Message, at index: Int) -> Bool {
        let isFromCurrentUser = message.senderId.lowercased() == authManager.currentUserID?.lowercased()
        if isFromCurrentUser { return false }
        
        // Show avatar if it's the last message in a sequence from this sender
        if index == messages.count - 1 { return true }
        
        let nextMessage = messages[index + 1]
        let nextIsFromSameSender = nextMessage.senderId == message.senderId
        let nextIsFromCurrentUser = nextMessage.senderId.lowercased() == authManager.currentUserID?.lowercased()
        
        return !nextIsFromSameSender || nextIsFromCurrentUser
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

// MARK: - iMessage-style Components

struct TimestampView: View {
    let date: Date
    
    var body: some View {
        Text(formatTimestamp(date))
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        }
    }
}

@ViewBuilder
func iMessageBubbleView(message: Message, isFromCurrentUser: Bool, showAvatar: Bool, conversation: Conversation) -> some View {
    HStack(alignment: .bottom, spacing: 8) {
        if !isFromCurrentUser {
            // Avatar space
            if showAvatar {
                Circle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(getInitials(from: message.senderId))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
            } else {
                // Spacer to maintain alignment
                Color.clear
                    .frame(width: 30, height: 30)
            }
        }
        
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
            // Message bubble
            HStack {
                if isFromCurrentUser {
                    Spacer(minLength: 60)
                }
                
                messageContentView(message: message, isFromCurrentUser: isFromCurrentUser)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isFromCurrentUser ? 
                                  Color.blue : 
                                  Color(.systemGray5)
                            )
                    )
                
                if !isFromCurrentUser {
                    Spacer(minLength: 60)
                }
            }
            
            // Status and timestamp
            HStack(spacing: 4) {
                if isFromCurrentUser {
                    Spacer()
                    statusIndicator(for: message)
                    Text(formatMessageTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text(formatMessageTime(message.createdAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, isFromCurrentUser ? 20 : 46)
        }
        
        if isFromCurrentUser {
            Color.clear
                .frame(width: 8)
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 1)
}

@ViewBuilder
private func messageContentView(message: Message, isFromCurrentUser: Bool) -> some View {
    switch message.messageType {
    case .text:
        Text(message.content)
            .font(.body)
            .foregroundColor(isFromCurrentUser ? .white : .primary)
            .multilineTextAlignment(.leading)
            
    case .image:
        VStack(alignment: .leading, spacing: 8) {
            // Image placeholder with iMessage styling
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray4))
                .frame(width: 200, height: 150)
                .overlay(
                    VStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 30))
                            .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .gray)
                        Text("Photo")
                            .font(.caption)
                            .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .gray)
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
                Spacer()
            }
            
            // Location preview with iMessage styling
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray4))
                .frame(width: 200, height: 100)
                .overlay(
                    VStack {
                        Image(systemName: "map.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .gray)
                        Text("Tap to view")
                            .font(.caption)
                            .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .gray)
                    }
                )
            
            if let locationData = parseLocationData(message.content) {
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
                Spacer()
            }
            
            if let pinData = parsePinData(message.content) {
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
                        
                        Spacer()
                    }
                }
            }
        }
    }
}

@ViewBuilder
private func statusIndicator(for message: Message) -> some View {
    switch message.status {
    case .sending:
        ProgressView()
            .scaleEffect(0.6)
            .tint(.secondary)
            
    case .sent:
        Text("Sent")
            .font(.caption2)
            .foregroundColor(.secondary)
            
    case .delivered:
        Text("Delivered")
            .font(.caption2)
            .foregroundColor(.secondary)
            
    case .read:
        Text("Read")
            .font(.caption2)
            .foregroundColor(.blue)
            
    case .failed:
        Image(systemName: "exclamationmark.circle.fill")
            .font(.caption2)
            .foregroundColor(.red)
    }
}

private func formatMessageTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
}

private func getInitials(from userId: String) -> String {
    // Extract initials from user ID or handle
    let components = userId.components(separatedBy: CharacterSet.alphanumerics.inverted)
    let letters = components.compactMap { $0.first?.uppercased() }
    return letters.prefix(2).joined()
}

private func parseLocationData(_ content: String) -> MessageLocationData? {
    // Parse location data from message content
    // This is a simplified version - you might want to store location data separately
    return MessageLocationData(latitude: 0, longitude: 0, name: content.replacingOccurrences(of: "📍 ", with: ""))
}

private func parsePinData(_ content: String) -> MessagePinData? {
    // Parse pin data from message content
    // This is a simplified version - you might want to store pin data separately
    let name = content.replacingOccurrences(of: "📌 ", with: "")
    return MessagePinData(
        id: UUID().uuidString,
        locationName: name,
        city: "Unknown",
        latitude: 0,
        longitude: 0,
        reaction: "❤️",
        reviewText: "",
        starRating: 5,
        authorHandle: "user"
    )
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