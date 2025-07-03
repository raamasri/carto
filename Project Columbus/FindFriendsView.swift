//
//  FindFriendsView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//

import SwiftUI
import MapKit

/// A small triangular tail for the pin.
struct PinTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))           // tip at bottom‑center
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))        // top‑right
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))        // top‑left
        path.closeSubpath()
        return path
    }
}

/// A map‑pin style annotation that shows the friend's profile image in a circular pod
/// with a small tail underneath so it looks like a real map pin.
struct FriendPinView: View {
    let imageName: String            // system symbol or asset name
    let username: String             // username to display
    
    var body: some View {
        VStack(spacing: 2) {
            // Pin with circular profile image and tail
            VStack(spacing: 0) {
                // Circular profile image
                Image(systemName: imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.white, Color.gray]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Pin tail
                PinTail()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white, Color.gray]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 14, height: 10)
                    .offset(y: -2)
            }
            
            // Username label positioned close to the pin
            Text(username)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Color(.systemBackground)
                        .opacity(0.9)
                        .cornerRadius(4)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
        }
        // Align annotation so that the tip of the tail is placed exactly
        // at the coordinate point.
        .offset(y: -25)  // Adjusted offset to account for the label
    }
}

struct FriendHistoryView: View {
    let user: AppUser
    @State private var cameraPosition: MapCameraPosition

    init(user: AppUser) {
        self.user = user
        let defaultCoordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        self._cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: user.latitude ?? defaultCoordinate.latitude,
                longitude: user.longitude ?? defaultCoordinate.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            Annotation("", coordinate: CLLocationCoordinate2D(
                latitude: user.latitude ?? 0,
                longitude: user.longitude ?? 0
            )) {
                FriendPinView(imageName: "person.circle.fill", username: user.username)
            }
        }
        .ignoresSafeArea()
        .navigationTitle(user.username)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.clear, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .overlay(
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Alice: Hey, what's up?")
                                    .padding(10)
                                    .background(Color.white.opacity(0.8))
                                    .foregroundColor(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Spacer()
                            }
                            HStack {
                                Spacer()
                                Text("You: On my way!")
                                    .padding(10)
                                    .background(Color.blue.opacity(0.9))
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 100)

                    HStack(spacing: 12) {
                        TextField("Type a message...", text: .constant(""))
                            .padding(10)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundColor(.white)

                        Button(action: {
                            // Send action
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                .zIndex(1)
                .padding(.bottom, 80)
                .padding(.bottom, 50) // Adjust height above tab bar
            }
        )
    }
}

struct FindFriendsView: View {
    @EnvironmentObject var locationManager: AppLocationManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var selectedUser: AppUser?
    @State private var showChat = false
    @State private var showProfile = false
    @State private var isEditing: Bool = false
    @State private var allUsers: [AppUser] = []
    @State private var searchText: String = ""
    @State private var recommendedUsers: [AppUser] = []
    @State private var nearbyUsers: [AppUser] = []
    @State private var mutualFriendUsers: [AppUser] = []
    @State private var isLoadingRecommendations = false
    @State private var showRecommendations = true

