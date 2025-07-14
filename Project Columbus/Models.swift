//
//  Models.swift
//  Project Columbus
//
//  Created by raama srivatsan on 4/15/25.
//
//  DESCRIPTION:
//  This file contains the complete data model for Project Columbus (Carto), including
//  all core data structures, enums, and database conversion extensions. It serves as
//  the foundation for the app's data layer architecture.
//
//  MAJOR COMPONENTS:
//  - Pin Model: Core location data with social features
//  - PinList Model: Enhanced list system with sharing and collaboration
//  - User Models: User profiles and authentication data
//  - Messaging Models: Real-time messaging system
//  - Database Models: Supabase database integration
//  - Conversion Extensions: Type-safe database conversions
//
//  ARCHITECTURE:
//  - Protocol-driven design with Identifiable, Codable conformance
//  - Comprehensive enum system for type safety
//  - Bidirectional database conversion extensions
//  - Rich metadata and social features
//  - End-to-end encryption support
//  - Template and collaboration system
//

import Foundation
import CoreLocation
import SwiftUI
import MapKit

// MARK: - Core Enums

/**
 * Reaction
 * 
 * Represents the type of reaction a user can have to a location.
 * This enum defines the emotional response or intent related to a pin.
 */
enum Reaction: String, CaseIterable, Codable {
    case lovedIt = "Loved It"      // User loved this location
    case wantToGo = "Want to Go"   // User wants to visit this location
}

// MARK: - Core Pin Model

/**
 * Pin
 * 
 * The fundamental data structure representing a location pin in the app.
 * Each pin represents a specific location with associated metadata, social features,
 * and user-generated content.
 * 
 * FEATURES:
 * - Location coordinates and metadata
 * - User reactions and ratings
 * - Social features (mentions, reviews)
 * - Media attachments
 * - Trip organization
 * - Temporal information
 * 
 * RELATIONSHIPS:
 * - Belongs to one or more PinLists
 * - Created by a specific user (authorHandle)
 * - Can mention other users (mentionedFriends)
 * - Can include media attachments (mediaURLs)
 */
struct Pin: Identifiable, Equatable, Codable {
    // MARK: - Core Properties
    
    /// Unique identifier for the pin
    let id: UUID
    
    /// Human-readable location name
    let locationName: String
    
    /// City where the location is situated
    let city: String
    
    /// Formatted date string for display
    let date: String
    
    /// Latitude coordinate of the location
    let latitude: Double
    
    /// Longitude coordinate of the location
    let longitude: Double
    
    /// User's reaction to this location
    let reaction: Reaction
    
    // MARK: - Enhanced Properties
    
    /// User's written review of the location
    let reviewText: String?
    
    /// Array of media URLs (photos, videos) associated with the pin
    let mediaURLs: [String]?
    
    /// Array of user IDs mentioned in this pin
    let mentionedFriends: [UUID]
    
    /// User's star rating (1-5 stars)
    let starRating: Double?
    
    /// Distance from user's current location (in meters)
    let distance: Double?
    
    /// Handle/username of the user who created this pin
    let authorHandle: String
    
    /// Timestamp when the pin was created
    let createdAt: Date
    
    /// Optional trip name this pin belongs to
    let tripName: String?
    
    /**
     * Comprehensive initializer for Pin creation
     * 
     * @param id Unique identifier (defaults to new UUID)
     * @param locationName Human-readable location name
     * @param city City where the location is situated
     * @param date Formatted date string
     * @param latitude Latitude coordinate
     * @param longitude Longitude coordinate
     * @param reaction User's reaction to the location
     * @param reviewText Optional user review
     * @param mediaURLs Optional array of media URLs
     * @param mentionedFriends Array of mentioned user IDs
     * @param starRating Optional star rating (1-5)
     * @param distance Optional distance from current location
     * @param authorHandle Username of the creator
     * @param createdAt Creation timestamp
     * @param tripName Optional trip name
     */
    init(id: UUID = UUID(), locationName: String, city: String, date: String, latitude: Double, longitude: Double, reaction: Reaction, reviewText: String?, mediaURLs: [String]?, mentionedFriends: [UUID], starRating: Double?, distance: Double?, authorHandle: String, createdAt: Date, tripName: String?) {
        self.id = id
        self.locationName = locationName
        self.city = city
        self.date = date
        self.latitude = latitude
        self.longitude = longitude
        self.reaction = reaction
        self.reviewText = reviewText
        self.mediaURLs = mediaURLs
        self.mentionedFriends = mentionedFriends
        self.starRating = starRating
        self.distance = distance
        self.authorHandle = authorHandle
        self.createdAt = createdAt
        self.tripName = tripName
    }
}

// MARK: - List Sharing System

/**
 * ListSharingType
 * 
 * Defines the various sharing and privacy options available for pin lists.
 * This enum controls who can view and edit lists, enabling flexible
 * collaboration and privacy settings.
 */
enum ListSharingType: String, CaseIterable, Codable {
    case privateList = "private"                // Only owner can view/edit
    case publicReadOnly = "public_read_only"    // Anyone can view, owner can edit
    case publicEditable = "public_editable"     // Anyone can view and edit
    case friendsOnly = "friends_only"           // Only friends can view
    case specificUsers = "specific_users"       // Only specified users can view
    
    /// Human-readable display name for the sharing type
    var displayName: String {
        switch self {
        case .privateList: return "Private"
        case .publicReadOnly: return "Public (View Only)"
        case .publicEditable: return "Public (Editable)"
        case .friendsOnly: return "Friends Only"
        case .specificUsers: return "Specific Users"
        }
    }
    
    /// System icon name for the sharing type
    var icon: String {
        switch self {
        case .privateList: return "lock.fill"
        case .publicReadOnly: return "globe"
        case .publicEditable: return "globe.badge.chevron.backward"
        case .friendsOnly: return "person.2.fill"
        case .specificUsers: return "person.crop.circle.badge.plus"
        }
    }
}

// MARK: - Enhanced List Model

/**
 * PinList
 * 
 * An enhanced list model that supports sharing, collaboration, and templates.
 * This represents a collection of pins with advanced features for social
 * interaction and content organization.
 * 
 * FEATURES:
 * - Pin organization and management
 * - Flexible sharing and privacy controls
 * - Collaborative editing capabilities
 * - Template system for reusable lists
 * - Activity tracking and statistics
 * - Tag-based organization
 * - Invitation system for collaboration
 * 
 * RELATIONSHIPS:
 * - Contains multiple Pins
 * - Owned by a specific user (ownerId)
 * - Can have multiple collaborators and viewers
 * - Can be used as a template by other users
 */
struct PinList: Identifiable, Codable {
    // MARK: - Core Properties
    
    /// Unique identifier for the list
    let id: UUID
    
    /// Display name of the list
    let name: String
    
    /// Array of pins contained in this list
    var pins: [Pin]
    
    // MARK: - Ownership and Sharing
    
    /// User ID of the list owner
    let ownerId: UUID
    
    /// Current sharing/privacy settings
    var sharingType: ListSharingType
    
    /// Optional description of the list
    var description: String?
    
    /// Tags for categorization and discovery
    var tags: [String]
    
    /// Whether this list can be used as a template
    var isTemplate: Bool
    
    /// Template category for organization
    var templateCategory: String?
    
    // MARK: - Collaboration Properties
    
    /// Array of user IDs who can edit this list
    var collaborators: [UUID]
    
    /// Array of user IDs who can view this list (for specific_users type)
    var viewers: [UUID]
    
    /// Array of email addresses with pending invitations
    var pendingInvites: [String]
    
    // MARK: - Metadata and Statistics
    
    /// Timestamp when the list was created
    let createdAt: Date
    
    /// Timestamp when the list was last updated
    var updatedAt: Date
    
    /// Timestamp of the last activity on this list
    var lastActivityAt: Date
    
    /// Total number of views this list has received
    var totalViews: Int
    
    /// Total number of times this list has been shared
    var totalShares: Int
    
    /// Total number of times this list has been forked/copied
    var totalForks: Int
    
