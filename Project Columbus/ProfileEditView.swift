//
//  ProfileEditView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/16/25.
//

import SwiftUI

struct ProfileEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    
    @State private var username: String = ""
    @State private var fullName: String = ""
    @State private var bio: String = ""
    @State private var isLoading = true
    @State private var isUpdating = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading Profile...")
                } else {
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
                        
                        Section {
                            Button(action: saveProfile) {
                                HStack {
                                    if isUpdating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .padding(.trailing, 8)
                                    }
                                    Text(isUpdating ? "Saving..." : "Save Changes")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .disabled(isUpdating || username.isEmpty)
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
                // Get current profile to preserve email and avatar
                if let currentProfile = await SupabaseManager.shared.fetchUserProfile(userID: userID) {
                    try await SupabaseManager.shared.updateUserProfile(
                        userID: userID,
                        username: username,
                        fullName: fullName,
                        email: currentProfile.email ?? "",
                        bio: bio,
                        avatarURL: currentProfile.avatarURL ?? ""
                    )
                    
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