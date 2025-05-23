//
//  ValidationManager.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import Foundation
import SwiftUI
import UIKit
import Combine

// MARK: - Validation Result
enum ValidationResult: Equatable {
    case valid
    case invalid(String)
    
    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message):
            return message
        }
    }
}

// MARK: - Validation Rules
protocol ValidationRule {
    func validate(_ value: String) -> ValidationResult
}

// Basic validation rules
struct RequiredRule: ValidationRule {
    let fieldName: String
    
    func validate(_ value: String) -> ValidationResult {
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .invalid("\(fieldName) is required")
            : .valid
    }
}

struct EmailRule: ValidationRule {
    func validate(_ value: String) -> ValidationResult {
        let emailPattern = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailPattern)
        
        return emailPredicate.evaluate(with: value)
            ? .valid
            : .invalid("Please enter a valid email address")
    }
}

struct PasswordRule: ValidationRule {
    let minLength: Int
    let requireSpecialChars: Bool
    
    init(minLength: Int = 8, requireSpecialChars: Bool = false) {
        self.minLength = minLength
        self.requireSpecialChars = requireSpecialChars
    }
    
    func validate(_ value: String) -> ValidationResult {
        if value.count < minLength {
            return .invalid("Password must be at least \(minLength) characters long")
        }
        
        if requireSpecialChars {
            let specialCharPattern = #".*[!@#$%^&*(),.?":{}|<>].*"#
            let specialCharPredicate = NSPredicate(format: "SELF MATCHES %@", specialCharPattern)
            
            if !specialCharPredicate.evaluate(with: value) {
                return .invalid("Password must contain at least one special character")
            }
        }
        
        return .valid
    }
}

struct UsernameRule: ValidationRule {
    func validate(_ value: String) -> ValidationResult {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check length
        if trimmed.count < 3 {
            return .invalid("Username must be at least 3 characters long")
        }
        
        if trimmed.count > 20 {
            return .invalid("Username must be no more than 20 characters long")
        }
        
        // Check pattern (alphanumeric and underscores only)
        let usernamePattern = #"^[a-zA-Z0-9_]+$"#
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernamePattern)
        
        if !usernamePredicate.evaluate(with: trimmed) {
            return .invalid("Username can only contain letters, numbers, and underscores")
        }
        
        return .valid
    }
}

struct PhoneRule: ValidationRule {
    func validate(_ value: String) -> ValidationResult {
        // Remove all non-digit characters
        let digitsOnly = value.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        // Check if it's a valid length (10 digits for US numbers)
        if digitsOnly.count >= 10 && digitsOnly.count <= 15 {
            return .valid
        } else {
            return .invalid("Please enter a valid phone number")
        }
    }
}

struct MinLengthRule: ValidationRule {
    let minLength: Int
    let fieldName: String
    
    func validate(_ value: String) -> ValidationResult {
        return value.trimmingCharacters(in: .whitespacesAndNewlines).count >= minLength
            ? .valid
            : .invalid("\(fieldName) must be at least \(minLength) characters long")
    }
}

struct MaxLengthRule: ValidationRule {
    let maxLength: Int
    let fieldName: String
    
    func validate(_ value: String) -> ValidationResult {
        return value.count <= maxLength
            ? .valid
            : .invalid("\(fieldName) must be no more than \(maxLength) characters long")
    }
}

// MARK: - Field Validator
class FieldValidator: ObservableObject {
    @Published var value: String = ""
    @Published var validationResult: ValidationResult = .valid
    @Published var hasBeenValidated: Bool = false
    
    private let rules: [ValidationRule]
    private let validateOnChange: Bool
    
    init(rules: [ValidationRule], validateOnChange: Bool = false) {
        self.rules = rules
        self.validateOnChange = validateOnChange
        
        if validateOnChange {
            setupValidationOnChange()
        }
    }
    
    private func setupValidationOnChange() {
        $value
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                if self?.hasBeenValidated == true {
                    self?.validate()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    @discardableResult
    func validate() -> ValidationResult {
        hasBeenValidated = true
        
        for rule in rules {
            let result = rule.validate(value)
            if !result.isValid {
                validationResult = result
                return result
            }
        }
        
        validationResult = .valid
        return .valid
    }
    
    var isValid: Bool {
        validate().isValid
    }
    
    var errorMessage: String? {
        validationResult.errorMessage
    }
}

// MARK: - Form Validator
class FormValidator: ObservableObject {
    @Published var isValid: Bool = false
    
    private let validators: [FieldValidator]
    
    init(validators: [FieldValidator]) {
        self.validators = validators
        setupValidation()
    }
    
    private func setupValidation() {
        // Subscribe to each validator's result and update form validity
        for validator in validators {
            validator.$validationResult
                .sink { [weak self] _ in
                    self?.updateFormValidity()
                }
                .store(in: &cancellables)
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func updateFormValidity() {
        isValid = validators.allSatisfy { $0.validationResult.isValid }
    }
    
    func validateAll() -> Bool {
        let results = validators.map { $0.validate() }
        return results.allSatisfy { $0.isValid }
    }
    
    func resetValidation() {
        validators.forEach { validator in
            validator.hasBeenValidated = false
            validator.validationResult = .valid
        }
    }
}

// MARK: - Validated Text Field
struct ValidatedTextField: View {
    let title: String
    let placeholder: String
    @ObservedObject var validator: FieldValidator
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var autocapitalization: TextInputAutocapitalization = .sentences
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if isSecure {
                SecureField(placeholder, text: $validator.value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .onSubmit {
                        validator.validate()
                    }
            } else {
                TextField(placeholder, text: $validator.value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .onSubmit {
                        validator.validate()
                    }
            }
            
            if let errorMessage = validator.errorMessage, validator.hasBeenValidated {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validator.validationResult)
    }
}

// MARK: - Validation Extensions
extension String {
    var isValidEmail: Bool {
        EmailRule().validate(self).isValid
    }
    
    var isValidUsername: Bool {
        UsernameRule().validate(self).isValid
    }
    
    var isValidPhone: Bool {
        PhoneRule().validate(self).isValid
    }
    
    func isValidPassword(minLength: Int = 8) -> Bool {
        PasswordRule(minLength: minLength).validate(self).isValid
    }
}