    /**
     * Initializer for PinList creation with sensible defaults
     * 
     * @param id Unique identifier (defaults to new UUID)
     * @param name Display name of the list
     * @param pins Array of pins (defaults to empty)
     * @param ownerId User ID of the owner
     * @param sharingType Privacy/sharing settings (defaults to private)
     * @param description Optional description
     * @param tags Array of tags (defaults to empty)
     * @param isTemplate Whether this is a template (defaults to false)
     * @param templateCategory Optional template category
     */
    init(id: UUID = UUID(), name: String, pins: [Pin] = [], ownerId: UUID, sharingType: ListSharingType = .privateList, description: String? = nil, tags: [String] = [], isTemplate: Bool = false, templateCategory: String? = nil) {
        self.id = id
        self.name = name
        self.pins = pins
        self.ownerId = ownerId
        self.sharingType = sharingType
        self.description = description
        self.tags = tags
        self.isTemplate = isTemplate
        self.templateCategory = templateCategory
        self.collaborators = []
        self.viewers = []
        self.pendingInvites = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastActivityAt = Date()
        self.totalViews = 0
        self.totalShares = 0
        self.totalForks = 0
    }
    
    // MARK: - Computed Properties
    
    /// Whether this list is publicly accessible
    var isPublic: Bool {
        return sharingType == .publicReadOnly || sharingType == .publicEditable
    }
    
    /// Whether this list supports collaborative editing
    var isCollaborative: Bool {
        return sharingType == .publicEditable || !collaborators.isEmpty
    }
    
    /// Whether this list can be shared with others
    var canBeShared: Bool {
        return sharingType != .privateList
    }
    
    /// Human-readable sharing status for display
    var displaySharingStatus: String {
        switch sharingType {
        case .privateList: return "Private"
        case .publicReadOnly: return "Public"
        case .publicEditable: return "Collaborative"
        case .friendsOnly: return "Friends"
        case .specificUsers: return "\(viewers.count + collaborators.count) users"
        }
    }
}

// MARK: - Backward Compatibility

/**
 * PinCollection
 * 
 * Legacy type alias for PinList to maintain backward compatibility.
 * This allows existing code to continue using the old PinCollection name
 * while benefiting from the enhanced PinList functionality.
 */
typealias PinCollection = PinList

// MARK: - Database Models
struct ListDB: Codable {
    let id: String
    let user_id: String
    let name: String
    let created_at: String
}

struct PinDB: Codable {
    let id: String
    let user_id: String
    let location_name: String
    let city: String
    let date: String
    let latitude: Double
    let longitude: Double
    let reaction: String?
    let review_text: String?
    let media_urls: [String]?
    let mentioned_friends: [String]?
    let star_rating: Double?
    let distance: Double?
    let author_handle: String?
    let created_at: String
    let trip_name: String?
}

struct ListPinDB: Codable {
    let id: String
    let list_id: String
    let pin_id: String
}

// MARK: - Enhanced List Database Models

struct EnhancedListDB: Codable {
    let id: String
    let user_id: String
    let name: String
    let description: String?
    let sharing_type: String
    let tags: [String]?
    let is_template: Bool
    let template_category: String?
    let total_views: Int
    let total_shares: Int
    let total_forks: Int
    let created_at: String
    let updated_at: String
    let last_activity_at: String
}

struct ListCollaboratorDB: Codable {
    let id: String
    let list_id: String
    let user_id: String
    let permission_type: String // "edit" or "view"
    let invited_by: String
    let invited_at: String
    let accepted_at: String?
    let is_active: Bool
}

struct ListInviteDB: Codable {
    let id: String
    let list_id: String
    let email: String
    let permission_type: String
    let invited_by: String
    let invited_at: String
    let expires_at: String
    let is_used: Bool
}

struct ListTemplateDB: Codable {
    let id: String
    let name: String
    let description: String
    let category: String
    let tags: [String]
    let pin_count: Int
    let usage_count: Int
    let created_by: String
    let created_at: String
    let is_featured: Bool
}

struct ListActivityDB: Codable {
    let id: String
    let list_id: String
    let user_id: String
    let action_type: String // "pin_added", "pin_removed", "list_shared", etc.
    let details: String? // JSON string with additional details
    let created_at: String
}

struct PinDBInsert: Codable {
    let id: String
    let user_id: String
    let location_name: String
    let city: String
    let date: String
    let latitude: Double
    let longitude: Double
    let reaction: String
    let review_text: String
    let media_urls: [String]
    let mentioned_friends: [String]
    let star_rating: Double
    let distance: Double
    let author_handle: String
    let created_at: String
    let trip_name: String
}

// MARK: - User Model
struct User: Identifiable {
    let id: UUID
    var username: String
    let isPrivate: Bool
    var followers: [UUID]
    var following: [UUID]
    var followRequests: [UUID]
    var collections: [PinList] = []
    var favoriteSpots: [Pin] = []
    var activityFeed: [Pin] = []
    
    // Encryption support
    var publicKey: String? // Base64 encoded public key for E2E encryption
}

// MARK: - Encryption Models

struct UserPublicKey: Codable {
    let userId: String
    let publicKey: String
    let createdAt: Date
    let updatedAt: Date
}

struct UserPublicKeyDB: Codable {
    let user_id: String
    let public_key: String
    let created_at: String
    let updated_at: String
}

// MARK: - Conversion Extensions
extension Pin {
    func toMapItem() -> MKMapItem {
        let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = locationName
        return item
    }
    
    func toPinDB(userId: String) -> PinDBInsert {
        return PinDBInsert(
            id: id.uuidString,
            user_id: userId,
            location_name: locationName,
            city: city,
            date: date,
            latitude: latitude,
            longitude: longitude,
            reaction: reaction.rawValue,
            review_text: reviewText ?? "",
            media_urls: mediaURLs ?? [],
            mentioned_friends: mentionedFriends.map { $0.uuidString },
            star_rating: starRating ?? 0,
            distance: distance ?? 0,
            author_handle: authorHandle,
            created_at: ISO8601DateFormatter().string(from: createdAt),
            trip_name: tripName ?? ""
        )
    }
}

extension PinDB {
    func toPin() -> Pin {
        let mentionedFriendsUUIDs = (mentioned_friends ?? []).compactMap { UUID(uuidString: $0) }
        let createdAtDate = ISO8601DateFormatter().date(from: created_at) ?? Date()
        let pinReaction = Reaction(rawValue: reaction ?? "Loved It") ?? .lovedIt
        
        return Pin(
            id: UUID(uuidString: id) ?? UUID(),
            locationName: location_name,
            city: city,
            date: date,
            latitude: latitude,
            longitude: longitude,
            reaction: pinReaction,
            reviewText: review_text?.isEmpty == true ? nil : review_text,
            mediaURLs: media_urls?.isEmpty == true ? nil : media_urls,
            mentionedFriends: mentionedFriendsUUIDs,
            starRating: star_rating == 0 ? nil : star_rating,
            distance: distance == 0 ? nil : distance,
            authorHandle: author_handle ?? "@unknown",
            createdAt: createdAtDate,
            tripName: trip_name?.isEmpty == true ? nil : trip_name
        )
    }
}

extension ListDB {
    func toPinList(pins: [Pin] = []) -> PinList {
        return PinList(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            pins: pins,
            ownerId: UUID(uuidString: user_id) ?? UUID()
        )
    }
}

// MARK: - Additional List Models

struct ListTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: String
    let tags: [String]
    let pinCount: Int
    let usageCount: Int
    let createdBy: String
    let createdAt: Date
    let isFeatured: Bool
    let previewPins: [Pin] // Sample pins to show what the template contains
    
    var displayCategory: String {
        return category.capitalized
    }
    
    var displayUsage: String {
        return "\(usageCount) uses"
    }
}

struct ListShare: Identifiable, Codable {
    let id: UUID
    let listId: UUID
    let shareUrl: String
    let shareType: ListSharingType
    let createdAt: Date
    let expiresAt: Date?
    let viewCount: Int
    let isActive: Bool
    
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

struct ListCollaborator: Identifiable, Codable {
    let id: UUID
    let listId: UUID
    let userId: UUID
    let username: String
    let fullName: String?
    let permissionType: CollaboratorPermission
    let invitedBy: UUID
    let invitedAt: Date
    let acceptedAt: Date?
    let isActive: Bool
    
    var displayName: String {
        return fullName ?? username
    }
    
