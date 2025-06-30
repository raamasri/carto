//
//  UserProfileView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//

import SwiftUI
import MapKit
import PhotosUI
import UIKit
import Supabase

struct UserProfileView: View {
    let profileUser: AppUser
    @State private var displayedUser: AppUser
    @State private var bio: String
    
    // @State private var bio = "✨ Travel lover. Coffee first. Exploring the world one pin at a time! 🌍"
    @State private var selectedSection = "My Lists"
    let sections = ["Just Added", "Loved", "Want to Go", "Recommendations"]
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    
    // The isCurrentUser flag is now provided by the backend via profileUser.isCurrentUser
    
    init(profileUser: AppUser) {
        self.profileUser = profileUser
        _displayedUser = State(initialValue: profileUser)
        _bio = State(initialValue: profileUser.bio ?? "")
    }
    
    @State private var selectedFilter: Reaction? = nil
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showChangePicturePrompt = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedUIImage: UIImage? = nil
    @State private var imageToCrop: UIImage? = nil
    @State private var profileImage: Image? = nil
    @State private var tempUsername: String = ""
    @State private var tempFullName: String = ""
    @State private var isEditingProfile = false
    @State private var tempBio = ""
    @State private var hasRequestedFollow = false
    @State private var showFullscreenMap = false
    @State private var showBlockReportSheet = false
    @State private var showReportSheet = false
    @State private var isBlocked = false
    @State private var blockReportMessage = ""
    @State private var showBlockReportAlert = false
    
    private var profileHeader: some View {
        HStack {
            Text("@\(profileUser.username)")
                .font(.title)
                .fontWeight(.bold)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var profileBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Profile Header Card
                ZStack(alignment: .topTrailing) {
                    HStack(alignment: .center, spacing: 12) {
                        if let profileImage {
                            profileImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 4)
                                .onTapGesture { showChangePicturePrompt = true }
                        } else if let avatar = displayedUser.avatarURL, !avatar.isEmpty, let url = URL(string: avatar) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let img):
                                    img
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(radius: 4)
                                        .onTapGesture { showChangePicturePrompt = true }
                                case .failure:
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        .shadow(radius: 4)
                                        .onTapGesture { showChangePicturePrompt = true }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 4)
                                .onTapGesture { showChangePicturePrompt = true }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayedUser.full_name.isEmpty ? "@\(displayedUser.username)" : displayedUser.full_name)
                                .font(.headline)

                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(2)

