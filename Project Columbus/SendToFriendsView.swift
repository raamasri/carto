//
//  SendToFriendsView.swift
//  Project Columbus
//
//  Created by Assistant
//

import SwiftUI

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
            do {
                // Create notifications for each selected user
                let selectedUsernames = followingUsers.filter { selectedUsers.contains($0.id) }.map { $0.username }
                
                for userId in selectedUsers {
                    let notificationData = [
                        "user_id": userId,
                        "from_user_id": authManager.currentUserID ?? "",
                        "type": "pin_recommendation"
                    ]
                    
                    _ = try await SupabaseManager.shared.client
                        .from("notifications")
                        .insert(notificationData)
                        .execute()
                }
                
                await MainActor.run {
                    let names = selectedUsernames.joined(separator: ", ")
                    onSent("Pin sent to \(names)")
                    isSending = false
                }
                
            } catch {
                await MainActor.run {
                    onSent("Failed to send pin")
                    isSending = false
                }
            }
        }
    }
} 