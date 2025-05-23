//
//  ErrorHandling.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import Foundation
import SwiftUI

// MARK: - App-wide Error Types
enum AppError: LocalizedError, Equatable {
    // Authentication Errors
    case authenticationFailed
    case invalidCredentials
    case accountNotFound
    case accountAlreadyExists
    case biometricAuthUnavailable
    case sessionExpired
    
    // Network Errors
    case networkUnavailable
    case serverError(Int)
    case timeoutError
    case invalidResponse
    
    // Validation Errors
    case invalidEmail
    case weakPassword
    case usernameUnavailable
    case missingRequiredField(String)
    case invalidInput(String)
    
    // Location Errors
    case locationPermissionDenied
    case locationUnavailable
    case geocodingFailed
    
    // Data Errors
    case dataCorrupted
    case syncFailed
    case cacheMiss
    
    // Unknown
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        // Authentication
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .invalidCredentials:
            return "Invalid email or password."
        case .accountNotFound:
            return "Account not found. Please check your credentials."
        case .accountAlreadyExists:
            return "An account with this email already exists."
        case .biometricAuthUnavailable:
            return "Biometric authentication is not available on this device."
        case .sessionExpired:
            return "Your session has expired. Please log in again."
            
        // Network
        case .networkUnavailable:
            return "No internet connection. Please check your network."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .timeoutError:
            return "Request timed out. Please try again."
        case .invalidResponse:
            return "Invalid server response. Please try again."
            
        // Validation
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 8 characters long."
        case .usernameUnavailable:
            return "This username is already taken."
        case .missingRequiredField(let field):
            return "\(field) is required."
        case .invalidInput(let message):
            return message
            
        // Location
        case .locationPermissionDenied:
            return "Location access is required for this feature."
        case .locationUnavailable:
            return "Unable to determine your location."
        case .geocodingFailed:
            return "Unable to find location information."
            
        // Data
        case .dataCorrupted:
            return "Data appears to be corrupted. Please refresh."
        case .syncFailed:
            return "Failed to sync data. Check your connection."
        case .cacheMiss:
            return "Data not available offline."
            
        // Unknown
        case .unknown(let message):
            return message.isEmpty ? "An unexpected error occurred." : message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .sessionExpired:
            return "Please log in again to continue."
        case .locationPermissionDenied:
            return "Enable location access in Settings > Privacy & Security > Location Services."
        case .syncFailed:
            return "Pull down to refresh or check your connection."
        default:
            return nil
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .serverError, .timeoutError, .syncFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Error Manager
@MainActor
class ErrorManager: ObservableObject {
    @Published var currentError: AppError?
    @Published var showError: Bool = false
    
    func handle(_ error: Error) {
        let appError = mapToAppError(error)
        currentError = appError
        showError = true
    }
    
    func handle(_ appError: AppError) {
        currentError = appError
        showError = true
    }
    
    func dismissError() {
        currentError = nil
        showError = false
    }
    
    private func mapToAppError(_ error: Error) -> AppError {
        // Map system errors to app errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .timeoutError
            default:
                return .unknown(urlError.localizedDescription)
            }
        }
        
        // Map other known error types
        let description = error.localizedDescription.lowercased()
        if description.contains("invalid login credentials") || description.contains("invalid email or password") {
            return .invalidCredentials
        } else if description.contains("user already registered") {
            return .accountAlreadyExists
        } else if description.contains("user not found") {
            return .accountNotFound
        }
        
        return .unknown(error.localizedDescription)
    }
}

// MARK: - Result Extensions
extension Result {
    func mapError<E: Error>(_ transform: (Failure) -> E) -> Result<Success, E> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(transform(error))
        }
    }
}

// MARK: - Error Alert View Modifier
struct ErrorAlert: ViewModifier {
    @ObservedObject var errorManager: ErrorManager
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorManager.showError, presenting: errorManager.currentError) { error in
                Button("OK") {
                    errorManager.dismissError()
                }
                
                if error.isRetryable {
                    Button("Retry") {
                        // Emit retry notification that can be handled by the view
                        NotificationCenter.default.post(name: .retryLastAction, object: nil)
                        errorManager.dismissError()
                    }
                }
            } message: { error in
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.errorDescription ?? "An unknown error occurred")
                    
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
    }
}

extension View {
    func errorAlert(_ errorManager: ErrorManager) -> some View {
        modifier(ErrorAlert(errorManager: errorManager))
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let retryLastAction = Notification.Name("retryLastAction")
}

// MARK: - Loading State Manager
@MainActor
class LoadingManager: ObservableObject {
    @Published private var loadingStates: [String: Bool] = [:]
    
    var isLoading: Bool {
        loadingStates.values.contains(true)
    }
    
    func setLoading(_ key: String, _ loading: Bool) {
        loadingStates[key] = loading
    }
    
    func isLoading(_ key: String) -> Bool {
        loadingStates[key] ?? false
    }
    
    func clearAll() {
        loadingStates.removeAll()
    }
}

// MARK: - Async Button for Error Handling
struct AsyncButton<Label: View>: View {
    let action: () async throws -> Void
    let label: () -> Label
    
    @State private var isLoading = false
    @EnvironmentObject private var errorManager: ErrorManager
    
    init(action: @escaping () async throws -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button {
            Task {
                isLoading = true
                do {
                    try await action()
                } catch {
                    errorManager.handle(error)
                }
                isLoading = false
            }
        } label: {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    label()
                }
            }
        }
        .disabled(isLoading)
    }
} 