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
    @State private var allUsers: [AppUser] = []
    @State private var searchText: String = ""

    var filteredUsers: [AppUser] {
        if searchText.isEmpty {
            return allUsers
        } else {
            return allUsers.filter { user in
                user.username.lowercased().contains(searchText.lowercased()) ||
                user.full_name.lowercased().contains(searchText.lowercased()) ||
                user.email.lowercased().contains(searchText.lowercased())
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
                        print("Fetching users...")
                        let users = try await SupabaseManager.shared.fetchAllUsers()
                        print("Fetched \(users.count) users.")
                        allUsers = users
                    } catch {
                        print("Error fetching users: \(error)")
                    }
                }
                
                .safeAreaInset(edge: .top) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("@handle, names, or email", text: $searchText)
                            .autocorrectionDisabled()
                            .padding(8)

                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                }

                VStack {
                    Spacer()
                    List {
                        ForEach(filteredUsers) { user in
                            NavigationLink(destination: UserProfileView(profileUser: user)) {
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .background(Circle().fill(Color.gray.opacity(0.2)))
                                        .padding(.trailing, 8)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.username)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("Last seen: now")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    selectedUser = user
                                    showProfile = true
                                } label: {
                                    Label("Profile", systemImage: "person.crop.circle")
                                }
                                .tint(.blue)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: UIScreen.main.bounds.height / 3)
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
