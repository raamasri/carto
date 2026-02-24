//
//  StorageService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation

class StorageService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Delete an image from storage
    func deleteImage(from bucket: String, path: String) async throws {
        _ = try await client.storage
            .from(bucket)
            .remove(paths: [path])
    }
    
    /// Upload an image to Supabase Storage
    func uploadImage(_ imageData: Data, to bucket: String, path: String) async throws -> String {
        try await client.storage
            .from(bucket)
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        // Get the public URL for the uploaded image
        return try client.storage
            .from(bucket)
            .getPublicURL(path: path)
            .absoluteString
    }
    
    /// Upload profile image
    func uploadProfileImage(_ imageData: Data, for userID: String) async throws -> String {
        let fileName = "\(userID)_\(Date().timeIntervalSince1970).jpg"
        let path = "profile-images/\(fileName)"
        
        return try await uploadImage(imageData, to: "profile-images", path: path)
    }
    
    /// Upload pin media image
    func uploadPinImage(_ imageData: Data, for pinID: String) async throws -> String {
        let fileName = "\(pinID)_\(Date().timeIntervalSince1970).jpg"
        let path = "pin-images/\(fileName)"
        
        return try await uploadImage(imageData, to: "pin-images", path: path)
    }
    
    /// Upload image for messaging and return URL
    func uploadMessageImage(_ imageData: Data, conversationId: String) async -> String? {
        let fileName = "message_\(UUID().uuidString).jpg"
        let filePath = "message-images/\(conversationId)/\(fileName)"
        
        do {
            try await client.storage
                .from("message-images")
                .upload(filePath, data: imageData, options: FileOptions(contentType: "image/jpeg"))
            
            let response = try client.storage
                .from("message-images")
                .getPublicURL(path: filePath)
            
            print("✅ Message image uploaded: \(response.absoluteString)")
            return response.absoluteString
        } catch {
            print("❌ Failed to upload message image: \(error)")
            return nil
        }
    }
}
