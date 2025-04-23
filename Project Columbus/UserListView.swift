//
//  UserListView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/21/25.
//
import SwiftUI

enum UserListType {
    case followers
    case following
}

struct UserListView: View {
    let userID: String
    let listType: UserListType
    
    @State private var users: [AppUser] = []
    @State private var isLoading = true
    
    var body: some View {
        List(users, id: \.id) { user in
            NavigationLink(destination: UserProfileView(profileUser: user)) {
                HStack {
                    if let avatar = user.avatarURL, !avatar.isEmpty, let url = URL(string: avatar) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                            .frame(width: 40, height: 40)
                    }

                    VStack(alignment: .leading) {
                        Text(user.full_name.isEmpty ? "@\(user.username)" : user.full_name)
                        Text("@\(user.username)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle(listType == .followers ? "Followers" : "Following")
        .task {
            isLoading = true
            do {
                print("🧪 Fetching \(listType == .followers ? "followers" : "following") for userID: \(userID)")
                if listType == .followers {
                    users = try await SupabaseManager.shared.getFollowers(for: userID)
                } else {
                    users = try await SupabaseManager.shared.getFollowingUsers(for: userID)
                }
                print("🧪 Retrieved users: \(users.map { $0.username })")
            } catch {
                print("❌ Failed to fetch users: \(error)")
            }
            isLoading = false
            print("📍 Loaded \(users.count) users for \(listType == .followers ? "followers" : "following")")
        }
        
        if !isLoading && users.isEmpty {
            Text("No users found.")
                .foregroundColor(.gray)
        }
    }
}
