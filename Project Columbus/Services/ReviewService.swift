//
//  ReviewService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation

class ReviewService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Create a location review
    func createLocationReview(
        pinId: UUID,
        rating: Int,
        title: String? = nil,
        content: String,
        pros: [String] = [],
        cons: [String] = [],
        mediaURLs: [String] = [],
        visitDate: Date? = nil,
        priceRange: Int? = nil,
        tags: [String] = []
    ) async throws -> LocationReview {
        guard let session = try? await client.auth.session,
              let currentUser = try? await getCurrentUser() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let reviewDB = LocationReviewDB(
            id: UUID().uuidString,
            pin_id: pinId.uuidString,
            user_id: session.user.id.uuidString,
            username: currentUser.username,
            user_avatar_url: currentUser.avatarURL,
            rating: rating,
            title: title,
            content: content,
            pros: pros,
            cons: cons,
            media_urls: mediaURLs,
            visit_date: visitDate.map { ISO8601DateFormatter().string(from: $0) },
            price_range: priceRange,
            tags: tags,
            helpful_count: 0,
            reply_count: 0,
            is_verified_visit: false,
            is_edited: false,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response: [LocationReviewDB] = try await client
            .from("location_reviews")
            .insert(reviewDB)
            .select()
            .execute()
            .value
        
        guard let createdDB = response.first else {
            throw NSError(domain: "Database", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create review"])
        }
        
        try await createFriendActivity(
            activityType: .ratedPlace,
            relatedPinId: pinId,
            locationName: nil,
            description: "rated a place \(rating) stars"
        )
        
        return convertToLocationReview(createdDB)
    }
    
    /// Get reviews for a location
    func getLocationReviews(pinId: UUID) async throws -> [LocationReview] {
        let reviewsDB: [LocationReviewDB] = try await client
            .from("location_reviews")
            .select()
            .eq("pin_id", value: pinId.uuidString)
            .order("helpful_count", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return reviewsDB.map(convertToLocationReview)
    }
    
    /// Vote on review helpfulness
    func voteReviewHelpful(reviewId: UUID, isHelpful: Bool) async throws {
        guard let userId = try? await client.auth.session.user.id.uuidString else { return }
        
        let voteData = ReviewHelpfulVoteInsert(
            review_id: reviewId.uuidString,
            user_id: userId,
            is_helpful: isHelpful
        )
        
        _ = try await client
            .from("review_helpful_votes")
            .upsert(voteData, onConflict: "review_id,user_id")
            .execute()
        
        if isHelpful {
            _ = try await client
                .rpc("increment_review_helpful_count", params: ["review_id": reviewId.uuidString])
                .execute()
        }
    }
    
    // MARK: - Private Helpers
    
    private func convertToLocationReview(_ db: LocationReviewDB) -> LocationReview {
        LocationReview(
            id: UUID(uuidString: db.id) ?? UUID(),
            pinId: UUID(uuidString: db.pin_id) ?? UUID(),
            userId: db.user_id,
            username: db.username,
            userAvatarURL: db.user_avatar_url,
            rating: db.rating,
            title: db.title,
            content: db.content,
            pros: db.pros,
            cons: db.cons,
            mediaURLs: db.media_urls,
            visitDate: db.visit_date.flatMap { ISO8601DateFormatter().date(from: $0) },
            priceRange: db.price_range,
            tags: db.tags,
            helpfulCount: db.helpful_count,
            replyCount: db.reply_count,
            isVerifiedVisit: db.is_verified_visit,
            isEdited: db.is_edited,
            createdAt: ISO8601DateFormatter().date(from: db.created_at) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: db.updated_at) ?? Date()
        )
    }
    
    private func getCurrentUser() async throws -> AppUser {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
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
    
    private func createFriendActivity(
        activityType: FriendActivityType,
        relatedPinId: UUID? = nil,
        locationName: String? = nil,
        description: String
    ) async throws {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        guard let currentUser = try? await getCurrentUser() else {
            throw NSError(domain: "User", code: 404, userInfo: [NSLocalizedDescriptionKey: "Current user not found"])
        }
        
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
        
        let activityInsert = ActivityInsert(
            id: UUID().uuidString,
            user_id: session.user.id.uuidString,
            username: currentUser.username,
            user_avatar_url: currentUser.avatarURL,
            activity_type: activityType.rawValue,
            related_pin_id: relatedPinId?.uuidString,
            related_list_id: nil,
            related_user_id: nil,
            location_name: locationName,
            location_latitude: nil,
            location_longitude: nil,
            description: description,
            metadata: "{}",
            created_at: ISO8601DateFormatter().string(from: Date()),
            is_visible: true
        )
        
        try await client
            .from("friend_activities")
            .insert(activityInsert)
            .execute()
        
        print("✅ [Activity Feed] Created activity: \(activityType.rawValue)")
    }
}
