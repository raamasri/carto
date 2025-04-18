//
//  ProfileView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/17/25.
//

import SwiftUI
import MapKit

struct ProfileView: View {
    let friend: Friend

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: friend.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .padding(.top)

            Text(friend.name)
                .font(.largeTitle)
                .bold()

            Text("Location: San Francisco")
                .foregroundColor(.gray)

            Spacer()
        }
        .padding()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlaceholderProfileView: View {
    var body: some View {
        VStack(spacing: 16) {
            // Avatar placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 100, height: 100)
                .padding(.top)

            // Name placeholder
            Text("Full Name")
                .font(.largeTitle)
                .bold()

            // Username placeholder
            Text("@username")
                .foregroundColor(.gray)

            // Bio placeholder
            Text("Bio goes here...")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()

            // Stats and follow button
            HStack(spacing: 20) {
                VStack {
                    Text("0")
                        .font(.headline)
                    Text("Followers")
                        .font(.subheadline)
                }
                VStack {
                    Text("0")
                        .font(.headline)
                    Text("Following")
                        .font(.subheadline)
                }
                Button(action: {}) {
                    Text("Follow")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke())
                }
            }
            .padding(.vertical)

            Divider()

            // Tab icons placeholder
            HStack {
                Spacer()
                VStack {
                    Image(systemName: "square.grid.2x2")
                    Text("Posts")
                }
                Spacer()
                VStack {
                    Image(systemName: "person.2")
                    Text("Friends")
                }
                Spacer()
                VStack {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                Spacer()
            }
            .padding(.vertical)

            // Content grid placeholder
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(0..<4) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView(friend: Friend(
                name: "Alice",
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), imageName: "person.circle",
                history: []
            ))
        }
        .previewDisplayName("ProfileView")
    }
}

struct PlaceholderProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PlaceholderProfileView()
        }
        .previewDisplayName("PlaceholderProfileView")
    }
}