    var status: String {
        if acceptedAt != nil {
            return isActive ? "Active" : "Inactive"
        } else {
            return "Pending"
        }
    }
}

enum CollaboratorPermission: String, CaseIterable, Codable {
    case view = "view"
    case edit = "edit"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .view: return "Can View"
        case .edit: return "Can Edit"
        case .admin: return "Admin"
        }
    }
    
    var icon: String {
        switch self {
        case .view: return "eye"
        case .edit: return "pencil"
        case .admin: return "crown"
        }
    }
}

struct ListActivity: Identifiable, Codable {
    let id: UUID
    let listId: UUID
    let userId: UUID
    let username: String
    let actionType: ListActivityType
    let details: String?
    let createdAt: Date
    
    var displayText: String {
        switch actionType {
        case .pinAdded:
            return "\(username) added a pin"
        case .pinRemoved:
            return "\(username) removed a pin"
        case .listShared:
            return "\(username) shared the list"
        case .collaboratorAdded:
            return "\(username) added a collaborator"
        case .listRenamed:
            return "\(username) renamed the list"
        case .listDescriptionChanged:
            return "\(username) updated the description"
        }
    }
}

enum ListActivityType: String, CaseIterable, Codable {
    case pinAdded = "pin_added"
    case pinRemoved = "pin_removed"
    case listShared = "list_shared"
    case collaboratorAdded = "collaborator_added"
    case listRenamed = "list_renamed"
    case listDescriptionChanged = "list_description_changed"
}

// MARK: - Messaging Models

struct Message: Identifiable, Codable {
    let id: UUID
    let conversationId: String
    let senderId: String
    let content: String
    let createdAt: Date
    let messageType: MessageType
    
    // Enhanced status tracking
    var status: MessageStatus = .sending
    var readBy: [String] = []
    var editedAt: Date?
    var isDeleted: Bool = false
    
    // Rich media properties
    var imageURL: String?
    var locationData: MessageLocationData?
    var pinData: MessagePinData?
    
    // Encryption support
    var isEncrypted: Bool = false
    var encryptedContent: String? // Base64 encoded encrypted content
    var encryptionNonce: String? // Base64 encoded nonce
    var encryptionTag: String? // Base64 encoded authentication tag
    
    // Computed properties for UI
    var isFromCurrentUser: Bool {
        // This will be set based on the current user context
        return false // Placeholder - will be updated in UI
    }
    
    var isRead: Bool {
        return !readBy.isEmpty
    }
    
    var displayContent: String {
        switch messageType {
        case .text:
            return content
        case .image:
            return "📷 Photo"
        case .location:
            return "📍 Location"
        case .pin:
            return "📌 Pin shared"
        }
    }
    
    init(id: UUID = UUID(), conversationId: String, senderId: String, content: String, createdAt: Date = Date(), messageType: MessageType = .text) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.content = content
        self.createdAt = createdAt
        self.messageType = messageType
        self.status = .sending
    }
}

enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case location = "location"
    case pin = "pin"
}

enum MessageStatus: String, Codable, CaseIterable {
    case sending = "sending"
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
    
    var displayText: String {
        switch self {
        case .sending: return "Sending..."
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }
}

struct MessageLocationData: Codable {
    let latitude: Double
    let longitude: Double
    let name: String
}

struct MessagePinData: Codable {
    let id: String
    let locationName: String
    let city: String
    let latitude: Double
    let longitude: Double
    let reaction: String
    let reviewText: String
    let starRating: Double
    let authorHandle: String
}

struct Conversation: Identifiable {
    let id: UUID
    let participants: [Any] // AppUser - using Any to avoid scope issues
    let lastMessage: Message?
    let updatedAt: Date
    let unreadCount: Int
    let title: String // Set by SupabaseManager where AppUser is available
    
    // Computed properties for UI
    
    var subtitle: String {
        return lastMessage?.content ?? "No messages yet"
    }
    
    var timeString: String {
        let formatter = DateFormatter()
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(updatedAt, inSameDayAs: now) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: updatedAt)
        } else if calendar.isDate(updatedAt, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
            return "Yesterday"
        } else if calendar.isDate(updatedAt, equalTo: now, toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: updatedAt)
        } else {
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: updatedAt)
        }
    }
    
    init(id: UUID = UUID(), participants: [Any], lastMessage: Message? = nil, updatedAt: Date = Date(), unreadCount: Int = 0, title: String = "Conversation") {
        self.id = id
        self.participants = participants
        self.lastMessage = lastMessage
        self.updatedAt = updatedAt
        self.unreadCount = unreadCount
        self.title = title
    }
}

// MARK: - Messaging Database Models

struct ConversationDB: Codable {
    let id: String
    let created_at: String
    let updated_at: String
    let is_group: Bool
    let name: String?
}

struct MessageDB: Codable {
    let id: String
    let conversation_id: String
    let sender_id: String
    let content: String
    let message_type: String
    let created_at: String
    let edited_at: String?
    let is_deleted: Bool
    
    // Encryption support
    let is_encrypted: Bool?
    let encrypted_content: String?
    let encryption_nonce: String?
    let encryption_tag: String?
    
    func toMessage() -> Message {
        // Parse timestamp with support for fractional seconds
        func parseTimestamp(_ timestamp: String) -> Date? {
            // Try ISO8601 with fractional seconds first
            let iso8601WithFractionsFormatter = ISO8601DateFormatter()
            iso8601WithFractionsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = iso8601WithFractionsFormatter.date(from: timestamp) {
                return date
            }
            
            // Fallback to standard ISO8601
            let iso8601Formatter = ISO8601DateFormatter()
            return iso8601Formatter.date(from: timestamp)
        }
        
        let createdDate = parseTimestamp(created_at) ?? Date()
        
        var message = Message(
            id: UUID(uuidString: id) ?? UUID(),
            conversationId: conversation_id,
            senderId: sender_id,
            content: content,
            createdAt: createdDate,
            messageType: MessageType(rawValue: message_type) ?? .text
        )
        
        // Set encryption properties
        message.isEncrypted = is_encrypted ?? false
        message.encryptedContent = encrypted_content
        message.encryptionNonce = encryption_nonce
        message.encryptionTag = encryption_tag
        
        return message
    }
}

struct ConversationParticipantDB: Codable {
    let id: String
    let conversation_id: String
    let user_id: String
    let joined_at: String
    let last_read_at: String?
    let is_active: Bool
}

// Response models for our custom functions
struct ConversationDetailDB: Codable {
    let conversation_id: String
    let is_group: Bool
    let conversation_name: String?
    let created_at: String
    let updated_at: String
    let last_message_content: String?
    let last_message_sender_id: String?
    let last_message_created_at: String?
    let unread_count: Int
    let participant_ids: [String]
    let participant_usernames: [String]
    let participant_full_names: [String]
}

struct MessageDetailDB: Codable {
    let message_id: String
    let sender_id: String
    let sender_username: String
    let sender_full_name: String
    let content: String
    let message_type: String
    let created_at: String
    let edited_at: String?
}

// Insert models
struct MessageInsert: Codable {
    let id: String
    let conversation_id: String
    let sender_id: String
    let content: String
    let message_type: String
    let is_encrypted: Bool?
    let encrypted_content: String?
    let encryption_nonce: String?
    let encryption_tag: String?
    
    init(id: String, conversation_id: String, sender_id: String, content: String, message_type: String, is_encrypted: Bool? = nil, encrypted_content: String? = nil, encryption_nonce: String? = nil, encryption_tag: String? = nil) {
        self.id = id
        self.conversation_id = conversation_id
        self.sender_id = sender_id
        self.content = content
        self.message_type = message_type
        self.is_encrypted = is_encrypted
        self.encrypted_content = encrypted_content
        self.encryption_nonce = encryption_nonce
        self.encryption_tag = encryption_tag
    }
}

// MARK: - Conversion Extensions for Messaging

