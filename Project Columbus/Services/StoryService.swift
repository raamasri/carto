//
//  StoryService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation

class StoryService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Create a location story
    func createLocationStory(
        locationId: UUID? = nil,
        locationName: String,
        latitude: Double,
        longitude: Double,
        contentType: StoryContentType,
        mediaURL: String? = nil,
        thumbnailURL: String? = nil,
        caption: String? = nil,
        visibility: StoryVisibility = .friends
    ) async throws -> LocationStory {
        guard let session = try? await client.auth.session,
              let currentUser = try? await getCurrentUser() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let storyDB = LocationStoryDB(
            id: UUID().uuidString,
            user_id: session.user.id.uuidString,
            username: currentUser.username,
            user_avatar_url: currentUser.avatarURL,
            location_id: locationId?.uuidString,
            location_name: locationName,
            location_latitude: latitude,
            location_longitude: longitude,
            content_type: contentType.rawValue,
            media_url: mediaURL,
            thumbnail_url: thumbnailURL,
            caption: caption,
            visibility: visibility.rawValue,
            view_count: 0,
            is_active: true,
            expires_at: ISO8601DateFormatter().string(from: Date().addingTimeInterval(24 * 60 * 60)),
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response: [LocationStoryDB] = try await client
            .from("location_stories")
            .insert(storyDB)
            .select()
            .execute()
            .value
        
        guard let createdStoryDB = response.first else {
            throw NSError(domain: "Database", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create story"])
        }
        
        return convertToLocationStory(createdStoryDB)
    }
    
    /// Fetch active stories from friends
    func fetchFriendStories() async throws -> [LocationStory] {
        guard let userId = try? await client.auth.session.user.id.uuidString else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let storiesDB: [LocationStoryDB] = try await client
            .from("location_stories")
            .select()
            .eq("is_active", value: true)
            .gte("expires_at", value: ISO8601DateFormatter().string(from: Date()))
            .or("visibility.eq.public,user_id.eq.\(userId),and(visibility.eq.friends,user_id.in.(select following_id from follows where follower_id=\(userId)))")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return storiesDB.map(convertToLocationStory)
    }
    
    /// Record a story view
    func recordStoryView(storyId: UUID) async throws {
        guard let userId = try? await client.auth.session.user.id.uuidString else { return }
        
        let viewData = [
            "story_id": storyId.uuidString,
            "viewer_id": userId
        ]
        
        _ = try? await client
            .from("story_views")
            .insert(viewData)
            .execute()
        
        _ = try? await client
            .rpc("increment_story_view_count", params: ["story_id": storyId.uuidString])
            .execute()
    }
    
    /// Get story viewers
    func getStoryViewers(storyId: UUID) async throws -> [AppUser] {
        struct StoryViewResponse: Codable {
            let viewer_id: String
        }
        
        let viewsDB: [StoryViewResponse] = try await client
            .from("story_views")
            .select("viewer_id")
            .eq("story_id", value: storyId.uuidString)
            .order("viewed_at", ascending: false)
            .execute()
            .value
        
        var viewers: [AppUser] = []
        for view in viewsDB {
            if let user = await fetchUserProfile(userID: view.viewer_id) {
                viewers.append(user)
            }
        }
        return viewers
    }
    
    /// Add reaction to a story
    func addStoryReaction(storyId: UUID, reactionType: ReactionType) async throws {
        guard let userId = try? await client.auth.session.user.id.uuidString else { return }
        
        let reactionData = [
            "story_id": storyId.uuidString,
            "user_id": userId,
            "reaction_type": reactionType.rawValue
        ]
        
        _ = try await client
            .from("story_reactions")
            .upsert(reactionData, onConflict: "story_id,user_id")
            .execute()
    }
    
    // MARK: - Private Helpers
    
    private func convertToLocationStory(_ db: LocationStoryDB) -> LocationStory {
        LocationStory(
            id: UUID(uuidString: db.id) ?? UUID(),
            userId: db.user_id,
            username: db.username,
            userAvatarURL: db.user_avatar_url,
            locationId: db.location_id.flatMap(UUID.init),
            locationName: db.location_name,
            locationLatitude: db.location_latitude,
            locationLongitude: db.location_longitude,
            contentType: StoryContentType(rawValue: db.content_type) ?? .photo,
            mediaURL: db.media_url,
            thumbnailURL: db.thumbnail_url,
            caption: db.caption,
            visibility: StoryVisibility(rawValue: db.visibility) ?? .friends,
            viewCount: db.view_count,
            isActive: db.is_active,
            expiresAt: ISO8601DateFormatter().date(from: db.expires_at) ?? Date(),
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
    
    private func fetchUserProfile(userID: String) async -> AppUser? {
        do {
            let basicUser: BasicUser = try await client
                .from("users")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            
            let followerCount: Int
            do {
                struct CountResult: Codable {
                    let count: Int
                }
                let followerResult: CountResult = try await client
                    .from("follows")
                    .select("count", count: .exact)
                    .eq("following_id", value: userID)
                    .single()
                    .execute()
                    .value
                followerCount = followerResult.count
            } catch {
                followerCount = 0
            }
            
            let followingCount: Int
            do {
                struct CountResult: Codable {
                    let count: Int
                }
                let followingResult: CountResult = try await client
                    .from("follows")
                    .select("count", count: .exact)
                    .eq("follower_id", value: userID)
                    .single()
                    .execute()
                    .value
                followingCount = followingResult.count
            } catch {
                followingCount = 0
            }
            
            let selfFollowCount: Int
            do {
                struct CountResult: Codable {
                    let count: Int
                }
                let selfFollowResult: CountResult = try await client
                    .from("follows")
                    .select("count", count: .exact)
                    .eq("follower_id", value: userID)
                    .eq("following_id", value: userID)
                    .single()
                    .execute()
                    .value
                selfFollowCount = selfFollowResult.count
            } catch {
                selfFollowCount = 0
            }
            
            return AppUser(
                id: basicUser.id,
                username: basicUser.username,
                full_name: basicUser.full_name,
                email: basicUser.email,
                bio: basicUser.bio,
                follower_count: max(0, followerCount - selfFollowCount),
                following_count: max(0, followingCount - selfFollowCount),
                isFollowedByCurrentUser: false,
                latitude: basicUser.latitude,
                longitude: basicUser.longitude,
                isCurrentUser: false,
                avatarURL: basicUser.avatar_url
            )
        } catch {
            print("❌ Failed to fetch user profile: \(error)")
            return nil
        }
    }
}
