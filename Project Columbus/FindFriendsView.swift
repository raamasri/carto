//
//  FindFriendsView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//

import SwiftUI
import MapKit

struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let location: CLLocationCoordinate2D
    let imageName: String
    let history: [CLLocationCoordinate2D]
}

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
    let friend: Friend
    @State private var cameraPosition: MapCameraPosition

    init(friend: Friend) {
        self.friend = friend
        self._cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: friend.location,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )))
    }

    var body: some View {
        Map(position: $cameraPosition) {
            MapPolyline(coordinates: friend.history)
                .stroke(Color.white, lineWidth: 4)

            Annotation(friend.name, coordinate: friend.location) {
                FriendPinView(imageName: friend.imageName)
            }
        }
        .ignoresSafeArea()
        .navigationTitle(friend.name)
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
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var selectedFriend: Friend?
    @State private var showChat = false
    @State private var showProfile = false

    let friends = [
        Friend(name: "Alice",
               location: CLLocationCoordinate2D(latitude: 37.775, longitude: -122.418),
               imageName: "person.circle.fill",
               history: [
                   CLLocationCoordinate2D(latitude: 37.770, longitude: -122.422),
                   CLLocationCoordinate2D(latitude: 37.772, longitude: -122.419),
                   CLLocationCoordinate2D(latitude: 37.775, longitude: -122.418)
               ]),
        Friend(name: "Bob",
               location: CLLocationCoordinate2D(latitude: 37.776, longitude: -122.420),
               imageName: "person.circle.fill",
               history: [
                   CLLocationCoordinate2D(latitude: 37.772, longitude: -122.423),
                   CLLocationCoordinate2D(latitude: 37.774, longitude: -122.421),
                   CLLocationCoordinate2D(latitude: 37.776, longitude: -122.420)
               ]),
        Friend(name: "Charlie",
               location: CLLocationCoordinate2D(latitude: 37.774, longitude: -122.417),
               imageName: "person.circle.fill",
               history: [
                   CLLocationCoordinate2D(latitude: 37.770, longitude: -122.415),
                   CLLocationCoordinate2D(latitude: 37.772, longitude: -122.416),
                   CLLocationCoordinate2D(latitude: 37.774, longitude: -122.417)
               ])
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    ForEach(friends) { friend in
                        Annotation(friend.name, coordinate: friend.location) {
                            FriendPinView(imageName: friend.imageName)
                        }
                    }
                }
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    List {
                        ForEach(friends) { friend in
                            NavigationLink(destination: FriendHistoryView(friend: friend)) {
                                HStack {
                                    Image(systemName: friend.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .background(Circle().fill(Color.gray.opacity(0.2)))
                                        .padding(.trailing, 8)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(friend.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("San Francisco • Now")
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
                                    selectedFriend = friend
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
                if let friend = selectedFriend {
                    ProfileView(friend: friend)
                }
            }
        }
    }
}