extension ConversationDetailDB {
    func toConversation(with participants: [Any], title: String) -> Conversation {
        // Parse dates with multiple formatters to handle different timestamp formats
        func parseTimestamp(_ timestamp: String) -> Date? {
            // Try ISO8601 with fractional seconds first
            let iso8601WithFractionsFormatter = ISO8601DateFormatter()
            iso8601WithFractionsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = iso8601WithFractionsFormatter.date(from: timestamp) {
                return date
            }
            
            // Fallback to standard ISO8601
            let iso8601Formatter = ISO8601DateFormatter()
            return iso8601Formatter.date(from: timestamp)
        }
        
        let createdDate = parseTimestamp(created_at) ?? Date()
        let updatedDate = parseTimestamp(updated_at) ?? Date()
        let lastMessageDate = last_message_created_at != nil ? parseTimestamp(last_message_created_at!) : nil
        
        // Create last message if available
        var lastMessage: Message? = nil
        if let content = last_message_content,
           let senderId = last_message_sender_id,
           let messageDate = lastMessageDate {
            lastMessage = Message(
                id: UUID(),
                conversationId: conversation_id,
                senderId: senderId,
                content: content,
                createdAt: messageDate,
                messageType: MessageType(rawValue: "text") ?? .text
            )
            print("✅ Created lastMessage: '\(content)' at \(messageDate)")
        } else {
            print("❌ Failed to create lastMessage:")
            print("  - content: \(last_message_content ?? "nil")")
            print("  - senderId: \(last_message_sender_id ?? "nil")")
            print("  - messageDate: \(lastMessageDate?.description ?? "nil")")
            print("  - timestamp: \(last_message_created_at ?? "nil")")
        }
        
        return Conversation(
            id: UUID(uuidString: conversation_id) ?? UUID(),
            participants: participants,
            lastMessage: lastMessage,
            updatedAt: updatedDate,
            unreadCount: unread_count,
            title: title
        )
    }
}

extension MessageDetailDB {
    func toMessage() -> Message {
        // Parse timestamp with support for fractional seconds
        func parseTimestamp(_ timestamp: String) -> Date? {
            // Try ISO8601 with fractional seconds first
            let iso8601WithFractionsFormatter = ISO8601DateFormatter()
            iso8601WithFractionsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = iso8601WithFractionsFormatter.date(from: timestamp) {
                return date
            }
            
            // Fallback to standard ISO8601
            let iso8601Formatter = ISO8601DateFormatter()
            return iso8601Formatter.date(from: timestamp)
        }
        
        let createdDate = parseTimestamp(created_at) ?? Date()
        
        return Message(
            id: UUID(uuidString: message_id) ?? UUID(),
            conversationId: "", // Will be set by the calling context
            senderId: sender_id,
            content: content,
            createdAt: createdDate,
            messageType: MessageType(rawValue: message_type) ?? .text
        )
    }
}

// MARK: - Location Models

struct LocationHistoryEntry: Identifiable, Codable {
    let id: String
    let userID: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let altitude: Double?
    let speed: Double?
    let heading: Double?
    let locationName: String?
    let city: String?
    let country: String?
    let createdAt: Date
    let isManual: Bool
    let activityType: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case latitude
        case longitude
        case accuracy
        case altitude
        case speed
        case heading
        case locationName = "location_name"
        case city
        case country
        case createdAt = "created_at"
        case isManual = "is_manual"
        case activityType = "activity_type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        accuracy = try container.decodeIfPresent(Double.self, forKey: .accuracy)
        altitude = try container.decodeIfPresent(Double.self, forKey: .altitude)
        speed = try container.decodeIfPresent(Double.self, forKey: .speed)
        heading = try container.decodeIfPresent(Double.self, forKey: .heading)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        isManual = try container.decode(Bool.self, forKey: .isManual)
        activityType = try container.decodeIfPresent(String.self, forKey: .activityType)
        
        // Parse the timestamp
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        createdAt = iso8601Formatter.date(from: createdAtString) ?? Date()
    }
}

struct Geofence: Identifiable, Codable {
    let id: String
    let userID: String
    let name: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let radius: Double
    let isActive: Bool
    let notificationType: String
    let createdAt: Date
    let updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case description
        case latitude
        case longitude
        case radius
        case isActive = "is_active"
        case notificationType = "notification_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        radius = try container.decode(Double.self, forKey: .radius)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        notificationType = try container.decode(String.self, forKey: .notificationType)
        
        // Parse timestamps
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        createdAt = iso8601Formatter.date(from: createdAtString) ?? Date()
        
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        updatedAt = iso8601Formatter.date(from: updatedAtString) ?? Date()
    }
}

struct GeofenceEvent: Identifiable, Codable {
    let id: String
    let userID: String
    let geofenceID: String
    let eventType: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date
    let geofenceName: String?
    let geofenceDescription: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case geofenceID = "geofence_id"
        case eventType = "event_type"
        case latitude
        case longitude
        case createdAt = "created_at"
        case geofences
    }
    
    private enum GeofenceKeys: String, CodingKey {
        case name
        case description
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        geofenceID = try container.decode(String.self, forKey: .geofenceID)
        eventType = try container.decode(String.self, forKey: .eventType)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        
        // Parse timestamp
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        createdAt = iso8601Formatter.date(from: createdAtString) ?? Date()
        
        // Parse nested geofence data
        if let geofenceContainer = try? container.nestedContainer(keyedBy: GeofenceKeys.self, forKey: .geofences) {
            geofenceName = try geofenceContainer.decodeIfPresent(String.self, forKey: .name)
            geofenceDescription = try geofenceContainer.decodeIfPresent(String.self, forKey: .description)
        } else {
            geofenceName = nil
            geofenceDescription = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userID, forKey: .userID)
        try container.encode(geofenceID, forKey: .geofenceID)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        
        // Encode timestamp
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(iso8601Formatter.string(from: createdAt), forKey: .createdAt)
        
        // Encode nested geofence data if available
        if geofenceName != nil || geofenceDescription != nil {
            var geofenceContainer = container.nestedContainer(keyedBy: GeofenceKeys.self, forKey: .geofences)
            try geofenceContainer.encodeIfPresent(geofenceName, forKey: .name)
            try geofenceContainer.encodeIfPresent(geofenceDescription, forKey: .description)
        }
    }
}

struct LocationPrivacySettings: Identifiable, Codable {
    let id: String?
    let userID: String
    let shareLocationWithFriends: Bool
    let shareLocationWithFollowers: Bool
    let shareLocationPublicly: Bool
    let shareLocationHistory: Bool
    let locationAccuracyLevel: String
    let autoDeleteHistoryDays: Int
    let allowLocationRequests: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case shareLocationWithFriends = "share_location_with_friends"
        case shareLocationWithFollowers = "share_location_with_followers"
        case shareLocationPublicly = "share_location_publicly"
        case shareLocationHistory = "share_location_history"
        case locationAccuracyLevel = "location_accuracy_level"
        case autoDeleteHistoryDays = "auto_delete_history_days"
        case allowLocationRequests = "allow_location_requests"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: String? = nil,
        userID: String,
        shareLocationWithFriends: Bool = true,
        shareLocationWithFollowers: Bool = false,
        shareLocationPublicly: Bool = false,
        shareLocationHistory: Bool = false,
        locationAccuracyLevel: String = "approximate",
        autoDeleteHistoryDays: Int = 30,
        allowLocationRequests: Bool = true,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userID = userID
        self.shareLocationWithFriends = shareLocationWithFriends
        self.shareLocationWithFollowers = shareLocationWithFollowers
        self.shareLocationPublicly = shareLocationPublicly
        self.shareLocationHistory = shareLocationHistory
        self.locationAccuracyLevel = locationAccuracyLevel
        self.autoDeleteHistoryDays = autoDeleteHistoryDays
        self.allowLocationRequests = allowLocationRequests
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        shareLocationWithFriends = try container.decode(Bool.self, forKey: .shareLocationWithFriends)
        shareLocationWithFollowers = try container.decode(Bool.self, forKey: .shareLocationWithFollowers)
        shareLocationPublicly = try container.decode(Bool.self, forKey: .shareLocationPublicly)
        shareLocationHistory = try container.decode(Bool.self, forKey: .shareLocationHistory)
        locationAccuracyLevel = try container.decode(String.self, forKey: .locationAccuracyLevel)
        autoDeleteHistoryDays = try container.decode(Int.self, forKey: .autoDeleteHistoryDays)
        allowLocationRequests = try container.decode(Bool.self, forKey: .allowLocationRequests)
        
