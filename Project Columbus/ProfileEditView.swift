//
//  ProfileEditView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/16/25.
//

import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var username: String = ""
    @State private var fullName: String = ""
    @State private var bio: String = ""
    @State private var selectedInterests: Set<String> = []
    @State private var profileImage: Image? = nil
    @State private var profileImageData: Data? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showImagePicker = false
    @State private var showPhotoActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    
    // Privacy settings
    @State private var isPrivateAccount: Bool = false
    @State private var showLocation: Bool = true
    @State private var allowDirectMessages: Bool = true
    @State private var showActivityStatus: Bool = true
    
    // UI states
    @State private var isLoading = true
    @State private var isUpdating = false
    @State private var isUploadingAvatar = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    
    let interests = ["Food", "Travel", "Nature", "Art", "Sports", "History", "Music", "Photography", "Technology", "Books", "Coffee", "Nightlife", "Shopping", "Adventure", "Culture", "Fitness"]
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading Profile...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Profile Photo Section - Instagram Style
                            VStack(spacing: 16) {
                                ZStack {
                                    // Profile image container
                                    Circle()
                                        .fill(Color(.systemGray6))
                                        .frame(width: 100, height: 100)
                                    
                                    if let image = profileImage {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 80))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    // Upload progress overlay
                                    if isUploadingAvatar {
                                        Circle()
                                            .fill(Color.black.opacity(0.5))
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            )
                                    }
                                }
                                .onTapGesture {
                                    showPhotoActionSheet = true
                                }
                                
                                Button(action: { showPhotoActionSheet = true }) {
                                    Text("Change Profile Photo")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                                .disabled(isUploadingAvatar)
                                
                                if profileImage != nil && !isUploadingAvatar {
                                    Button(action: {
                                        profileImage = nil
                                        profileImageData = nil
                                        selectedPhotoItem = nil
                                    }) {
                                        Text("Remove Photo")
                                            .font(.subheadline)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(.top, 32)
                            .padding(.bottom, 32)
                            
                            // Form Content
                            VStack(spacing: 0) {
                                // Basic Information Section
                                VStack(spacing: 0) {
                                    sectionHeader("Basic Information")
                                    
                                    VStack(spacing: 1) {
                                        formRow(
                                            title: "Full Name",
                                            text: $fullName,
                                            placeholder: "Enter your full name"
                                        )
                                        
                                        formRow(
                                            title: "Username",
                                            text: $username,
                                            placeholder: "Enter username"
                                        )
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                    }
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                                    
                                    // Bio Section
                                    VStack(spacing: 0) {
                                        HStack {
                                            Text("Bio")
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemBackground))
                                        
                                        TextEditor(text: $bio)
                                            .frame(minHeight: 80)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 0)
                                                    .stroke(Color(.separator), lineWidth: 0.5)
                                            )
                                    }
                                    .cornerRadius(10)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 32)
                                }
                                
                                // Interests Section
                                VStack(spacing: 0) {
                                    sectionHeader("Interests")
                                    
                                    LazyVGrid(columns: [
                                        GridItem(.adaptive(minimum: 80), spacing: 8)
                                    ], spacing: 8) {
                                        ForEach(interests, id: \.self) { interest in
                                            Button(action: {
                                                if selectedInterests.contains(interest) {
                                                    selectedInterests.remove(interest)
                                                } else {
                                                    selectedInterests.insert(interest)
                                                }
                                            }) {
                                                Text(interest)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        selectedInterests.contains(interest) ? 
                                                        Color.blue : Color(.systemGray6)
                                                    )
                                                    .foregroundColor(
                                                        selectedInterests.contains(interest) ? 
                                                        .white : .primary
                                                    )
                                                    .cornerRadius(16)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 32)
                                }
                                
                                // Privacy Settings Section
                                VStack(spacing: 0) {
                                    sectionHeader("Privacy Settings")
                                    
                                    VStack(spacing: 1) {
                                        privacyRow(
                                            title: "Private Account",
                                            subtitle: "Only approved followers can see your posts",
                                            isOn: $isPrivateAccount
                                        )
                                        
                                        privacyRow(
                                            title: "Show Location",
                                            subtitle: "Allow others to see your location on pins",
                                            isOn: $showLocation
                                        )
                                        
                                        privacyRow(
                                            title: "Direct Messages",
                                            subtitle: "Allow anyone to send you messages",
                                            isOn: $allowDirectMessages
                                        )
                                        
                                        privacyRow(
                                            title: "Activity Status",
                                            subtitle: "Show when you're active on the app",
                                            isOn: $showActivityStatus
                                        )
                                    }
                                    .background(Color(.systemBackground))
                                    .cornerRadius(10)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 32)
                                }
                                
                                // Save Button
                                Button(action: saveProfile) {
                                    HStack {
                                        if isUpdating {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        }
                                        Text(isUpdating ? "Saving..." : "Save Changes")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        username.isEmpty ? Color(.systemGray4) : Color.blue
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .disabled(isUpdating || username.isEmpty)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 32)
                            }
                        }
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(successMessage)
            }
            .actionSheet(isPresented: $showPhotoActionSheet) {
                ActionSheet(
                    title: Text("Change Profile Photo"),
                    buttons: [
                        .default(Text("Take Photo")) {
                            showCamera = true
                        },
                        .default(Text("Choose from Library")) {
                            showPhotoLibrary = true
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera) { image in
                    if let image = image {
                        profileImage = Image(uiImage: image)
                        profileImageData = image.jpegData(compressionQuality: 0.8)
                    }
                }
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    if let image = image {
                        profileImage = Image(uiImage: image)
                        profileImageData = image.jpegData(compressionQuality: 0.8)
                    }
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private func formRow(title: String, text: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            
            TextField(placeholder, text: text)
                .font(.subheadline)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
                .padding(.leading, 16),
            alignment: .bottom
        )
    }
    
    private func privacyRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
                .padding(.leading, 16),
            alignment: .bottom
        )
    }
    
    // MARK: - Functions
    
    private func loadCurrentProfile() {
        guard let userID = authManager.currentUserID else {
            errorMessage = "Unable to load user profile"
            showError = true
            return
        }
        
        Task {
            if let profile = await SupabaseManager.shared.fetchUserProfile(userID: userID) {
                await MainActor.run {
                    username = profile.username
                    fullName = profile.full_name
                    bio = profile.bio ?? ""
                    
                    // Load interests if stored (for now, start empty - can be enhanced later)
                    selectedInterests = []
                    
                    // Load privacy settings (defaults for now - can be enhanced with backend storage)
                    isPrivateAccount = false
                    showLocation = true
                    allowDirectMessages = true
                    showActivityStatus = true
                    
                    // Load avatar image if available
                    if let avatarURL = profile.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                        Task {
                            do {
                                let (data, _) = try await URLSession.shared.data(from: url)
                                if let uiImage = UIImage(data: data) {
                                    await MainActor.run {
                                        profileImage = Image(uiImage: uiImage)
                                    }
                                }
                            } catch {
                                print("Failed to load avatar image: \(error)")
                            }
                        }
                    }
                    
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    errorMessage = "Failed to load profile"
                    showError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func saveProfile() {
        guard let userID = authManager.currentUserID else {
            errorMessage = "Unable to save profile"
            showError = true
            return
        }
        
        isUpdating = true
        errorMessage = ""
        
        Task {
            do {
                var avatarURL = ""
                
                // Upload new avatar if selected
                if let imageData = profileImageData {
                    isUploadingAvatar = true
                    
                    do {
                        avatarURL = try await SupabaseManager.shared.uploadProfileImage(imageData, for: userID)
                        print("✅ Avatar uploaded successfully: \(avatarURL)")
                    } catch {
                        await MainActor.run {
                            isUploadingAvatar = false
                        }
                        throw AppError.unknown("Failed to upload profile image: \(error.localizedDescription)")
                    }
                    
                    await MainActor.run {
                        isUploadingAvatar = false
                    }
                } else {
                    // Keep existing avatar URL
                    if let currentProfile = await SupabaseManager.shared.fetchUserProfile(userID: userID) {
                        avatarURL = currentProfile.avatarURL ?? ""
                    }
                }
                
                // Get current profile to preserve email
                if let currentProfile = await SupabaseManager.shared.fetchUserProfile(userID: userID) {
                    try await SupabaseManager.shared.updateUserProfile(
                        userID: userID,
                        username: username,
                        fullName: fullName,
                        email: currentProfile.email ?? "",
                        bio: bio,
                        avatarURL: avatarURL
                    )
                    
                    // TODO: Save interests and privacy settings to backend when backend support is added
                    // For now, they're stored locally in the UI state
                    
                    await MainActor.run {
                        isUpdating = false
                        successMessage = "Profile updated successfully!"
                        showSuccess = true
                    }
                } else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch current profile"])
                }
                
            } catch {
                await MainActor.run {
                    isUpdating = false
                    errorMessage = "Failed to update profile: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.onImagePicked(image)
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImagePicked(nil)
            picker.dismiss(animated: true)
        }
    }
}

struct ProfileEditView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileEditView()
            .environmentObject(AuthManager())
    }
} 