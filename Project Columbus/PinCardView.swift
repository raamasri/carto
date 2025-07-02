//
//  PinCardView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 5/20/25.
//


import SwiftUI
import MapKit
import Foundation
import AVKit
// Pin is defined in Models.swift in the same module

struct PinCardView: View {
    let pin: Pin
    @State private var showFullMap = false
    @State private var showAddToList = false
    @State private var showAddedAlert = false
    @State private var showFriendReviewList = false
    @State private var friends: [AppUser] = []
    @State private var isLoadingFriends = false
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager

    // Helper: Relative date string
    private var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: pin.createdAt, relativeTo: Date())
    }

    // Helper: Styled review text with mentions
    private func styledReview(_ text: String) -> Text {
        let words = text.split(separator: " ")
        var result = Text("")
        for (i, word) in words.enumerated() {
            if i > 0 { result = result + Text(" ") }
            if word.hasPrefix("@") || word.hasPrefix("#") {
                result = result + Text(String(word)).foregroundColor(.blue).bold()
            } else {
                result = result + Text(String(word))
            }
        }
        return result
    }

    // Helper: Avatars for friends who reviewed this place
    private func friendsWhoReviewed() -> [(AppUser, Pin)] {
        let allPins = pinStore.masterPins
        let placePins = allPins.filter { abs($0.latitude - pin.latitude) < 0.0001 && abs($0.longitude - pin.longitude) < 0.0001 }
        return placePins.compactMap { p in
            if let user = friends.first(where: { $0.username == p.authorHandle.replacingOccurrences(of: "@", with: "") }) {
                return (user, p)
            }
            return nil
        }.sorted { $0.1.createdAt > $1.1.createdAt }
    }

    // Friend Avatar View Component
    private struct FriendAvatarView: View {
        let user: AppUser
        
        var body: some View {
            if let avatar = user.avatarURL, !avatar.isEmpty, let url = URL(string: avatar) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                    }
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
        }
    }

    // Friend Avatars Row Content
    private struct FriendAvatarsRowContent: View {
        let friendPins: [(AppUser, Pin)]
        let count: Int
        let onTap: () -> Void
        
        var body: some View {
            HStack(spacing: -10) {
                ForEach(Array(friendPins.prefix(3).enumerated()), id: \.element.0.id) { _, element in
                    let (user, _) = element
                    FriendAvatarView(user: user)
                }
                if count > 3 {
                    Text("+\(count - 3)")
                        .font(.caption)
                        .padding(.leading, 4)
                }
            }
            .padding(.vertical, 2)
            .onTapGesture(perform: onTap)
        }
    }

    private var friendsAvatarsRow: some View {
        let friendPins = friendsWhoReviewed()
        let count = friendPins.count
        
        return Group {
            if isLoadingFriends {
                ProgressView().frame(width: 24, height: 24)
            } else {
                FriendAvatarsRowContent(
                    friendPins: friendPins,
                    count: count,
                    onTap: { showFriendReviewList = true }
                )
            }
        }
    }

    // Helper: Trip tag
    private var tripTag: some View {
        Group {
            if let trip = pin.tripName, !trip.isEmpty {
                Text(trip)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
    }

    var hasReviewOrMedia: Bool {
        (pin.reviewText?.isEmpty == false) || !(pin.mediaURLs?.isEmpty ?? true)
    }

    private var miniMap: some View {
        Map(
            coordinateRegion: .constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )),
            annotationItems: [pin]
        ) { pin in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                Image(systemName: "mappin.circle.fill")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.red)
                    .shadow(radius: 2)
            }
        }
        .frame(width: 60, height: 60)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 2))
        .onTapGesture { showFullMap = true }
        .sheet(isPresented: $showFullMap) {
            VStack {
                Map(
                    coordinateRegion: .constant(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )),
                    annotationItems: [pin]
                ) { pin in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                        Image(systemName: "mappin.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.red)
                            .shadow(radius: 3)
                    }
                }
                .edgesIgnoringSafeArea(.all)
                Button("Close") { showFullMap = false }
                    .padding()
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                // Header: Place, city, star, mini map
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(pin.locationName)
                                .font(.headline)
                            if let rating = pin.starRating {
                                Text("\(String(format: "%.1f", rating)) ★")
                                    .font(.subheadline).bold()
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text(pin.city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    miniMap
                }
                // Avatars row (if any)
                friendsAvatarsRow
                // Minimal card (just a pin, no review/media)
                if !hasReviewOrMedia {
                    Text(relativeDateString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                // Full card (review/media)
                if hasReviewOrMedia {
                    if let review = pin.reviewText, !review.isEmpty {
                        styledReview(review)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                    if let media = pin.mediaURLs, !media.isEmpty {
                        TabView {
                            ForEach(media, id: \.self) { urlString in
                                if urlString.hasSuffix(".mp4"), let url = URL(string: urlString) {
                                    VideoPlayer(player: AVPlayer(url: url))
                                        .aspectRatio(16/9, contentMode: .fit)
                                        .clipped()
                                } else if let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .clipped()
                                        } else {
                                            Color.gray
                                        }
                                    }
                                } else {
                                    Color.gray
                                }
                            }
                        }
                        .frame(height: 220)
                        .tabViewStyle(.page)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    HStack(spacing: 8) {
                        tripTag
                        Text(relativeDateString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                // Action icons and author
                HStack {
                    Text(pin.authorHandle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 18) {
                        Image(systemName: "heart")
                        Image(systemName: "message")
                        Image(systemName: "square.and.arrow.up")
                        Image(systemName: "bookmark")
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(hasReviewOrMedia ? 0.12 : 0.05), radius: hasReviewOrMedia ? 5 : 2, x: 0, y: 2)

            // Add to List button
            Button(action: {
                print("Add to List tapped for \(pin.locationName)")
                showAddToList = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .padding(10)
            .shadow(radius: 2)
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showAddToList) {
            AddToListSheet(pin: pin) { list in
                pinStore.addPin(pin, to: list)
                showAddedAlert = true
            }
        }
        .alert("Added to List!", isPresented: $showAddedAlert) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            if friends.isEmpty, let userID = authManager.currentUserID {
                isLoadingFriends = true
                Task {
                    let fetched = await SupabaseManager.shared.getFollowingUsers(for: userID)
                    await MainActor.run {
                        friends = fetched
                        isLoadingFriends = false
                    }
                }
            }
        }
        .sheet(isPresented: $showFriendReviewList) {
            FriendReviewListView(
                placeName: pin.locationName,
                latitude: pin.latitude,
                longitude: pin.longitude,
                allPins: pinStore.masterPins,
                friends: friends
            )
        }
    }
}

struct AddToListSheet: View {
    let pin: Pin
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var pinStore: PinStore

    // Helper to check if a list contains this pin (by coordinates or name)
    private func listContainsPin(_ list: PinList) -> Bool {
        list.pins.contains { existingPin in
            let latitudeDiff = abs(existingPin.latitude - pin.latitude)
            let longitudeDiff = abs(existingPin.longitude - pin.longitude)
            let isLocationMatch = latitudeDiff < 0.0001 && longitudeDiff < 0.0001
            let isNameMatch = existingPin.locationName.lowercased() == pin.locationName.lowercased()
            return isLocationMatch || isNameMatch
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Add to List")
                .font(.title2)
                .bold()
                .padding(.top)
            
            // Use actual lists from PinStore
            ForEach(pinStore.lists, id: \.id) { list in
                Button(action: {
                    onSelect(list.name)
                    dismiss()
                }) {
                    HStack {
                        Text(list.name)
                            .font(.headline)
                        Spacer()
                        if listContainsPin(list) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Button("Cancel", role: .cancel) { dismiss() }
                .padding(.top, 8)
        }
        .padding()
        .onAppear {
            // Ensure lists are loaded when sheet appears
            if pinStore.lists.isEmpty {
                Task {
                    await pinStore.refresh()
                }
            }
        }
    }
}
