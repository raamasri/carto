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
                Image(systemName: friend.imageName)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.gray)
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
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

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
                Map(coordinateRegion: $region, annotationItems: friends) { friend in
                    MapAnnotation(coordinate: friend.location) {
                        VStack {
                            Image(systemName: friend.imageName)
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.gray)
                            Text(friend.name)
                                .font(.caption)
                        }
                    }
                }
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
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
                            }
                        }
                        .padding()
                    }
                    .frame(maxHeight: UIScreen.main.bounds.height / 3)
                }
            }
        }
    }
}
