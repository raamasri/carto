//
//  SendToFriendsView.swift
//  Project Columbus
//
//  Created by Assistant
//

import SwiftUI
import MapKit
import Foundation

// Explicit references to ensure types are available
typealias ProjectPin = Pin
typealias ProjectAppUser = AppUser
typealias ProjectAuthManager = AuthManager

struct SendToFriendsView: View {
    let pin: Pin
    let followingUsers: [AppUser]
    let onSent: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedUsers: Set<String> = []
    @State private var isSending = false
    @State private var message = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Pin preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sending:")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.locationName)
                                .font(.title3)
                                .bold()
                            Text(pin.city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let rating = pin.starRating {
                                HStack {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: "star.fill")
                                            .foregroundColor(star <= Int(rating) ? .yellow : .gray)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        Spacer()
                        
                        Image(systemName: "location.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Message section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a message (optional):")
                        .font(.headline)
                    
                    TextField("Hey, check out this place!", text: $message)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Friends list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Send to:")
                        .font(.headline)
                    
                    if followingUsers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("You're not following anyone yet")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(followingUsers) { user in
                            HStack {
                                AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                
                                VStack(alignment: .leading) {
                                    Text(user.username)
                                        .font(.headline)
                                    if !user.full_name.isEmpty {
                                        Text(user.full_name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedUsers.contains(user.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedUsers.contains(user.id) {
                                    selectedUsers.remove(user.id)
                                } else {
                                    selectedUsers.insert(user.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Send button
                Button("Send") {
                    sendPin()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedUsers.isEmpty || isSending)
                .padding()
            }
            .navigationTitle("Send Pin")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendPin() {
        guard !selectedUsers.isEmpty else { return }
        
        isSending = true
        
        Task {
            // Create notifications for each selected user using the enhanced notification system
            let selectedUsernames = followingUsers.filter { selectedUsers.contains($0.id) }.map { $0.username }
            
            var allSuccessful = true
            for userId in selectedUsers {
                let success = await SupabaseManager.shared.sendPinRecommendationNotification(
                    pinID: pin.id.uuidString,
                    to: userId,
                    message: message.isEmpty ? nil : message
                )
                
                if !success {
                    print("❌ Failed to send notification to user: \(userId)")
                    allSuccessful = false
                }
            }
            
            await MainActor.run {
                if allSuccessful {
                    let names = selectedUsernames.joined(separator: ", ")
                    onSent("Pin sent to \(names)")
                } else {
                    onSent("Pin sent with some failures")
                }
                isSending = false
            }
        }
    }
}

// Test preview to see if types are accessible
#if DEBUG
struct SendToFriendsView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePin = Pin(
            locationName: "Test Place",
            city: "Test City",
            date: "Today",
            latitude: 37.7749,
            longitude: -122.4194,
            reaction: .lovedIt,
            reviewText: nil,
            mediaURLs: nil,
            mentionedFriends: [],
            starRating: nil,
            distance: nil,
            authorHandle: "@test",
            createdAt: Date(),
            tripName: nil
        )
        
        let sampleUsers = [
            AppUser(
                id: "1",
                username: "testuser",
                full_name: "Test User",
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
        ]
        
        SendToFriendsView(
            pin: samplePin,
            followingUsers: sampleUsers,
            onSent: { _ in }
        )
        .environmentObject(AuthManager())
    }
}
#endif 