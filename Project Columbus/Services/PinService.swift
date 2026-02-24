//
//  PinService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation
import SwiftUI

class PinService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    // MARK: - Pins Management
    
    /// Creates a new pin in the database
    func createPin(pin: Pin) async throws -> String {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let pinInsert = pin.toPinDB(userId: session.user.id.uuidString)
        
        let response: [PinDB] = try await client
            .from("pins")
            .insert(pinInsert)
            .select()
            .execute()
            .value
        
        let pinId = response.first?.id ?? ""
        
        // Create friend activity for this pin creation
        if !pinId.isEmpty, let pinUUID = UUID(uuidString: pinId) {
            Task {
                do {
                    let activityType: FriendActivityType = pin.starRating != nil ? .ratedPlace : .visitedPlace
                    let description = pin.starRating != nil ?
                        "rated \(pin.locationName) \(Int(pin.starRating ?? 0)) stars" :
                        "visited \(pin.locationName)"
                    
                    try await createFriendActivityForPin(
                        activityType: activityType,
                        relatedPinId: pinUUID,
                        locationName: pin.locationName,
                        locationLatitude: pin.latitude,
                        locationLongitude: pin.longitude,
                        description: description,
                        metadata: [
                            "pin_id": pinId,
                            "location_name": pin.locationName,
                            "city": pin.city,
                            "rating": pin.starRating ?? 0
                        ]
                    )
                    
                    NotificationCenter.default.post(name: .friendActivityUpdated, object: nil)
                } catch {
                    print("❌ Failed to create friend activity for pin: \(error)")
                }
            }
        }
        
        return pinId
    }
    
    /// Fetches pins for a specific list
    func getPinsForList(listId: String) async -> [Pin] {
        do {
            let listPins: [ListPinDB] = try await client
                .from("list_pins")
                .select("*")
                .eq("list_id", value: listId)
                .execute()
                .value
            
            let pinIds = listPins.map { $0.pin_id }
            if pinIds.isEmpty { return [] }
            
            let pinsDB: [PinDB] = try await client
                .from("pins")
                .select("*")
                .in("id", values: pinIds)
                .execute()
                .value
            
            return pinsDB.map { $0.toPin() }
        } catch {
            print("❌ Failed to fetch pins for list: \(error)")
            return []
        }
    }
    
    /// Fetches all pins for the current user
    func getAllUserPins() async -> [Pin] {
        guard let session = try? await client.auth.session else { return [] }
        
        do {
            let pinsDB: [PinDB] = try await client
                .from("pins")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
                .value
            
            return pinsDB.map { $0.toPin() }
        } catch {
            print("❌ Failed to fetch user pins: \(error)")
            return []
        }
    }
    
    /// Checks if a pin exists in the database (by coordinates and location name)
    func findExistingPin(pin: Pin) async -> String? {
        guard let session = try? await client.auth.session else { return nil }
        
        do {
            struct PinIdResponse: Codable {
                let id: String
            }
            
            let existingPins: [PinIdResponse] = try await client
                .from("pins")
                .select("id")
                .eq("user_id", value: session.user.id.uuidString)
                .eq("location_name", value: pin.locationName)
                .eq("latitude", value: pin.latitude)
                .eq("longitude", value: pin.longitude)
                .limit(1)
                .execute()
                .value
            
            return existingPins.first?.id
        } catch {
            print("❌ Failed to find existing pin: \(error)")
            return nil
        }
    }
    
    /// Get public pins from all users for discovery feed
    func getPublicPins(limit: Int = 50) async -> [Pin] {
        do {
            let pinsDB: [PinDB] = try await client
                .from("pins")
                .select("*")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            return pinsDB.map { $0.toPin() }
        } catch {
            print("❌ Failed to fetch public pins: \(error)")
            return []
        }
    }
    
    /// Get pins from users that the specified user follows
    func getFeedPins(for userID: String, limit: Int = 50, followingIds: [String]) async -> [Pin] {
        do {
            if followingIds.isEmpty { return [] }
            
            let pinsDB: [PinDB] = try await client
                .from("pins")
                .select("*")
                .in("user_id", values: followingIds)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            return pinsDB.map { $0.toPin() }
        } catch {
            print("❌ Failed to fetch feed pins: \(error)")
            return []
        }
    }
    
    // MARK: - Social Features - Comments
    
    /// Add a comment to a pin
    func addComment(pinId: UUID, content: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        guard let currentUser = try? await getCurrentUserProfile() else { return false }
        
        do {
            struct CommentData: Codable {
                let id: String
                let pin_id: String
                let user_id: String
                let username: String
                let user_avatar_url: String?
                let content: String
                let created_at: String
                let likes_count: Int
            }
            
            let commentData = CommentData(
                id: UUID().uuidString,
                pin_id: pinId.uuidString,
                user_id: session.user.id.uuidString,
                username: currentUser.username,
                user_avatar_url: currentUser.avatarURL,
                content: content,
                created_at: ISO8601DateFormatter().string(from: Date()),
                likes_count: 0
            )
            
            _ = try await client
                .from("pin_comments")
                .insert(commentData)
                .execute()
            
            // Create friend activity for comment
            try? await createFriendActivityForPin(
                activityType: .commentedOnPin,
                relatedPinId: pinId,
                locationName: nil,
                locationLatitude: nil,
                locationLongitude: nil,
                description: "commented on a pin",
                metadata: [:]
            )
            
            return true
        } catch {
            print("❌ Failed to add comment: \(error)")
            return false
        }
    }
    
    /// Get comments for a pin
    func getComments(for pinId: UUID, currentUserId: String) async -> [PinComment] {
        do {
            let commentsDB: [PinCommentDB] = try await client
                .from("pin_comments")
                .select("*")
                .eq("pin_id", value: pinId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            var comments: [PinComment] = []
            for commentDB in commentsDB {
                let isLiked = await isCommentLikedByUser(commentId: commentDB.id, userId: currentUserId)
                comments.append(commentDB.toPinComment(isLikedByCurrentUser: isLiked))
            }
            
            return comments
        } catch {
            print("❌ Failed to get comments: \(error)")
            return []
        }
    }
    
    /// Like/unlike a comment
    func toggleCommentLike(commentId: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            let userId = session.user.id.uuidString
            
            let existing: [CommentLikeDB] = try await client
                .from("comment_likes")
                .select("*")
                .eq("comment_id", value: commentId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if existing.isEmpty {
                struct LikeData: Codable {
                    let id: String
                    let comment_id: String
                    let user_id: String
                    let created_at: String
                }
                
                let likeData = LikeData(
                    id: UUID().uuidString,
                    comment_id: commentId,
                    user_id: userId,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("comment_likes")
                    .insert(likeData)
                    .execute()
            } else {
                _ = try await client
                    .from("comment_likes")
                    .delete()
                    .eq("comment_id", value: commentId)
                    .eq("user_id", value: userId)
                    .execute()
            }
            
            return true
        } catch {
            print("❌ Failed to toggle comment like: \(error)")
            return false
        }
    }
    
    private func isCommentLikedByUser(commentId: String, userId: String) async -> Bool {
        do {
            let likes: [CommentLikeDB] = try await client
                .from("comment_likes")
                .select("*")
                .eq("comment_id", value: commentId)
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            
            return !likes.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Social Features - Reactions (PinReactionType)
    
    /// Add/update reaction to a pin
    func addReaction(pinId: UUID, reactionType: PinReactionType) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        guard let currentUser = try? await getCurrentUserProfile() else { return false }
        
        do {
            let userId = session.user.id.uuidString
            
            let existing: [PinReactionDB] = try await client
                .from("pin_reactions")
                .select("*")
                .eq("pin_id", value: pinId.uuidString)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if existing.isEmpty {
                struct ReactionData: Codable {
                    let id: String
                    let pin_id: String
                    let user_id: String
                    let username: String
                    let user_avatar_url: String?
                    let reaction_type: String
                    let created_at: String
                }
                
                let reactionData = ReactionData(
                    id: UUID().uuidString,
                    pin_id: pinId.uuidString,
                    user_id: userId,
                    username: currentUser.username,
                    user_avatar_url: currentUser.avatarURL,
                    reaction_type: reactionType.rawValue,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("pin_reactions")
                    .insert(reactionData)
                    .execute()
                
                // Create friend activity for reaction
                try? await createFriendActivityForPin(
                    activityType: .reactedToPin,
                    relatedPinId: pinId,
                    locationName: nil,
                    locationLatitude: nil,
                    locationLongitude: nil,
                    description: "reacted to a pin with \(reactionType.emoji)",
                    metadata: [:]
                )
            } else {
                _ = try await client
                    .from("pin_reactions")
                    .update(["reaction_type": reactionType.rawValue])
                    .eq("pin_id", value: pinId.uuidString)
                    .eq("user_id", value: userId)
                    .execute()
            }
            
            return true
        } catch {
            print("❌ Failed to add reaction: \(error)")
            return false
        }
    }
    
    /// Remove reaction from a pin
    func removeReaction(pinId: UUID) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            _ = try await client
                .from("pin_reactions")
                .delete()
                .eq("pin_id", value: pinId.uuidString)
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to remove reaction: \(error)")
            return false
        }
    }
    
    /// Get reactions for a pin
    func getReactions(for pinId: UUID) async -> [PinReaction] {
        do {
            let reactionsDB: [PinReactionDB] = try await client
                .from("pin_reactions")
                .select("*")
                .eq("pin_id", value: pinId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return reactionsDB.map { $0.toPinReaction() }
        } catch {
            print("❌ Failed to get reactions: \(error)")
            return []
        }
    }
    
    // MARK: - Social Reactions (ReactionType) - Stories/Activities System
    
    /// Add reaction to a pin (ReactionType variant)
    func addPinReaction(pinId: UUID, reactionType: ReactionType) async throws {
        guard let userId = try? await client.auth.session.user.id.uuidString else { return }
        
        let reactionData = [
            "pin_id": pinId.uuidString,
            "user_id": userId,
            "reaction_type": reactionType.rawValue
        ]
        
        _ = try await client
            .from("pin_reactions")
            .upsert(reactionData, onConflict: "pin_id,user_id")
            .execute()
    }
    
    /// Remove reaction from a pin (ReactionType variant)
    func removePinReaction(pinId: UUID) async throws {
        guard let userId = try? await client.auth.session.user.id.uuidString else { return }
        
        _ = try await client
            .from("pin_reactions")
            .delete()
            .eq("pin_id", value: pinId.uuidString)
            .eq("user_id", value: userId)
            .execute()
    }
    
    /// Get reactions for a pin (SocialPinReaction variant)
    func getPinReactions(pinId: UUID) async throws -> [SocialPinReaction] {
        struct PinReactionResponse: Codable {
            let id: String
            let user_id: String
            let reaction_type: String
            let created_at: String
        }
        
        let reactionsDB: [PinReactionResponse] = try await client
            .from("pin_reactions")
            .select("id, user_id, reaction_type, created_at")
            .eq("pin_id", value: pinId.uuidString)
            .execute()
            .value
        
        return reactionsDB.compactMap { reaction in
            guard let type = ReactionType(rawValue: reaction.reaction_type) else {
                return nil
            }
            
            return SocialPinReaction(
                id: UUID(uuidString: reaction.id) ?? UUID(),
                pinId: pinId,
                userId: reaction.user_id,
                reactionType: type,
                createdAt: ISO8601DateFormatter().date(from: reaction.created_at) ?? Date()
            )
        }
    }
    
    /// Get a single pin by ID (internal - used by activity feed etc.)
    func getPinById(_ pinId: UUID) async -> Pin? {
        do {
            let pinDB: PinDB = try await client
                .from("pins")
                .select("*")
                .eq("id", value: pinId.uuidString)
                .single()
                .execute()
                .value
            
            return pinDB.toPin()
        } catch {
            print("❌ Failed to get pin by ID: \(error)")
            return nil
        }
    }
    
    // MARK: - Private Helpers
    
    private func getCurrentUserProfile() async throws -> AppUser {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let basicUser: BasicUser = try await client
            .from("users")
            .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
            .eq("id", value: session.user.id.uuidString)
            .single()
            .execute()
            .value
        
        return basicUser.toAppUser(currentUserID: session.user.id.uuidString)
    }
    
    private func createFriendActivityForPin(
        activityType: FriendActivityType,
        relatedPinId: UUID,
        locationName: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        description: String,
        metadata: [String: Any] = [:]
    ) async throws {
        guard let session = try? await client.auth.session else { return }
        guard let currentUser = try? await getCurrentUserProfile() else { return }
        
        struct ActivityInsert: Codable {
            let id: String
            let user_id: String
            let username: String
            let user_avatar_url: String?
            let activity_type: String
            let related_pin_id: String?
            let related_list_id: String?
            let related_user_id: String?
            let location_name: String?
            let location_latitude: Double?
            let location_longitude: Double?
            let description: String
            let metadata: String
            let created_at: String
            let is_visible: Bool
        }
        
        let metadataJSON = try JSONSerialization.data(withJSONObject: metadata)
        let metadataString = String(data: metadataJSON, encoding: .utf8) ?? "{}"
        
        let activityInsert = ActivityInsert(
            id: UUID().uuidString,
            user_id: session.user.id.uuidString,
            username: currentUser.username,
            user_avatar_url: currentUser.avatarURL,
            activity_type: activityType.rawValue,
            related_pin_id: relatedPinId.uuidString,
            related_list_id: nil,
            related_user_id: nil,
            location_name: locationName,
            location_latitude: locationLatitude,
            location_longitude: locationLongitude,
            description: description,
            metadata: metadataString,
            created_at: ISO8601DateFormatter().string(from: Date()),
            is_visible: true
        )
        
        try await client
            .from("friend_activities")
            .insert(activityInsert)
            .execute()
    }
}
