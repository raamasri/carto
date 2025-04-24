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
                if listType == .followers {
                    users = try await SupabaseManager.shared.getFollowers(for: userID)
                } else {
                    users = try await SupabaseManager.shared.getFollowingUsers(for: userID)
                }
            } catch {
                print("❌ Failed to refresh users: \(error)")
            }
            isLoading = false
        }
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
