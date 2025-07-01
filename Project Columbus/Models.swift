//
//  Models.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//
import Foundation
import CoreLocation
import MapKit

// MARK: - Reaction Enum
enum Reaction: String, CaseIterable, Codable {
    case lovedIt = "Loved It"
    case wantToGo = "Want to Go"
}

// MARK: - Pin Model
struct Pin: Identifiable, Equatable, Codable {
    let id: UUID
    let locationName: String
    let city: String
    let date: String
    let latitude: Double
    let longitude: Double
    let reaction: Reaction
    // --- New properties ---
    let reviewText: String?
    let mediaURLs: [String]?
    let mentionedFriends: [UUID]
    let starRating: Double?
    let distance: Double?
    let authorHandle: String
    let createdAt: Date
    let tripName: String?
    
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

// MARK: - List Model (Updated from PinCollection)
struct PinList: Identifiable, Codable {
    let id: UUID
    let name: String
    var pins: [Pin]
    
    init(id: UUID = UUID(), name: String, pins: [Pin] = []) {
        self.id = id
        self.name = name
        self.pins = pins
    }
}

// MARK: - Legacy PinCollection (for backward compatibility)
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
            pins: pins
        )
    }
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
    let conversation_id: String
    let sender_id: String
    let content: String
    let message_type: String
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
