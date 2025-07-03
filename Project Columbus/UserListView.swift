//
//  UserListView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/21/25.
//
import SwiftUI
import Foundation

enum UserListType {
    case followers
    case following
}

struct UserListView: View {
    let userID: String
    let listType: UserListType
    
    @State private var users: [AppUser] = []
    @State private var isLoading = true
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    
    var body: some View {
        List(users, id: \.id) { user in
            NavigationLink(destination: UserProfileView(profileUser: user)
                .environmentObject(authManager)
                .environmentObject(pinStore)
            ) {
                HStack {
                    if let avatar = user.avatarURL, !avatar.isEmpty {
                        if let cached = ImageCache.shared.image(forKey: user.id) {
                            Image(uiImage: cached)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else if let url = URL(string: avatar) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    let _ = {
                                        if let uiImage = image.asUIImage() {
                                            ImageCache.shared.insertImage(uiImage, forKey: user.id)
                                        }
                                    }()
                                    image.resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure(_):
                                    Color.gray
                                case .empty:
                                    Color.gray
                                @unknown default:
                                    Color.gray
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        }
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
        .refreshable {
            isLoading = true
            do {
                var fetchedUsers: [AppUser]
                if listType == .followers {
                    fetchedUsers = try await SupabaseManager.shared.getFollowers(for: userID)
                } else {
                    fetchedUsers = try await SupabaseManager.shared.getFollowingUsers(for: userID)
                }
                
                // Filter out the current user from the display
                if let currentUserID = authManager.currentUserID {
                    fetchedUsers = fetchedUsers.filter { $0.id.lowercased() != currentUserID.lowercased() }
                }
                
                users = fetchedUsers
            } catch {
                print("❌ Failed to refresh users: \(error)")
            }
            isLoading = false
        }
        .task {
            isLoading = true
            do {
                print("🧪 Fetching \(listType == .followers ? "followers" : "following") for userID: \(userID)")
                var fetchedUsers: [AppUser]
                if listType == .followers {
                    fetchedUsers = try await SupabaseManager.shared.getFollowers(for: userID)
                } else {
                    fetchedUsers = try await SupabaseManager.shared.getFollowingUsers(for: userID)
                }
                
                // Filter out the current user from the display
                let originalCount = fetchedUsers.count
                if let currentUserID = authManager.currentUserID {
                    print("🔍 Current user ID: \(currentUserID)")
                    print("🔍 User IDs in list: \(fetchedUsers.map { "\($0.username): \($0.id)" })")
                    fetchedUsers = fetchedUsers.filter { $0.id.lowercased() != currentUserID.lowercased() }
                    print("🧪 Filtered out current user: \(originalCount) -> \(fetchedUsers.count) users")
                } else {
                    print("⚠️ No current user ID found in authManager")
                }
                
                users = fetchedUsers
                print("🧪 Final users list: \(users.map { $0.username })")
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

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self.resizable())
        let view = controller.view

        let targetSize = CGSize(width: 40, height: 40)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: view!.bounds, afterScreenUpdates: true)
        }
    }
}
