//
//  ListService.swift
//  Project Columbus
//
//  Extracted from SupabaseManager
//

import Supabase
import Foundation

class ListService {
    private let client: SupabaseClient
    private let pinService: PinService
    
    init(client: SupabaseClient) {
        self.client = client
        self.pinService = PinService(client: client)
    }
    
    // MARK: - Lists Management
    
    /// Creates a new list for the user
    func createList(name: String) async throws -> String {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let list = ["user_id": session.user.id.uuidString, "name": name]
        
        let response: [ListDB] = try await client
            .from("lists")
            .insert(list)
            .select()
            .execute()
            .value
        
        return response.first?.id ?? ""
    }
    
    /// Fetches all lists for the current user
    func getUserLists() async -> [PinList] {
        print("📱 ListService: getUserLists() called")
        
        guard let session = try? await client.auth.session else {
            print("❌ ListService: No session available in getUserLists()")
            return []
        }
        
        print("📱 ListService: Session found, user ID: \(session.user.id.uuidString)")
        
        do {
            let listsDB: [ListDB] = try await client
                .from("lists")
                .select("*")
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
                .value
            
            print("📱 ListService: Found \(listsDB.count) lists in database")
            
            var lists: [PinList] = []
            
            for listDB in listsDB {
                print("📱 ListService: Processing list: \(listDB.name)")
                let pins = await pinService.getPinsForList(listId: listDB.id)
                print("📱 ListService: List '\(listDB.name)' has \(pins.count) pins")
                let list = listDB.toPinList(pins: pins)
                lists.append(list)
            }
            
            print("📱 ListService: Returning \(lists.count) lists")
            return lists
        } catch {
            print("❌ Failed to fetch lists: \(error)")
            return []
        }
    }
    
    /// Fetches all lists for a specific user
    func getUserLists(for userID: String) async -> [PinList] {
        do {
            let listsDB: [ListDB] = try await client
                .from("lists")
                .select("*")
                .eq("user_id", value: userID)
                .execute()
                .value
            
            var lists: [PinList] = []
            
            for listDB in listsDB {
                let pins = await pinService.getPinsForList(listId: listDB.id)
                let list = listDB.toPinList(pins: pins)
                lists.append(list)
            }
            
            return lists
        } catch {
            print("❌ Failed to fetch lists for user \(userID): \(error)")
            return []
        }
    }
    
    /// Deletes a list
    func deleteList(listId: String) async -> Bool {
        guard let session = try? await client.auth.session else { return false }
        
        do {
            _ = try await client
                .from("lists")
                .delete()
                .eq("id", value: listId)
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
            
            return true
        } catch {
            print("❌ Failed to delete list: \(error)")
            return false
        }
    }
    
    // MARK: - List-Pin Associations
    
    /// Adds a pin to a list by listId (creates pin if it doesn't exist)
    func addPinToListById(pin: Pin, listId: String) async -> Bool {
        do {
            var pinId = await pinService.findExistingPin(pin: pin)
            if pinId == nil {
                pinId = try await pinService.createPin(pin: pin)
            }
            guard let finalPinId = pinId else { return false }
            if await isPinInList(pinId: finalPinId, listId: listId) {
                print("ℹ️ Pin already in list with id '", listId, "'")
                return true
            }
            let listPin = ["list_id": listId, "pin_id": finalPinId]
            _ = try await client
                .from("list_pins")
                .insert(listPin)
                .execute()
            return true
        } catch {
            print("❌ Failed to add pin to list by id: \(error)")
            return false
        }
    }
    
    /// Removes a pin from a list by listId
    func removePinFromListById(pin: Pin, listId: String) async -> Bool {
        do {
            let pinId = await pinService.findExistingPin(pin: pin)
            guard let finalPinId = pinId else { return false }
            _ = try await client
                .from("list_pins")
                .delete()
                .eq("list_id", value: listId)
                .eq("pin_id", value: finalPinId)
                .execute()
            return true
        } catch {
            print("❌ Failed to remove pin from list by id: \(error)")
            return false
        }
    }
    