        // Parse timestamps if present
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = iso8601Formatter.date(from: createdAtString)
        } else {
            createdAt = nil
        }
        
        if let updatedAtString = try container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt = iso8601Formatter.date(from: updatedAtString)
        } else {
            updatedAt = nil
        }
    }
}

// MARK: - Location Accuracy Levels

enum LocationAccuracyLevel: String, CaseIterable {
    case exact = "exact"
    case approximate = "approximate"
    case cityOnly = "city_only"
    case hidden = "hidden"
    
    var displayName: String {
        switch self {
        case .exact:
            return "Exact Location"
        case .approximate:
            return "Approximate Location"
        case .cityOnly:
            return "City Only"
        case .hidden:
            return "Hidden"
        }
    }
    
    var description: String {
        switch self {
        case .exact:
            return "Share your precise location"
        case .approximate:
            return "Share general area (~1km radius)"
        case .cityOnly:
            return "Share only your city"
        case .hidden:
            return "Don't share location"
        }
    }
}

// MARK: - Insert Models for Database Operations

struct LocationHistoryInsert: Codable {
    let user_id: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let altitude: Double?
    let speed: Double?
    let heading: Double?
    let location_name: String?
    let city: String?
    let country: String?
    let is_manual: Bool
    let activity_type: String
}

struct GeofenceInsert: Codable {
    let user_id: String
    let name: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let radius: Double
    let notification_type: String
}

struct GeofenceEventInsert: Codable {
    let user_id: String
    let geofence_id: String
    let event_type: String
    let latitude: Double
    let longitude: Double
}

struct LocationPrivacySettingsInsert: Codable {
    let user_id: String
    let share_location_with_friends: Bool
    let share_location_with_followers: Bool
    let share_location_publicly: Bool
    let share_location_history: Bool
    let location_accuracy_level: String
    let auto_delete_history_days: Int
    let allow_location_requests: Bool
}

// MARK: - Geofence Notification Types

enum GeofenceNotificationType: String, CaseIterable {
    case enter = "enter"
    case exit = "exit"
    case both = "both"
    
    var displayName: String {
        switch self {
        case .enter:
            return "When Entering"
        case .exit:
            return "When Leaving"
        case .both:
            return "Enter & Exit"
        }
    }
}

// MARK: - Activity Types

enum LocationActivityType: String, CaseIterable {
    case stationary = "stationary"
    case walking = "walking"
    case running = "running"
    case automotive = "automotive"
    case cycling = "cycling"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .stationary:
            return "Stationary"
        case .walking:
            return "Walking"
        case .running:
            return "Running"
        case .automotive:
            return "Driving"
        case .cycling:
            return "Cycling"
        case .unknown:
            return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .stationary:
            return "figure.stand"
        case .walking:
            return "figure.walk"
        case .running:
            return "figure.run"
        case .automotive:
            return "car.fill"
        case .cycling:
            return "bicycle"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

// MARK: - Social Features Models

// Comment model for pins
struct PinComment: Identifiable, Codable {
    let id: UUID
    let pinId: UUID
    let userId: String
    let username: String
    let userAvatarURL: String?
    let content: String
    let createdAt: Date
    let updatedAt: Date?
    let parentCommentId: UUID? // For reply threads
    var likesCount: Int
    var isLikedByCurrentUser: Bool
    
    init(id: UUID = UUID(), pinId: UUID, userId: String, username: String, userAvatarURL: String? = nil, content: String, createdAt: Date = Date(), updatedAt: Date? = nil, parentCommentId: UUID? = nil, likesCount: Int = 0, isLikedByCurrentUser: Bool = false) {
        self.id = id
        self.pinId = pinId
        self.userId = userId
        self.username = username
        self.userAvatarURL = userAvatarURL
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.parentCommentId = parentCommentId
        self.likesCount = likesCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }
}

// Reaction model for pins (likes, hearts, etc.)
struct PinReaction: Identifiable, Codable {
    let id: UUID
    let pinId: UUID
    let userId: String
    let username: String
    let userAvatarURL: String?
    let reactionType: PinReactionType
    let createdAt: Date
    
    init(id: UUID = UUID(), pinId: UUID, userId: String, username: String, userAvatarURL: String? = nil, reactionType: PinReactionType, createdAt: Date = Date()) {
        self.id = id
        self.pinId = pinId
        self.userId = userId
        self.username = username
        self.userAvatarURL = userAvatarURL
        self.reactionType = reactionType
        self.createdAt = createdAt
    }
}

// Types of reactions users can leave on pins
enum PinReactionType: String, CaseIterable, Codable {
    case like = "like"
    case love = "love"
    case wow = "wow"
    case haha = "haha"
    case sad = "sad"
    case angry = "angry"
    
    var emoji: String {
        switch self {
        case .like: return "👍"
        case .love: return "❤️"
        case .wow: return "😮"
        case .haha: return "😂"
        case .sad: return "😢"
        case .angry: return "😠"
        }
    }
    
    var systemImage: String {
        switch self {
        case .like: return "hand.thumbsup.fill"
        case .love: return "heart.fill"
        case .wow: return "face.dazzled"
        case .haha: return "face.laughing"
        case .sad: return "face.frowning"
        case .angry: return "face.angry"
        }
    }
}

// Friend activity feed item
struct FriendActivity: Identifiable, Codable {
    let id: UUID
    let userId: String
    let username: String
    let userAvatarURL: String?
    let activityType: FriendActivityType
    let relatedPinId: UUID?
    let relatedPin: Pin?
    let locationName: String?
    let description: String
    let createdAt: Date
    
    init(id: UUID = UUID(), userId: String, username: String, userAvatarURL: String? = nil, activityType: FriendActivityType, relatedPinId: UUID? = nil, relatedPin: Pin? = nil, locationName: String? = nil, description: String, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.username = username
        self.userAvatarURL = userAvatarURL
        self.activityType = activityType
        self.relatedPinId = relatedPinId
        self.relatedPin = relatedPin
        self.locationName = locationName
        self.description = description
        self.createdAt = createdAt
    }
}

// Types of friend activities to show in feed
enum FriendActivityType: String, CaseIterable, Codable {
    case visitedPlace = "visited_place"
    case ratedPlace = "rated_place"
    case addedToList = "added_to_list"
    case commentedOnPin = "commented_on_pin"
    case reactedToPin = "reacted_to_pin"
    case createdList = "created_list"
    case followedUser = "followed_user"
    case sharedLocation = "shared_location"
    
    var actionText: String {
        switch self {
        case .visitedPlace: return "visited a place"
        case .ratedPlace: return "rated a place"
        case .addedToList: return "added to list"
        case .commentedOnPin: return "commented on pin"
        case .reactedToPin: return "reacted to pin"
        case .createdList: return "created a list"
        case .followedUser: return "followed a user"
        case .sharedLocation: return "shared location"
        }
    }
    
    var systemImage: String {
        switch self {
        case .visitedPlace: return "location.fill"
        case .ratedPlace: return "star.fill"
        case .addedToList: return "plus.square.fill"
        case .commentedOnPin: return "bubble.left.fill"
        case .reactedToPin: return "heart.fill"
        case .createdList: return "list.bullet"
        case .followedUser: return "person.fill.badge.plus"
        case .sharedLocation: return "location.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .visitedPlace: return .blue
        case .ratedPlace: return .yellow
        case .addedToList: return .green
        case .commentedOnPin: return .purple
        case .reactedToPin: return .red
        case .createdList: return .orange
        case .followedUser: return .blue
        case .sharedLocation: return .cyan
        }
    }
}

// Friend recommendation based on activity
struct FriendRecommendation: Identifiable, Codable {
    let id: UUID
    let recommendedPlace: Pin
    let recommendingFriendIds: [String] // Store friend IDs instead of full AppUser objects
    let recommendingFriendUsernames: [String] // Store usernames for display
    let averageRating: Double
    let totalVisits: Int
    let recentVisits: [Date]
    let reasonText: String
    let confidence: Double // 0.0 to 1.0 confidence score
    
