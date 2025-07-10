//
//  FriendActivityFeedView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import SwiftUI
import MapKit

struct FriendActivityFeedView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var pinStore: PinStore
    @StateObject private var notificationManager = NotificationManager.shared
    
    @State private var activities: [FriendActivity] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var selectedActivity: FriendActivity?
    @State private var showActivityDetail = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var lastRefresh = Date()
    
    // Filter states
    @State private var selectedFilter: ActivityFilter = .all
    @State private var showFilterMenu = false
    
    enum ActivityFilter: String, CaseIterable {
        case all = "All"
        case visited = "Visited Places"
        case rated = "Ratings"
        case lists = "Lists"
        case social = "Social"
        
        var icon: String {
            switch self {
            case .all: return "rectangle.grid.2x2"
            case .visited: return "location.fill"
            case .rated: return "star.fill"
            case .lists: return "list.bullet"
            case .social: return "person.2.fill"
            }
        }
        
        var activityTypes: [FriendActivityType] {
            switch self {
            case .all: return FriendActivityType.allCases
            case .visited: return [.visitedPlace]
            case .rated: return [.ratedPlace]
            case .lists: return [.addedToList, .createdList]
            case .social: return [.followedUser, .commentedOnPin, .reactedToPin]
            }
        }
    }
    
    var filteredActivities: [FriendActivity] {
        let typeFiltered = activities.filter { activity in
            selectedFilter.activityTypes.contains(activity.activityType)
        }
        
        return typeFiltered.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Header
                filterHeader
                
                // Activity Feed
                if isLoading && activities.isEmpty {
                    loadingView
                } else if activities.isEmpty {
                    emptyStateView
                } else {
                    activityListView
                }
            }
            .navigationTitle("Friend Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshFeed) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRefreshing)
                    }
                }
            }
            .refreshable {
                await refreshFeedAsync()
            }
            .sheet(isPresented: $showActivityDetail) {
                if let activity = selectedActivity {
                    ActivityDetailView(activity: activity)
                        .environmentObject(authManager)
                        .environmentObject(supabaseManager)
                        .environmentObject(pinStore)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                loadActivityFeed()
                setupRealTimeUpdates()
            }
            .onReceive(NotificationCenter.default.publisher(for: .friendActivityUpdated)) { _ in
                Task {
                    await refreshFeedAsync()
                }
            }
        }
    }
    
    // MARK: - Filter Header
    private var filterHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ActivityFilter.allCases, id: \.self) { filter in
                    ActivityFilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Activity List
    private var activityListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredActivities) { activity in
                    ActivityCard(activity: activity) {
                        selectedActivity = activity
                        showActivityDetail = true
                    }
                    .padding(.horizontal)
                }
                
                if filteredActivities.count >= 20 {
                    loadMoreButton
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.2)
            
                        Text("Loading friend activities...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                .foregroundColor(.secondary)
                        
            VStack(spacing: 8) {
                        Text("No Friend Activity Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                Text("Follow friends to see their latest activities and discoveries")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
            }
            
            Button("Find Friends") {
                // Navigate to find friends view
            }
            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Load More Button
    private var loadMoreButton: some View {
        Button("Load More") {
            loadMoreActivities()
        }
        .font(.subheadline)
        .foregroundColor(.blue)
        .padding()
    }
    
    // MARK: - Methods
    private func loadActivityFeed() {
        guard let currentUserID = authManager.currentUserID else { return }
        
        isLoading = true
        
        Task {
            do {
                let fetchedActivities = try await supabaseManager.getFriendActivityFeed(
                    for: currentUserID,
                    limit: 50,
                    offset: 0
                )
                
                await MainActor.run {
                    self.activities = fetchedActivities
                    self.isLoading = false
                    self.lastRefresh = Date()
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func refreshFeed() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        Task {
            await refreshFeedAsync()
        }
    }
    
    @MainActor
    private func refreshFeedAsync() async {
        guard let currentUserID = authManager.currentUserID else { return }
        
        isRefreshing = true
        
        do {
            let fetchedActivities = try await supabaseManager.getFriendActivityFeed(
                for: currentUserID,
                limit: 50,
                offset: 0
            )
            
            self.activities = fetchedActivities
            self.lastRefresh = Date()
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
        
        isRefreshing = false
    }
    
    private func loadMoreActivities() {
        guard let currentUserID = authManager.currentUserID, !isLoading else { return }
        
        isLoading = true
        
        Task {
            do {
                let moreActivities = try await supabaseManager.getFriendActivityFeed(
                    for: currentUserID,
                    limit: 20,
                    offset: activities.count
                )
                
                await MainActor.run {
                    self.activities.append(contentsOf: moreActivities)
                    self.isLoading = false
                }
                
            } catch {
        await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func setupRealTimeUpdates() {
        // Set up timer for periodic refresh
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            if Date().timeIntervalSince(lastRefresh) > 30 {
                Task {
                    await refreshFeedAsync()
                }
            }
        }
    }
}

// MARK: - Filter Chip
struct ActivityFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Activity Card
struct ActivityCard: View {
    let activity: FriendActivity
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
        VStack(alignment: .leading, spacing: 12) {
                // Header with user info
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: activity.userAvatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                        Circle()
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                            )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                        Text(activity.username)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(activity.activityType.actionText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: activity.activityType.systemImage)
                            .font(.caption)
                            .foregroundColor(activity.activityType.color)
                    
                    Text(timeAgoString(from: activity.createdAt))
                            .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
                
                // Activity description
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // Location info if available
                if let locationName = activity.locationName {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(locationName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Related pin preview if available
                if let relatedPin = activity.relatedPin {
                    PinPreviewCard(pin: relatedPin)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
    
    var body: some View {
            HStack(spacing: 12) {
                // Pin image or placeholder
            AsyncImage(url: URL(string: pin.mediaURLs?.first ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pin.locationName)
                    .font(.caption)
                    .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if let rating = pin.starRating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                .font(.system(size: 8))
                                    .foregroundColor(.yellow)
                        }
                    }
                }
                
                if let reviewText = pin.reviewText, !reviewText.isEmpty {
                    Text(reviewText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    }
                }
                
                Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Activity Detail View
struct ActivityDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var pinStore: PinStore
    
    let activity: FriendActivity
    @State private var showPinDetail = false
    @State private var showUserProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // User header
                    userHeader
                    
                    // Activity details
                    activityDetails
                    
                    // Related content
                    if let relatedPin = activity.relatedPin {
                        relatedPinSection(pin: relatedPin)
                    }
                    
                    // Location map if available
                    if activity.locationName != nil {
                        locationSection
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var userHeader: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: activity.userAvatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                    )
            }
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.username)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(activity.activityType.actionText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(activity.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("View Profile") {
                showUserProfile = true
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var activityDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity")
                .font(.headline)
            
            Text(activity.description)
                .font(.body)
                .foregroundColor(.primary)
        }
    }
    
    private func relatedPinSection(pin: Pin) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Place")
                .font(.headline)
            
            Button(action: { showPinDetail = true }) {
                PinDetailCard(pin: pin)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
            
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                
                Text(activity.locationName ?? "Unknown Location")
                    .font(.subheadline)
            }
            
            // Simple map view placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("Map View")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
    }
}

// MARK: - Pin Detail Card
struct PinDetailCard: View {
    let pin: Pin
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pin image
            AsyncImage(url: URL(string: pin.mediaURLs?.first ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    )
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(pin.locationName)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                if let rating = pin.starRating, rating > 0 {
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
                        Text("\(rating, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let reviewText = pin.reviewText, !reviewText.isEmpty {
                    Text(reviewText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                    
                    Text(pin.city)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let friendActivityUpdated = Notification.Name("friendActivityUpdated")
}

// MARK: - Preview
struct FriendActivityFeedView_Previews: PreviewProvider {
    static var previews: some View {
    FriendActivityFeedView()
        .environmentObject(AuthManager())
            .environmentObject(SupabaseManager.shared)
        .environmentObject(PinStore())
    }
} 