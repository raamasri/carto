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
    @State private var showConfirmation = false
    @State private var confirmationMessage = ""

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
                                print("✅ Accept button pressed for @\(request.fromUsername)")
                                acceptFollowRequest(request)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .refreshable {
                await fetchFollowRequests()
            }
            .navigationTitle("Notifications")
            .onAppear {
                Task {
                    await fetchFollowRequests()
                }
            }
        }
        .alert(isPresented: $showConfirmation) {
            Alert(title: Text("Follow Request"), message: Text(confirmationMessage), dismissButton: .default(Text("OK")))
        }
    }

    func fetchFollowRequests() async {
        guard let currentUserID = authManager.currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let rawData = try await supabaseManager.client
                .from("notifications")
                .select("id, from_user_id, users!notifications_from_user_id_fkey(username, full_name, avatar_url)")
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

            // Remove duplicates by keeping only the most recent notification per sender
            var seen = Set<String>()
            let deduplicated = requests.filter { request in
                if seen.contains(request.fromUserID) {
                    return false
                } else {
                    seen.insert(request.fromUserID)
                    return true
                }
            }

            followRequests = deduplicated
        } catch {
            print("❌ Failed to fetch notifications:", error)
        }
    }

    func acceptFollowRequest(_ request: NotificationItem) {
        Task {
            print("────────── Accept Flow Start ──────────")
            print("🚀 acceptFollowRequest called for notification ID:", request.id.uuidString)

            do {
                // 1) Perform follow + notification in a single RPC
                let didFollow = await supabaseManager.followUser(followingID: UUID(uuidString: request.fromUserID)!)
                print("🧪 rpc_follow_and_notify returned:", didFollow)

                // 2) If follow succeeded, mark this notification as read
                if didFollow {
                    let markReadResponse = try await supabaseManager.client
                        .from("notifications")
                        .update(["is_read": true])
                        .eq("id", value: request.id.uuidString)
                        .eq("user_id", value: authManager.currentUserID ?? "")
                        .execute()
                    print("📤 Notification update status code:", markReadResponse.response.statusCode)
                    if let json = String(data: markReadResponse.data, encoding: .utf8) {
                        print("📤 Notification update response JSON:", json)
                    }
                } else {
                    print("❌ rpc_follow_and_notify failed, skipping notification update")
                }
            } catch {
                print("❌ Accept flow failed:", error)
            }

            print("────────── Accept Flow End ──────────")

            // Refresh the list so the marked notification is excluded
            await fetchFollowRequests()

            await MainActor.run {
                confirmationMessage = "Accepted follow request from @\(request.fromUsername)"
                showConfirmation = true
            }
        }
    }
}