    var filteredUsers: [AppUser] {
        guard isEditing else { return [] }
        if searchText.isEmpty {
            return allUsers
        } else {
            return allUsers.filter { user in
                user.username.lowercased().contains(searchText.lowercased()) ||
                user.full_name.lowercased().contains(searchText.lowercased()) ||
                (user.email?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    ForEach(allUsers) { user in
                        if let coordinate = user.location {
                            Annotation("", coordinate: coordinate) {
                                FriendPinView(imageName: "person.circle.fill", username: user.username)
                            }
                        }
                    }
                }
                .ignoresSafeArea()
                .task {
                    if let userID = authManager.currentUserID,
                       let location = locationManager.currentLocation {
                        await SupabaseManager.shared.updateUserLocation(
                            userID: userID,
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude
                        )
                    }
                    do {
                        print("FindFriendsView: fetching users...")
                        let users = try await SupabaseManager.shared.fetchAllUsers()
                        allUsers = users
                        print("FindFriendsView: fetched allUsers (\(allUsers.count)):", allUsers)
                        
                        // Load recommendations
                        await loadRecommendations()
                    } catch {
                        print("Error fetching users: \(error)")
                    }
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        // Search bar - always visible
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("@handle, names, or email",
                                      text: $searchText,
                                      onEditingChanged: { editing in 
                                isEditing = editing
                                if editing {
                                    showRecommendations = false
                                }
                            })
                                .autocorrectionDisabled()
                                .padding(8)
                            if !searchText.isEmpty || !filteredUsers.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    isEditing = false
                                    showRecommendations = true
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(AppSpacing.vertical)
                        .background(.ultraThinMaterial)
                        .cornerRadius(AppSpacing.cornerRadius)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, AppSpacing.horizontal)
                        .padding(.top, AppSpacing.vertical)
                        
                        // Content area - flexible height
                        if isEditing && !filteredUsers.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(filteredUsers.prefix(6)) { user in // Limit to 6 results
                                    Button {
                                        selectedUser = user
                                        showProfile = true
                                        isEditing = false
                                        searchText = ""
                                    } label: {
                                        HStack {
                                            Text(user.username)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding()
                                    }
                                    if user.id != filteredUsers.prefix(6).last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        } else if showRecommendations && !isEditing && searchText.isEmpty {
                            // Flexible recommendations sheet
                            VStack(spacing: 0) {
                                // Handle bar for dismissing
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showRecommendations = false
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 12)
                                
                                ScrollView {
                                    VStack(spacing: 20) {
                                        if !nearbyUsers.isEmpty {
                                            RecommendationSection(
                                                title: "People Nearby",
                                                subtitle: "Based on your location",
                                                users: nearbyUsers,
                                                onUserTap: { user in
                                                    selectedUser = user
                                                    showProfile = true
                                                }
                                            )
                                        }
                                        
                                        if !mutualFriendUsers.isEmpty {
                                            RecommendationSection(
                                                title: "Mutual Friends",
                                                subtitle: "People you might know",
                                                users: mutualFriendUsers,
                                                onUserTap: { user in
                                                    selectedUser = user
                                                    showProfile = true
                                                }
                                            )
                                        }
                                        
                                        if !recommendedUsers.isEmpty {
                                            RecommendationSection(
                                                title: "Suggested for You",
                                                subtitle: "Based on your activity",
                                                users: recommendedUsers,
                                                onUserTap: { user in
                                                    selectedUser = user
                                                    showProfile = true
                                                }
                                            )
                                        }
                                        
                                        if isLoadingRecommendations {
                                            VStack(spacing: 12) {
                                                ProgressView()
                                                Text("Finding people you might know...")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding()
                                        }
                                        
                                        // Bottom padding to ensure content doesn't get cut off
                                        Color.clear.frame(height: 20)
                                    }
                                    .padding(.top, 12)
                                }
                                .frame(maxHeight: 400) // Limit max height but allow flexibility
                            }
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        Spacer()
                    }
                }
                
                // Floating action button to show recommendations when hidden
                if !showRecommendations && !isEditing && searchText.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showRecommendations = true
                                }
                            }) {
                                Image(systemName: "person.2.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            .frame(width: 50, height: 50)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                            .padding(.leading, 20)
                            .padding(.bottom, 100) // Account for tab bar
                            
                            Spacer()
                        }
                    }
                }
            } // end ZStack
            .sheet(isPresented: $showProfile) {
                if let user = selectedUser {
                    UserProfileView(profileUser: user)
                        .environmentObject(authManager)
                        .environmentObject(pinStore)
                }
            }
        }
    }
    
    private func loadRecommendations() async {
        guard let currentUserID = authManager.currentUserID,
              let currentLocation = locationManager.currentLocation else { return }
        
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        
        // Filter out blocked users but include current user for nearby section
        let availableUsers = allUsers.filter { user in
            user.id != currentUserID && !user.isCurrentUser
        }
        
        // 1. Nearby Users (within 50km) - include current user first
        var nearbyList: [AppUser] = []
        
        // Add current user if they have location
        if let currentUser = allUsers.first(where: { $0.isCurrentUser }) {
            nearbyList.append(currentUser)
        }
        
        // Add other nearby users
        let nearbyOthers = availableUsers.filter { user in
            guard let userLat = user.latitude, let userLng = user.longitude else { return false }
            let userLocation = CLLocation(latitude: userLat, longitude: userLng)
            let distance = currentLocation.distance(from: userLocation)
            return distance <= 50000 // 50km in meters
        }.sorted { user1, user2 in
            guard let lat1 = user1.latitude, let lng1 = user1.longitude,
                  let lat2 = user2.latitude, let lng2 = user2.longitude else { return false }
            let loc1 = CLLocation(latitude: lat1, longitude: lng1)
            let loc2 = CLLocation(latitude: lat2, longitude: lng2)
            return currentLocation.distance(from: loc1) < currentLocation.distance(from: loc2)
        }.prefix(4) // Limit to 4 since we already have current user
        
        nearbyList.append(contentsOf: nearbyOthers)
        
        // 2. Mutual Friends (users who follow people you follow)
        let followingUsers = await SupabaseManager.shared.getFollowingUsers(for: currentUserID)
        let followingIds = Set(followingUsers.map { $0.id })
        
        var mutualFriendCounts: [String: Int] = [:]
        for followingUser in followingUsers {
            let theirFollowing = await SupabaseManager.shared.getFollowingUsers(for: followingUser.id)
            for mutual in theirFollowing {
                if !followingIds.contains(mutual.id) && mutual.id != currentUserID {
                    mutualFriendCounts[mutual.id, default: 0] += 1
                }
            }
        }
        
        let mutual = availableUsers.filter { user in
            mutualFriendCounts[user.id] != nil
        }.sorted { user1, user2 in
            mutualFriendCounts[user1.id, default: 0] > mutualFriendCounts[user2.id, default: 0]
        }.prefix(5)
        
        // 3. Activity-based recommendations (users with similar pin activity)
        let recommended = availableUsers.filter { user in
            !nearbyList.contains(where: { $0.id == user.id }) &&
            !mutual.contains(where: { $0.id == user.id })
        }.shuffled().prefix(5)
        
        await MainActor.run {
            nearbyUsers = nearbyList
            mutualFriendUsers = Array(mutual)
            recommendedUsers = Array(recommended)
        }
    }
}

