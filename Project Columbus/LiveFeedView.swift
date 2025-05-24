import SwiftUI
import MapKit
import Foundation

struct AlertMessage: Identifiable {
    var id: String { message }
    let message: String
}

struct LiveFeedView: View {
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
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
    @State private var followingUsers: [AppUser] = []
    @State private var isLoadingFollowing = false
    @State private var sendConfirmation: AlertMessage? = nil
    let tabs = ["History", "Friends", "Following", "For You"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                                List(pinStore.masterPins.filter { $0.authorHandle.contains(authManager.currentUsername ?? "") }.reversed()) { pin in
                                    NavigationLink(
                                        destination: LocationDetailView(
                                            mapItem: pin.toMapItem(),
                                            onAddPin: { _ in }
                                        )
                                        .environmentObject(pinStore)
                                    ) {
                                        PinCardView(pin: pin)
                                            .environmentObject(pinStore)
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
                    List(pinStore.masterPins.reversed()) { pin in
                        NavigationLink(
                            destination: LocationDetailView(
                                mapItem: pin.toMapItem(),
                                onAddPin: { _ in }
                            )
                            .environmentObject(pinStore)
                        ) {
                            PinCardView(pin: pin)
                                .environmentObject(pinStore)
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
                                        ForEach(pinStore.masterPins.filter { pin in
                                            followingUsers.contains { user in
                                                pin.authorHandle.contains(user.username)
                                            }
                                        }.reversed()) { pin in
                                            NavigationLink(
                                                destination: LocationDetailView(
                                                    mapItem: pin.toMapItem(),
                                                    onAddPin: { _ in }
                                                )
                                                .environmentObject(pinStore)
                                            ) {
                                                PinCardView(pin: pin)
                                                    .environmentObject(pinStore)
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
                    default:
                        // For You Tab
                        List(pinStore.masterPins.reversed()) { pin in
                            NavigationLink(
                                destination: LocationDetailView(
                                    mapItem: pin.toMapItem(),
                                    onAddPin: { _ in }
                                )
                                .environmentObject(pinStore)
                            ) {
                                PinCardView(pin: pin)
                                    .environmentObject(pinStore)
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
            .navigationTitle("Live Feed")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showVideoFeed = true
                    }) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.accentColor))
                            .shadow(radius: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
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

    func refreshPins() async {
        await pinStore.fetchPins()
        // TODO: Add sync when DataManager is integrated
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
    case "favorites": return "heart.fill"
    case "coffee shops": return "cup.and.saucer.fill"
    case "restaurants": return "fork.knife"
    case "bars": return "wineglass.fill"
    case "shopping": return "bag.fill"
    default: return "folder.fill"
    }
}

private func colorForCollection(_ name: String) -> Color {
    switch name.lowercased() {
    case "favorites": return .red
    case "coffee shops": return .brown
    case "restaurants": return .orange
    case "bars": return .purple
    case "shopping": return .pink
    default: return .blue
    }
}

struct AddToListSheetDynamic: View {
    let pin: Pin
    @EnvironmentObject var pinStore: PinStore
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Add to List")
                .font(.title2)
                .bold()
                .padding(.top)
            ForEach(pinStore.lists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }, id: \.name) { list in
                Button(action: {
                    onSelect(list.name)
                    dismiss()
                }) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorForCollection(list.name))
                                .frame(width: 32, height: 32)
                            Image(systemName: iconForCollection(list.name))
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                        }
                        Text(list.name)
                            .font(.headline)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
                .padding(.top, 8)
        }
        .padding()
    }
}
