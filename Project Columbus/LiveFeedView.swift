import SwiftUI
import MapKit
import Foundation

struct AlertMessage: Identifiable {
    var id: String { message }
    let message: String
}

// MARK: - Filter Types

enum FeedFilter: String, CaseIterable {
    case allActivity = "All Activity"
    case nearMe = "Near Me"
    case thisWeekend = "This Weekend"
}

// MARK: - Live Feed View

struct LiveFeedView: View {
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager

    @State private var followingUsers: [AppUser] = []
    @State private var selectedFilter: FeedFilter = .allActivity
    @State private var isLoadingFollowing = false
    @State private var showSendToModal = false
    @State private var pinToSend: Pin? = nil
    @State private var pinToAdd: Pin? = nil
    @State private var showAddToListSheet = false
    @State private var sendConfirmation: AlertMessage? = nil
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var liveBannerDismissed = false
    @State private var latestFriendActivity: FriendActivity? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Filter pills
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                // Live banner - uses real friend activity from Supabase
                if !liveBannerDismissed {
                    if let activity = latestFriendActivity {
                        liveBannerFromActivity(activity)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    } else if let latestPin = filteredPins.first(where: { !isCurrentUser($0) }) ?? filteredPins.first {
                        liveBanner(for: latestPin)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }

                // Feed
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredPins) { pin in
                            NavigationLink(destination:
                                LocationDetailView(
                                    mapItem: pin.toMapItem(),
                                    onAddPin: { newPin in
                                        pinStore.addPin(newPin, to: "Favorites")
                                    }
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await refreshFeed()
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
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
        .onAppear {
            fetchFollowingUsersIfNeeded()
            if let userID = authManager.currentUserID {
                Task { await loadLatestFriendActivity(userID: userID) }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Carto")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                Button {
                    withAnimation { showSearch.toggle() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            if showSearch {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search places...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(FeedFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedFilter == filter ? Color.white : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedFilter == filter ? Color(red: 0.18, green: 0.55, blue: 0.53) : Color.gray.opacity(0.25), lineWidth: selectedFilter == filter ? 1.5 : 1)
                        )
                        .foregroundColor(selectedFilter == filter ? Color(red: 0.18, green: 0.55, blue: 0.53) : .secondary)
                }
                .buttonStyle(.plain)
            }

            Menu {
                NavigationLink(destination: FriendActivityFeedView()
                    .environmentObject(authManager)
                    .environmentObject(pinStore)
                ) {
                    Label("Activity Feed", systemImage: "bell")
                }
                NavigationLink(destination: VideoFeedView()
                    .environmentObject(authManager)
                ) {
                    Label("Video Feed", systemImage: "play.rectangle")
                }
            } label: {
                Text("•••")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Live Banner

    private func liveBanner(for pin: Pin) -> some View {
        let rawName = pin.authorHandle.replacingOccurrences(of: "@", with: "")
            .split(separator: " ").first.map(String.init) ?? pin.authorHandle
        let name = rawName.prefix(1).uppercased() + rawName.dropFirst()
        let verb = pin.reaction == .lovedIt ? "tried" : "saved"
        var distanceText = ""
        if let userLoc = locationManager.currentLocation {
            let pinLoc = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            let miles = userLoc.distance(from: pinLoc) * 0.000621371
            distanceText = " \(String(format: "%.1f", miles)) miles away"
        }

        return HStack(spacing: 8) {
            // Pulsing green dot
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }

            Text("Live")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.18, green: 0.55, blue: 0.53))

            Text("· \(name) just \(verb) a spot\(distanceText)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation { liveBannerDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(red: 0.18, green: 0.55, blue: 0.53).opacity(0.3), lineWidth: 1)
        )
    }

    private func liveBannerFromActivity(_ activity: FriendActivity) -> some View {
        let name = activity.username.split(separator: " ").first.map(String.init) ?? activity.username
        let capitalizedName = name.prefix(1).uppercased() + name.dropFirst()

        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }

            Text("Live")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(red: 0.18, green: 0.55, blue: 0.53))

            Text("· \(capitalizedName) \(activity.description)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer()

            Button {
                withAnimation { liveBannerDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(red: 0.18, green: 0.55, blue: 0.53).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Filtered Pins

    private var filteredPins: [Pin] {
        var pins = getAllFeedPins()

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            pins = pins.filter {
                $0.locationName.lowercased().contains(query) ||
                $0.city.lowercased().contains(query) ||
                $0.authorHandle.lowercased().contains(query)
            }
        }

        switch selectedFilter {
        case .allActivity:
            return pins
        case .nearMe:
            guard let userLoc = locationManager.currentLocation else { return pins }
            return pins.filter { pin in
                let pinLoc = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
                let miles = userLoc.distance(from: pinLoc) * 0.000621371
                return miles <= 10
            }
        case .thisWeekend:
            let calendar = Calendar.current
            let now = Date()
            let weekday = calendar.component(.weekday, from: now)
            let daysToSubtract = (weekday + 1) % 7
            guard let lastFriday = calendar.date(byAdding: .day, value: -daysToSubtract, to: now) else { return pins }
            let fridayStart = calendar.startOfDay(for: lastFriday)
            return pins.filter { $0.createdAt >= fridayStart }
        }
    }

    private func getAllFeedPins() -> [Pin] {
        let allPins = pinStore.lists.flatMap { $0.pins }
        var unique: [Pin] = []
        var seen: Set<UUID> = []
        for pin in allPins {
            if !seen.contains(pin.id) {
                unique.append(pin)
                seen.insert(pin.id)
            }
        }
        // Also include master pins from other users
        for pin in pinStore.masterPins {
            if !seen.contains(pin.id) {
                unique.append(pin)
                seen.insert(pin.id)
            }
        }
        return unique.sorted { $0.createdAt > $1.createdAt }
    }

    private func isCurrentUser(_ pin: Pin) -> Bool {
        guard let currentUsername = authManager.currentUsername else { return false }
        return pin.authorHandle.contains(currentUsername)
    }

    // MARK: - Data Loading

    private func refreshFeed() async {
        guard let userID = authManager.currentUserID else { return }

        let publicPins = await SupabaseManager.shared.getPublicPins(limit: 100)
        let feedPins = await SupabaseManager.shared.getFeedPins(for: userID, limit: 50)

        await MainActor.run {
            let existingIds = Set(pinStore.masterPins.map { $0.id })
            let newPublic = publicPins.filter { !existingIds.contains($0.id) }
            let newPublicIds = Set(newPublic.map { $0.id })
            let newFeed = feedPins.filter { pin in !existingIds.contains(pin.id) && !newPublicIds.contains(pin.id) }
            pinStore.masterPins.append(contentsOf: newPublic)
            pinStore.masterPins.append(contentsOf: newFeed)
        }

        // Fetch latest friend activity for live banner
        await loadLatestFriendActivity(userID: userID)

        fetchFollowingUsersIfNeeded()
    }

    private func loadLatestFriendActivity(userID: String) async {
        if let activities = try? await SupabaseManager.shared.getFriendActivityFeed(for: userID, limit: 1, offset: 0),
           let latest = activities.first {
            await MainActor.run {
                latestFriendActivity = latest
            }
        }
    }

    private func fetchFollowingUsersIfNeeded() {
        guard let userID = authManager.currentUserID, followingUsers.isEmpty else { return }
        isLoadingFollowing = true
        Task {
            let fetched = await SupabaseManager.shared.getFollowingUsers(for: userID)
            await MainActor.run {
                followingUsers = fetched
                isLoadingFollowing = false
            }
        }
    }
}

// MARK: - Supporting Views

struct SendToSheet: View {
    let pin: Pin
    let followingUsers: [AppUser]
    let isLoading: Bool
    var onSend: (AppUser) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Send \(pin.locationName) to...")
                .font(.title2).bold().padding(.top)
            if isLoading {
                ProgressView("Loading...")
            } else if followingUsers.isEmpty {
                Text("You are not following anyone yet.")
                    .foregroundColor(.gray)
            } else {
                List(followingUsers, id: \.id) { user in
                    Button {
                        onSend(user)
                        dismiss()
                    } label: {
                        HStack {
                            if let avatar = user.avatarURL, !avatar.isEmpty, let url = URL(string: avatar) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                                    }
                                }
                                .frame(width: 32, height: 32).clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable().foregroundColor(.gray)
                                    .frame(width: 32, height: 32)
                            }
                            VStack(alignment: .leading) {
                                Text(user.full_name.isEmpty ? "@\(user.username)" : user.full_name)
                                Text("@\(user.username)").font(.caption).foregroundColor(.gray)
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
            Text(pin.locationName).font(.headline).padding()
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
                            .foregroundColor(.blue).font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pin.locationName).font(.headline).fontWeight(.semibold).lineLimit(1)
                            Text(pin.city).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.top, 16)

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search lists...", text: $searchText).textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(.regularMaterial).cornerRadius(10).padding(.horizontal)
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
                                            Circle().fill(colorForCollection(list.name).opacity(0.1)).frame(width: 44, height: 44)
                                            Image(systemName: iconForCollection(list.name))
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(colorForCollection(list.name))
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
                                    .cornerRadius(12).padding(.horizontal)
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
}
