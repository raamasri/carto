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
    @State private var showCommentsSheet = false
    @State private var reactions: [PinReaction] = []
    @State private var userReaction: PinReactionType? = nil
    @State private var commentsCount: Int = 0
    @State private var authorAvatarURL: String? = nil
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager

    private var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: pin.createdAt, relativeTo: Date())
    }

    private var distanceFromUser: String? {
        guard let currentLocation = locationManager.currentLocation else { return nil }
        let pinLocation = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
        let distance = currentLocation.distance(from: pinLocation)
        let miles = distance * 0.000621371
        if miles < 0.1 { return "< 0.1mi" }
        else if miles < 10 { return String(format: "%.1fmi", miles) }
        else { return String(format: "%.0fmi", miles) }
    }

    private var isCurrentUserAuthor: Bool {
        guard let currentUsername = authManager.currentUsername else { return false }
        return pin.authorHandle.contains(currentUsername)
    }

    private var authorFirstName: String {
        let handle = pin.authorHandle.replacingOccurrences(of: "@", with: "")
        let name = handle.split(separator: " ").first.map(String.init) ?? handle
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    private var actionVerb: String {
        switch pin.reaction {
        case .lovedIt: return "tried"
        case .wantToGo: return "saved"
        }
    }

    private var categoryEmoji: String {
        let name = pin.locationName.lowercased()
        let lists = pinStore.lists.filter { list in
            list.pins.contains(where: { $0.id == pin.id })
        }
        let listName = lists.first?.name.lowercased() ?? ""
        
        if listName.contains("coffee") || name.contains("coffee") || name.contains("cafe") { return "☕" }
        if listName.contains("restaurant") || name.contains("restaurant") { return "🍽️" }
        if listName.contains("bar") || name.contains("bar") || name.contains("pub") || name.contains("brewery") { return "🍸" }
        if listName.contains("bakery") || name.contains("bakery") || name.contains("croissant") { return "🥐" }
        if name.contains("taco") || name.contains("mexican") { return "🌮" }
        if name.contains("pizza") { return "🍕" }
        if name.contains("trail") || name.contains("hike") || name.contains("park") { return "🌲" }
        if name.contains("beach") { return "🏖️" }
        if name.contains("museum") || name.contains("gallery") { return "🏛️" }
        if name.contains("gym") || name.contains("fitness") { return "💪" }
        return ""
    }

    private func getListsContainingPin() -> [PinList] {
        return pinStore.lists.filter { list in
            list.pins.contains { existingPin in
                let latDiff = abs(existingPin.latitude - pin.latitude)
                let lngDiff = abs(existingPin.longitude - pin.longitude)
                return (latDiff < 0.0001 && lngDiff < 0.0001) ||
                       existingPin.locationName.lowercased() == pin.locationName.lowercased()
            }
        }
    }

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

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            userHeader
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            heroSection

            if let review = pin.reviewText, !review.isEmpty {
                styledReview(review)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }

            Divider()
                .padding(.horizontal, 14)
                .padding(.top, 10)

            actionBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .sheet(isPresented: $showAddToList) {
            AddToListSheet(pin: pin) { list in
                pinStore.addPin(pin, to: list)
                showAddedAlert = true
            }
        }
        .sheet(isPresented: $showLocationDetail) {
            LocationDetailView(
                mapItem: pin.toMapItem(),
                onAddPin: { newPin in
                    pinStore.addPin(newPin, to: "Favorites")
                }
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
        .sheet(isPresented: $showFriendReviewList) {
            FriendReviewListView(
                placeName: pin.locationName,
                latitude: pin.latitude,
                longitude: pin.longitude,
                allPins: pinStore.masterPins,
                friends: friends
            )
        }
        .sheet(isPresented: $showCommentsSheet) {
            CommentsAndReactionsView(pin: pin)
                .environmentObject(authManager)
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
        .task {
            await loadSocialData()
            await loadAuthorAvatar()
        }
    }

    private static let avatarColors: [Color] = [
        Color(red: 0.85, green: 0.92, blue: 0.95),
        Color(red: 0.95, green: 0.88, blue: 0.85),
        Color(red: 0.88, green: 0.95, blue: 0.88),
        Color(red: 0.93, green: 0.88, blue: 0.95),
        Color(red: 0.95, green: 0.93, blue: 0.85),
    ]

    private var avatarColor: Color {
        let index = abs(pin.authorHandle.hashValue) % Self.avatarColors.count
        return Self.avatarColors[index]
    }

    private var avatarFallback: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: 34, height: 34)
            .overlay(
                Text(authorFirstName.prefix(1).uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            )
    }

    // MARK: - User Header

    private var userHeader: some View {
        HStack(spacing: 10) {
            // Real avatar from Supabase user profile, with initial-letter fallback
            if let urlStr = authorAvatarURL, !urlStr.isEmpty, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        avatarFallback
                    }
                }
                .frame(width: 34, height: 34)
                .clipShape(Circle())
            } else {
                avatarFallback
            }

            HStack(spacing: 0) {
                Text(authorFirstName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(" \(actionVerb)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text(" · \(relativeDateString)")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.tertiaryLabel))
            }

            Spacer()

            Menu {
                Button { showLocationDetail = true } label: {
                    Label("View Details", systemImage: "info.circle")
                }
                Button { sharePin() } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                if !isCurrentUserAuthor {
                    Button { showAddToList = true } label: {
                        Label("Add to List", systemImage: "plus.circle")
                    }
                }
                if isCurrentUserAuthor {
                    Button { showAddPhotoSheet = true } label: {
                        Label("Add Photos", systemImage: "photo")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundColor(Color(.tertiaryLabel))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                if let media = pin.mediaURLs, !media.isEmpty {
                    photoCarousel(media, width: geo.size.width)
                } else {
                    mapSnapshot
                }

                // Dark gradient overlay for text readability
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.7), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Name and city overlay
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(pin.locationName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if !categoryEmoji.isEmpty {
                            Text(categoryEmoji)
                                .font(.system(size: 16))
                        }
                        Spacer()
                        if let rating = pin.starRating, rating > 0 {
                            Text("❤️")
                                .font(.system(size: 14))
                        }
                    }

                    if !pin.city.isEmpty {
                        HStack(spacing: 4) {
                            Text(pin.city)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .frame(height: 180)
        .clipped()
    }

    private func photoCarousel(_ media: [String], width: CGFloat) -> some View {
        TabView(selection: $selectedPhotoIndex) {
            ForEach(Array(media.enumerated()), id: \.offset) { index, urlString in
                if urlString.hasSuffix(".mp4"), let url = URL(string: urlString) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(width: width, height: 180)
                        .clipped()
                        .tag(index)
                } else if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: width, height: 180)
                                .clipped()
                        } else {
                            Color.gray.opacity(0.1)
                                .frame(width: width, height: 180)
                        }
                    }
                    .tag(index)
                } else {
                    Color.gray.opacity(0.1)
                        .frame(width: width, height: 180)
                        .tag(index)
                }
            }
        }
        .frame(height: 180)
        .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .always : .never))
        .clipped()
    }

    @State private var snapshotImage: UIImage? = nil

    private var mapSnapshot: some View {
        Group {
            if let img = snapshotImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.08))
                    .frame(height: 180)
                    .overlay(
                        ProgressView()
                    )
                    .onAppear { generateSnapshot() }
            }
        }
    }

    private func generateSnapshot() {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        )
        options.size = CGSize(width: 400, height: 220)
        options.scale = UIScreen.main.scale

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            guard let snapshot = snapshot else { return }

            let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
            let annotatedImage = renderer.image { ctx in
                snapshot.image.draw(at: .zero)
                let point = snapshot.point(for: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
                let pinSize: CGFloat = 24
                let rect = CGRect(x: point.x - pinSize/2, y: point.y - pinSize, width: pinSize, height: pinSize)
                ctx.cgContext.setFillColor(UIColor.systemRed.cgColor)
                ctx.cgContext.fillEllipse(in: CGRect(x: rect.midX - 8, y: rect.minY, width: 16, height: 16))
                ctx.cgContext.setFillColor(UIColor.white.cgColor)
                ctx.cgContext.fillEllipse(in: CGRect(x: rect.midX - 4, y: rect.minY + 4, width: 8, height: 8))
            }
            DispatchQueue.main.async {
                snapshotImage = annotatedImage
            }
        }
    }

    private let tealAccent = Color(red: 0.18, green: 0.55, blue: 0.53)

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 14) {
                // Save -> opens AddToListSheet which persists via pinStore.addPin -> SupabaseManager.addPinToListById -> createPin (creates friend activity)
                Button { showAddToList = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Save")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                // Comment -> opens CommentsAndReactionsView which uses SupabaseManager.addComment / getComments
                Button { showCommentsSheet = true } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 14))
                        if commentsCount > 0 {
                            Text("\(commentsCount)")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .foregroundColor(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)

                // Share -> opens iOS share sheet
                Button { sharePin() } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                        .foregroundColor(Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)

                // Heart reaction -> SupabaseManager.addReaction / removeReaction
                Button {
                    Task { await toggleReaction() }
                } label: {
                    Image(systemName: userReaction != nil ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor(userReaction != nil ? .red : Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Add to Map -> adds to user's list and opens detail
            Button { addToMapAndShow() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 12))
                    Text("Add to Map")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(tealAccent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func sharePin() {
        let text = "Check out \(pin.locationName) in \(pin.city)!"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func addToMapAndShow() {
        if !isCurrentUserAuthor {
            pinStore.addPin(pin, to: "Favorites")
        }
        showLocationDetail = true
    }

    private func toggleReaction() async {
        if userReaction != nil {
            let success = await SupabaseManager.shared.removeReaction(pinId: pin.id)
            if success {
                await MainActor.run { userReaction = nil }
                await loadSocialData()
            }
        } else {
            let success = await SupabaseManager.shared.addReaction(pinId: pin.id, reactionType: .like)
            if success {
                await MainActor.run { userReaction = .like }
                await loadSocialData()
            }
        }
    }

    private func loadSocialData() async {
        guard let userId = authManager.currentUserID else { return }
        async let reactionsTask = SupabaseManager.shared.getReactions(for: pin.id)
        async let commentsTask = SupabaseManager.shared.getComments(for: pin.id, currentUserId: userId)
        let (fetchedReactions, fetchedComments) = await (reactionsTask, commentsTask)
        await MainActor.run {
            reactions = fetchedReactions
            commentsCount = fetchedComments.count
            userReaction = fetchedReactions.first(where: { $0.userId == userId })?.reactionType
        }
    }

    private func loadAuthorAvatar() async {
        let username = pin.authorHandle.replacingOccurrences(of: "@", with: "")
        if let user = try? await SupabaseManager.shared.getUserByUsername(username) {
            await MainActor.run {
                authorAvatarURL = user.avatarURL
            }
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

                Button {
                    showingPhotoPicker = true
                } label: {
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
        Task {
            var uploadedURLs: [String] = pin.mediaURLs ?? []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    do {
                        let url = try await SupabaseManager.shared.storageService.uploadPinImage(data, for: pin.id.uuidString)
                        uploadedURLs.append(url)
                    } catch {
                        print("Failed to upload image: \(error)")
                    }
                }
            }
            do {
                try await SupabaseManager.shared.client
                    .from("pins")
                    .update(["media_urls": uploadedURLs])
                    .eq("id", value: pin.id.uuidString)
                    .execute()
            } catch {
                print("Failed to update pin media URLs: \(error)")
            }
            await MainActor.run {
                isUploading = false
                dismiss()
            }
        }
    }
}

// MARK: - Add To List Sheet

struct AddToListSheet: View {
    let pin: Pin
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var pinStore: PinStore
    @State private var searchText = ""
    @State private var newListName = ""
    @State private var showCreateList = false

    private func listContainsPin(_ list: PinList) -> Bool {
        list.pins.contains { existingPin in
            let latDiff = abs(existingPin.latitude - pin.latitude)
            let lngDiff = abs(existingPin.longitude - pin.longitude)
            return (latDiff < 0.0001 && lngDiff < 0.0001) ||
                   existingPin.locationName.lowercased() == pin.locationName.lowercased()
        }
    }

    private var filteredLists: [PinList] {
        let sorted = pinStore.lists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pin.locationName)
                                .font(.headline).fontWeight(.semibold).lineLimit(1)
                            Text(pin.city)
                                .font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
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

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your Lists").font(.title3).fontWeight(.semibold)
                        Spacer()
                        Text("\(pinStore.lists.count)")
                            .font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.regularMaterial).cornerRadius(8)
                    }
                    .padding(.horizontal, 20)

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredLists, id: \.id) { list in
                                Button {
                                    onSelect(list.name)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle().fill(.blue.opacity(0.1)).frame(width: 44, height: 44)
                                            Image(systemName: iconForList(list.name))
                                                .font(.system(size: 18, weight: .medium)).foregroundColor(.blue)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(list.name).font(.headline).fontWeight(.medium).foregroundColor(.primary).lineLimit(1)
                                            Text("\(list.pins.count) places").font(.subheadline).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if listContainsPin(list) {
                                            ZStack {
                                                Circle().fill(.green).frame(width: 28, height: 28)
                                                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                                            }
                                        } else {
                                            Image(systemName: "plus.circle").font(.system(size: 24)).foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                    .background(listContainsPin(list) ? .green.opacity(0.05) : .clear)
                                    .background(.regularMaterial)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(listContainsPin(list) ? .green.opacity(0.3) : .clear, lineWidth: 1))
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

                Button { showCreateList = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                        Text("Create New List").font(.headline).fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(.regularMaterial).cornerRadius(10).padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Save Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
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
            Button("Cancel", role: .cancel) { newListName = "" }
        } message: {
            Text("Enter a name for your new list")
        }
        .onAppear {
            if pinStore.lists.isEmpty {
                Task { await pinStore.refresh() }
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
