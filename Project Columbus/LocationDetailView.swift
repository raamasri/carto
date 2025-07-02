//
//  LocationDetailView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//

import MapKit
import SwiftUI

struct LocationDetailView: View {
    let mapItem: MKMapItem
    let onAddPin: (Pin) -> Void

    @State private var showListDialog = false
    private let defaultLists = ["Favorites", "Coffee Shops", "Restaurants", "Bars", "Shopping"]
    @State private var region: MKCoordinateRegion
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @State private var friends: [AppUser] = []
    @State private var isLoadingFriends = false

    init(mapItem: MKMapItem, onAddPin: @escaping (Pin) -> Void) {
        self.mapItem = mapItem
        self.onAddPin = onAddPin
        _region = State(initialValue: MKCoordinateRegion(
            center: mapItem.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        ScrollView {
            content
                .padding()
        }
        .navigationTitle("Details")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleSection
            friendsSection
            Map(initialPosition: .region(region)) {
                Marker(mapItem.name ?? "Place", coordinate: mapItem.placemark.coordinate)
            }
                .frame(height: 250)
                .cornerRadius(12)
            LookAroundPreview(coordinate: mapItem.placemark.coordinate)
                .frame(height: 250)
                .cornerRadius(12)
            infoSection
            addButton
        }
        .onAppear {
            loadFriendsData()
        }
    }

    private var titleSection: some View {
        Text(mapItem.name ?? "Unknown Place")
            .font(.largeTitle)
            .bold()
    }
    
    private var friendsSection: some View {
        Group {
            if isLoadingFriends {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading friends...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                let friendsAtLocation = getFriendsAtLocation()
                let averageRating = getAverageRating(from: friendsAtLocation)
                
                if !friendsAtLocation.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            // Friends avatars
                            HStack(spacing: -8) {
                                ForEach(Array(friendsAtLocation.prefix(3).enumerated()), id: \.offset) { index, friendPin in
                                    AsyncImage(url: URL(string: friendPin.friend.avatarURL ?? "")) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.caption)
                                            )
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                    .zIndex(Double(3 - index))
                                }
                                
                                if friendsAtLocation.count > 3 {
                                    Circle()
                                        .fill(Color.gray.opacity(0.7))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text("+\(friendsAtLocation.count - 3)")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        )
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                }
                            }
                            
                            // Friends text and rating
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friendsText(count: friendsAtLocation.count))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let rating = averageRating {
                                    HStack(spacing: 4) {
                                        HStack(spacing: 1) {
                                            ForEach(1...5, id: \.self) { star in
                                                Image(systemName: star <= Int(rating.rounded()) ? "star.fill" : "star")
                                                    .font(.caption2)
                                                    .foregroundColor(.yellow)
                                            }
                                        }
                                        Text(String(format: "%.1f avg", rating))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    private var infoSection: some View {
        Group {
            if let category = mapItem.pointOfInterestCategory {
                Label(category.displayName, systemImage: "tag")
            }

            if let phone = mapItem.phoneNumber {
                Label(phone, systemImage: "phone")
            }

            if let url = mapItem.url {
                Link("Website", destination: url)
            }

            if let address = mapItem.placemark.title {
                Label(address, systemImage: "mappin.circle")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label("Lat: \(mapItem.placemark.coordinate.latitude), Lon: \(mapItem.placemark.coordinate.longitude)", systemImage: "location")

            if let tz = mapItem.timeZone {
                Label(tz.identifier, systemImage: "clock")
            }
        }
    }
    
    // MARK: - Friends Helper Functions
    
    private func loadFriendsData() {
        guard let userID = authManager.currentUserID else { return }
        
        isLoadingFriends = true
        Task {
            let fetchedFriends = await SupabaseManager.shared.getFollowingUsers(for: userID)
            await MainActor.run {
                friends = fetchedFriends
                isLoadingFriends = false
            }
        }
    }
    
    private func getFriendsAtLocation() -> [(friend: AppUser, pin: Pin)] {
        let coordinate = mapItem.placemark.coordinate
        let locationName = mapItem.name ?? "Unknown Place"
        
        // Get all pins that match this location
        let matchingPins = pinStore.masterPins.filter { pin in
            // Check if coordinates are very close (within ~10 meters)
            let latitudeDiff = abs(pin.latitude - coordinate.latitude)
            let longitudeDiff = abs(pin.longitude - coordinate.longitude)
            let isLocationMatch = latitudeDiff < 0.0001 && longitudeDiff < 0.0001
            
            // Also check if the name matches (case insensitive)
            let isNameMatch = pin.locationName.lowercased() == locationName.lowercased()
            
            return isLocationMatch || isNameMatch
        }
        
        // Match pins with friends
        return matchingPins.compactMap { pin in
            if let friend = friends.first(where: { $0.username == pin.authorHandle.replacingOccurrences(of: "@", with: "") }) {
                return (friend, pin)
            }
            return nil
        }.sorted { $0.pin.createdAt > $1.pin.createdAt } // Most recent first
    }
    
    private func getAverageRating(from friendPins: [(friend: AppUser, pin: Pin)]) -> Double? {
        let ratings = friendPins.compactMap { $0.pin.starRating }
        guard !ratings.isEmpty else { return nil }
        return ratings.reduce(0, +) / Double(ratings.count)
    }
    
    private func friendsText(count: Int) -> String {
        switch count {
        case 1:
            return "1 friend has been here"
        case 2:
            return "2 friends have been here"
        default:
            return "\(count) friends have been here"
        }
    }
    
    // MARK: - Helper Functions for List Status
    
    /// Finds all lists that contain a location with matching coordinates and name
    private func getListsContainingLocation() -> [PinList] {
        let coordinate = mapItem.placemark.coordinate
        let locationName = mapItem.name ?? "Unknown Place"
        
        return pinStore.lists.filter { list in
            list.pins.contains { pin in
                // Check if coordinates are very close (within ~10 meters)
                let latitudeDiff = abs(pin.latitude - coordinate.latitude)
                let longitudeDiff = abs(pin.longitude - coordinate.longitude)
                let isLocationMatch = latitudeDiff < 0.0001 && longitudeDiff < 0.0001
                
                // Also check if the name matches (case insensitive)
                let isNameMatch = pin.locationName.lowercased() == locationName.lowercased()
                
                return isLocationMatch || isNameMatch
            }
        }
    }
    
    /// Gets the button text based on whether the location is already in lists
    private func getButtonText() -> String {
        let listsContainingLocation = getListsContainingLocation()
        
        if listsContainingLocation.isEmpty {
            return "Add to List"
        } else if listsContainingLocation.count == 1 {
            let listName = listsContainingLocation.first!.name
            return "In \(listName)"
        } else {
            return "In \(listsContainingLocation.count) lists"
        }
    }
    
    /// Gets the button icon based on whether the location is already in lists
    private func getButtonIcon() -> String {
        let listsContainingLocation = getListsContainingLocation()
        return listsContainingLocation.isEmpty ? "plus.circle.fill" : "checkmark.circle.fill"
    }
    
    /// Gets the button color based on whether the location is already in lists
    private func getButtonColor() -> Color {
        let listsContainingLocation = getListsContainingLocation()
        return listsContainingLocation.isEmpty ? .blue : .green
    }
    
    /// Creates the content to share when the share button is tapped
    private var shareContent: String {
        let placeName = mapItem.name ?? "Unknown Place"
        let address = mapItem.placemark.title ?? "No address available"
        let coordinate = mapItem.placemark.coordinate
        let mapsURL = "https://maps.apple.com/?q=\(coordinate.latitude),\(coordinate.longitude)"
        
        return """
        Check out this place I found: \(placeName)
        
        📍 \(address)
        
        🗺️ View on Maps: \(mapsURL)
        """
    }

    private var addButton: some View {
        VStack(spacing: 12) {
            // Top row: Share and Directions buttons
            HStack(spacing: 12) {
                // Share Button
                ShareLink(item: shareContent) {
                    HStack {
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                // Directions Button
                Button(action: {
                    let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                    mapItem.openInMaps(launchOptions: launchOptions)
                    print("Opening directions for \(mapItem.name ?? "unknown location") in Apple Maps.")
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "car.fill")
                            .font(.title2)
                        Spacer()
                    }
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            
            // Bottom row: Add to List button (full width)
            Button(action: {
                showListDialog = true
            }) {
                HStack {
                    Spacer()
                    Label(getButtonText(), systemImage: getButtonIcon())
                        .font(.title2)
                    Spacer()
                }
                .padding()
                .background(getButtonColor())
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .confirmationDialog("Choose a list", isPresented: $showListDialog, titleVisibility: .visible) {
            ForEach(defaultLists, id: \.self) { list in
                Button(list) {
                    let newPin = Pin(
                        locationName: mapItem.name ?? "Unknown Place",
                        city: mapItem.placemark.locality ?? "Unknown City",
                        date: formattedDate(),
                        latitude: mapItem.placemark.coordinate.latitude,
                        longitude: mapItem.placemark.coordinate.longitude,
                        reaction: .wantToGo,
                        reviewText: nil,
                        mediaURLs: [],
                        mentionedFriends: [],
                        starRating: nil,
                        distance: nil,
                        authorHandle: "@you",
                        createdAt: Date(),
                        tripName: nil
                    )
                    pinStore.addPin(newPin, to: list)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

// Removed unused collectionPickerSheet, collectionList, and addPin(to:) as they are no longer needed.
}

struct LookAroundPreview: UIViewControllerRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let controller = MKLookAroundViewController()
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        Task {
            if let scene = try? await request.scene {
                controller.scene = scene
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MKLookAroundViewController, context: Context) {}
}
