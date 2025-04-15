//
//  UserProfileView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//

import SwiftUI

struct UserProfileView: View {
    let currentUserID = UUID()

    @State var profileUser = User(
        id: UUID(),
        username: "mojojojo",
        isPrivate: false,
        followers: Array(repeating: UUID(), count: 5),
        following: Array(repeating: UUID(), count: 10),
        followRequests: [],
        collections: [
            PinCollection(name: "San Francisco", pins: [
                Pin(locationName: "Zuni Café", city: "San Francisco", date: "Mar 26", latitude: 37.7730, longitude: -122.4210, reaction: .lovedIt),
                Pin(locationName: "Tartine Bakery", city: "San Francisco", date: "Mar 25", latitude: 37.7614, longitude: -122.4241, reaction: .lovedIt),
                Pin(locationName: "House of Prime Rib", city: "San Francisco", date: "Mar 24", latitude: 37.7930, longitude: -122.4228, reaction: .wantToGo),
                Pin(locationName: "La Taqueria", city: "San Francisco", date: "Mar 23", latitude: 37.7502, longitude: -122.4185, reaction: .wantToGo),
                Pin(locationName: "Swan Oyster Depot", city: "San Francisco", date: "Mar 22", latitude: 37.7913, longitude: -122.4212, reaction: .lovedIt)
            ]),
            PinCollection(name: "Bday", pins: []),
            PinCollection(name: "Car Tour", pins: []),
            PinCollection(name: "Europe 25", pins: []),
            PinCollection(name: "Psychos", pins: []),
            PinCollection(name: "Pizza", pins: [])
        ],
        favoriteSpots: [],
        activityFeed: []
    )

    @State private var bio = "✨ Travel lover. Coffee first. Exploring the world one pin at a time! 🌍"
    @State private var selectedSection = "Just Added"
    let sections = ["Just Added", "Loved", "Want to Go", "Recommendations"]

    @State var recentPins: [Pin] = [
        Pin(locationName: "Golden Gate Park", city: "San Francisco", date: "Mar 10", latitude: 37.7694, longitude: -122.4862, reaction: .lovedIt),
        Pin(locationName: "Central Park", city: "New York", date: "Feb 22", latitude: 40.7851, longitude: -73.9683, reaction: .wantToGo),
        Pin(locationName: "Eiffel Tower", city: "Paris", date: "Jan 18", latitude: 48.8584, longitude: 2.2945, reaction: .lovedIt)
    ]

    @State private var selectedFilter: Reaction? = nil

    struct StoryHighlight: Identifiable {
        let id = UUID()
        let imageName: String
        let title: String
    }

    let storyHighlights: [StoryHighlight] = [
        StoryHighlight(imageName: "story1", title: "Travel"),
        StoryHighlight(imageName: "story2", title: "Food"),
        StoryHighlight(imageName: "story3", title: "Friends"),
        StoryHighlight(imageName: "story4", title: "Nature")
    ]

    var filteredPins: [Pin] {
        if let filter = selectedFilter {
            return recentPins.filter { $0.reaction == filter }
        } else {
            return recentPins
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("@\(profileUser.username)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Profile Header
                    ZStack(alignment: .topTrailing) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 4)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("@\(profileUser.username)")
                                    .font(.headline)

                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)

                                Text("\(profileUser.followers.count) followers • \(profileUser.following.count) following")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            Button(action: {}) {
                                Text("Edit Profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            Button(action: {}) {
                                Text("Share profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(storyHighlights) { highlight in
                                    VStack {
                                        Image(highlight.imageName)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.pink, lineWidth: 2))
                                        Text(highlight.title)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                    }

                    Divider()

                    // Posts Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Posts")
                            .font(.headline)
                            .padding(.horizontal)
                        let columns = [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ]
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(recentPins) { pin in
                                Image("postPlaceholder")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 120)
                                    .clipped()
                            }
                        }
                        .padding(.horizontal, 4)
                    }

                    Divider()

                    // Collections Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Collections")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                            ForEach(profileUser.collections) { collection in
                                NavigationLink(destination: CollectionDetailView(collection: collection)) {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                            .overlay(Text("📍"))
                                        Text(collection.name)
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 60)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
    }
}