    init(id: UUID = UUID(), recommendedPlace: Pin, recommendingFriendIds: [String], recommendingFriendUsernames: [String], averageRating: Double, totalVisits: Int, recentVisits: [Date], reasonText: String, confidence: Double) {
        self.id = id
        self.recommendedPlace = recommendedPlace
        self.recommendingFriendIds = recommendingFriendIds
        self.recommendingFriendUsernames = recommendingFriendUsernames
        self.averageRating = averageRating
        self.totalVisits = totalVisits
        self.recentVisits = recentVisits
        self.reasonText = reasonText
        self.confidence = confidence
    }
}

// MARK: - Database Models for Social Features

struct PinCommentDB: Codable {
    let id: String
    let pin_id: String
    let user_id: String
    let username: String
    let user_avatar_url: String?
    let content: String
    let created_at: String
    let updated_at: String?
    let parent_comment_id: String?
    let likes_count: Int
}

struct PinReactionDB: Codable {
    let id: String
    let pin_id: String
    let user_id: String
    let username: String
    let user_avatar_url: String?
    let reaction_type: String
    let created_at: String
}

struct CommentLikeDB: Codable {
    let id: String
    let comment_id: String
    let user_id: String
    let created_at: String
}

struct FriendActivityDB: Codable {
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

// MARK: - Conversion Extensions for Social Features

extension PinCommentDB {
    func toPinComment(isLikedByCurrentUser: Bool = false) -> PinComment {
        return PinComment(
            id: UUID(uuidString: id) ?? UUID(),
            pinId: UUID(uuidString: pin_id) ?? UUID(),
            userId: user_id,
            username: username,
            userAvatarURL: user_avatar_url,
            content: content,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date(),
            updatedAt: updated_at != nil ? ISO8601DateFormatter().date(from: updated_at!) : nil,
            parentCommentId: parent_comment_id != nil ? UUID(uuidString: parent_comment_id!) : nil,
            likesCount: likes_count,
            isLikedByCurrentUser: isLikedByCurrentUser
        )
    }
}

extension PinReactionDB {
    func toPinReaction() -> PinReaction {
        return PinReaction(
            id: UUID(uuidString: id) ?? UUID(),
            pinId: UUID(uuidString: pin_id) ?? UUID(),
            userId: user_id,
            username: username,
            userAvatarURL: user_avatar_url,
            reactionType: PinReactionType(rawValue: reaction_type) ?? .like,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date()
        )
    }
}

extension FriendActivityDB {
    func toFriendActivity(relatedPin: Pin? = nil) -> FriendActivity {
        return FriendActivity(
            id: UUID(uuidString: id) ?? UUID(),
            userId: user_id,
            username: username,
            userAvatarURL: user_avatar_url,
            activityType: FriendActivityType(rawValue: activity_type) ?? .visitedPlace,
            relatedPinId: related_pin_id != nil ? UUID(uuidString: related_pin_id!) : nil,
            relatedPin: relatedPin,
            locationName: location_name,
            description: description,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date()
        )
    }
}

// MARK: - Enhanced Pin Model with Social Features

extension Pin {
    // Add social engagement counts
    var commentsCount: Int {
        // This will be populated from the database
        return 0
    }
    
    var reactionsCount: Int {
        // This will be populated from the database
        return 0
    }
    
    var isLikedByCurrentUser: Bool {
        // This will be populated from the database
        return false
    }
    
    var topReactions: [PinReactionType] {
        // This will be populated from the database
        return []
    }
}

// MARK: - Video Content Models

struct VideoContent: Identifiable, Codable {
    let id: UUID
    let videoURL: String
    let thumbnailURL: String?
    let duration: TimeInterval
    let authorId: String
    let authorUsername: String
    let authorAvatarURL: String?
    let caption: String
    let hashtags: [String]
    let mentionedUsers: [String]
    let locationName: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    let updatedAt: Date
    var viewsCount: Int
    var likesCount: Int
    var commentsCount: Int
    var sharesCount: Int
    var isLikedByCurrentUser: Bool
    var isBookmarkedByCurrentUser: Bool
    var musicInfo: VideoMusicInfo?
    
    init(id: UUID = UUID(), videoURL: String, thumbnailURL: String? = nil, duration: TimeInterval, authorId: String, authorUsername: String, authorAvatarURL: String? = nil, caption: String, hashtags: [String] = [], mentionedUsers: [String] = [], locationName: String? = nil, city: String? = nil, latitude: Double? = nil, longitude: Double? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), viewsCount: Int = 0, likesCount: Int = 0, commentsCount: Int = 0, sharesCount: Int = 0, isLikedByCurrentUser: Bool = false, isBookmarkedByCurrentUser: Bool = false, musicInfo: VideoMusicInfo? = nil) {
        self.id = id
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.authorAvatarURL = authorAvatarURL
        self.caption = caption
        self.hashtags = hashtags
        self.mentionedUsers = mentionedUsers
        self.locationName = locationName
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.viewsCount = viewsCount
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.sharesCount = sharesCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.isBookmarkedByCurrentUser = isBookmarkedByCurrentUser
        self.musicInfo = musicInfo
    }
    
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }
    
