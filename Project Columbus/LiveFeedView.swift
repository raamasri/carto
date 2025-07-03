import SwiftUI
import MapKit
import Foundation

struct AlertMessage: Identifiable {
    var id: String { message }
    let message: String
}

struct LiveFeedView: View {
    let tabs = ["History", "Friends", "Following", "For You", "Activity"]
    @State private var followingUsers: [AppUser] = []
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedPin: Pin? = nil
    @State private var showMap = false
    @State private var lovedPins: Set<UUID> = []
    @State private var selectedTab = 3
    @State private var showDetail = false
    @State private var showVideoFeed = false
    @State private var showSendToModal = false
    @State private var pinToSend: Pin? = nil
    @State private var pinToAdd: Pin? = nil
    @State private var showAddToListSheet = false
    @State private var isLoadingFollowing = false
    @State private var sendConfirmation: AlertMessage? = nil

    var body: some View {
        return NavigationView {
            VStack(spacing: 0) {
                // Custom header with title and video button
                HStack {
                    Text("Live Feed")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    
                    Button(action: {
                        showVideoFeed = true
                    }) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Picker("Tabs", selection: $selectedTab) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Text(tabs[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case 0:
                        // History Tab - User's own activity
                        VStack {
                            if authManager.isLoggedIn {
                                List(getFilteredPins().filter { $0.authorHandle.contains(authManager.currentUsername ?? "") }.reversed()) { pin in
                                    NavigationLink(
                                        destination: LocationDetailView(
                                            mapItem: pin.toMapItem(),
                                            onAddPin: { _ in }
                                        )
                                        .environmentObject(pinStore)
                                        .environmentObject(authManager)
                                    ) {
                                        PinCardView(pin: pin)
                                            .environmentObject(pinStore)
                                            .environmentObject(authManager)
                                            .environmentObject(locationManager)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .refreshable {
                                    await refreshPins()
                                }
                            } else {
                                Text("Please log in to view your history")
                                    .foregroundColor(.gray)
                            }
                        }
                    case 1:
                        // Friends Tab
                        List(getFriendsTabPins().reversed()) { pin in
                            NavigationLink(
                                destination: LocationDetailView(
                                    mapItem: pin.toMapItem(),
                                    onAddPin: { _ in }
                                )
                                .environmentObject(pinStore)
                                .environmentObject(authManager)
                            ) {
                                PinCardView(pin: pin)
                                    .environmentObject(pinStore)
                                    .environmentObject(authManager)
                                    .environmentObject(locationManager)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    pinToAdd = pin
                                    showAddToListSheet = true
                                } label: {
                                    Label("Add to List", systemImage: "plus")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    pinToSend = pin
                                    showSendToModal = true
                                    fetchFollowingUsersIfNeeded()
                                } label: {
                                    Label("Send To", systemImage: "paperplane")
                                }
                                .tint(.green)
                            }
                            .contentShape(Rectangle())
                        }
                        .refreshable {
                            await refreshPins()
                        }
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { _ in }
                                .onEnded { _ in }
                        )
                    case 2:
                        // Following Tab - Content from people you follow
                        VStack {
                            if authManager.isLoggedIn {
                                if followingUsers.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "person.3")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                        Text("You're not following anyone yet")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                        Text("Follow friends to see their recommendations here")
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.secondary)
                                        
                                        Button("Find Friends") {
                                            // Navigate to find friends
                                            selectedTab = 1
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else {
                                    List {
                                        ForEach(getFilteredPins().filter { pin in
                                            followingUsers.contains(where: { user in
                                                pin.authorHandle.contains(user.username)
                                            })
                                        }.reversed()) { pin in
                                            NavigationLink(
                                                destination: LocationDetailView(
                                                    mapItem: pin.toMapItem(),
                                                    onAddPin: { _ in }
                                                )
                                                .environmentObject(pinStore)
                                                .environmentObject(authManager)
                                            ) {
                                                PinCardView(pin: pin)
                                                    .environmentObject(pinStore)
                                                    .environmentObject(authManager)
                                                    .environmentObject(locationManager)
                                            }
                                            .buttonStyle(.plain)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button {
                                                    pinToAdd = pin
                                                    showAddToListSheet = true
                                                } label: {
                                                    Label("Add to List", systemImage: "plus")
                                                }
                                                .tint(.blue)
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                                Button {
                                                    pinToSend = pin
                                                    showSendToModal = true
                                                    fetchFollowingUsersIfNeeded()
                                                } label: {
                                                    Label("Send To", systemImage: "paperplane")
                                                }
                                                .tint(.green)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                    }
                                    .refreshable {
                                        await refreshPins()
                                        fetchFollowingUsersIfNeeded()
                                    }
                                    .simultaneousGesture(
                                        DragGesture()
                                            .onChanged { _ in }
                                            .onEnded { _ in }
                                    )
                                }
                            } else {
                                Text("Please log in to see content from people you follow")
                                    .foregroundColor(.gray)
                            }
                        }
                        .onAppear {
                            fetchFollowingUsersIfNeeded()
                        }
                    case 4:
                        // Activity Tab - Friend Activity Feed
                        FriendActivityFeedView()
                            .environmentObject(authManager)
                            .environmentObject(pinStore)

                    default:
                        // For You Tab - Smart algorithm
                        List(getRecommendedPins().reversed()) { pin in
                            NavigationLink(
                                destination: LocationDetailView(
                                    mapItem: pin.toMapItem(),
                                    onAddPin: { _ in }
                                )
                                .environmentObject(pinStore)
                                .environmentObject(authManager)
                            ) {
                                EnhancedPinCardView(pin: pin)
                                    .environmentObject(pinStore)
                                    .environmentObject(authManager)
                                    .environmentObject(locationManager)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    pinToAdd = pin
                                    showAddToListSheet = true
                                } label: {
                                    Label("Add to List", systemImage: "plus")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    pinToSend = pin
                                    showSendToModal = true
                                    fetchFollowingUsersIfNeeded()
                                } label: {
                                    Label("Send To", systemImage: "paperplane")
                                }
                                .tint(.green)
                            }
                            .contentShape(Rectangle())
                        }
                        .refreshable {
                            await refreshPins()
                        }
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { _ in }
                                .onEnded { _ in }
                        )
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showMap) {
                if let pin = selectedPin {
                    ZStack(alignment: .topTrailing) {
                        Map(coordinateRegion: $region, annotationItems: [pin]) { pin in
                            MapMarker(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude), tint: .red)
                        }
                        .edgesIgnoringSafeArea(.all)

                        Button(action: {
                            showMap = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
            }
            .sheet(isPresented: $showDetail) {
                if let pin = selectedPin {
                    LocationDetailView(
                        mapItem: MKMapItem(placemark: MKPlacemark(
                            coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                        )),
                        onAddPin: { _ in }
                    )
                }
            }
            .sheet(isPresented: $showVideoFeed) {
                VideoFeedView()
            }
            .sheet(isPresented: $showSendToModal) {
                if let pin = pinToSend {
                    SendToSheet(pin: pin, followingUsers: followingUsers, isLoading: isLoadingFollowing) { user in
                        sendConfirmation = AlertMessage(message: "Sent to @\(user.username)")
                    }
                }
            }
            .sheet(isPresented: $showAddToListSheet) {
                if let pin = pinToAdd {
                    AddToListSheetDynamic(pin: pin) { list in
                        pinStore.addPin(pin, to: list)
                    }
                }
            }
            .alert(item: $sendConfirmation) { confirmation in
                Alert(title: Text(confirmation.message))
            }
        }
    }

    /// Get filtered pins that are only in user lists (not orphaned pins)
    func getFilteredPins() -> [Pin] {
        // Only show pins that are actually in user's lists (not orphaned pins)
        // Use Set to remove duplicates when pins appear in multiple lists
        let allPins = pinStore.lists.flatMap { $0.pins }
        var uniquePins: [Pin] = []
        var seenIds: Set<UUID> = []
        
        for pin in allPins {
            if !seenIds.contains(pin.id) {
                uniquePins.append(pin)
                seenIds.insert(pin.id)
            }
        }
        
        // Debug logging to help identify discrepancies
        if pinStore.masterPins.count != uniquePins.count {
            print("🔍 LiveFeed: Found \(pinStore.masterPins.count) total pins in database, \(uniquePins.count) pins in lists (filtered out \(pinStore.masterPins.count - uniquePins.count) orphaned pins)")
        }
        
        return uniquePins
    }

    /// Get pins for Friends tab - includes user's organized pins + public pins from others, but excludes user's orphaned pins
    func getFriendsTabPins() -> [Pin] {
        let currentUsername = authManager.currentUsername ?? ""
        
        // Get pins from user's lists (organized pins)
        let userListPins = getFilteredPins()
        
        // Get all master pins and filter out user's orphaned pins
        let publicPins = pinStore.masterPins.filter { pin in
            // Include if it's in user's lists OR if it's from another user
            userListPins.contains(where: { $0.id == pin.id }) || 
            !pin.authorHandle.contains(currentUsername)
        }
        
        // Remove duplicates
        var uniquePins: [Pin] = []
        var seenIds: Set<UUID> = []
        
        for pin in publicPins {
            if !seenIds.contains(pin.id) {
                uniquePins.append(pin)
                seenIds.insert(pin.id)
            }
        }
        
        print("🔍 Friends Tab: Showing \(uniquePins.count) pins (user organized + public from others, filtered out user's orphaned pins)")
        return uniquePins
    }

    func refreshPins() async {
        guard let userID = authManager.currentUserID else { return }
        
        // Load different types of pins based on the selected tab
        switch selectedTab {
        case 0: // History - User's own pins
            await pinStore.loadFromDatabase()
        case 1: // Friends - All public pins for discovery
            let publicPins = await SupabaseManager.shared.getPublicPins(limit: 100)
            await MainActor.run {
                // Merge with existing pins, avoiding duplicates
                let existingIds = Set(pinStore.masterPins.map { $0.id })
                let newPins = publicPins.filter { !existingIds.contains($0.id) }
                pinStore.masterPins.append(contentsOf: newPins)
            }
        case 2: // Following - Pins from users you follow
            let feedPins = await SupabaseManager.shared.getFeedPins(for: userID, limit: 50)
            await MainActor.run {
                // Update pins from following users
                let existingIds = Set(pinStore.masterPins.map { $0.id })
                let newPins = feedPins.filter { !existingIds.contains($0.id) }
                pinStore.masterPins.append(contentsOf: newPins)
            }
        case 3: // For You - Curated/recommended content
            let publicPins = await SupabaseManager.shared.getPublicPins(limit: 50)
            await MainActor.run {
                // For now, use public pins as "For You" content
                // TODO: Implement proper recommendation algorithm
                let existingIds = Set(pinStore.masterPins.map { $0.id })
                let newPins = publicPins.filter { !existingIds.contains($0.id) }
                pinStore.masterPins.append(contentsOf: newPins)
            }
        default:
            await pinStore.loadFromDatabase()
        }
    }

    func sharePin(_ pin: Pin) {
        let text = "Check out \(pin.locationName) in \(pin.city)!"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }

    func fetchFollowingUsersIfNeeded() {
        guard let userID = authManager.currentUserID, followingUsers.isEmpty else { return }
        isLoadingFollowing = true
        let start = Date()
        Task {
            print("⏱️ Fetching following users started at \(start)")
            let fetched = await SupabaseManager.shared.getFollowingUsers(for: userID)
            let end = Date()
            let duration = end.timeIntervalSince(start)
            print("⏱️ Fetching following users finished at \(end) (duration: \(duration) seconds)")
            await MainActor.run {
                followingUsers = fetched
                isLoadingFollowing = false
            }
        }
    }
    
    /// Smart recommendation algorithm for "For You" feed
    func getRecommendedPins() -> [Pin] {
        guard authManager.isLoggedIn else { return getFilteredPins() }
        
        let currentUsername = authManager.currentUsername ?? ""
        let allPins = getFilteredPins()
        
        // Score each pin based on multiple factors
        let scoredPins = allPins.map { pin -> (Pin, Double) in
            var score: Double = 0.0
            
            // 1. Recency score (newer pins get higher scores)
            let pinDate = pin.createdAt ?? Date()
            let daysSinceCreated = Date().timeIntervalSince(pinDate) / (24 * 60 * 60)
            let recencyScore = max(0, 10 - daysSinceCreated) // Decays over 10 days
            score += recencyScore * 0.3
            
            // 2. Following score (pins from people you follow get higher scores)
            if followingUsers.contains(where: { pin.authorHandle.contains($0.username) }) {
                score += 15.0
            }
            
            // 3. Star rating score (higher rated places get preference)
            if let starRating = pin.starRating {
                score += starRating * 2.0 // 0-10 points from star rating
            }
            
            // 4. Interaction score (pins with reviews/reactions get bonus)
            if let reviewText = pin.reviewText, !reviewText.isEmpty {
                score += 5.0
            }
            // All pins have reactions, so give a small bonus for engagement
            score += 2.0
            
            // 5. Location relevance (if user has location, prefer nearby pins)
            // This would require user location data which we don't have readily available
            
            // 6. Diversity penalty (avoid showing too many pins from same author)
            let authorPinCount = allPins.filter { $0.authorHandle == pin.authorHandle }.count
            if authorPinCount > 3 {
                score -= Double(authorPinCount - 3) * 1.0
            }
            
            // 7. Random factor for discovery (small random boost)
            score += Double.random(in: 0...2)
            
            return (pin, score)
        }
        
        // Sort by score and return the pins
        return scoredPins
            .sorted { $0.1 > $1.1 } // Sort by score descending
            .map { $0.0 } // Extract just the pins
    }
}

// MARK: - Enhanced Pin Card with Social Features

struct EnhancedPinCardView: View {
    let pin: Pin
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager
    @State private var showCommentsAndReactions = false
    @State private var reactions: [PinReaction] = []
    @State private var commentsCount = 0
    @State private var userReaction: PinReactionType? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Original pin card content
            PinCardView(pin: pin)
                .environmentObject(pinStore)
                .environmentObject(authManager)
                .environmentObject(locationManager)
            
            // Social engagement section
            HStack(spacing: 20) {
                // Reactions summary
                Button(action: {
                    showCommentsAndReactions = true
                }) {
                    HStack(spacing: 6) {
                        if reactions.isEmpty {
                            Image(systemName: "heart")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("React")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            // Show top reaction emojis
                            let topReactions = getTopReactions()
                            HStack(spacing: 2) {
                                ForEach(topReactions.prefix(3), id: \.self) { reactionType in
                                    Text(reactionType.emoji)
                                        .font(.caption)
                                }
                            }
                            Text("\(reactions.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Comments summary
                Button(action: {
                    showCommentsAndReactions = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(commentsCount == 0 ? "Comment" : "\(commentsCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Quick reaction button
                Button(action: {
                    Task {
                        await quickReaction()
                    }
                }) {
                    Image(systemName: userReaction != nil ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .foregroundColor(userReaction != nil ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showCommentsAndReactions) {
            CommentsAndReactionsView(pin: pin)
                .environmentObject(authManager)
        }
        .task {
            await loadSocialData()
        }
    }
    
    private func getTopReactions() -> [PinReactionType] {
        let reactionCounts = Dictionary(grouping: reactions, by: { $0.reactionType })
            .mapValues { $0.count }
        return reactionCounts.sorted { $0.value > $1.value }.map { $0.key }
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
    
    private func quickReaction() async {
        if userReaction != nil {
            // Remove reaction
            let success = await SupabaseManager.shared.removeReaction(pinId: pin.id)
            if success {
                await MainActor.run {
                    userReaction = nil
                }
                await loadSocialData()
            }
        } else {
            // Add like reaction
            let success = await SupabaseManager.shared.addReaction(pinId: pin.id, reactionType: .like)
            if success {
                await MainActor.run {
                    userReaction = .like
                }
                await loadSocialData()
            }
        }
    }
}

struct SendToSheet: View {
    let pin: Pin
    let followingUsers: [AppUser]
    let isLoading: Bool
    var onSend: (AppUser) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Send \(pin.locationName) to...")
                .font(.title2)
                .bold()
                .padding(.top)
            if isLoading {
                ProgressView("Loading...")
            } else if followingUsers.isEmpty {
                Text("You are not following anyone yet.")
                    .foregroundColor(.gray)
            } else {
                List(followingUsers, id: \.id) { user in
                    Button(action: {
                        onSend(user)
                        dismiss()
                    }) {
                        HStack {
                            if let avatar = user.avatarURL, !avatar.isEmpty, let url = URL(string: avatar) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .onAppear {
                                                print("🖼️ Image loaded for \(user.username) at \(Date())")
                                            }
                                    default:
                                        Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                                    }
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundColor(.gray)
                                    .frame(width: 32, height: 32)
                            }
                            VStack(alignment: .leading) {
                                Text(user.full_name.isEmpty ? "@\(user.username)" : user.full_name)
                                Text("@\(user.username)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
                .padding(.top, 8)
        }
        .padding()
    }
}

struct POIView: View {
    let pin: Pin
    @State private var region: MKCoordinateRegion

    init(pin: Pin) {
        self.pin = pin
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        VStack {
            Map(coordinateRegion: $region, annotationItems: [pin]) { pin in
                MapMarker(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude), tint: .red)
            }
            .edgesIgnoringSafeArea(.all)

            Text(pin.locationName)
                .font(.headline)
                .padding()
            // Additional POI details can be added here
        }
        .navigationTitle(pin.locationName)
    }
}

private func iconForCollection(_ name: String) -> String {
    switch name.lowercased() {
    case "favorites":  "heart.fill"
    case "coffee shops":  "cup.and.saucer.fill"
    case "restaurants":  "fork.knife"
    case "bars":  "wineglass.fill"
    case "shopping":  "bag.fill"
    default:  "folder.fill"
    }
}

private func colorForCollection(_ name: String) -> Color {
    switch name.lowercased() {
    case "favorites":  .red
    case "coffee shops":  .brown
    case "restaurants":  .orange
    case "bars":  .purple
    case "shopping":  .pink
    default:  .blue
    }
}

struct AddToListSheetDynamic: View {
    let pin: Pin
    @EnvironmentObject var pinStore: PinStore
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
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
                                                .fill(colorForCollection(list.name).opacity(0.1))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: iconForCollection(list.name))
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(colorForCollection(list.name))
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
}
