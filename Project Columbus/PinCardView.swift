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
import PhotosUI
// Pin is defined in Models.swift in the same module

struct PinCardView: View {
    let pin: Pin
    @State private var showFullMap = false
    @State private var showAddToList = false
    @State private var showAddedAlert = false
    @State private var showFriendReviewList = false
    @State private var friends: [AppUser] = []
    @State private var isLoadingFriends = false
    @State private var showLocationDetail = false
    @State private var selectedPhotoIndex = 0
    @State private var showAddPhotoSheet = false
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager

    // Helper: Relative date string
    private var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: pin.createdAt, relativeTo: Date())
    }

    // Helper: Calculate distance from current location
    private var distanceFromUser: String? {
        guard let currentLocation = locationManager.currentLocation else { return nil }
        let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        let distance = currentLocation.distance(from: pinLocation)
        
        // Convert to miles and format
        let miles = distance * 0.000621371
        if miles < 0.1 {
            return "< 0.1mi"
        } else if miles < 10 {
            return String(format: "%.1fmi", miles)
        } else {
            return String(format: "%.0fmi", miles)
        }
    }

    // Helper: Check if current user is the author
    private var isCurrentUserAuthor: Bool {
        guard let currentUsername = authManager.currentUsername else { return false }
        return pin.authorHandle.contains(currentUsername)
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
            } else if count > 0 {
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

    // Enhanced header with rating, distance, and mini map
    private var enhancedHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(pin.locationName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let rating = pin.starRating {
                        HStack(spacing: 2) {
                            Text(String(format: "%.1f", rating))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    // Show city/address information
                    if !pin.city.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(pin.city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Show distance from user
                    if let distance = distanceFromUser {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(distance)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // Mini map
            miniMap
        }
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
                    .frame(width: 20, height: 20)
                    .foregroundColor(.red)
                    .shadow(radius: 1)
            }
        }
        .frame(width: 56, height: 56)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
        .onTapGesture { showLocationDetail = true }
    }

    // Enhanced photo carousel with add photo functionality
    private var photoCarousel: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedPhotoIndex) {
                ForEach(Array((pin.mediaURLs ?? []).enumerated()), id: \.offset) { index, urlString in
                    if urlString.hasSuffix(".mp4"), let url = URL(string: urlString) {
                        VideoPlayer(player: AVPlayer(url: url))
                            .aspectRatio(16/9, contentMode: .fit)
                            .clipped()
                            .tag(index)
                    } else if let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                            } else {
                                Color.gray.opacity(0.2)
                            }
                        }
                        .tag(index)
                    } else {
                        Color.gray.opacity(0.2).tag(index)
                    }
                }
            }
            .frame(height: 200)
            .tabViewStyle(.page(indexDisplayMode: .always))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Photo + button (only for current user's pins)
            if isCurrentUserAuthor {
                Button(action: {
                    showAddPhotoSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.caption)
                        Text("+")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Enhanced header with rating, distance, MAP button
                enhancedHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                
                // Friends avatars row (if any)
                let friendPins = friendsWhoReviewed()
                if !friendPins.isEmpty {
                    friendsAvatarsRow
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
                
                // Review text (expanded)
                if let review = pin.reviewText, !review.isEmpty {
                    styledReview(review)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(nil)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
                
                // Enhanced photo carousel
                if let media = pin.mediaURLs, !media.isEmpty {
                    photoCarousel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
                
                // Trip tag and timestamp
                HStack(spacing: 8) {
                    tripTag
                    Text(relativeDateString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // Action icons and author
                HStack {
                    Text(pin.authorHandle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 16) {
                        Image(systemName: "heart")
                            .font(.system(size: 16))
                        Image(systemName: "message")
                            .font(.system(size: 16))
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16))
                        Image(systemName: "bookmark")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(hasReviewOrMedia ? 0.1 : 0.04), radius: hasReviewOrMedia ? 8 : 4, x: 0, y: hasReviewOrMedia ? 4 : 2)

            // Add to List button (only for non-current user pins)
            if !isCurrentUserAuthor {
                Button(action: {
                    print("Add to List tapped for \(pin.locationName)")
                    showAddToList = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 36, height: 36)
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .padding(12)
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showAddToList) {
            AddToListSheet(pin: pin) { list in
                pinStore.addPin(pin, to: list)
                showAddedAlert = true
            }
        }
        .sheet(isPresented: $showLocationDetail) {
            LocationDetailView(
                mapItem: pin.toMapItem(),
                onAddPin: { _ in }
            )
            .environmentObject(pinStore)
            .environmentObject(authManager)
        }
        .sheet(isPresented: $showAddPhotoSheet) {
            AddPhotoToExistingPinSheet(pin: pin)
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

// MARK: - Add Photo to Existing Pin Sheet
struct AddPhotoToExistingPinSheet: View {
    let pin: Pin
    @Environment(\.dismiss) var dismiss
    @State private var showingPhotoPicker = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Photos to \(pin.locationName)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Add more photos or videos to this location")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    showingPhotoPicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Select Photos")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                if isUploading {
                    ProgressView("Uploading photos...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedItems,
            maxSelectionCount: 5,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedItems) { _, newItems in
            if !newItems.isEmpty {
                uploadPhotos(newItems)
            }
        }
    }
    
    private func uploadPhotos(_ items: [PhotosPickerItem]) {
        isUploading = true
        // TODO: Implement photo upload functionality
        // This would involve:
        // 1. Converting PhotosPickerItems to Data
        // 2. Uploading to Supabase Storage
        // 3. Updating the pin's mediaURLs array
        // 4. Refreshing the pin store
        
        // For now, just simulate upload
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isUploading = false
            dismiss()
        }
    }
}

struct AddToListSheet: View {
    let pin: Pin
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var pinStore: PinStore
    @State private var searchText = ""
    @State private var newListName = ""
    @State private var showCreateList = false

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
            return pinStore.lists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            return pinStore.lists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with location info
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pin.locationName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            Text(pin.city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search lists...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.bottom, 16)
                
                // Lists section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your Lists")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text("\(pinStore.lists.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 20)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredLists, id: \.id) { list in
                                Button(action: {
                                    onSelect(list.name)
                                    dismiss()
                                }) {
                                    HStack(spacing: 16) {
                                        // List icon
                                        ZStack {
                                            Circle()
                                                .fill(.blue.opacity(0.1))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: iconForList(list.name))
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                        
                                        // List info
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(list.name)
                                                .font(.headline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            Text("\(list.pins.count) places")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Checkmark for existing lists
                                        if listContainsPin(list) {
                                            ZStack {
                                                Circle()
                                                    .fill(.green)
                                                    .frame(width: 28, height: 28)
                                                
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        } else {
                                            Image(systemName: "plus.circle")
                                                .font(.system(size: 24))
                                                .foregroundColor(.blue)
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
                                    .padding(.horizontal)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Spacer()
                
                // Create new list button
                Button(action: {
                    showCreateList = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        Text("Create New List")
                            .font(.headline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Save Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Create New List", isPresented: $showCreateList) {
            TextField("List name", text: $newListName)
            Button("Create") {
                if !newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let trimmedName = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
                    pinStore.createCustomList(name: trimmedName)
                    onSelect(trimmedName)
                    newListName = ""
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {
                newListName = ""
            }
        } message: {
            Text("Enter a name for your new list")
        }
        .onAppear {
            // Ensure lists are loaded when sheet appears
            if pinStore.lists.isEmpty {
                Task {
                    await pinStore.refresh()
                }
            }
        }
    }
    
    private func iconForList(_ name: String) -> String {
        switch name.lowercased() {
        case "favorites": return "heart.fill"
        case "coffee shops": return "cup.and.saucer.fill"
        case "restaurants": return "fork.knife"
        case "bars": return "wineglass.fill"
        case "shopping": return "bag.fill"
        default: return "list.bullet"
        }
    }
}