    var displayLocation: String? {
        guard let locationName = locationName else { return nil }
        if let city = city {
            return "\(locationName), \(city)"
        }
        return locationName
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

struct VideoMusicInfo: Codable {
    let title: String
    let artist: String
    let albumArt: String?
    let spotifyURL: String?
    let appleMusicURL: String?
}

struct VideoComment: Identifiable, Codable {
    let id: UUID
    let videoId: UUID
    let authorId: String
    let authorUsername: String
    let authorAvatarURL: String?
    let content: String
    let createdAt: Date
    let updatedAt: Date?
    let parentCommentId: UUID? // For reply threads
    var likesCount: Int
    var isLikedByCurrentUser: Bool
    var repliesCount: Int
    
    init(id: UUID = UUID(), videoId: UUID, authorId: String, authorUsername: String, authorAvatarURL: String? = nil, content: String, createdAt: Date = Date(), updatedAt: Date? = nil, parentCommentId: UUID? = nil, likesCount: Int = 0, isLikedByCurrentUser: Bool = false, repliesCount: Int = 0) {
        self.id = id
        self.videoId = videoId
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.authorAvatarURL = authorAvatarURL
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.parentCommentId = parentCommentId
        self.likesCount = likesCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.repliesCount = repliesCount
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

struct VideoLike: Identifiable, Codable {
    let id: UUID
    let videoId: UUID
    let userId: String
    let username: String
    let userAvatarURL: String?
    let createdAt: Date
    
    init(id: UUID = UUID(), videoId: UUID, userId: String, username: String, userAvatarURL: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.videoId = videoId
        self.userId = userId
        self.username = username
        self.userAvatarURL = userAvatarURL
        self.createdAt = createdAt
    }
}

enum VideoFeedFilter: String, CaseIterable {
    case forYou = "For You"
    case following = "Following"
    case trending = "Trending"
    case nearby = "Nearby"
    case saved = "Saved"
    
    var icon: String {
        switch self {
        case .forYou: return "sparkles"
        case .following: return "person.2.fill"
        case .trending: return "flame.fill"
        case .nearby: return "location.fill"
        case .saved: return "bookmark.fill"
        }
    }
}

// MARK: - Video Database Models

struct VideoContentDB: Codable {
    let id: String
    let video_url: String
    let thumbnail_url: String?
    let duration: Double
    let author_id: String
    let author_username: String
    let author_avatar_url: String?
    let caption: String
    let hashtags: [String]?
    let mentioned_users: [String]?
    let location_name: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let created_at: String
    let updated_at: String
    let views_count: Int
    let likes_count: Int
    let comments_count: Int
    let shares_count: Int
    let music_title: String?
    let music_artist: String?
    let music_album_art: String?
    let music_spotify_url: String?
    let music_apple_music_url: String?
}

struct VideoCommentDB: Codable {
    let id: String
    let video_id: String
    let author_id: String
    let author_username: String
    let author_avatar_url: String?
    let content: String
    let created_at: String
    let updated_at: String?
    let parent_comment_id: String?
    let likes_count: Int
    let replies_count: Int
}

struct VideoLikeDB: Codable {
    let id: String
    let video_id: String
    let user_id: String
    let username: String
    let user_avatar_url: String?
    let created_at: String
}

struct VideoBookmarkDB: Codable {
    let id: String
    let video_id: String
    let user_id: String
    let created_at: String
}

struct VideoViewDB: Codable {
    let id: String
    let video_id: String
    let user_id: String
    let watch_duration: TimeInterval
    let created_at: String
}

struct VideoCommentLikeDB: Codable {
    let id: String
    let comment_id: String
    let user_id: String
    let created_at: String
}

// MARK: - Video Extensions

extension VideoContentDB {
    func toVideoContent(isLikedByCurrentUser: Bool = false, isBookmarkedByCurrentUser: Bool = false) -> VideoContent {
        let musicInfo: VideoMusicInfo? = {
            guard let title = music_title, let artist = music_artist else { return nil }
            return VideoMusicInfo(
                title: title,
                artist: artist,
                albumArt: music_album_art,
                spotifyURL: music_spotify_url,
                appleMusicURL: music_apple_music_url
            )
        }()
        
        return VideoContent(
            id: UUID(uuidString: id) ?? UUID(),
            videoURL: video_url,
            thumbnailURL: thumbnail_url,
            duration: duration,
            authorId: author_id,
            authorUsername: author_username,
            authorAvatarURL: author_avatar_url,
            caption: caption,
            hashtags: hashtags ?? [],
            mentionedUsers: mentioned_users ?? [],
            locationName: location_name,
            city: city,
            latitude: latitude,
            longitude: longitude,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: updated_at) ?? Date(),
            viewsCount: views_count,
            likesCount: likes_count,
            commentsCount: comments_count,
            sharesCount: shares_count,
            isLikedByCurrentUser: isLikedByCurrentUser,
            isBookmarkedByCurrentUser: isBookmarkedByCurrentUser,
            musicInfo: musicInfo
        )
    }
}

extension VideoContent {
    func toVideoContentDB() -> VideoContentDB {
        return VideoContentDB(
            id: id.uuidString,
            video_url: videoURL,
            thumbnail_url: thumbnailURL,
            duration: duration,
            author_id: authorId,
            author_username: authorUsername,
            author_avatar_url: authorAvatarURL,
            caption: caption,
            hashtags: hashtags.isEmpty ? nil : hashtags,
            mentioned_users: mentionedUsers.isEmpty ? nil : mentionedUsers,
            location_name: locationName,
            city: city,
            latitude: latitude,
            longitude: longitude,
            created_at: ISO8601DateFormatter().string(from: createdAt),
            updated_at: ISO8601DateFormatter().string(from: updatedAt),
            views_count: viewsCount,
            likes_count: likesCount,
            comments_count: commentsCount,
            shares_count: sharesCount,
            music_title: musicInfo?.title,
            music_artist: musicInfo?.artist,
            music_album_art: musicInfo?.albumArt,
            music_spotify_url: musicInfo?.spotifyURL,
            music_apple_music_url: musicInfo?.appleMusicURL
        )
    }
}

extension VideoCommentDB {
    func toVideoComment(isLikedByCurrentUser: Bool = false) -> VideoComment {
        return VideoComment(
            id: UUID(uuidString: id) ?? UUID(),
            videoId: UUID(uuidString: video_id) ?? UUID(),
            authorId: author_id,
            authorUsername: author_username,
            authorAvatarURL: author_avatar_url,
            content: content,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date(),
            updatedAt: updated_at != nil ? ISO8601DateFormatter().date(from: updated_at!) : nil,
            parentCommentId: parent_comment_id != nil ? UUID(uuidString: parent_comment_id!) : nil,
            likesCount: likes_count,
            isLikedByCurrentUser: isLikedByCurrentUser,
            repliesCount: replies_count
        )
    }
}

extension VideoLikeDB {
    func toVideoLike() -> VideoLike {
        return VideoLike(
            id: UUID(uuidString: id) ?? UUID(),
            videoId: UUID(uuidString: video_id) ?? UUID(),
            userId: user_id,
            username: username,
            userAvatarURL: user_avatar_url,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date()
        )
    }
}

// MARK: - Encrypted Location Sharing Models

// Sharing tier enum for location privacy
enum SharingTier: String, CaseIterable, Codable {
    case precise = "precise"
    case approximate = "approximate"
    case city = "city"
    
    var displayName: String {
        switch self {
        case .precise: return "Precise Location"
        case .approximate: return "Approximate Location"
        case .city: return "City Only"
        }
    }
    
    var description: String {
        switch self {
        case .precise: return "Share exact location"
        case .approximate: return "Share location within ~100m"
        case .city: return "Share city only"
        }
    }
    
    var icon: String {
        switch self {
        case .precise: return "location.fill"
        case .approximate: return "location.circle"
        case .city: return "building.2.fill"
        }
    }
}

// Friend Group model
struct FriendGroup: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let sharingTier: SharingTier
    let createdAt: Date
    var memberIds: [UUID] = []
    
    init(id: UUID = UUID(), userId: UUID, name: String, sharingTier: SharingTier, createdAt: Date = Date(), memberIds: [UUID] = []) {
        self.id = id
        self.userId = userId
        self.name = name
        self.sharingTier = sharingTier
        self.createdAt = createdAt
        self.memberIds = memberIds
    }
}

// Friend Group Member model
struct FriendGroupMember: Identifiable, Codable {
    let id: UUID = UUID()
    let groupId: UUID
    let memberUserId: UUID
    let createdAt: Date
    
    init(groupId: UUID, memberUserId: UUID, createdAt: Date = Date()) {
        self.groupId = groupId
        self.memberUserId = memberUserId
        self.createdAt = createdAt
    }
}

// Shared Location model for encrypted location data
struct SharedLocation: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let senderUserId: UUID
    let recipientUserId: UUID
    let ciphertext: String
    let nonce: String
    let tag: String
    let expiresAt: Date
    
    init(id: UUID = UUID(), createdAt: Date = Date(), senderUserId: UUID, recipientUserId: UUID, ciphertext: String, nonce: String, tag: String, expiresAt: Date) {
        self.id = id
        self.createdAt = createdAt
        self.senderUserId = senderUserId
        self.recipientUserId = recipientUserId
        self.ciphertext = ciphertext
        self.nonce = nonce
        self.tag = tag
        self.expiresAt = expiresAt
    }
    
    var isActive: Bool {
        return expiresAt > Date()
    }
}

// MARK: - Database Models for Encrypted Location Sharing

struct FriendGroupDB: Codable {
    let id: String
    let user_id: String
    let name: String
    let sharing_tier: String
    let created_at: String
}

struct FriendGroupMemberDB: Codable {
    let group_id: String
    let member_user_id: String
    let created_at: String
}

struct SharedLocationDB: Codable {
    let id: String
    let created_at: String
    let sender_user_id: String
    let recipient_user_id: String
    let ciphertext: String
    let nonce: String
    let tag: String
    let expires_at: String
}

// MARK: - Extensions for Database Conversion

extension FriendGroupDB {
    func toFriendGroup() -> FriendGroup {
        return FriendGroup(
            id: UUID(uuidString: id) ?? UUID(),
            userId: UUID(uuidString: user_id) ?? UUID(),
            name: name,
            sharingTier: SharingTier(rawValue: sharing_tier) ?? .approximate,
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date(),
            memberIds: []
        )
    }
}

extension FriendGroup {
    func toFriendGroupDB() -> FriendGroupDB {
        return FriendGroupDB(
            id: id.uuidString,
            user_id: userId.uuidString,
            name: name,
            sharing_tier: sharingTier.rawValue,
            created_at: ISO8601DateFormatter().string(from: createdAt)
        )
    }
}

extension SharedLocationDB {
    func toSharedLocation() -> SharedLocation {
        return SharedLocation(
            id: UUID(uuidString: id) ?? UUID(),
            createdAt: ISO8601DateFormatter().date(from: created_at) ?? Date(),
            senderUserId: UUID(uuidString: sender_user_id) ?? UUID(),
            recipientUserId: UUID(uuidString: recipient_user_id) ?? UUID(),
            ciphertext: ciphertext,
            nonce: nonce,
            tag: tag,
            expiresAt: ISO8601DateFormatter().date(from: expires_at) ?? Date()
        )
    }
}

extension SharedLocation {
    func toSharedLocationDB() -> SharedLocationDB {
        return SharedLocationDB(
            id: id.uuidString,
            created_at: ISO8601DateFormatter().string(from: createdAt),
            sender_user_id: senderUserId.uuidString,
            recipient_user_id: recipientUserId.uuidString,
            ciphertext: ciphertext,
            nonce: nonce,
            tag: tag,
            expires_at: ISO8601DateFormatter().string(from: expiresAt)
        )
    }
}

// MARK: - Additional Models for Activity Feed

struct UserPreferences: Codable {
    let userId: String
    let preferredCategories: [String]
    let favoriteCuisines: [String]
    let activityTypes: [String]
    let priceRangeMin: Int
    let priceRangeMax: Int
    let distancePreferenceKm: Double
    let avoidCategories: [String]
    let recommendationFrequency: String
}

struct ActivityFeedSubscriptionDB: Codable {
    let id: String
    let subscriber_user_id: String
    let publisher_user_id: String
    let subscription_type: String
    let activity_types: [String]
    let is_active: Bool
    let created_at: String
}

// MARK: - Advanced Social Features Models (v0.75.0)

// MARK: - Stories/Moments System

enum StoryContentType: String, Codable, CaseIterable {
    case photo = "photo"
    case video = "video"
    case text = "text"
    
