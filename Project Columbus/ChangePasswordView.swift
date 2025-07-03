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
    @Environment(\.dismiss) private var dismiss
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
    
    // Password strength logic
    private var passwordStrengthScore: Int {
        var score = 0
        if newPassword.count >= 8 { score += 1 }
        if newPassword.range(of: "[A-Za-z]", options: .regularExpression) != nil { score += 1 }
        if newPassword.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if newPassword.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }
        return score
    }

    private var passwordStrengthLabel: String {
        switch passwordStrengthScore {
        case 0, 1: return "Weak"
        case 2: return "Medium"
        case 3: return "Strong"
        case 4: return "Very Strong"
        default: return ""
        }
    }

    private var passwordStrengthColor: Color {
        switch passwordStrengthScore {
        case 0, 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        default: return .gray
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Title
                Text("Change Password")
                    .font(.title2).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    .padding(.bottom, 12)
                    .multilineTextAlignment(.center)

                // Card background for inputs
                VStack(spacing: 20) {
                    // Current Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CURRENT PASSWORD")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 2)
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
                            .onSubmit { newPasswordFocused = true }
                            Button(action: { showCurrentPassword.toggle() }) {
                                Image(systemName: showCurrentPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground).opacity(0.7))
                        .cornerRadius(10)
                    }

                    // New Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NEW PASSWORD")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 2)
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
                            .onSubmit { confirmPasswordFocused = true }
                            Button(action: { showNewPassword.toggle() }) {
                                Image(systemName: showNewPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground).opacity(0.7))
                        .cornerRadius(10)

                        // Password strength bar
                        if !newPassword.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .frame(height: 8)
                                        .foregroundColor(Color(.systemGray5))
                                    Capsule()
                                        .frame(width: CGFloat(passwordStrengthScore) / 4 * 180, height: 8)
                                        .foregroundColor(passwordStrengthColor)
                                        .animation(.easeInOut(duration: 0.25), value: passwordStrengthScore)
                                }
                                .frame(width: 180, height: 8)
                                Text(passwordStrengthLabel)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(passwordStrengthColor)
                                    .padding(.leading, 2)
                            }
                            .padding(.top, 2)
                            .padding(.bottom, 2)
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
                            .onSubmit { if isFormValid { changePassword() } }
                            Button(action: { showConfirmPassword.toggle() }) {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground).opacity(0.7))
                        .cornerRadius(10)

                        // Validation feedback
                        VStack(alignment: .leading, spacing: 4) {
                            if let error = passwordTooShortError {
                                Text(error).foregroundColor(.red).font(.caption)
                            }
                            if let error = passwordMismatchError {
                                Text(error).foregroundColor(.red).font(.caption)
                            }
                            if let error = samePasswordError {
                                Text(error).foregroundColor(.red).font(.caption)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(20)
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Spacer(minLength: 0)

                // Change Password Button
                Button(action: changePassword) {
                    HStack {
                        if isUpdating {
                            ProgressView().scaleEffect(0.8).padding(.trailing, 8)
                        }
                        Text(isUpdating ? "Updating Password..." : "Change Password")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .background(isFormValid && !isUpdating ? Color.accentColor : Color(.secondarySystemFill))
                    .foregroundColor(isFormValid && !isUpdating ? .white : .gray)
                    .cornerRadius(12)
                    .shadow(color: isFormValid && !isUpdating ? Color.accentColor.opacity(0.18) : .clear, radius: 6, x: 0, y: 2)
                }
                .disabled(!isFormValid || isUpdating)
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarBackButtonHidden(false)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
                            Button("OK") { dismiss() }
        } message: {
            Text(successMessage)
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