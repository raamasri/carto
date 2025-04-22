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
                    if let url = URL(string: user.avatarURL), !user.avatarURL.isEmpty {
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
            if listType == .followers {
                users = await SupabaseManager.shared.getFollowers(for: userID)
            } else {
                users = await SupabaseManager.shared.getFollowingUsers(for: userID)
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
