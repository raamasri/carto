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
    @State private var selectedSection = "Just Added"
    let sections = ["Just Added", "Loved", "Want to Go", "Recommendations"]
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    
    // The isCurrentUser flag is now provided by the backend via profileUser.isCurrentUser
    
    init(profileUser: AppUser) {
        self.profileUser = profileUser
        _displayedUser = State(initialValue: profileUser)
        _bio = State(initialValue: profileUser.bio)
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
                        } else if let url = URL(string: profileUser.avatarURL), !profileUser.avatarURL.isEmpty {
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
                            Text(displayedUser.full_name)
                                .font(.headline)

                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(2)

                            Text("\(displayedUser.follower_count) followers • \(displayedUser.following_count) following")
                                .font(.caption)
                                .foregroundColor(.gray)
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
                            Button(action: {}) {
                                Text("Share profile")
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
                        Button(action: {
                            Task {
                                let isNowFollowing = await SupabaseManager.shared.toggleFollowStatus(
                                    targetUserID: profileUser.id
                                )
                                await MainActor.run {
                                    if isNowFollowing {
                                        displayedUser.follower_count += 1
                                        displayedUser.isFollowedByCurrentUser = true
                                    } else {
                                        displayedUser.follower_count -= 1
                                        displayedUser.isFollowedByCurrentUser = false
                                    }
                                }
                            }
                        }) {
                            Text(displayedUser.isFollowedByCurrentUser ? "Unfollow" : "Follow")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(profileUser.isFollowedByCurrentUser ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }

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
                    .frame(height: 470)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.top, 16)
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
                    bio = updated.bio
                }
            }
        }
    }

    var body: some View {
        print("🧭 Loading UserProfileView for username:", profileUser.username)
        return Group {
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
                                email: profileUser.email,
                                bio: tempBio,
                                avatarURL: profileUser.avatarURL
                            )
                            // Re-fetch to get the definitive record
                            if let updated = await SupabaseManager.shared.fetchUserProfile(userID: profileUser.id) {
                                await MainActor.run {
                                    displayedUser = updated
                                    bio = updated.bio
                                    tempBio = updated.bio
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
                            let url = try await SupabaseManager.shared.uploadProfileImage(jpegData, for: userID)
                            try await SupabaseManager.shared.updateUserProfile(
                                userID: profileUser.id,
                                username: displayedUser.username,
                                fullName: tempFullName, // ✅ user's edited name
                                email: profileUser.email,
                                bio: bio,
                                avatarURL: url.absoluteString
                            )
                            if let updated = await SupabaseManager.shared.fetchUserProfile(userID: profileUser.id) {
                                await MainActor.run {
                                    displayedUser = updated
                                    bio = updated.bio
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
