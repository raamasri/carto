//
//  TestValidationView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import SwiftUI

struct TestValidationView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isFormValid = false
    
    // TODO: Re-enable when ValidationManager infrastructure is fully integrated
    // @StateObject private var emailValidator = FieldValidator(rules: [
    //     RequiredRule(fieldName: "Email"),
    //     EmailRule()
    // ], validateOnChange: true)
    // 
    // @StateObject private var passwordValidator = FieldValidator(rules: [
    //     RequiredRule(fieldName: "Password"),
    //     PasswordRule(minLength: 8)
    // ])
    // 
    // @StateObject private var formValidator: FormValidator
    // @EnvironmentObject var errorManager: ErrorManager
    // @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Infrastructure Demo")
                    .font(.title)
                    .padding()
                
                Text("New validation and error handling infrastructure is ready!")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Basic Form Demo:")
                        .font(.headline)
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.newPassword)
                    
                    HStack {
                        Text("Form Valid:")
                        Spacer()
                        Image(systemName: isFormValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isFormValid ? .green : .red)
                    }
                    
                    Button("Submit") {
                        // Basic validation
                        isFormValid = !email.isEmpty && !password.isEmpty && email.contains("@")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Text("TODO: Integrate ValidationManager, ErrorManager, and DataManager when infrastructure is fully connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Infrastructure Test")
        }
        .onChange(of: email) { _, _ in
            isFormValid = !email.isEmpty && !password.isEmpty && email.contains("@")
        }
        .onChange(of: password) { _, _ in
            isFormValid = !email.isEmpty && !password.isEmpty && email.contains("@")
        }
    }
} 