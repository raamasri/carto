import Foundation
import CryptoKit
import Security
import CoreLocation // Added for CLLocationCoordinate2D

/// Manages end-to-end encryption for messages and local data encryption
class EncryptionManager {
    static let shared = EncryptionManager()
    
    private init() {}
    
    // MARK: - Key Management
    
    /// Generate a new encryption key pair for the user
    func generateUserKeyPair() throws -> (privateKey: P256.KeyAgreement.PrivateKey, publicKey: P256.KeyAgreement.PublicKey) {
        let privateKey = P256.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        return (privateKey, publicKey)
    }
    
    /// Store private key securely in Keychain
    func storePrivateKey(_ privateKey: P256.KeyAgreement.PrivateKey, for userID: String) throws {
        let keyData = privateKey.rawRepresentation
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "privateKey_\(userID)",
            kSecAttrService as String: "com.carto.app.encryption",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing key if it exists
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError("Failed to store private key: \(status)")
        }
    }
    
    /// Retrieve private key from Keychain
    func retrievePrivateKey(for userID: String) throws -> P256.KeyAgreement.PrivateKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "privateKey_\(userID)",
            kSecAttrService as String: "com.carto.app.encryption",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            throw EncryptionError.keychainError("Failed to retrieve private key: \(status)")
        }
        
        return try P256.KeyAgreement.PrivateKey(rawRepresentation: keyData)
    }
    
    /// Convert public key to string for storage/transmission
    func publicKeyToString(_ publicKey: P256.KeyAgreement.PublicKey) -> String {
        return publicKey.rawRepresentation.base64EncodedString()
    }
    
    /// Convert string to public key
    func stringToPublicKey(_ string: String) throws -> P256.KeyAgreement.PublicKey {
        guard let keyData = Data(base64Encoded: string) else {
            throw EncryptionError.invalidKey("Invalid base64 encoded key")
        }
        
        return try P256.KeyAgreement.PublicKey(rawRepresentation: keyData)
    }
    
    // MARK: - Message Encryption
    
    /// Encrypt a message for a specific recipient
    func encryptMessage(_ message: String, senderPrivateKey: P256.KeyAgreement.PrivateKey, recipientPublicKey: P256.KeyAgreement.PublicKey) throws -> EncryptedMessage {
        // Generate shared secret using ECDH
        let sharedSecret = try senderPrivateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)
        
        // Derive encryption key from shared secret
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("message_encryption".utf8),
            outputByteCount: 32
        )
        
        // Encrypt the message
        let messageData = Data(message.utf8)
        let sealedBox = try AES.GCM.seal(messageData, using: symmetricKey)
        
        return EncryptedMessage(
            ciphertext: sealedBox.ciphertext.base64EncodedString(),
            nonce: sealedBox.nonce.withUnsafeBytes { Data($0) }.base64EncodedString(),
            tag: sealedBox.tag.base64EncodedString()
        )
    }
    
    /// Decrypt a message from a specific sender
    func decryptMessage(_ encryptedMessage: EncryptedMessage, recipientPrivateKey: P256.KeyAgreement.PrivateKey, senderPublicKey: P256.KeyAgreement.PublicKey) throws -> String {
        // Generate shared secret using ECDH
        let sharedSecret = try recipientPrivateKey.sharedSecretFromKeyAgreement(with: senderPublicKey)
        
        // Derive encryption key from shared secret
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("message_encryption".utf8),
            outputByteCount: 32
        )
        
        // Reconstruct the sealed box
        guard let ciphertext = Data(base64Encoded: encryptedMessage.ciphertext),
              let nonce = Data(base64Encoded: encryptedMessage.nonce),
              let tag = Data(base64Encoded: encryptedMessage.tag) else {
            throw EncryptionError.invalidData("Invalid encrypted message format")
        }
        
        let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce), ciphertext: ciphertext, tag: tag)
        
        // Decrypt the message
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        guard let decryptedMessage = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed("Failed to decode decrypted message")
        }
        
        return decryptedMessage
    }
    
    // MARK: - Local Data Encryption
    
    /// Get or create device-specific encryption key
    func getDeviceEncryptionKey() throws -> SymmetricKey {
        let keyIdentifier = "device_encryption_key"
        
        // Try to retrieve existing key
        if let existingKey = try? retrieveSymmetricKey(identifier: keyIdentifier) {
            return existingKey
        }
        
        // Generate new key if none exists
        let newKey = SymmetricKey(size: .bits256)
        try storeSymmetricKey(newKey, identifier: keyIdentifier)
        return newKey
    }
    
    /// Store symmetric key in Keychain
    private func storeSymmetricKey(_ key: SymmetricKey, identifier: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.carto.app.local_encryption",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing key if it exists
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError("Failed to store symmetric key: \(status)")
        }
    }
    
    /// Retrieve symmetric key from Keychain
    private func retrieveSymmetricKey(identifier: String) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "com.carto.app.local_encryption",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            throw EncryptionError.keychainError("Failed to retrieve symmetric key: \(status)")
        }
        
        return SymmetricKey(data: keyData)
    }
    
    /// Encrypt local data (like cached user data, preferences, etc.)
    func encryptLocalData<T: Codable>(_ data: T) throws -> Data {
        let key = try getDeviceEncryptionKey()
        let jsonData = try JSONEncoder().encode(data)
        let sealedBox = try AES.GCM.seal(jsonData, using: key)
        
        // Combine nonce, ciphertext, and tag
        var encryptedData = Data()
        encryptedData.append(sealedBox.nonce.withUnsafeBytes { Data($0) })
        encryptedData.append(sealedBox.ciphertext)
        encryptedData.append(sealedBox.tag)
        
        return encryptedData
    }
    
    /// Decrypt local data
    func decryptLocalData<T: Codable>(_ encryptedData: Data, as type: T.Type) throws -> T {
        let key = try getDeviceEncryptionKey()
        
        // Extract nonce, ciphertext, and tag
        let nonceSize = 12 // AES.GCM nonce size
        let tagSize = 16   // AES.GCM tag size
        
        guard encryptedData.count > nonceSize + tagSize else {
            throw EncryptionError.invalidData("Encrypted data too short")
        }
        
        let nonce = encryptedData.prefix(nonceSize)
        let tag = encryptedData.suffix(tagSize)
        let ciphertext = encryptedData.dropFirst(nonceSize).dropLast(tagSize)
        
        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonce),
            ciphertext: ciphertext,
            tag: tag
        )
        
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return try JSONDecoder().decode(type, from: decryptedData)
    }
    
    // MARK: - Secure Hash Functions
    
    /// Generate secure hash for data integrity
    func secureHash(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Generate HMAC for message authentication
    func generateHMAC(for data: Data, key: SymmetricKey) -> String {
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(authenticationCode).base64EncodedString()
    }
    
    /// Verify HMAC
    func verifyHMAC(_ hmac: String, for data: Data, key: SymmetricKey) -> Bool {
        guard let hmacData = Data(base64Encoded: hmac) else { return false }
        return HMAC<SHA256>.isValidAuthenticationCode(hmacData, authenticating: data, using: key)
    }

    /// Encrypt location data for sharing
    func encryptLocation(
        _ coordinate: CLLocationCoordinate2D,
        senderPrivateKey: P256.KeyAgreement.PrivateKey,
        recipientPublicKey: P256.KeyAgreement.PublicKey,
        recipientId: UUID
    ) throws -> EncryptedLocation {
        // Create location data
        let locationData = LocationData(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timestamp: Date()
        )
        
        // Serialize to JSON
        let jsonData = try JSONEncoder().encode(locationData)
        
        // Generate shared secret using ECDH
        let sharedSecret = try senderPrivateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)
        
        // Derive encryption key from shared secret
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("location_encryption".utf8),
            outputByteCount: 32
        )
        
        // Encrypt the location data
        let sealedBox = try AES.GCM.seal(jsonData, using: symmetricKey)
        
        // Combine encrypted data into a single string
        let encryptedData = EncryptedLocationData(
            ciphertext: sealedBox.ciphertext.base64EncodedString(),
            nonce: sealedBox.nonce.withUnsafeBytes { Data($0) }.base64EncodedString(),
            tag: sealedBox.tag.base64EncodedString()
        )
        
        let encryptedDataString = try JSONEncoder().encode(encryptedData)
        
        return EncryptedLocation(
            id: UUID(),
            senderId: UUID(), // This should be set by the caller
            recipientId: recipientId,
            encryptedData: String(data: encryptedDataString, encoding: .utf8) ?? "",
            sharingTier: "approximate", // Use string literal instead of enum
            expiresAt: Date().addingTimeInterval(24 * 60 * 60) // 24 hours
        )
    }
}

// MARK: - Data Models for Encryption

struct EncryptedMessage: Codable {
    let ciphertext: String
    let nonce: String
    let tag: String
}

// MARK: - Location Encryption Data Models

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

struct EncryptedLocationData: Codable {
    let ciphertext: String
    let nonce: String
    let tag: String
}

struct EncryptedLocation: Codable {
    let id: UUID
    let senderId: UUID
    let recipientId: UUID
    let encryptedData: String
    let sharingTier: String // Use String instead of SharingTier to avoid circular dependency
    let expiresAt: Date
}

// MARK: - Error Types

enum EncryptionError: Error {
    case invalidKey(String)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case keychainError(String)
    case invalidData(String)
    
    var localizedDescription: String {
        switch self {
        case .invalidKey(let message):
            return "Invalid key: \(message)"
        case .encryptionFailed(let message):
            return "Encryption failed: \(message)"
        case .decryptionFailed(let message):
            return "Decryption failed: \(message)"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
} 