                            HStack(spacing: 8) {
                                NavigationLink(destination: UserListView(userID: profileUser.id, listType: .followers)) {
                                    Text("\(displayedUser.follower_count) \(displayedUser.follower_count == 1 ? "follower" : "followers")")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                NavigationLink(destination: UserListView(userID: profileUser.id, listType: .following)) {
                                    Text("\(displayedUser.following_count) following")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            if displayedUser.isCurrentUser == false && profileUser.isFollowedByCurrentUser {
                                Text("Follows you")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal)
                }

                // Buttons and Map
                VStack(spacing: 8) {
                    if profileUser.isCurrentUser ?? false {
                        HStack(spacing: 16) {
                            Button(action: {
                                tempUsername = profileUser.username
                                tempFullName = profileUser.full_name
                                tempBio = bio
                                isEditingProfile = true
                            }) {
                                Text("Edit Profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            NavigationLink(destination:
                                NotificationView()
                                    .environmentObject(authManager)
                                    .environmentObject(SupabaseManager.shared)
                            ) {
                                Text("Notifications")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }

                    if !(profileUser.isCurrentUser ?? false) {
                        FollowButton(isFollowing: $hasRequestedFollow, followText: hasRequestedFollow ? "Requested" : "Follow") {
                            Task {
                                print("📍 Follow button tapped")
                                print("🧪 currentUserID =", authManager.currentUserID ?? "nil")
                                guard let currentUserID = authManager.currentUserID else { return }
                                do {
                                    if hasRequestedFollow {
                                        print("🔄 Cancelling follow request...")
                                        _ = try await SupabaseManager.shared.client
                                            .from("notifications")
                                            .delete()
                                            .eq("user_id", value: profileUser.id)
                                            .eq("from_user_id", value: currentUserID)
                                            .eq("type", value: "follow_request")
                                            .execute()
                                        await MainActor.run {
                                            hasRequestedFollow = false
                                            print("🔁 Follow state updated. Requested: \(hasRequestedFollow)")
                                        }
                                    } else {
                                        // Remove any previous requests before inserting
                                        _ = try await SupabaseManager.shared.client
                                            .from("notifications")
                                            .delete()
                                            .eq("user_id", value: profileUser.id)
                                            .eq("from_user_id", value: currentUserID)
                                            .eq("type", value: "follow_request")
                                            .execute()

                                        // Log values about to be inserted
                                        print("📤 Inserting follow request with from_user_id:", currentUserID, "→ user_id:", profileUser.id)

                                        // Insert new follow request
                                        let insertResult = try await SupabaseManager.shared.client
                                            .from("notifications")
                                            .insert([
                                                "user_id": AnyJSON.string(profileUser.id),
                                                "from_user_id": AnyJSON.string(currentUserID),
                                                "type": AnyJSON.string("follow_request"),
                                                "is_read": AnyJSON.bool(false)
                                            ])
                                            .execute()

                                        print("✅ Insert result:", insertResult)

                                        hasRequestedFollow = true
                                    }
                                } catch {
                                    print("❌ Failed to toggle follow request:", error)
                                    print("❌ Full error details:", error.localizedDescription)
                                }
                            }
                        }
                        
                        // Block/Report Menu
                        Menu {
                            Button(action: {
                                showBlockReportSheet = true
                            }) {
                                Label("Block User", systemImage: "hand.raised")
                            }
                            
                            Button(action: {
                                showReportSheet = true
                            }) {
                                Label("Report User", systemImage: "exclamationmark.triangle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.primary)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .clipShape(Circle())
                        }
                    }

                    // --- Tabbed View for Map & Collections ---
                    VStack(spacing: 0) {
                        Picker("Profile Tabs", selection: $selectedSection) {
                            Text("Map View").tag("Map View")
                            Text("My Lists").tag("My Lists")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)

                        if selectedSection == "Map View" {
                            ZStack(alignment: .topTrailing) {
                                Map(
                                    coordinateRegion: $region,
                                    annotationItems: pinStore.masterPins
                                ) { pin in
                                    MapAnnotation(
                                        coordinate: CLLocationCoordinate2D(
                                            latitude: pin.latitude,
                                            longitude: pin.longitude
                                        )
                                    ) {
                                        Image(systemName: "mappin.circle.fill")
                                            .resizable()
                                            .frame(width: 30, height: 30)
                                            .foregroundColor(.blue)
                                            .shadow(radius: 3)
                                    }
                                }
                                .frame(height: 400)
                                .cornerRadius(10)
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .padding(.bottom, 20)
                                
                                Button(action: {
                                    showFullscreenMap = true
                                }) {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(.top, 20)
                                .padding(.trailing, 30)
                            }
                        } else if selectedSection == "My Lists" {
                            UserListsView(
                                userID: profileUser.id,
                                isCurrentUser: profileUser.isCurrentUser ?? false
                            )
                            .padding(.top, 8)
                            .onAppear {
                                print("🔍 UserProfileView: Creating UserListsView with:")
                                print("  - profileUser.id: \(profileUser.id)")
                                print("  - profileUser.isCurrentUser: \(String(describing: profileUser.isCurrentUser))")
                                print("  - final isCurrentUser value: \(profileUser.isCurrentUser ?? false)")
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .refreshable {
            refreshUserProfile()
        }
        .padding(.bottom, 4)
    }

    func refreshUserProfile() {
        Task {
            if let updated = await SupabaseManager.shared.fetchUserProfile(userID: profileUser.id) {
                await MainActor.run {
                    displayedUser = updated
                    bio = updated.bio ?? ""
                }
            }
        }
    }

    private func centerMapOnPins() {
        let pins = pinStore.masterPins
        guard !pins.isEmpty else {
            // Default to San Francisco if no pins
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            return
        }
        
        if pins.count == 1 {
            // Single pin - center on it with reasonable zoom
            let pin = pins[0]
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            return
        }
        
        // Multiple pins - calculate bounding box
        let latitudes = pins.map { $0.latitude }
        let longitudes = pins.map { $0.longitude }
        
        let minLat = latitudes.min()!
        let maxLat = latitudes.max()!
        let minLon = longitudes.min()!
        let maxLon = longitudes.max()!
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        // Add 20% padding to the span
        let latDelta = max((maxLat - minLat) * 1.2, 0.01)
        let lonDelta = max((maxLon - minLon) * 1.2, 0.01)
        
        region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    var body: some View {
        print("🧭 Loading UserProfileView for username:", profileUser.username)
        return NavigationStack {
            Group {
                if profileUser.username.isEmpty {
                    // Loading state while placeholder data is present
                    ProgressView("Loading Profile…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        profileHeader
                        profileBody
                    }
                    .padding(.top, 4)
                }
            }
        }
        .toolbar {
            if profileUser.isCurrentUser ?? false {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination:
                        NotificationView()
                            .environmentObject(authManager)
                            .environmentObject(SupabaseManager.shared)
                    ) {
                        Image(systemName: "bell")
                    }
                }
            }
        }
        .padding(.top, 4)
        .confirmationDialog(
            "Change profile picture?",
            isPresented: $showChangePicturePrompt,
            titleVisibility: .visible
        ) {
            Button("Change Profile Picture") {
                isShowingPhotoPicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedUIImage = uiImage
                    imageToCrop = uiImage // triggers cropper
                }
            }
        }
        .sheet(isPresented: $isEditingProfile) {
            EditProfileSheet(
                username: $tempUsername,
                fullName: $tempFullName,
                bio: $tempBio,
                onSave: {
                    Task {
                        do {
                            // Persist change to backend
                            try await SupabaseManager.shared.updateUserProfile(
                                userID: profileUser.id,
                                username: tempUsername,
                                fullName: tempFullName,
                                email: profileUser.email ?? "",
                                bio: tempBio,
                                avatarURL: profileUser.avatarURL ?? ""
                            )
                            // Re-fetch to get the definitive record
                            if let updated = await SupabaseManager.shared.fetchUserProfile(userID: profileUser.id) {
                                await MainActor.run {
                                    displayedUser = updated
                                    bio = updated.bio ?? ""
                                    tempBio = updated.bio ?? ""
                                    isEditingProfile = false
                                }
                            }
                        } catch {
                            print("Failed to save profile:", error)
                        }
                    }
                },
                onCancel: {
                    isEditingProfile = false
                }
            )
        }
                .sheet(item: $imageToCrop) { image in
            CircleCropperView(image: image) { cropped in
                Task {
                    do {
                        if let jpegData = cropped.jpegData(compressionQuality: 0.8) {
                            guard let userID = authManager.currentUserID else { return }
                            print("✏️ authManager.currentUserID:", authManager.currentUserID ?? "nil")
                            print("✏️ target userID for upload:", userID)
                            try await SupabaseManager.shared.client.storage
                                .from("profile-images")
                                .upload(
                                    "\(userID)-avatar.jpg",
                                    data: jpegData,
                                    options: FileOptions(
                                        contentType: "image/jpeg",
                                        upsert: true,
                                        metadata: ["owner": AnyJSON.string(userID)]
                                    )
                                )
                            let url = try SupabaseManager.shared.client.storage
                                .from("profile-images")
                                .getPublicURL(path: "\(userID)-avatar.jpg")
                            try await SupabaseManager.shared.updateUserProfile(
                                userID: profileUser.id,
                                username: displayedUser.username,
                                fullName: tempFullName, // ✅ user's edited name
                                email: profileUser.email ?? "",
                                bio: bio,
                                avatarURL: url.absoluteString
                            )
                            if let updated = await SupabaseManager.shared.fetchUserProfile(userID: profileUser.id) {
                                await MainActor.run {
                                    displayedUser = updated
                                    bio = updated.bio ?? ""
                                    profileImage = Image(uiImage: cropped)
                                }
                            }
                        }
                    } catch {
                        print("Failed to upload avatar:", error)
                    }
                }
            }
        }
        .onAppear {
            print("👀 UserProfileView appeared for:", profileUser.username)
            
            // Center map on pins
            centerMapOnPins()
            
            Task {
                if let updated = await SupabaseManager.shared.fetchUserProfile(userID: profileUser.id) {
                    displayedUser = updated
                    bio = updated.bio ?? ""
                    
                    // Recenter map after loading pins
                    centerMapOnPins()

                    if let avatar = updated.avatarURL {
                        if let cached = ImageCache.shared.image(forKey: profileUser.id) {
                            await MainActor.run {
                                profileImage = Image(uiImage: cached)
                            }
                        } else if let url = URL(string: avatar) {
                            do {
                                let (data, _) = try await URLSession.shared.data(from: url)
                                if let uiImage = UIImage(data: data) {
                                    ImageCache.shared.insertImage(uiImage, forKey: profileUser.id)
                                    await MainActor.run {
                                        profileImage = Image(uiImage: uiImage)
                                    }
                                }
                            } catch {
                                print("Failed to load image data:", error)
                            }
                        }
                    }
                }

                print("👤 Checking follow request from:", authManager.currentUserID ?? "nil")

                // Only check for follow request if this is not your own profile
                guard !(profileUser.isCurrentUser ?? false) else {
                    print("ℹ️ Skipping follow request check – viewing own profile.")
                    return
                }

                do {
                    if let uuid = UUID(uuidString: profileUser.id) {
                        let hasSent = await SupabaseManager.shared.hasFollowRequestSent(to: uuid)
                        print("📌 hasFollowRequestSent(to:) result:", hasSent)
                        await MainActor.run {
                            hasRequestedFollow = hasSent
                        }
                    } else {
                        print("❌ Failed to convert profileUser.id to UUID:", profileUser.id)
                    }
                    
                    // Check if user is blocked
                    let blocked = await SupabaseManager.shared.isUserBlocked(userID: profileUser.id)
                    await MainActor.run {
                        isBlocked = blocked
                    }
                } catch {
                    print("❌ Error checking follow request via helper:", error)
                }
            }
        }
        .onChange(of: pinStore.masterPins) { _, _ in
            centerMapOnPins()
        }
        .fullScreenCover(isPresented: $showFullscreenMap) {
            FullscreenMapView(
                region: $region,
                pins: pinStore.masterPins,
                isPresented: $showFullscreenMap
            )
        }
        .sheet(isPresented: $showBlockReportSheet) {
            BlockUserSheet(
                user: profileUser,
                isBlocked: $isBlocked,
                onBlock: { reason in
                    Task {
                        let success = await SupabaseManager.shared.blockUser(userID: profileUser.id, reason: reason)
                        await MainActor.run {
                            if success {
                                isBlocked = true
                                blockReportMessage = "User blocked successfully"
                                showBlockReportAlert = true
                            } else {
                                blockReportMessage = "Failed to block user"
                                showBlockReportAlert = true
                            }
                        }
                    }
                },
                onUnblock: {
                    Task {
                        let success = await SupabaseManager.shared.unblockUser(userID: profileUser.id)
                        await MainActor.run {
                            if success {
                                isBlocked = false
                                blockReportMessage = "User unblocked successfully"
                                showBlockReportAlert = true
                            } else {
                                blockReportMessage = "Failed to unblock user"
                                showBlockReportAlert = true
                            }
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showReportSheet) {
            ReportUserSheet(
                user: profileUser,
                onReport: { reason in
                    Task {
                        let success = await SupabaseManager.shared.reportUser(userID: profileUser.id, reason: reason)
                        await MainActor.run {
                            if success {
                                blockReportMessage = "User reported successfully"
                                showBlockReportAlert = true
                            } else {
                                blockReportMessage = "Failed to report user"
                                showBlockReportAlert = true
                            }
                        }
                    }
                }
            )
        }
        .alert("Block/Report Status", isPresented: $showBlockReportAlert) {
            Button("OK") { }
        } message: {
            Text(blockReportMessage)
        }
    }
}

// Allow UIImage to be used with .sheet(item:)
extension UIImage: @retroactive Identifiable {
    public var id: UUID {
        // use the object identifier so the same image isn't re‑presented repeatedly
        UUID()
    }
}

struct CircleCropperView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var onCrop: (UIImage) -> Void
    
    init(image: UIImage, onCrop: @escaping (UIImage) -> Void) {
        _image = State(initialValue: image)
        self.onCrop = onCrop
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                GeometryReader { geo in
                    ZStack {
                        Color.black.opacity(0.85).ignoresSafeArea()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / scale
                                        scale *= delta
                                    }
                                    .simultaneously(with:
                                        DragGesture().onChanged { value in
                                            offset = value.translation
                                        }
                                    )
                            )
                            .clipShape(Circle())
                            .frame(
                                width: min(geo.size.width, geo.size.height) * 0.8,
                                height: min(geo.size.width, geo.size.height) * 0.8
                            )
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
                .frame(
                    height: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * 0.8
                )
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Done") {
                        let cropped = cropToCircle()
                        onCrop(cropped)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func cropToCircle() -> UIImage {
        let side = min(image.size.width, image.size.height)
        let origin = CGPoint(x: (image.size.width - side) / 2,
                             y: (image.size.height - side) / 2)
        let cropRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        guard let cgCropped = image.cgImage?.cropping(to: cropRect) else { return image }
        let square = UIImage(cgImage: cgCropped)
        
        let renderer = UIGraphicsImageRenderer(size: square.size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: square.size)
            UIBezierPath(ovalIn: rect).addClip()
            square.draw(in: rect)
        }
    }
}

struct EditProfileSheet: View {
    @Binding var username: String
    @Binding var fullName: String
    @Binding var bio: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name")) {
                    TextField("Full name", text: $fullName)
                }
                Section(header: Text("Username")) {
                    TextField("Username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section(header: Text("Bio")) {
                    TextEditor(text: $bio)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                }
            }
        }
    }
}


struct FollowButton: View {
    @Binding var isFollowing: Bool
    var followText: String
    var action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            Text(followText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue.opacity(0.2))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }
}

struct BlockUserSheet: View {
    let user: AppUser
    @Binding var isBlocked: Bool
    let onBlock: (String?) -> Void
    let onUnblock: () -> Void
    
    @State private var blockReason = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: isBlocked ? "hand.raised.slash" : "hand.raised")
                        .font(.system(size: 50))
                        .foregroundColor(isBlocked ? .orange : .red)
                    
                    Text(isBlocked ? "Unblock @\(user.username)?" : "Block @\(user.username)?")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if isBlocked {
                        Text("You will see their content again and they can message you.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    } else {
                        Text("You won't see their content and they won't be able to message you.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reason (optional)")
                                .font(.headline)
                            TextField("Why are you blocking this user?", text: $blockReason, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        if isBlocked {
                            onUnblock()
                        } else {
                            onBlock(blockReason.isEmpty ? nil : blockReason)
                        }
                        dismiss()
                    }) {
                        Text(isBlocked ? "Unblock User" : "Block User")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isBlocked ? Color.orange : Color.red)
                            .cornerRadius(12)
                    }
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle(isBlocked ? "Unblock User" : "Block User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ReportUserSheet: View {
    let user: AppUser
    let onReport: (String) -> Void
    
    @State private var selectedReason = "Inappropriate content"
    @State private var customReason = ""
    @State private var showCustomReason = false
    @Environment(\.dismiss) private var dismiss
    
    private let reportReasons = [
        "Inappropriate content",
        "Harassment or bullying",
        "Spam or fake account",
        "Hate speech",
        "Violence or dangerous behavior",
        "Intellectual property violation",
        "Other"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Report @\(user.username)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Help us understand what's happening. Your report is anonymous.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("What's the issue?")
                        .font(.headline)
                    
                    ForEach(reportReasons, id: \.self) { reason in
                        Button(action: {
                            selectedReason = reason
                            showCustomReason = (reason == "Other")
                        }) {
                            HStack {
                                Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedReason == reason ? .blue : .gray)
                                Text(reason)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    if showCustomReason {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Please specify")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("Describe the issue...", text: $customReason, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        let reason = showCustomReason && !customReason.isEmpty ? customReason : selectedReason
                        onReport(reason)
                        dismiss()
                    }) {
                        Text("Submit Report")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .disabled(showCustomReason && customReason.isEmpty)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FullscreenMapView: View {
    @Binding var region: MKCoordinateRegion
    let pins: [Pin]
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Map(
                coordinateRegion: $region,
                annotationItems: pins
            ) { pin in
                MapAnnotation(
                    coordinate: CLLocationCoordinate2D(
                        latitude: pin.latitude,
                        longitude: pin.longitude
                    )
                ) {
                    Image(systemName: "mappin.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.blue)
                        .shadow(radius: 3)
                }
            }
            .ignoresSafeArea()
            
            // Minimize button in top-right corner
            Button(action: {
                isPresented = false
            }) {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .padding(.top, 60) // Account for status bar and notch
            .padding(.trailing, 20)
        }
    }
}

struct UserListsView: View {
    let userID: String
    let isCurrentUser: Bool
    @State private var userLists: [PinList] = []
    @State private var isLoading = false
    @State private var searchText = ""
    
    // Deduplicate lists by name (case-insensitive)
    var filteredLists: [PinList] {
        print("🎯 filteredLists: Starting with \(userLists.count) lists")
        let sorted = userLists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        print("🎯 filteredLists: After sorting: \(sorted.count) lists")
        var seen = Set<String>()
        let deduped = sorted.filter { list in
            let lower = list.name.lowercased()
            if seen.contains(lower) { 
                print("🎯 filteredLists: Filtering out duplicate '\(list.name)'")
                return false 
            }
            seen.insert(lower)
            print("🎯 filteredLists: Keeping '\(list.name)'")
            return true
        }
        print("🎯 filteredLists: After deduplication: \(deduped.count) lists")
        
        if searchText.isEmpty {
            print("🎯 filteredLists: No search text, returning \(deduped.count) lists")
            return deduped
        } else {
            let filtered = deduped.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
            print("🎯 filteredLists: After search filtering: \(filtered.count) lists")
            return filtered
        }
    }
    
    var body: some View {
        let _ = print("🖼️ UserListsView body rendering - isLoading: \(isLoading), filteredLists.count: \(filteredLists.count), userLists.count: \(userLists.count)")
        return VStack {
            // Search bar (only for current user)
            if isCurrentUser {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search lists...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
            }
            
            if isLoading {
                let _ = print("🔄 Showing loading state")
                VStack {
                    ProgressView("Loading lists...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredLists.isEmpty {
                let _ = print("📂 Showing empty state")
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text(isCurrentUser ? "No Lists Yet" : "No Public Lists")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(isCurrentUser ? "Start organizing your pins by creating lists!" : "This user hasn't created any public lists yet.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let _ = print("📋 Showing list state with \(filteredLists.count) lists")
                List {
                    ForEach(filteredLists, id: \.id) { list in
                        NavigationLink(destination: ListDetailView(list: list)) {
                            UserListRowView(list: list)
                        }
                    }
                }
                .listStyle(.plain)
                .ignoresSafeArea(.container, edges: .bottom)
                .refreshable {
                    await loadUserLists()
                }
                .onAppear {
                    print("📱 List view appeared with \(filteredLists.count) filtered lists")
                    for list in filteredLists {
                        print("  📋 \(list.name) (\(list.pins.count) pins)")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadUserLists()
            }
        }
    }
    
    private func loadUserLists() async {
        isLoading = true
        print("🔄 UserListsView: Loading lists for userID: \(userID), isCurrentUser: \(isCurrentUser)")
        let lists: [PinList]
        if isCurrentUser {
            // For current user, use the authenticated method
            print("📱 Using authenticated getUserLists() for current user")
            lists = await SupabaseManager.shared.getUserLists()
        } else {
            // For other users, use the method that takes a user ID
            print("👤 Using getUserLists(for:) for user: \(userID)")
            lists = await SupabaseManager.shared.getUserLists(for: userID)
        }
        print("📊 UserListsView: Retrieved \(lists.count) lists")
        for list in lists {
            print("  - \(list.name) (\(list.pins.count) pins)")
        }
        await MainActor.run {
            userLists = lists
            isLoading = false
        }
    }
}

struct UserListRowView: View {
    let list: PinList
    
    var body: some View {
        HStack {
            // List icon with notification dots overlay
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorForCollection(list.name))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: iconForCollection(list.name))
                            .foregroundColor(.white)
                            .font(.title2)
                    )
                
                // Notification dots on top corner of icon
                if !list.pins.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(list.pins.prefix(3)), id: \.id) { pin in
                            Circle()
                                .fill(pin.reaction == .lovedIt ? .red : .blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .offset(x: 5, y: -5) // Position on top corner
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(list.pins.count) pin\(list.pins.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !list.pins.isEmpty {
                    Text("Latest: \(list.pins.first?.locationName ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Just the arrow now
            if !list.pins.isEmpty {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
    }
}

// Helper functions for UserListRowView
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
