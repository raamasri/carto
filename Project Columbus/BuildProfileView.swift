//
//  BuildProfileView.swift
//  Project Columbus
//
//  Created by Joe Schacter on 3/17/25.
//

import SwiftUI
import PhotosUI

struct BuildProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode

    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var selectedInterests: Set<String> = []
    @State private var profileImage: Image? = nil
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var profileImageData: Data? = nil
    
    // Validation and UI states
    @State private var isValidatingUsername = false
    @State private var isUsernameAvailable: Bool? = nil
    @State private var usernameError: String? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil
    @State private var isUploadingAvatar = false

    let interests = ["Food", "Travel", "Nature", "Art", "Sports", "History"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text("Build Your Profile")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    // Profile Image Picker with PhotosPicker
                    VStack {
                        ZStack {
                            if let image = profileImage {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Image(systemName: "camera")
                                            .font(.title)
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            if isUploadingAvatar {
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
                        }
                        
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Choose Photo")
                                .foregroundColor(.blue)
                                .padding(.top, 8)
                        }
                    }

                    // Username field with validation
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            TextField("Username", text: $username)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                                .onChange(of: username) { _, newValue in
                                    validateUsername(newValue)
                                }
                            
                            if isValidatingUsername {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            } else if let isAvailable = isUsernameAvailable {
                                Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isAvailable ? .green : .red)
                            }
                        }
                        
                        if let error = usernameError {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        } else if let isAvailable = isUsernameAvailable {
                            Text(isAvailable ? "Username is available" : "Username is taken")
                                .foregroundColor(isAvailable ? .green : .red)
                                .font(.caption)
                        }
                    }

                    TextField("Bio (optional)", text: $bio)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)

                    Text("Select Your Interests")
                        .foregroundColor(.white)
                        .font(.headline)

                    // Interests Selection
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                        ForEach(interests, id: \.self) { interest in
                            Text(interest)
                                .padding(8)
                                .background(selectedInterests.contains(interest) ? Color.blue : Color.white)
                                .foregroundColor(selectedInterests.contains(interest) ? .white : .black)
                                .cornerRadius(8)
                                .onTapGesture {
                                    if selectedInterests.contains(interest) {
                                        selectedInterests.remove(interest)
                                    } else {
                                        selectedInterests.insert(interest)
                                    }
                                }
                        }
                    }

                    // Error message
                    if let error = saveError {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button("Finish") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isSaving || !isValidInput)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isValidInput && !isSaving ? Color.white : Color.gray)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .overlay(
                        Group {
                            if isSaving {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                        .scaleEffect(0.7)
                                    Text("Saving...")
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    )
                }
                .padding()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadSelectedPhoto(newItem)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isValidInput: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isUsernameAvailable == true &&
        usernameError == nil
    }
    
    // MARK: - Username Validation
    
    private func validateUsername(_ newUsername: String) {
        let trimmed = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Reset states
        usernameError = nil
        isUsernameAvailable = nil
        
        // Basic validation
        guard !trimmed.isEmpty else { return }
        
        // Check length
        guard trimmed.count >= 3 else {
            usernameError = "Username must be at least 3 characters"
            return
        }
        
        guard trimmed.count <= 20 else {
            usernameError = "Username must be 20 characters or less"
            return
        }
        
        // Check format (alphanumeric and underscores only)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            usernameError = "Username can only contain letters, numbers, and underscores"
            return
        }
        
        // Check availability
        checkUsernameAvailability(trimmed)
    }
    
    private func checkUsernameAvailability(_ username: String) {
        isValidatingUsername = true
        
        Task {
            do {
                let isAvailable = await SupabaseManager.shared.isUsernameAvailable(username: username)
                
                await MainActor.run {
                    self.isValidatingUsername = false
                    self.isUsernameAvailable = isAvailable
                }
            }
        }
    }
    
    // MARK: - Photo Loading
    
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
                self.saveError = "Failed to load selected image: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Profile Save
    
    private func saveProfile() async {
        guard let session = try? await SupabaseManager.shared.client.auth.session else {
            await MainActor.run {
                self.saveError = "Authentication error. Please try logging in again."
            }
            return
        }
        
        await MainActor.run {
            self.isSaving = true
            self.saveError = nil
        }
        
        do {
            var avatarURL = ""
            
            // Upload avatar if selected
            if let imageData = profileImageData {
                await MainActor.run {
                    self.isUploadingAvatar = true
                }
                
                do {
                    avatarURL = try await SupabaseManager.shared.uploadProfileImage(imageData, for: session.user.id.uuidString)
                    print("✅ Avatar uploaded successfully: \(avatarURL)")
                } catch {
                    print("❌ Avatar upload failed: \(error)")
                    await MainActor.run {
                        self.saveError = "Failed to upload profile image: \(error.localizedDescription)"
                        self.isUploadingAvatar = false
                        self.isSaving = false
                    }
                    return
                }
                
                await MainActor.run {
                    self.isUploadingAvatar = false
                }
            }
            
            // Save profile to database
            try await SupabaseManager.shared.updateUserProfile(
                userID: session.user.id.uuidString,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                fullName: session.user.userMetadata["full_name"] as? String ?? "",
                email: session.user.email ?? "",
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarURL: avatarURL
            )
            
            print("✅ Profile saved successfully")
            
            await MainActor.run {
                self.isSaving = false
                // Mark as logged in and dismiss
                self.authManager.isLoggedIn = true
            }
            
        } catch {
            print("❌ Profile save failed: \(error)")
            await MainActor.run {
                self.isSaving = false
                self.saveError = "Failed to save profile: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    BuildProfileView()
        .environmentObject(AuthManager())
}