    var icon: String {
        switch self {
        case .photo: return "photo"
        case .video: return "video"
        case .text: return "text.quote"
        }
    }
}

enum StoryVisibility: String, Codable, CaseIterable {
    case publicVisibility = "public"
    case friends = "friends"
    case privateVisibility = "private"
    
    var icon: String {
        switch self {
        case .publicVisibility: return "globe"
        case .friends: return "person.2"
        case .privateVisibility: return "lock"
        }
    }
    
    var displayName: String {
        switch self {
        case .publicVisibility: return "Public"
        case .friends: return "Friends"
        case .privateVisibility: return "Private"
        }
    }
}

struct LocationStory: Identifiable, Codable {
    let id: UUID
    let userId: String
    let username: String
    let userAvatarURL: String?
    let locationId: UUID?
    let locationName: String
    let locationLatitude: Double
    let locationLongitude: Double
    let contentType: StoryContentType
    let mediaURL: String?
    let thumbnailURL: String?
    let caption: String?
    let visibility: StoryVisibility
    let viewCount: Int
    let isActive: Bool
    let expiresAt: Date
    let createdAt: Date
    let updatedAt: Date
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: locationLatitude, longitude: locationLongitude)
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var timeRemaining: TimeInterval {
        expiresAt.timeIntervalSince(Date())
    }
}

struct StoryView: Identifiable, Codable {
    let id: UUID
    let storyId: UUID
    let viewerId: String
    let viewedAt: Date
}

// MARK: - Group Lists System

struct GroupList: Identifiable, Codable {
    let id: UUID
    let listId: UUID
    let ownerId: String
    let isCollaborative: Bool
    let memberCanAdd: Bool
    let memberCanRemove: Bool
    let memberCanInvite: Bool
    let requireApproval: Bool
    let createdAt: Date
    let updatedAt: Date
}

enum GroupListRole: String, Codable, CaseIterable {
    case owner = "owner"
    case admin = "admin"
    case member = "member"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .owner: return "crown"
        case .admin: return "star"
        case .member: return "person"
        }
    }
}

struct GroupListMember: Identifiable, Codable {
    let id: UUID
    let groupListId: UUID
    let userId: String
    let role: GroupListRole
    let permissions: GroupListPermissions
    let invitedBy: String?
    let joinedAt: Date
}

struct GroupListPermissions: Codable {
    let canAdd: Bool
    let canRemove: Bool
    let canInvite: Bool
}

enum GroupListActivityType: String, Codable, CaseIterable {
    case addedPin = "added_pin"
    case removedPin = "removed_pin"
    case invitedMember = "invited_member"
    case joined = "joined"
    case left = "left"
    case changedSettings = "changed_settings"
    case renamedList = "renamed_list"
    
    var actionText: String {
        switch self {
        case .addedPin: return "added a pin"
        case .removedPin: return "removed a pin"
        case .invitedMember: return "invited"
        case .joined: return "joined the list"
        case .left: return "left the list"
        case .changedSettings: return "changed settings"
        case .renamedList: return "renamed the list"
        }
    }
}

struct GroupListActivity: Identifiable, Codable {
    let id: UUID
    let groupListId: UUID
    let userId: String
    let username: String
    let activityType: GroupListActivityType
    let relatedPinId: UUID?
    let relatedUserId: UUID?
    let createdAt: Date
}

// MARK: - Location Reviews System

struct LocationReview: Identifiable, Codable {
    let id: UUID
    let pinId: UUID
    let userId: String
    let username: String
    let userAvatarURL: String?
    let rating: Int
    let title: String?
    let content: String
    let pros: [String]
    let cons: [String]
    let mediaURLs: [String]
    let visitDate: Date?
    let priceRange: Int?
    let tags: [String]
    let helpfulCount: Int
    let replyCount: Int
    let isVerifiedVisit: Bool
    let isEdited: Bool
    let createdAt: Date
    let updatedAt: Date
    
    var priceRangeDisplay: String {
        guard let range = priceRange else { return "" }
        return String(repeating: "$", count: range)
    }
}

struct ReviewResponse: Identifiable, Codable {
    let id: UUID
    let reviewId: UUID
    let userId: String
    let username: String
    let content: String
    let isOwnerResponse: Bool
    let createdAt: Date
}

struct ReviewHelpfulVote: Identifiable, Codable {
    let id: UUID
    let reviewId: UUID
    let userId: String
    let isHelpful: Bool
    let createdAt: Date
}

// MARK: - Social Reactions System

enum ReactionType: String, Codable, CaseIterable {
    case like = "like"
    case love = "love"
    case wow = "wow"
    case haha = "haha"
    case sad = "sad"
    case angry = "angry"
    case fire = "fire"
    case star = "star"
    case celebrate = "celebrate"
    case support = "support"
    case clap = "clap"
    
    var emoji: String {
        switch self {
        case .like: return "👍"
        case .love: return "❤️"
        case .wow: return "😮"
        case .haha: return "😂"
        case .sad: return "😢"
        case .angry: return "😡"
        case .fire: return "🔥"
        case .star: return "⭐"
        case .celebrate: return "🎉"
        case .support: return "🤝"
        case .clap: return "👏"
        }
    }
    
    var color: Color {
        switch self {
        case .like: return .blue
        case .love: return .red
        case .wow: return .yellow
        case .haha: return .orange
        case .sad: return .blue
        case .angry: return .red
        case .fire: return .orange
        case .star: return .yellow
        case .celebrate: return .purple
        case .support: return .green
        case .clap: return .yellow
        }
    }
}

struct SocialPinReaction: Identifiable, Codable {
    let id: UUID
    let pinId: UUID
    let userId: String
    let reactionType: ReactionType
    let createdAt: Date
}

struct ActivityReaction: Identifiable, Codable {
    let id: UUID
    let activityId: UUID
    let userId: String
    let reactionType: ReactionType
    let createdAt: Date
}

struct StoryReaction: Identifiable, Codable {
    let id: UUID
    let storyId: UUID
    let userId: String
    let reactionType: ReactionType
    let createdAt: Date
}

// MARK: - Database Conversion Models

struct LocationStoryDB: Codable {
    let id: String
    let user_id: String
    let username: String
    let user_avatar_url: String?
    let location_id: String?
    let location_name: String
    let location_latitude: Double
    let location_longitude: Double
    let content_type: String
    let media_url: String?
    let thumbnail_url: String?
    let caption: String?
    let visibility: String
    let view_count: Int
    let is_active: Bool
    let expires_at: String
    let created_at: String
    let updated_at: String
}

struct GroupListDB: Codable {
    let id: String
    let list_id: String
    let owner_id: String
    let is_collaborative: Bool
    let member_can_add: Bool
    let member_can_remove: Bool
    let member_can_invite: Bool
    let require_approval: Bool
    let created_at: String
    let updated_at: String
}

struct LocationReviewDB: Codable {
    let id: String
    let pin_id: String
    let user_id: String
    let username: String
    let user_avatar_url: String?
    let rating: Int
    let title: String?
    let content: String
    let pros: [String]
    let cons: [String]
    let media_urls: [String]
    let visit_date: String?
    let price_range: Int?
    let tags: [String]
    let helpful_count: Int
    let reply_count: Int
    let is_verified_visit: Bool
    let is_edited: Bool
    let created_at: String
    let updated_at: String
}


