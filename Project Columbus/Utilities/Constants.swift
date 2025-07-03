//
//  Constants.swift
//  Project Columbus
//
//  Created by Assistant
//

import Foundation

// MARK: - App Constants
struct AppConstants {
    
    // MARK: - UI Constants
    struct UI {
        static let smallSpacing: CGFloat = 8
        static let mediumSpacing: CGFloat = 16
        static let largeSpacing: CGFloat = 24
        static let extraLargeSpacing: CGFloat = 32
        
        static let smallCornerRadius: CGFloat = 8
        static let mediumCornerRadius: CGFloat = 12
        static let largeCornerRadius: CGFloat = 16
        static let extraLargeCornerRadius: CGFloat = 20
        
        static let defaultAnimationDuration: Double = 0.3
        static let fastAnimationDuration: Double = 0.2
        static let slowAnimationDuration: Double = 0.5
    }
    
    // MARK: - Pagination Constants
    struct Pagination {
        static let defaultPageSize: Int = 20
        static let maxPageSize: Int = 100
        static let initialPage: Int = 0
    }
    
    // MARK: - Cache Constants
    struct Cache {
        static let imageCacheSize: Int = 50 * 1024 * 1024 // 50MB
        static let diskCacheSize: Int = 200 * 1024 * 1024 // 200MB
        static let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
        static let compressionQuality: CGFloat = 0.8
    }
    
    // MARK: - Network Constants
    struct Network {
        static let defaultTimeout: TimeInterval = 30.0
        static let maxRetries: Int = 3
        static let retryDelay: TimeInterval = 1.0
        static let syncInterval: TimeInterval = 30.0
    }
    
    // MARK: - Location Constants
    struct Location {
        static let defaultLocationAccuracy: Double = 100.0
        static let nearbyRadius: Double = 1000.0 // 1km
        static let maxLocationAge: TimeInterval = 300.0 // 5 minutes
        static let coordinateThreshold: Double = 0.0001 // For duplicate detection
    }
    
    // MARK: - Search Constants
    struct Search {
        static let maxResults: Int = 20
        static let minSearchLength: Int = 2
        static let searchDebounceDelay: TimeInterval = 0.5
    }
    
    // MARK: - Validation Constants
    struct Validation {
        static let minUsernameLength: Int = 3
        static let maxUsernameLength: Int = 20
        static let minPasswordLength: Int = 8
        static let maxBioLength: Int = 200
        static let maxPinNameLength: Int = 100
    }
    
    // MARK: - Notification Constants
    struct Notifications {
        static let pollingInterval: TimeInterval = 3.0
        static let conversationPollingInterval: TimeInterval = 10.0
        static let backgroundRefreshInterval: TimeInterval = 60.0
    }
    
    // MARK: - String Constants
    struct Strings {
        static let defaultErrorMessage = "An unexpected error occurred."
        static let networkErrorMessage = "Please check your internet connection."
        static let authErrorMessage = "Authentication failed. Please try again."
        static let locationErrorMessage = "Location access is required for this feature."
    }
    
    // MARK: - Keychain Constants
    struct Keychain {
        static let credentialsKey = "carto.credentials"
        static let biometricKey = "carto.biometric"
        static let encryptionKey = "carto.encryption"
    }
    
    // MARK: - Storage Constants
    struct Storage {
        static let profileImagesBucket = "profile-images"
        static let pinImagesBucket = "pin-images"
        static let videoContentBucket = "video-content"
        static let maxImageSize: Int = 5 * 1024 * 1024 // 5MB
        static let maxVideoSize: Int = 50 * 1024 * 1024 // 50MB
    }
} 