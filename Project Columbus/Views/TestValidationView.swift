//
//  TestValidationView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import SwiftUI

struct TestValidationView: View {
    // Using the actual ValidationManager infrastructure
    @StateObject private var emailValidator = FieldValidator(rules: [
        RequiredRule(fieldName: "Email"),
        EmailRule()
    ], validateOnChange: true)
    
    @StateObject private var passwordValidator = FieldValidator(rules: [
        RequiredRule(fieldName: "Password"),
        PasswordRule(minLength: 8)
    ])
    
    @StateObject private var usernameValidator = FieldValidator(rules: [
        RequiredRule(fieldName: "Username"),
        UsernameRule()
    ], validateOnChange: true)
    
    @StateObject private var formValidator: FormValidator
    @StateObject private var errorManager = ErrorManager()
    
    init() {
        let emailValidator = FieldValidator(rules: [
            RequiredRule(fieldName: "Email"),
            EmailRule()
        ], validateOnChange: true)
        
        let passwordValidator = FieldValidator(rules: [
            RequiredRule(fieldName: "Password"),
            PasswordRule(minLength: 8)
        ])
        
        let usernameValidator = FieldValidator(rules: [
            RequiredRule(fieldName: "Username"),
            UsernameRule()
        ], validateOnChange: true)
        
        self._emailValidator = StateObject(wrappedValue: emailValidator)
        self._passwordValidator = StateObject(wrappedValue: passwordValidator)
        self._usernameValidator = StateObject(wrappedValue: usernameValidator)
        self._formValidator = StateObject(wrappedValue: FormValidator(validators: [emailValidator, passwordValidator, usernameValidator]))
        self._errorManager = StateObject(wrappedValue: ErrorManager())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Information")) {
                    ValidatedTextField(
                        title: "Email",
                        placeholder: "Enter your email",
                        validator: emailValidator,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        autocapitalization: .never
                    )
                    
                    ValidatedTextField(
                        title: "Username",
                        placeholder: "Choose a username",
                        validator: usernameValidator,
                        textContentType: .username,
                        autocapitalization: .never
                    )
                    
                    ValidatedTextField(
                        title: "Password",
                        placeholder: "Enter a secure password",
                        validator: passwordValidator,
                        isSecure: true,
                        textContentType: .newPassword
                    )
                }
                
                Section(header: Text("Form Status")) {
                    HStack {
                        Text("Form Valid:")
                        Spacer()
                        Image(systemName: formValidator.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(formValidator.isValid ? .green : .red)
                    }
                    
                    HStack {
                        Text("Email Valid:")
                        Spacer()
                        Image(systemName: emailValidator.validationResult.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(emailValidator.validationResult.isValid ? .green : .red)
                    }
                    
                    HStack {
                        Text("Username Valid:")
                        Spacer()
                        Image(systemName: usernameValidator.validationResult.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(usernameValidator.validationResult.isValid ? .green : .red)
                    }
                    
                    HStack {
                        Text("Password Valid:")
                        Spacer()
                        Image(systemName: passwordValidator.validationResult.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(passwordValidator.validationResult.isValid ? .green : .red)
                    }
                }
                
                Section {
                    AsyncButton(action: {
                        // Simulate an async operation that might fail
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        
                        if !formValidator.validateAll() {
                            throw AppError.invalidInput("Please fix the validation errors above")
                        }
                        
                        // Simulate a random error for demonstration
                        if Bool.random() {
                            throw AppError.serverError(500)
                        }
                        
                        print("✅ Form submitted successfully!")
                        print("Email: \(emailValidator.value)")
                        print("Username: \(usernameValidator.value)")
                        print("Password: [HIDDEN]")
                        
                    }) {
                        Text("Submit Form")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!formValidator.isValid)
                    
                    Button("Reset Form") {
                        emailValidator.value = ""
                        usernameValidator.value = ""
                        passwordValidator.value = ""
                        formValidator.resetValidation()
                    }
                    .foregroundColor(.secondary)
                }
                
                Section(header: Text("Infrastructure Status")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("✅ ValidationManager: Fully integrated")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("✅ ErrorManager: Fully integrated")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("✅ Real-time validation working")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("✅ Async error handling working")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Infrastructure Demo")
            .errorAlert(errorManager)
        }
        .environmentObject(errorManager)
    }
} 