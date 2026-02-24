//
//  VideoService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation

class VideoService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient) {
        self.client = client
    }
    
    /// Upload video file to storage
    func uploadVideo(_ videoData: Data, for videoID: String) async throws -> String {
        let fileName = "\(videoID)_\(Date().timeIntervalSince1970).mp4"
        let path = "videos/\(fileName)"
        
        do {
            _ = try await client.storage
                .from("videos")
                .upload(path, data: videoData)
            
            print("✅ Video uploaded successfully: \(path)")
            
            // Get public URL
            let publicURL = try client.storage
                .from("videos")
                .getPublicURL(path: path)
            
            return publicURL.absoluteString
        } catch {
            print("❌ Failed to upload video: \(error)")
            throw error
        }
    }
    
    /// Upload video thumbnail
    func uploadVideoThumbnail(_ imageData: Data, for videoID: String) async throws -> String {
        let fileName = "\(videoID)_thumbnail_\(Date().timeIntervalSince1970).jpg"
        let path = "video-thumbnails/\(fileName)"
        
        return try await uploadImage(imageData, to: "video-thumbnails", path: path)
    }
    
    /// Create a new video post
    func createVideoContent(_ video: VideoContent) async throws -> VideoContent {
        do {
            let videoContentDB = video.toVideoContentDB()
            
            let insertedVideo: [VideoContentDB] = try await client
                .from("video_content")
                .insert(videoContentDB)
                .select()
                .execute()
                .value
            
            guard let insertedVideoData = insertedVideo.first else {
                throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create video content"])
            }
            
            print("✅ Video content created successfully: \(insertedVideoData.id)")
            return insertedVideoData.toVideoContent()
        } catch {
            print("❌ Failed to create video content: \(error)")
            throw error
        }
    }
    
    /// Get video feed based on filter
    func getVideoFeed(filter: VideoFeedFilter, userID: String, limit: Int = 20, offset: Int = 0) async throws -> [VideoContent] {
        do {
            // Build query based on feed type
            let videos: [VideoContentDB] = try await {
                switch filter {
                case .following:
                    // Get videos from users the current user follows
                    let followingUsers = await getFollowingUsers(for: userID)
                    let followingUserIds = followingUsers.map { $0.id }
                    if !followingUserIds.isEmpty {
                        return try await client
                            .from("video_content")
                            .select("*")
                            .eq("author_id", value: followingUserIds.first!)
                            .order("created_at", ascending: false)
                            .range(from: offset, to: offset + limit - 1)
                            .execute()
                            .value
                    } else {
                        return []
                    }
                case .trending:
                    return try await client
                        .from("video_content")
                        .select("*")
                        .order("likes_count", ascending: false)
                        .order("views_count", ascending: false)
                        .order("created_at", ascending: false)
                        .range(from: offset, to: offset + limit - 1)
                        .execute()
                        .value
                case .nearby:
                    return try await client
                        .from("video_content")
                        .select("*")
                        .order("created_at", ascending: false)
                        .range(from: offset, to: offset + limit - 1)
                        .execute()
                        .value
                case .saved:
                    let savedVideoIds = await getSavedVideoIds(for: userID)
                    if !savedVideoIds.isEmpty {
                        return try await client
                            .from("video_content")
                            .select("*")
                            .eq("id", value: savedVideoIds.first!)
                            .order("created_at", ascending: false)
                            .range(from: offset, to: offset + limit - 1)
                            .execute()
                            .value
                    } else {
                        return []
                    }
                case .forYou:
                    return try await client
                        .from("video_content")
                        .select("*")
                        .order("created_at", ascending: false)
                        .range(from: offset, to: offset + limit - 1)
                        .execute()
                        .value
                }
            }()
            
            var videoContents: [VideoContent] = []
            for videoDB in videos {
                let isLiked = await isVideoLikedByUser(videoId: videoDB.id, userId: userID)
                let isBookmarked = await isVideoBookmarkedByUser(videoId: videoDB.id, userId: userID)
                let videoContent = videoDB.toVideoContent(isLikedByCurrentUser: isLiked, isBookmarkedByCurrentUser: isBookmarked)
                videoContents.append(videoContent)
            }
            
            print("✅ Retrieved \(videoContents.count) videos for \(filter.rawValue) feed")
            return videoContents
        } catch {
            print("❌ Failed to get video feed: \(error)")
            throw error
        }
    }
    
    /// Get specific video by ID
    func getVideo(id: String, userID: String) async throws -> VideoContent? {
        do {
            let videos: [VideoContentDB] = try await client
                .from("video_content")
                .select("*")
                .eq("id", value: id)
                .execute()
                .value
            
            guard let videoDB = videos.first else { return nil }
            
            let isLiked = await isVideoLikedByUser(videoId: id, userId: userID)
            let isBookmarked = await isVideoBookmarkedByUser(videoId: id, userId: userID)
            
            return videoDB.toVideoContent(isLikedByCurrentUser: isLiked, isBookmarkedByCurrentUser: isBookmarked)
        } catch {
            print("❌ Failed to get video: \(error)")
            throw error
        }
    }
    
    /// Like/unlike a video
    func toggleVideoLike(videoId: String, userId: String, username: String, userAvatarURL: String?) async -> Bool {
        do {
            let existingLikes: [VideoLikeDB] = try await client
                .from("video_likes")
                .select("*")
                .eq("video_id", value: videoId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if let existingLike = existingLikes.first {
                _ = try await client
                    .from("video_likes")
                    .delete()
                    .eq("id", value: existingLike.id)
                    .execute()
                
                _ = try await client
                    .from("video_content")
                    .update(["likes_count": "likes_count - 1"])
                    .eq("id", value: videoId)
                    .execute()
                
                print("✅ Video unliked: \(videoId)")
                return false
            } else {
                let videoLike = VideoLikeDB(
                    id: UUID().uuidString,
                    video_id: videoId,
                    user_id: userId,
                    username: username,
                    user_avatar_url: userAvatarURL,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("video_likes")
                    .insert(videoLike)
                    .execute()
                
                _ = try await client
                    .from("video_content")
                    .update(["likes_count": "likes_count + 1"])
                    .eq("id", value: videoId)
                    .execute()
                
                print("✅ Video liked: \(videoId)")
                return true
            }
        } catch {
            print("❌ Failed to toggle video like: \(error)")
            return false
        }
    }
    
    /// Check if video is liked by user
    func isVideoLikedByUser(videoId: String, userId: String) async -> Bool {
        do {
            let likes: [VideoLikeDB] = try await client
                .from("video_likes")
                .select("id")
                .eq("video_id", value: videoId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            return !likes.isEmpty
        } catch {
            print("❌ Failed to check video like status: \(error)")
            return false
        }
    }
    
    /// Bookmark/unbookmark a video
    func toggleVideoBookmark(videoId: String, userId: String) async -> Bool {
        do {
            let existingBookmarks: [VideoBookmarkDB] = try await client
                .from("video_bookmarks")
                .select("*")
                .eq("video_id", value: videoId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if let existingBookmark = existingBookmarks.first {
                _ = try await client
                    .from("video_bookmarks")
                    .delete()
                    .eq("id", value: existingBookmark.id)
                    .execute()
                
                print("✅ Video unbookmarked: \(videoId)")
                return false
            } else {
                let bookmark = VideoBookmarkDB(
                    id: UUID().uuidString,
                    video_id: videoId,
                    user_id: userId,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("video_bookmarks")
                    .insert(bookmark)
                    .execute()
                
                print("✅ Video bookmarked: \(videoId)")
                return true
            }
        } catch {
            print("❌ Failed to toggle video bookmark: \(error)")
            return false
        }
    }
    
    /// Check if video is bookmarked by user
    func isVideoBookmarkedByUser(videoId: String, userId: String) async -> Bool {
        do {
            let bookmarks: [VideoBookmarkDB] = try await client
                .from("video_bookmarks")
                .select("id")
                .eq("video_id", value: videoId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            return !bookmarks.isEmpty
        } catch {
            print("❌ Failed to check video bookmark status: \(error)")
            return false
        }
    }
    
    /// Record video view
    func recordVideoView(videoId: String, userId: String, watchDuration: TimeInterval) async {
        do {
            let view = VideoViewDB(
                id: UUID().uuidString,
                video_id: videoId,
                user_id: userId,
                watch_duration: watchDuration,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            _ = try await client
                .from("video_views")
                .insert(view)
                .execute()
            
            _ = try await client
                .from("video_content")
                .update(["views_count": "views_count + 1"])
                .eq("id", value: videoId)
                .execute()
            
            print("✅ Video view recorded: \(videoId)")
        } catch {
            print("❌ Failed to record video view: \(error)")
        }
    }
    
    /// Add comment to video
    func addVideoComment(videoId: String, authorId: String, authorUsername: String, authorAvatarURL: String?, content: String, parentCommentId: String? = nil) async throws -> VideoComment {
        do {
            let commentDB = VideoCommentDB(
                id: UUID().uuidString,
                video_id: videoId,
                author_id: authorId,
                author_username: authorUsername,
                author_avatar_url: authorAvatarURL,
                content: content,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: nil,
                parent_comment_id: parentCommentId,
                likes_count: 0,
                replies_count: 0
            )
            
            let insertedComments: [VideoCommentDB] = try await client
                .from("video_comments")
                .insert(commentDB)
                .select()
                .execute()
                .value
            
            guard let insertedComment = insertedComments.first else {
                throw NSError(domain: "CommentError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to add comment"])
            }
            
            _ = try await client
                .from("video_content")
                .update(["comments_count": "comments_count + 1"])
                .eq("id", value: videoId)
                .execute()
            
            if let parentId = parentCommentId {
                _ = try await client
                    .from("video_comments")
                    .update(["replies_count": "replies_count + 1"])
                    .eq("id", value: parentId)
                    .execute()
            }
            
            print("✅ Comment added to video: \(videoId)")
            return insertedComment.toVideoComment()
        } catch {
            print("❌ Failed to add video comment: \(error)")
            throw error
        }
    }
    
    /// Get comments for video
    func getVideoComments(videoId: String, userId: String, limit: Int = 50, offset: Int = 0) async throws -> [VideoComment] {
        do {
            let commentsDB: [VideoCommentDB] = try await client
                .from("video_comments")
                .select("*")
                .eq("video_id", value: videoId)
                .is("parent_comment_id", value: nil)
                .order("created_at", ascending: true)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
            
            var comments: [VideoComment] = []
            for commentDB in commentsDB {
                let isLiked = await isVideoCommentLikedByUser(commentId: commentDB.id, userId: userId)
                let comment = commentDB.toVideoComment(isLikedByCurrentUser: isLiked)
                comments.append(comment)
            }
            
            print("✅ Retrieved \(comments.count) comments for video: \(videoId)")
            return comments
        } catch {
            print("❌ Failed to get video comments: \(error)")
            throw error
        }
    }
    
    /// Get replies for a comment
    func getCommentReplies(commentId: String, userId: String, limit: Int = 20) async throws -> [VideoComment] {
        do {
            let repliesDB: [VideoCommentDB] = try await client
                .from("video_comments")
                .select("*")
                .eq("parent_comment_id", value: commentId)
                .order("created_at", ascending: true)
                .limit(limit)
                .execute()
                .value
            
            var replies: [VideoComment] = []
            for replyDB in repliesDB {
                let isLiked = await isVideoCommentLikedByUser(commentId: replyDB.id, userId: userId)
                let reply = replyDB.toVideoComment(isLikedByCurrentUser: isLiked)
                replies.append(reply)
            }
            
            print("✅ Retrieved \(replies.count) replies for comment: \(commentId)")
            return replies
        } catch {
            print("❌ Failed to get comment replies: \(error)")
            throw error
        }
    }
    
    /// Like/unlike a comment
    func toggleCommentLike(commentId: String, userId: String) async -> Bool {
        do {
            let existingLikes: [VideoCommentLikeDB] = try await client
                .from("video_comment_likes")
                .select("*")
                .eq("comment_id", value: commentId)
                .eq("user_id", value: userId)
                .execute()
                .value
            
            if !existingLikes.isEmpty {
                _ = try await client
                    .from("video_comment_likes")
                    .delete()
                    .eq("comment_id", value: commentId)
                    .eq("user_id", value: userId)
                    .execute()
                
                _ = try await client
                    .from("video_comments")
                    .update(["likes_count": "likes_count - 1"])
                    .eq("id", value: commentId)
                    .execute()
                
                print("✅ Comment unliked: \(commentId)")
                return false
            } else {
                let like = VideoCommentLikeDB(
                    id: UUID().uuidString,
                    comment_id: commentId,
                    user_id: userId,
                    created_at: ISO8601DateFormatter().string(from: Date())
                )
                
                _ = try await client
                    .from("video_comment_likes")
                    .insert(like)
                    .execute()
                
                _ = try await client
                    .from("video_comments")
                    .update(["likes_count": "likes_count + 1"])
                    .eq("id", value: commentId)
                    .execute()
                
                print("✅ Comment liked: \(commentId)")
                return true
            }
        } catch {
            print("❌ Failed to toggle comment like: \(error)")
            return false
        }
    }
    
    /// Share video (increment share count)
    func shareVideo(videoId: String) async {
        do {
            _ = try await client
                .from("video_content")
                .update(["shares_count": "shares_count + 1"])
                .eq("id", value: videoId)
                .execute()
            
            print("✅ Video share count incremented: \(videoId)")
        } catch {
            print("❌ Failed to increment video share count: \(error)")
        }
    }
    
    /// Delete video (only by owner)
    func deleteVideo(videoId: String, userId: String) async -> Bool {
        do {
            let videos: [VideoContentDB] = try await client
                .from("video_content")
                .select("author_id")
                .eq("id", value: videoId)
                .execute()
                .value
            
            guard let video = videos.first, video.author_id == userId else {
                print("❌ User not authorized to delete video: \(videoId)")
                return false
            }
            
            _ = try await client
                .from("video_content")
                .delete()
                .eq("id", value: videoId)
                .execute()
            
            print("✅ Video deleted: \(videoId)")
            return true
        } catch {
            print("❌ Failed to delete video: \(error)")
            return false
        }
    }
    
    /// Get user's videos
    func getUserVideos(userId: String, limit: Int = 20, offset: Int = 0) async throws -> [VideoContent] {
        do {
            let videos: [VideoContentDB] = try await client
                .from("video_content")
                .select("*")
                .eq("author_id", value: userId)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
            
            let videoContents = videos.map { $0.toVideoContent() }
            print("✅ Retrieved \(videoContents.count) videos for user: \(userId)")
            return videoContents
        } catch {
            print("❌ Failed to get user videos: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Helpers
    
    private func uploadImage(_ imageData: Data, to bucket: String, path: String) async throws -> String {
        try await client.storage
            .from(bucket)
            .upload(path, data: imageData, options: FileOptions(contentType: "image/jpeg"))
        
        return try client.storage
            .from(bucket)
            .getPublicURL(path: path)
            .absoluteString
    }
    
    private func getSavedVideoIds(for userId: String) async -> [String] {
        do {
            let bookmarks: [VideoBookmarkDB] = try await client
                .from("video_bookmarks")
                .select("video_id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            return bookmarks.map { $0.video_id }
        } catch {
            print("❌ Failed to get saved video IDs: \(error)")
            return []
        }
    }
    
    private func isVideoCommentLikedByUser(commentId: String, userId: String) async -> Bool {
        do {
            let likes: [VideoCommentLikeDB] = try await client
                .from("video_comment_likes")
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
    
    private func getFollowingUsers(for userID: String) async -> [AppUser] {
        do {
            struct FollowResponse: Codable {
                let following_id: String
            }
            
            let follows: [FollowResponse] = try await client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: userID)
                .execute()
                .value
            
            let followingIds = follows.map { $0.following_id }
            if followingIds.isEmpty { return [] }
            
            let basicUsers: [BasicUser] = try await client
                .from("users")
                .select("id, username, full_name, email, bio, latitude, longitude, avatar_url")
                .in("id", values: followingIds)
                .execute()
                .value
            
            return basicUsers.map { $0.toAppUser(currentUserID: userID) }
        } catch {
            print("❌ Failed to fetch following users: \(error)")
            return []
        }
    }
}
