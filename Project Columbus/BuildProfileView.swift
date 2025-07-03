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

    // Enhanced validation using ValidationManager infrastructure
    @StateObject private var usernameValidator = FieldValidator(rules: [
        RequiredRule(fieldName: "Username"),
        UsernameRule()
    ], validateOnChange: true)
    
    @StateObject private var bioValidator = FieldValidator(rules: [
        MaxLengthRule(maxLength: 150, fieldName: "Bio")
    ])
    
    @StateObject private var errorManager = ErrorManager()
    
    @State private var bio: String = ""
    @State private var selectedInterests: Set<String> = []
    @State private var profileImage: Image? = nil
    @State private var showImagePicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var profileImageData: Data? = nil
    
    // UI states
    @State private var isValidatingUsername = false
    @State private var isUsernameAvailable: Bool? = nil
    @State private var isSaving = false
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

                    // Username field with enhanced validation
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Username", text: $usernameValidator.value)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .onChange(of: usernameValidator.value) { _, newValue in
                                        validateUsernameAvailability(newValue)
                                    }
                                
                                // Show validation errors from ValidationManager
                                if let errorMessage = usernameValidator.errorMessage, usernameValidator.hasBeenValidated {
                                    Text(errorMessage)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
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
                        
                        // Show availability status
                        if let isAvailable = isUsernameAvailable, usernameValidator.validationResult.isValid {
                            Text(isAvailable ? "Username is available" : "Username is taken")
                                .foregroundColor(isAvailable ? .green : .red)
                                .font(.caption)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Bio (optional)", text: $bioValidator.value)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(8)
                            .onChange(of: bioValidator.value) { _, _ in
                                bioValidator.validate()
                            }
                        
                        if let errorMessage = bioValidator.errorMessage, bioValidator.hasBeenValidated {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

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

                    AsyncButton(action: {
                        try await saveProfile()
                    }) {
                        Text("Finish")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .disabled(!isValidInput)
                    .background(isValidInput ? Color.white : Color.gray)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadSelectedPhoto(newItem)
            }
        }
        .errorAlert(errorManager)
        .environmentObject(errorManager)
    }
    
    // MARK: - Computed Properties
    
    private var isValidInput: Bool {
        usernameValidator.validationResult.isValid &&
        bioValidator.validationResult.isValid &&
        isUsernameAvailable == true
    }
    
    // MARK: - Username Validation
    
    private func validateUsernameAvailability(_ newUsername: String) {
        let trimmed = newUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Reset availability state
        isUsernameAvailable = nil
        
        // Only check availability if basic validation passes
        guard usernameValidator.validationResult.isValid && !trimmed.isEmpty else { 
            return 
        }
        
        // Check availability with Supabase
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
                self.errorManager.handle(AppError.unknown("Failed to load selected image: \(error.localizedDescription)"))
            }
        }
    }
    
    // MARK: - Profile Save
    
    private func saveProfile() async throws {
        guard let session = try? await SupabaseManager.shared.client.auth.session else {
            throw AppError.sessionExpired
        }
        
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
                await MainActor.run {
                    self.isUploadingAvatar = false
                }
                throw AppError.unknown("Failed to upload profile image: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                self.isUploadingAvatar = false
            }
        }
        
        // Save profile to database
        try await SupabaseManager.shared.updateUserProfile(
            userID: session.user.id.uuidString,
            username: usernameValidator.value.trimmingCharacters(in: .whitespacesAndNewlines),
            fullName: (session.user.userMetadata["full_name"]?.stringValue) ?? "",
            email: session.user.email ?? "",
            bio: bioValidator.value.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarURL: avatarURL
        )
        
        print("✅ Profile saved successfully")
        
        await MainActor.run {
            // Mark as logged in and dismiss
            self.authManager.isLoggedIn = true
        }
    }
}

#Preview {
    BuildProfileView()
        .environmentObject(AuthManager())
}
