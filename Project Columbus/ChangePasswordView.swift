//
//  ChangePasswordView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/16/25.
//

import SwiftUI
import Combine
import Supabase

struct ChangePasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    @State private var showCurrentPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    
    @State private var isUpdating = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showError = false
    @State private var showSuccess = false
    
    @FocusState private var currentPasswordFocused: Bool
    @FocusState private var newPasswordFocused: Bool
    @FocusState private var confirmPasswordFocused: Bool
    
    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8 &&
        newPassword != currentPassword
    }
    
    private var passwordMismatchError: String? {
        if !confirmPassword.isEmpty && newPassword != confirmPassword {
            return "Passwords don't match"
        }
        return nil
    }
    
    private var passwordTooShortError: String? {
        if !newPassword.isEmpty && newPassword.count < 8 {
            return "Password must be at least 8 characters"
        }
        return nil
    }
    
    private var samePasswordError: String? {
        if !newPassword.isEmpty && !currentPassword.isEmpty && newPassword == currentPassword {
            return "New password must be different from current password"
        }
        return nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Current Password")) {
                    HStack {
                        Group {
                            if showCurrentPassword {
                                TextField("Current Password", text: $currentPassword)
                            } else {
                                SecureField("Current Password", text: $currentPassword)
                            }
                        }
                        .focused($currentPasswordFocused)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        .onSubmit {
                            newPasswordFocused = true
                        }
                        
                        Button(action: {
                            showCurrentPassword.toggle()
                        }) {
                            Image(systemName: showCurrentPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("New Password"), footer: passwordValidationFooter) {
                    HStack {
                        Group {
                            if showNewPassword {
                                TextField("New Password", text: $newPassword)
                            } else {
                                SecureField("New Password", text: $newPassword)
                            }
                        }
                        .focused($newPasswordFocused)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        .onSubmit {
                            confirmPasswordFocused = true
                        }
                        
                        Button(action: {
                            showNewPassword.toggle()
                        }) {
                            Image(systemName: showNewPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Group {
                            if showConfirmPassword {
                                TextField("Confirm New Password", text: $confirmPassword)
                            } else {
                                SecureField("Confirm New Password", text: $confirmPassword)
                            }
                        }
                        .focused($confirmPasswordFocused)
                        .textContentType(.newPassword)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit {
                            if isFormValid {
                                changePassword()
                            }
                        }
                        
                        Button(action: {
                            showConfirmPassword.toggle()
                        }) {
                            Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section {
                    Button(action: changePassword) {
                        HStack {
                            if isUpdating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 8)
                            }
                            Text(isUpdating ? "Updating Password..." : "Change Password")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isUpdating)
                }
            }
            .navigationTitle("Change Password")
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
    }
    
    private var passwordValidationFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let error = passwordTooShortError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            if let error = passwordMismatchError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            if let error = samePasswordError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            if !newPassword.isEmpty && passwordTooShortError == nil && passwordMismatchError == nil && samePasswordError == nil {
                Text("Password meets requirements ✓")
                    .foregroundColor(.green)
                    .font(.caption)
            }
        }
    }
    
    private func changePassword() {
        guard isFormValid else { return }
        
        isUpdating = true
        errorMessage = ""
        
        Task {
            do {
                // First verify the current password by attempting to sign in
                guard let email = authManager.currentUser?.email else {
                    throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unable to get current user email"])
                }
                
                // Verify current password
                try await SupabaseManager.shared.client.auth.signIn(email: email, password: currentPassword)
                
                // Update to new password
                try await SupabaseManager.shared.client.auth.update(
                    user: .init(password: newPassword)
                )
                
                // Update the stored password for biometric auth
                authManager.lastUsedPassword = newPassword
                if UserDefaults.standard.bool(forKey: "biometricEnabled") {
                    authManager.saveCredentialsToKeychain(
                        username: authManager.currentUsername ?? "",
                        password: newPassword
                    )
                }
                
                await MainActor.run {
                    isUpdating = false
                    successMessage = "Password changed successfully!"
                    showSuccess = true
                }
                
            } catch {
                await MainActor.run {
                    isUpdating = false
                    if error.localizedDescription.lowercased().contains("invalid") || 
                       error.localizedDescription.lowercased().contains("credentials") {
                        errorMessage = "Current password is incorrect"
                    } else {
                        errorMessage = "Failed to change password: \(error.localizedDescription)"
                    }
                    showError = true
                }
            }
        }
    }
}

struct ChangePasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ChangePasswordView()
            .environmentObject(AuthManager())
    }
} 