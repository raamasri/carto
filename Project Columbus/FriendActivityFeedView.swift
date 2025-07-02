//
//  FriendActivityFeedView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import SwiftUI
import Foundation

struct FriendActivityFeedView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    @State private var activities: [FriendActivity] = []
    @State private var isLoading = false
    @State private var selectedPin: Pin? = nil
    @State private var showPinDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    AppleProgressView(
                        "Loading friend activities...",
                        subtitle: "Fetching latest updates",
                        tint: .blue
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if activities.isEmpty {
                    AppleEmptyState(
                        icon: "person.2.fill",
                        title: "No Friend Activity Yet",
                        subtitle: "Follow friends to see their latest discoveries and reviews here!",
                        actionTitle: "Find Friends"
                    ) {
                        // Navigate to FindFriendsView
                        // This would need proper navigation handling
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(activities) { activity in
                        ActivityRowView(activity: activity) { pin in
                            selectedPin = pin
                            showPinDetail = true
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadActivities()
                    }
                }
            }
            .navigationTitle("Friend Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await loadActivities()
                        }
                    }
                }
            }
            .sheet(isPresented: $showPinDetail) {
                if let pin = selectedPin {
                    LocationDetailView(
                        mapItem: pin.toMapItem(),
                        onAddPin: { _ in }
                    )
                    .environmentObject(pinStore)
                    .environmentObject(authManager)
                }
            }
        }
        .task {
            await loadActivities()
        }
    }
    
    private func loadActivities() async {
        guard let userId = authManager.currentUserID else { return }
        
        isLoading = true
        let fetchedActivities = await SupabaseManager.shared.getFriendActivityFeed(for: userId, limit: 50)
        
        await MainActor.run {
            activities = fetchedActivities
            isLoading = false
        }
    }
}

// MARK: - Activity Row View

struct ActivityRowView: View {
    let activity: FriendActivity
    let onPinTap: (Pin) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with user info and timestamp
            HStack(spacing: 12) {
                // User avatar
                AsyncImage(url: URL(string: activity.userAvatarURL ?? "")) { image in
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
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("@\(activity.username)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Image(systemName: activity.activityType.systemImage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(timeAgoString(from: activity.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Activity content
            VStack(alignment: .leading, spacing: 8) {
                Text(activityDescription)
                    .font(.body)
                
                // Show related pin if available
                if let pin = activity.relatedPin {
                    PinPreviewCard(pin: pin) {
                        onPinTap(pin)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
        .shadow(
            color: .black.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )
    }
    
    private var activityDescription: String {
        switch activity.activityType {
        case .visitedPlace:
            return "\(activity.activityType.actionText) \(activity.locationName ?? "a place")"
        case .ratedPlace:
            return "\(activity.activityType.actionText) \(activity.locationName ?? "a place")"
        case .addedToList, .commentedOnPin, .reactedToPin:
            return activity.description
        case .createdList:
            return "created a new list"
        case .followedUser:
            return "followed a new user"
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Pin Preview Card

struct PinPreviewCard: View {
    let pin: Pin
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Pin image or placeholder
                if let mediaURLs = pin.mediaURLs, let firstImageURL = mediaURLs.first, let url = URL(string: firstImageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                } else {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pin.locationName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(pin.city)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    if let rating = pin.starRating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FriendActivityFeedView()
        .environmentObject(AuthManager())
        .environmentObject(PinStore())
} 