struct RecommendationSection: View {
    let title: String
    let subtitle: String
    let users: [AppUser]
    let onUserTap: (AppUser) -> Void
    @State private var userLocationNames: [String: String] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(users) { user in
                        Button(action: {
                            // Don't open profile for current user
                            if !user.isCurrentUser {
                                onUserTap(user)
                            }
                        }) {
                            VStack(spacing: 8) {
                                if let avatarURL = user.avatarURL, !avatarURL.isEmpty,
                                   let url = URL(string: avatarURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                    }
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                }
                                
                                VStack(spacing: 2) {
                                    Text(user.isCurrentUser ? "Your location" : user.username)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                    
                                    if user.isCurrentUser {
                                        // Show approximate location for current user
                                        Text(userLocationNames[user.id] ?? "Loading...")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    } else if !user.full_name.isEmpty {
                                        Text(user.full_name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .frame(width: 80)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .onAppear {
            // Reverse geocode location for current user
            for user in users where user.isCurrentUser {
                reverseGeocodeUserLocation(user)
            }
        }
    }
    
    private func reverseGeocodeUserLocation(_ user: AppUser) {
        guard let latitude = user.latitude, let longitude = user.longitude else { return }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    // Create a readable location string like "San Jose, CA"
                    var locationString = ""
                    
                    if let locality = placemark.locality {
                        locationString = locality
                    }
                    
                    if let administrativeArea = placemark.administrativeArea {
                        if !locationString.isEmpty {
                            locationString += ", \(administrativeArea)"
                        } else {
                            locationString = administrativeArea
                        }
                    }
                    
                    if locationString.isEmpty {
                        locationString = placemark.name ?? "Unknown location"
                    }
                    
                    userLocationNames[user.id] = locationString
                }
            } else {
                DispatchQueue.main.async {
                    userLocationNames[user.id] = "Location unavailable"
                }
            }
        }
    }
}
