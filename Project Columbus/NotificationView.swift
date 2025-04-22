//
//  NotificationView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/21/25.
//

import SwiftUI
import Helpers
import PostgREST

struct NotificationPayload: Decodable {
    let id: String
    let from_user_id: String
    let users: UserPayload
}

struct UserPayload: Decodable {
    let username: String
    let full_name: String
    let avatar_url: String
}

struct NotificationItem: Identifiable {
    let id: UUID
    let fromUserID: String
    let fromUsername: String
    let fromFullName: String
    let avatarURL: String
}

struct NotificationView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var authManager: AuthManager

    @State private var followRequests: [NotificationItem] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView()
                } else if followRequests.isEmpty {
                    Text("No follow requests.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(followRequests) { request in
                        HStack {
                            AsyncImage(url: URL(string: request.avatarURL)) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text(request.fromFullName)
                                    .fontWeight(.bold)
                                Text("@\(request.fromUsername)")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }

                            Spacer()

                            Button("Accept") {
                                acceptFollowRequest(request)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Notifications")
            .onAppear {
                Task {
                    await fetchFollowRequests()
                }
            }
        }
    }

    func fetchFollowRequests() async {
        guard let currentUserID = authManager.currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let rawData = try await supabaseManager.client
                .from("notifications")
                .select("id, from_user_id, users!from_user_id(username, full_name, avatar_url)")
                .eq("user_id", value: currentUserID)
                .eq("type", value: "follow_request")
                .eq("is_read", value: false)
                .order("created_at", ascending: false)
                .execute()
                .value as [NotificationPayload]

            let requests: [NotificationItem] = rawData.compactMap { row in
                guard let id = UUID(uuidString: row.id) else { return nil }
                return NotificationItem(
                    id: id,
                    fromUserID: row.from_user_id,
                    fromUsername: row.users.username,
                    fromFullName: row.users.full_name,
                    avatarURL: row.users.avatar_url
                )
            }

            followRequests = requests
        } catch {
            print("❌ Failed to fetch notifications:", error)
        }
    }

    func acceptFollowRequest(_ request: NotificationItem) {
        Task {
            do {
                // Create new follow relationship
                _ = try await supabaseManager.client
                    .from("follows")
                    .insert([
                        "follower_id": request.fromUserID,
                        "following_id": authManager.currentUserID ?? ""
                    ])
                    .execute()

                // Mark notification as read
                _ = try await supabaseManager.client
                    .from("notifications")
                    .update(["is_read": true])
                    .eq("id", value: request.id.uuidString)
                    .execute()

                // Remove from local list
                followRequests.removeAll { $0.id == request.id }
            } catch {
                print("❌ Failed to accept follow request:", error)
            }
        }
    }
}
