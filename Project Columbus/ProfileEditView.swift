//
//  ProfileEditView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/16/25.
//

import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    
    @State private var username: String = ""
    @State private var fullName: String = ""
    @State private var bio: String = ""
    @State private var selectedInterests: Set<String> = []
    @State private var profileImage: Image? = nil
    @State private var profileImageData: Data? = nil
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showImagePicker = false
    
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
                    ProgressView("Loading Profile...")
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile Image Section - Enhanced and Always Visible
                            VStack(spacing: 16) {
                                ZStack {
                                    // Background circle
                                    Circle()
                                        .fill(Color(.systemGray6))
                                        .frame(width: 120, height: 120)
                                    
                                    // Profile image or placeholder
                                    if let image = profileImage {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 80))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    // Upload progress overlay
                                    if isUploadingAvatar {
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(1.2)
                                            )
                                    }
                                    
                                    // Camera icon overlay
                                    if !isUploadingAvatar {
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Spacer()
                                                Circle()
                                                    .fill(Color.blue)
                                                    .frame(width: 32, height: 32)
                                                    .overlay(
                                                        Image(systemName: "camera.fill")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.white)
                                                    )
                                                    .offset(x: -8, y: -8)
                                            }
                                        }
                                    }
                                }
                                .onTapGesture {
                                    // Trigger photo picker when tapping the avatar
                                    // Note: PhotosPicker will be triggered by the button below
                                }
                                
                                VStack(spacing: 8) {
                                    PhotosPicker(
                                        selection: $selectedPhotoItem,
                                        matching: .images,
                                        photoLibrary: .shared()
                                    ) {
                                        HStack {
                                            Image(systemName: "photo")
                                                .font(.system(size: 16))
                                            Text("Change Profile Photo")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(20)
                                    }
                                    .disabled(isUploadingAvatar)
                                    
                                    if profileImage != nil && !isUploadingAvatar {
                                        Button(action: {
                                            profileImage = nil
                                            profileImageData = nil
                                            selectedPhotoItem = nil
                                        }) {
                                            Text("Remove Photo")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                            }
                            .padding(.top, 20)
                            .padding(.bottom, 10)
                            
                            // Form sections
                            VStack(spacing: 16) {
                                // Basic Info Section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Basic Information")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Full Name")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        TextField("Enter your full name", text: $fullName)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Username")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        TextField("Enter username", text: $username)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Bio")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                            TextEditor(text: $bio)
                                            .frame(minHeight: 80)
                                            .padding(8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                                
                                // Interests Section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Interests")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                                        ForEach(interests, id: \.self) { interest in
                                            Text(interest)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedInterests.contains(interest) ? Color.blue : Color(.systemGray5))
                                                .foregroundColor(selectedInterests.contains(interest) ? .white : .primary)
                                                .cornerRadius(16)
                                                .onTapGesture {
                                                    if selectedInterests.contains(interest) {
                                                        selectedInterests.remove(interest)
                                                    } else {
                                                        selectedInterests.insert(interest)
                                                    }
                                                }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                                
                                // Privacy Settings Section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Privacy Settings")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    VStack(spacing: 12) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("Private Account")
                                                    .font(.subheadline)
                                                Text("Only approved followers can see your posts")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Toggle("", isOn: $isPrivateAccount)
                                        }
                                        
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("Show Location")
                                                    .font(.subheadline)
                                                Text("Allow others to see your location on pins")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Toggle("", isOn: $showLocation)
                                        }
                                        
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("Direct Messages")
                                                    .font(.subheadline)
                                                Text("Allow anyone to send you messages")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Toggle("", isOn: $allowDirectMessages)
                                        }
                                        
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("Activity Status")
                                                    .font(.subheadline)
                                                Text("Show when you're active on the app")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            Toggle("", isOn: $showActivityStatus)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                                
                                // Save Button
                            Button(action: saveProfile) {
                                HStack {
                                    if isUpdating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .padding(.trailing, 8)
                                    }
                                    Text(isUpdating ? "Saving..." : "Save Changes")
                                            .fontWeight(.semibold)
                                    }
                                        .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(username.isEmpty ? Color.gray : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(isUpdating || username.isEmpty)
                                .padding(.bottom, 20)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text(successMessage)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadSelectedPhoto(newItem)
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
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
    
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.profileImageData = data
                    if let uiImage = UIImage(data: data) {
                        self.profileImage = Image(uiImage: uiImage)
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load selected image: \(error.localizedDescription)"
                self.showError = true
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

struct ProfileEditView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileEditView()
            .environmentObject(AuthManager())
    }
} 