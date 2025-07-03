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
    
    // MARK: - Computed Properties
    
    /// Creates a formatted address string from placemark components
    private var formattedAddress: String {
        let placemark = mapItem.placemark
        var addressComponents: [String] = []
        
        // Add street number and name
        if let subThoroughfare = placemark.subThoroughfare,
           let thoroughfare = placemark.thoroughfare {
            addressComponents.append("\(subThoroughfare) \(thoroughfare)")
        } else if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        
        // Add locality (city)
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        
        // Add administrative area (state/province)
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        // Add postal code
        if let postalCode = placemark.postalCode {
            addressComponents.append(postalCode)
        }
        
        // Add country (only if we don't have more specific components)
        if addressComponents.isEmpty, let country = placemark.country {
            addressComponents.append(country)
        }
        
        return addressComponents.joined(separator: ", ")
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
        VStack(alignment: .leading, spacing: 12) {
            // Address section - made more prominent
            if !formattedAddress.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Address")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        
                        Text(formattedAddress)
                            .font(.body)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
            }
            
            // Other information
            VStack(alignment: .leading, spacing: 8) {
                if let category = mapItem.pointOfInterestCategory {
                    Label(category.displayName, systemImage: "tag")
                        .font(.subheadline)
                }

                if let phone = mapItem.phoneNumber {
                    Label(phone, systemImage: "phone")
                        .font(.subheadline)
                }

                if let url = mapItem.url {
                    Link("Website", destination: url)
                        .font(.subheadline)
                }

                Label("Lat: \(String(format: "%.6f", mapItem.placemark.coordinate.latitude)), Lon: \(String(format: "%.6f", mapItem.placemark.coordinate.longitude))", systemImage: "location")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let tz = mapItem.timeZone {
                    Label(tz.identifier, systemImage: "clock")
                        .font(.subheadline)
                }
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
        .sheet(isPresented: $showListDialog) {
            LocationAddToListSheet(pin: tempPin) { list in
                pinStore.addPin(tempPin, to: list)
            }
        }
    }
    
    private var tempPin: Pin {
        Pin(
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
    }
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

struct LocationAddToListSheet: View {
    let pin: Pin
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var pinStore: PinStore
    @State private var showCreateList = false
    @State private var newListName = ""
    @State private var searchText = ""

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
    
    private var filteredLists: [PinList] {
        if searchText.isEmpty {
            return pinStore.lists
        } else {
            return pinStore.lists.filter { list in
                list.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background with same material as navbar
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Location info header
                    locationHeader
                    
                    // Search bar
                    searchBar
                    
                    // Lists section
                    listsSection
                    
                    // Create new list section
                    createListSection
                    
                    Spacer()
                }
            }
            .navigationTitle("Save Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var locationHeader: some View {
        VStack(spacing: 12) {
            // Location icon and name
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.locationName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    if !pin.city.isEmpty && pin.city != "Unknown City" {
                        Text(pin.city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Material.regularMaterial)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("Search lists...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
                 .background(Material.regularMaterial)
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 16)
    }
    
    private var listsSection: some View {
        VStack(spacing: 0) {
            if !filteredLists.isEmpty {
                // Section header
                HStack {
                    Text("Your Lists")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("\(filteredLists.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                .padding(.bottom, 12)
                
                // Lists
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredLists, id: \.id) { list in
                            listRow(for: list)
                        }
                    }
                    .padding(.horizontal)
                }
            } else if !searchText.isEmpty {
                // No search results
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No lists found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
            }
        }
    }
    
    private func listRow(for list: PinList) -> some View {
        Button(action: {
            onSelect(list.name)
            dismiss()
        }) {
            HStack(spacing: 16) {
                // List icon
                Image(systemName: listContainsPin(list) ? "checkmark.circle.fill" : "list.bullet.circle")
                    .font(.title2)
                    .foregroundColor(listContainsPin(list) ? .green : .blue)
                
                // List details
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("\(list.pins.count) places")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                if listContainsPin(list) {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(width: 20, height: 20)
                    .background(.green)
                    .cornerRadius(10)
                } else {
                    Image(systemName: "plus")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(width: 20, height: 20)
                        .background(.blue.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(listContainsPin(list) ? .green.opacity(0.05) : .clear)
            .background(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(listContainsPin(list) ? .green.opacity(0.3) : .clear, lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private var createListSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)
                .padding(.top, 16)
            
            Button(action: {
                showCreateList = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Create New List")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.blue.opacity(0.05))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .alert("Create New List", isPresented: $showCreateList) {
            TextField("List name", text: $newListName)
            Button("Cancel", role: .cancel) {
                newListName = ""
            }
            Button("Create") {
                if !newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let trimmedName = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
                    pinStore.createCustomList(name: trimmedName)
                    onSelect(trimmedName)
                    newListName = ""
                    dismiss()
                }
            }
            .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a name for your new list")
        }
    }
}
