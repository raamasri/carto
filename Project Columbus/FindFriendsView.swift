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

/// A map‑pin style annotation that shows the friend’s profile image in a circular pod
/// with a small tail underneath so it looks like a real map pin.
struct FriendPinView: View {
    let imageName: String            // system symbol or asset name
    
    var body: some View {
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
        // Align annotation so that the tip of the tail is placed exactly
        // at the coordinate point.
        .offset(y: -20)
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
            Annotation(user.username, coordinate: CLLocationCoordinate2D(
                latitude: user.latitude ?? 0,
                longitude: user.longitude ?? 0
            )) {
                FriendPinView(imageName: "person.circle.fill")
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
                                Text("Alice: Hey, what’s up?")
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
                            Annotation(user.username, coordinate: coordinate) {
                                FriendPinView(imageName: "person.circle.fill")
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
                    } catch {
                        print("Error fetching users: \(error)")
                    }
                }
                
                .overlay(alignment: .top) {
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            Spacer().frame(height: 70)
                            if isEditing {
                                ZStack {
                                    ScrollView {
                                        VStack(spacing: 0) {
                                            ForEach(filteredUsers) { user in
                                                Button {
                                                    selectedUser = user
                                                    showProfile = true
                                                    isEditing = false
                                                } label: {
                                                    HStack {
                                                        Text(user.username)
                                                            .font(.headline)
                                                            .foregroundColor(.primary)
                                                        Spacer()
                                                    }
                                                    .padding()
                                                }
                                                Divider()
                                            }
                                        }
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                }
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                .padding(.horizontal)
                            }
                        }
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("@handle, names, or email",
                                      text: $searchText,
                                      onEditingChanged: { editing in isEditing = editing })
                                .autocorrectionDisabled()
                                .padding(8)
                            if !searchText.isEmpty || !filteredUsers.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    isEditing = false
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
                    }
                }
            } // end ZStack
            .sheet(isPresented: $showProfile) {
                if let user = selectedUser {
                    UserProfileView(profileUser: user)
                }
            }
        }
    }
}