    private func isPinInList(pinId: String, listId: String) async -> Bool {
        do {
            let existing: [ListPinDB] = try await client
                .from("list_pins")
                .select("*")
                .eq("list_id", value: listId)
                .eq("pin_id", value: pinId)
                .limit(1)
                .execute()
                .value
            
            return !existing.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Private List Helpers
    
    private func getOrCreateList(name: String) async throws -> String {
        guard let session = try? await client.auth.session else {
            throw NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let existing: [ListDB] = try await client
            .from("lists")
            .select("id")
            .eq("user_id", value: session.user.id.uuidString)
            .eq("name", value: name)
            .limit(1)
            .execute()
            .value
        
        if let existingList = existing.first {
            return existingList.id
        }
        
        return try await createList(name: name)
    }
    
    // MARK: - Legacy Deprecated Methods
    
    @available(*, deprecated, message: "Use addPinToListById(pin:listId:) instead")
    func addPinToList(pin: Pin, listName: String) async -> Bool {
        let lists = await getUserLists()
        if let list = lists.first(where: { $0.name.lowercased() == listName.lowercased() }) {
            return await addPinToListById(pin: pin, listId: list.id.uuidString)
        }
        return false
    }
    
    @available(*, deprecated, message: "Use removePinFromListById(pin:listId:) instead")
    func removePinFromList(pin: Pin, listName: String) async -> Bool {
        let lists = await getUserLists()
        if let list = lists.first(where: { $0.name.lowercased() == listName.lowercased() }) {
            return await removePinFromListById(pin: pin, listId: list.id.uuidString)
        }
        return false
    }
    
    // MARK: - Legacy Collections (DEPRECATED)
    
    @available(*, deprecated, message: "Use createList(name:) instead")
    func createCollection(name: String) async throws -> String {
        return try await createList(name: name)
    }
    
    @available(*, deprecated, message: "Use getUserLists() instead")
    func getUserCollections() async -> [PinList] {
        return await getUserLists()
    }
    
    @available(*, deprecated, message: "Use addPinToList(pin:listName:) instead")
    func addPinToCollection(pin: Pin, collectionName: String) async -> Bool {
        return await addPinToList(pin: pin, listName: collectionName)
    }
    
    @available(*, deprecated, message: "Use removePinFromList(pin:listName:) instead")
    func removePinFromCollection(pin: Pin, collectionName: String) async -> Bool {
        return await removePinFromList(pin: pin, listName: collectionName)
    }
    
    // MARK: - Group Lists System
    
    /// Create a collaborative group list
    func createGroupList(
        listId: UUID,
        memberCanAdd: Bool = true,
        memberCanRemove: Bool = false,
        memberCanInvite: Bool = true,
        requireApproval: Bool = false
    ) async throws -> GroupList {
        guard let userId = try? await client.auth.session.user.id.uuidString else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let groupListDB = GroupListDB(
            id: UUID().uuidString,
            list_id: listId.uuidString,
            owner_id: userId,
            is_collaborative: true,
            member_can_add: memberCanAdd,
            member_can_remove: memberCanRemove,
            member_can_invite: memberCanInvite,
            require_approval: requireApproval,
            created_at: ISO8601DateFormatter().string(from: Date()),
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        let response: [GroupListDB] = try await client
            .from("group_lists")
            .insert(groupListDB)
            .select()
            .execute()
            .value
        
        guard let createdDB = response.first else {
            throw NSError(domain: "Database", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create group list"])
        }
        
        guard let groupListId = UUID(uuidString: createdDB.id) else {
            throw NSError(domain: "Database", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid group list ID returned from database"])
        }
        
        _ = try await addGroupListMember(
            groupListId: groupListId,
            userId: userId,
            role: .owner
        )
        
        return convertToGroupList(createdDB)
    }
    
    /// Add member to group list
    func addGroupListMember(
        groupListId: UUID,
        userId: String,
        role: GroupListRole = .member,
        invitedBy: String? = nil
    ) async throws {
        let memberData = GroupListMemberInsert(
            group_list_id: groupListId.uuidString,
            user_id: userId,
            role: role.rawValue,
            permissions: [
                "can_add": role != .member,
                "can_remove": role == .owner || role == .admin,
                "can_invite": role != .member
            ],
            invited_by: invitedBy
        )
        
        _ = try await client
            .from("group_list_members")
            .insert(memberData)
            .execute()
    }
    
    /// Get group list members
    func getGroupListMembers(groupListId: UUID) async throws -> [GroupListMember] {
        struct MemberResponse: Codable {
            let id: String
            let user_id: String
            let role: String
            let permissions: [String: Bool]
            let invited_by: String?
            let joined_at: String
        }
        
        let membersDB: [MemberResponse] = try await client
            .from("group_list_members")
            .select("id, user_id, role, permissions, invited_by, joined_at")
            .eq("group_list_id", value: groupListId.uuidString)
            .execute()
            .value
        
        return membersDB.compactMap { member in
            guard let role = GroupListRole(rawValue: member.role) else {
                return nil
            }
            
            let permissions = GroupListPermissions(
                canAdd: member.permissions["can_add"] ?? false,
                canRemove: member.permissions["can_remove"] ?? false,
                canInvite: member.permissions["can_invite"] ?? false
            )
            
            return GroupListMember(
                id: UUID(uuidString: member.id) ?? UUID(),
                groupListId: groupListId,
                userId: member.user_id,
                role: role,
                permissions: permissions,
                invitedBy: member.invited_by,
                joinedAt: ISO8601DateFormatter().date(from: member.joined_at) ?? Date()
            )
        }
    }
    
    /// Record group list activity
    func recordGroupListActivity(
        groupListId: UUID,
        activityType: GroupListActivityType,
        relatedPinId: UUID? = nil,
        relatedUserId: UUID? = nil
    ) async throws {
        guard let session = try? await client.auth.session,
              let currentUser = try? await getCurrentUser() else { return }
        
        let activityData = GroupListActivityInsert(
            group_list_id: groupListId.uuidString,
            user_id: session.user.id.uuidString,
            username: currentUser.username,
            activity_type: activityType.rawValue,
            related_pin_id: relatedPinId?.uuidString,
            related_user_id: relatedUserId?.uuidString
        )
        
        _ = try await client
            .from("group_list_activities")
            .insert(activityData)
            .execute()
    }
    
    // MARK: - Private Helpers
    
    private func convertToGroupList(_ db: GroupListDB) -> GroupList {
        GroupList(
            id: UUID(uuidString: db.id) ?? UUID(),
            listId: UUID(uuidString: db.list_id) ?? UUID(),
            ownerId: db.owner_id,
            isCollaborative: db.is_collaborative,
            memberCanAdd: db.member_can_add,
            memberCanRemove: db.member_can_remove,
            memberCanInvite: db.member_can_invite,
            requireApproval: db.require_approval,
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
}
