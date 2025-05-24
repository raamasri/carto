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
    
    // Computed properties for UI
    var isFromCurrentUser: Bool {
        // This will be set based on the current user context
        return false // Placeholder - will be updated in UI
    }
    
    init(id: UUID = UUID(), conversationId: String, senderId: String, content: String, createdAt: Date = Date(), messageType: MessageType = .text) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.content = content
        self.createdAt = createdAt
        self.messageType = messageType
    }
}

enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case location = "location"
    case pin = "pin"
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
        // Parse dates
        let iso8601Formatter = ISO8601DateFormatter()
        let createdDate = iso8601Formatter.date(from: created_at) ?? Date()
        let updatedDate = iso8601Formatter.date(from: updated_at) ?? Date()
        let lastMessageDate = last_message_created_at != nil ? iso8601Formatter.date(from: last_message_created_at!) : nil
        
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
        let iso8601Formatter = ISO8601DateFormatter()
        let createdDate = iso8601Formatter.date(from: created_at) ?? Date()
        
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
