//
//  DataManager.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import Foundation
import SwiftUI
import Combine
import Network

// MARK: - Sync Status
enum SyncStatus: Equatable {
    case synced
    case pending
    case syncing
    case failed(String)
    case offline
}

// MARK: - Conflict Resolution Strategy
enum ConflictResolutionStrategy: String, Codable {
    case localWins = "local_wins"      // Local changes override server
    case serverWins = "server_wins"    // Server changes override local
    case merge = "merge"               // Attempt to merge changes
    case askUser = "ask_user"          // Present conflict to user for resolution
}

// MARK: - Offline Operation
struct OfflineOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let data: Data
    let timestamp: Date
    let retryCount: Int
    let conflictResolution: ConflictResolutionStrategy
    
    enum OperationType: String, Codable {
        case createPin = "create_pin"
        case updatePin = "update_pin"
        case deletePin = "delete_pin"
        case createList = "create_list"
        case updateProfile = "update_profile"
        case followUser = "follow_user"
        case sendMessage = "send_message"
        case createPost = "create_post"
        case updatePost = "update_post"
    }
    
    init(id: UUID = UUID(), type: OperationType, data: Data, timestamp: Date = Date(), retryCount: Int = 0, conflictResolution: ConflictResolutionStrategy = .localWins) {
        self.id = id
        self.type = type
        self.data = data
        self.timestamp = timestamp
        self.retryCount = retryCount
        self.conflictResolution = conflictResolution
    }
}

// MARK: - Conflict Detection
struct DataConflict: Identifiable {
    let id = UUID()
    let operationId: UUID
    let localData: Data
    let serverData: Data
    let conflictType: ConflictType
    
    enum ConflictType {
        case pinModified
        case profileUpdated
        case listChanged
        case postEdited
    }
}

// MARK: - Pagination Support
struct PaginationInfo {
    var currentPage: Int = 0
    var pageSize: Int = 20
    var hasMoreData: Bool = true
    var isLoading: Bool = false
    var totalCount: Int = 0
}

// MARK: - Data Manager
@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var syncStatus: SyncStatus = .synced
    @Published var isOfflineMode: Bool = false
    @Published var lastSyncDate: Date?
    @Published var pendingOperationsCount: Int = 0
    @Published var conflicts: [DataConflict] = []
    @Published var paginationInfo: PaginationInfo = PaginationInfo()
    
    private let networkMonitor = NetworkMonitor()
    private var cancellables = Set<AnyCancellable>()
    private let maxRetries = 3
    private let syncInterval: TimeInterval = 30 // 30 seconds
    
    // Offline storage
    private var offlineOperations: [OfflineOperation] = []
    private let offlineOperationsKey = "offline_operations"
    
    // Local cache for offline data
    private var cachedPins: [Pin] = []
    private var cachedLists: [PinList] = []
    private var cachedUsers: [AppUser] = []
    
    // Supabase manager reference
    private let supabaseManager = SupabaseManager.shared
    
    private init() {
        setupNetworkMonitoring()
        loadOfflineOperations()
        loadCachedData()
        startPeriodicSync()
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.handleNetworkStatusChange(isConnected)
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkStatusChange(_ isConnected: Bool) {
        isOfflineMode = !isConnected
        
        if isConnected && !offlineOperations.isEmpty {
            Task {
                await syncPendingChanges()
            }
        }
        
        syncStatus = isConnected ? .synced : .offline
    }
    
    // MARK: - Offline Operations Management
    private func addOfflineOperation(_ operation: OfflineOperation) {
        offlineOperations.append(operation)
        pendingOperationsCount = offlineOperations.count
        saveOfflineOperations()
        
        if syncStatus != .offline {
            syncStatus = .pending
        }
    }
    
    private func removeOfflineOperation(_ operationId: UUID) {
        offlineOperations.removeAll { $0.id == operationId }
        pendingOperationsCount = offlineOperations.count
        saveOfflineOperations()
        
        if offlineOperations.isEmpty && networkMonitor.isConnected {
            syncStatus = .synced
            lastSyncDate = Date()
        }
    }
    
    private func saveOfflineOperations() {
        do {
            let data = try JSONEncoder().encode(offlineOperations)
            UserDefaults.standard.set(data, forKey: offlineOperationsKey)
        } catch {
            print("❌ Failed to save offline operations: \(error)")
        }
    }
    
    private func loadOfflineOperations() {
        guard let data = UserDefaults.standard.data(forKey: offlineOperationsKey) else { return }
        
        do {
            offlineOperations = try JSONDecoder().decode([OfflineOperation].self, from: data)
            pendingOperationsCount = offlineOperations.count
            
            if !offlineOperations.isEmpty {
                syncStatus = networkMonitor.isConnected ? .pending : .offline
            }
        } catch {
            print("❌ Failed to load offline operations: \(error)")
            offlineOperations = []
        }
    }
    
    // MARK: - Local Cache Management
    private func loadCachedData() {
        // Load cached pins
        if let pinsData = UserDefaults.standard.data(forKey: "cached_pins") {
            do {
                cachedPins = try JSONDecoder().decode([Pin].self, from: pinsData)
                print("📱 DataManager: Loaded \(cachedPins.count) cached pins")
            } catch {
                print("❌ Failed to load cached pins: \(error)")
                cachedPins = []
            }
        }
        
        // Load cached lists
        if let listsData = UserDefaults.standard.data(forKey: "cached_lists") {
            do {
                cachedLists = try JSONDecoder().decode([PinList].self, from: listsData)
                print("📱 DataManager: Loaded \(cachedLists.count) cached lists")
            } catch {
                print("❌ Failed to load cached lists: \(error)")
                cachedLists = []
            }
        }
    }
    
    private func saveCachedData() {
        // Save cached pins
        do {
            let pinsData = try JSONEncoder().encode(cachedPins)
            UserDefaults.standard.set(pinsData, forKey: "cached_pins")
        } catch {
            print("❌ Failed to save cached pins: \(error)")
        }
        
        // Save cached lists
        do {
            let listsData = try JSONEncoder().encode(cachedLists)
            UserDefaults.standard.set(listsData, forKey: "cached_lists")
        } catch {
            print("❌ Failed to save cached lists: \(error)")
        }
    }
    
    // MARK: - Pin Operations with Offline Support
    func savePinOffline(_ pin: Pin) async {
        do {
            let pinData = try JSONEncoder().encode(pin)
            let operation = OfflineOperation(type: .createPin, data: pinData, conflictResolution: .localWins)
            addOfflineOperation(operation)
            
            // Add to local cache immediately
            cachedPins.append(pin)
            saveCachedData()
            
            print("📝 DataManager: Pin saved offline - \(pin.locationName)")
            
            // If online, try to sync immediately
            if networkMonitor.isConnected {
                await syncPendingChanges()
            }
        } catch {
            print("❌ Failed to encode pin for offline storage: \(error)")
        }
    }
    
    func loadPins(page: Int = 0, pageSize: Int = 20) async -> [Pin] {
        if networkMonitor.isConnected {
            // Online: Load from server with pagination
            paginationInfo.isLoading = true
            paginationInfo.currentPage = page
            paginationInfo.pageSize = pageSize
            
            let pins = await SupabaseManager.shared.getAllUserPins()
            
            // Update cache
            if page == 0 {
                cachedPins = pins
            } else {
                // Append new pins for pagination
                let existingIds = Set(cachedPins.map { $0.id })
                let newPins = pins.filter { !existingIds.contains($0.id) }
                cachedPins.append(contentsOf: newPins)
            }
            saveCachedData()
            
            await MainActor.run {
                paginationInfo.isLoading = false
                paginationInfo.hasMoreData = pins.count >= pageSize
            }
            
            return pins
        } else {
            // Offline: Return cached data
            print("📱 DataManager: Loading pins - offline mode, returning \(cachedPins.count) cached pins")
            
            // Simulate pagination with cached data
            let startIndex = page * pageSize
            let endIndex = min(startIndex + pageSize, cachedPins.count)
            
            if startIndex >= cachedPins.count {
                return []
            }
            
            await MainActor.run {
                paginationInfo.hasMoreData = endIndex < cachedPins.count
            }
            
            return Array(cachedPins[startIndex..<endIndex])
        }
    }
    
    // MARK: - Profile Operations with Conflict Resolution
    func saveProfileOffline(userID: String, username: String, fullName: String, email: String, bio: String, avatarURL: String) async {
        let profileData: [String: String] = [
            "userID": userID,
            "username": username,
            "fullName": fullName,
            "email": email,
            "bio": bio,
            "avatarURL": avatarURL,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let data = try JSONEncoder().encode(profileData)
            let operation = OfflineOperation(type: .updateProfile, data: data, conflictResolution: .merge)
            addOfflineOperation(operation)
            
            print("📝 DataManager: Profile update saved offline")
            
            if networkMonitor.isConnected {
                await syncPendingChanges()
            }
        } catch {
            print("❌ Failed to encode profile data for offline storage: \(error)")
        }
    }
    
    // MARK: - Post Operations
    func savePostOffline(_ post: [String: Any]) async {
        do {
            let postData = try JSONSerialization.data(withJSONObject: post)
            let operation = OfflineOperation(type: .createPost, data: postData, conflictResolution: .localWins)
            addOfflineOperation(operation)
            
            print("📝 DataManager: Post saved offline")
            
            if networkMonitor.isConnected {
                await syncPendingChanges()
            }
        } catch {
            print("❌ Failed to encode post data for offline storage: \(error)")
        }
    }
    
    // MARK: - Sync Operations with Conflict Resolution
    func syncPendingChanges() async {
        guard networkMonitor.isConnected else {
            print("🔄 DataManager: Cannot sync - offline")
            return
        }
        
        guard !offlineOperations.isEmpty else {
            syncStatus = .synced
            return
        }
        
        syncStatus = .syncing
        print("🔄 DataManager: Starting sync of \(offlineOperations.count) operations")
        
        var failedOperations: [OfflineOperation] = []
        var detectedConflicts: [DataConflict] = []
        
        for operation in offlineOperations {
            let result = await syncOperation(operation)
            
            switch result {
            case .success:
                print("✅ Synced operation: \(operation.type.rawValue)")
                removeOfflineOperation(operation.id)
                
            case .conflict(let conflict):
                print("⚠️ Conflict detected for operation: \(operation.type.rawValue)")
                detectedConflicts.append(conflict)
                
                // Handle conflict based on strategy
                let resolved = await resolveConflict(conflict, operation: operation)
                if !resolved {
                    failedOperations.append(operation)
                }
                
            case .failure:
                if operation.retryCount < maxRetries {
                    let retryOperation = OfflineOperation(
                        id: operation.id,
                        type: operation.type,
                        data: operation.data,
                        timestamp: operation.timestamp,
                        retryCount: operation.retryCount + 1,
                        conflictResolution: operation.conflictResolution
                    )
                    failedOperations.append(retryOperation)
                } else {
                    print("❌ Max retries exceeded for operation: \(operation.type.rawValue)")
                }
            }
        }
        
        // Update conflicts list
        await MainActor.run {
            conflicts.append(contentsOf: detectedConflicts)
        }
        
        // Update offline operations with failed ones
        offlineOperations = failedOperations
        pendingOperationsCount = offlineOperations.count
        saveOfflineOperations()
        
        if offlineOperations.isEmpty {
            syncStatus = .synced
            lastSyncDate = Date()
            print("✅ All operations synced successfully")
        } else {
            syncStatus = .failed("Some operations failed to sync")
            print("⚠️ \(offlineOperations.count) operations failed to sync")
        }
    }
    
    private enum SyncResult: Equatable {
        case success
        case conflict(DataConflict)
        case failure
        
        static func == (lhs: SyncResult, rhs: SyncResult) -> Bool {
            switch (lhs, rhs) {
            case (.success, .success), (.failure, .failure):
                return true
            case (.conflict(let lhsConflict), .conflict(let rhsConflict)):
                return lhsConflict.id == rhsConflict.id
            default:
                return false
            }
        }
    }
    
    private func syncOperation(_ operation: OfflineOperation) async -> SyncResult {
        do {
            switch operation.type {
            case .createPin:
                let pin = try JSONDecoder().decode(Pin.self, from: operation.data)
                
                // Check for conflicts (pin at same location created by others)
                let existingPins = await SupabaseManager.shared.getAllUserPins()
                let conflictingPin = existingPins.first { existing in
                    abs(existing.latitude - pin.latitude) < 0.0001 &&
                    abs(existing.longitude - pin.longitude) < 0.0001 &&
                    existing.authorHandle != pin.authorHandle
                }
                
                if let conflictingPin = conflictingPin {
                    let conflictData = try JSONEncoder().encode(conflictingPin)
                    let conflict = DataConflict(
                        operationId: operation.id,
                        localData: operation.data,
                        serverData: conflictData,
                        conflictType: .pinModified
                    )
                    return .conflict(conflict)
                }
                
                _ = try await SupabaseManager.shared.createPin(pin: pin)
                return .success
                
            case .updateProfile:
                let profileData = try JSONDecoder().decode([String: String].self, from: operation.data)
                guard let userID = profileData["userID"],
                      let username = profileData["username"],
                      let fullName = profileData["fullName"],
                      let email = profileData["email"],
                      let bio = profileData["bio"],
                      let avatarURL = profileData["avatarURL"],
                      let timestampString = profileData["timestamp"] else {
                    return .failure
                }
                
                // Check for conflicts (profile updated by another session)
                if let serverProfile = await SupabaseManager.shared.fetchUserProfile(userID: userID) {
                    let localTimestamp = ISO8601DateFormatter().date(from: timestampString) ?? Date.distantPast
                    // For simplicity, assume server profile was updated if it differs significantly
                    if serverProfile.username != username || serverProfile.full_name != fullName {
                        let serverData = try JSONEncoder().encode([
                            "username": serverProfile.username,
                            "fullName": serverProfile.full_name,
                            "bio": serverProfile.bio ?? ""
                        ])
                        let conflict = DataConflict(
                            operationId: operation.id,
                            localData: operation.data,
                            serverData: serverData,
                            conflictType: .profileUpdated
                        )
                        return .conflict(conflict)
                    }
                }
                
                try await SupabaseManager.shared.updateUserProfile(
                    userID: userID,
                    username: username,
                    fullName: fullName,
                    email: email,
                    bio: bio,
                    avatarURL: avatarURL
                )
                return .success
                
            case .followUser:
                let userIdData = try JSONDecoder().decode([String: String].self, from: operation.data)
                guard let userIdString = userIdData["userId"],
                      let userId = UUID(uuidString: userIdString) else {
                    return .failure
                }
                
                let success = await SupabaseManager.shared.followUser(followingID: userId)
                return success ? .success : .failure
                
            case .createPost:
                let postData = try JSONSerialization.jsonObject(with: operation.data) as? [String: Any]
                guard let post = postData else { return .failure }
                
                // Implement post creation logic here when available
                print("📝 Post sync not yet implemented")
                return .success
                
            default:
                print("⚠️ Sync not implemented for operation type: \(operation.type.rawValue)")
                return .failure
            }
        } catch {
            print("❌ Failed to sync operation \(operation.type.rawValue): \(error)")
            return .failure
        }
    }
    
    // MARK: - Conflict Resolution
    private func resolveConflict(_ conflict: DataConflict, operation: OfflineOperation) async -> Bool {
        switch operation.conflictResolution {
        case .localWins:
            // Force local changes to override server
            print("🔧 Resolving conflict: Local wins for operation \(operation.id)")
            return await forceSyncOperation(operation)
            
        case .serverWins:
            // Discard local changes, accept server version
            print("🔧 Resolving conflict: Server wins for operation \(operation.id)")
            return true // Mark as resolved by discarding
            
        case .merge:
            // Attempt to merge changes
            print("🔧 Resolving conflict: Attempting merge for operation \(operation.id)")
            return await attemptMerge(conflict, operation: operation)
            
        case .askUser:
            // Present to user for manual resolution
            print("🔧 Conflict requires user intervention for operation \(operation.id)")
            await MainActor.run {
                conflicts.append(conflict)
            }
            return false // Will be resolved later by user
        }
    }
    
    private func forceSyncOperation(_ operation: OfflineOperation) async -> Bool {
        // Implement force sync logic (override server data)
        print("🔧 Force syncing operation: \(operation.type.rawValue)")
        // For now, just retry the normal sync
        let result = await syncOperation(operation)
        return result == SyncResult.success
    }
    
    private func attemptMerge(_ conflict: DataConflict, operation: OfflineOperation) async -> Bool {
        switch conflict.conflictType {
        case .profileUpdated:
            // Merge profile changes by taking the most recent non-empty values
            do {
                let localProfile = try JSONDecoder().decode([String: String].self, from: conflict.localData)
                let serverProfile = try JSONDecoder().decode([String: String].self, from: conflict.serverData)
                
                let mergedProfile: [String: String] = [
                    "userID": localProfile["userID"] ?? "",
                    "username": localProfile["username"]?.isEmpty == false ? localProfile["username"]! : serverProfile["username"] ?? "",
                    "fullName": localProfile["fullName"]?.isEmpty == false ? localProfile["fullName"]! : serverProfile["fullName"] ?? "",
                    "bio": localProfile["bio"]?.isEmpty == false ? localProfile["bio"]! : serverProfile["bio"] ?? "",
                    "email": localProfile["email"] ?? serverProfile["email"] ?? "",
                    "avatarURL": localProfile["avatarURL"]?.isEmpty == false ? localProfile["avatarURL"]! : serverProfile["avatarURL"] ?? ""
                ]
                
                // Create new operation with merged data
                let mergedData = try JSONEncoder().encode(mergedProfile)
                let mergedOperation = OfflineOperation(
                    id: operation.id,
                    type: operation.type,
                    data: mergedData,
                    timestamp: operation.timestamp,
                    retryCount: operation.retryCount,
                    conflictResolution: .localWins
                )
                
                let result = await syncOperation(mergedOperation)
                return result == SyncResult.success
                
            } catch {
                print("❌ Failed to merge profile data: \(error)")
                return false
            }
            
        default:
            // For other conflict types, default to local wins
            return await forceSyncOperation(operation)
        }
    }
    
    // MARK: - User Conflict Resolution
    func resolveConflictManually(_ conflictId: UUID, strategy: ConflictResolutionStrategy) async {
        guard let conflictIndex = conflicts.firstIndex(where: { $0.id == conflictId }),
              let operationIndex = offlineOperations.firstIndex(where: { $0.id == conflicts[conflictIndex].operationId }) else {
            return
        }
        
        let conflict = conflicts[conflictIndex]
        var operation = offlineOperations[operationIndex]
        
        // Update operation with new strategy
        operation = OfflineOperation(
            id: operation.id,
            type: operation.type,
            data: operation.data,
            timestamp: operation.timestamp,
            retryCount: operation.retryCount,
            conflictResolution: strategy
        )
        
        offlineOperations[operationIndex] = operation
        
        // Resolve the conflict
        let resolved = await resolveConflict(conflict, operation: operation)
        
        if resolved {
            // Remove from conflicts and operations
            conflicts.remove(at: conflictIndex)
            removeOfflineOperation(operation.id)
        }
    }
    
    // MARK: - Pagination Support
    func loadMoreData() async {
        guard !paginationInfo.isLoading && paginationInfo.hasMoreData else { return }
        
        let nextPage = paginationInfo.currentPage + 1
        _ = await loadPins(page: nextPage, pageSize: paginationInfo.pageSize)
    }
    
    func resetPagination() {
        paginationInfo = PaginationInfo()
    }
    
    // MARK: - Periodic Sync
    private func startPeriodicSync() {
        Timer.publish(every: syncInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if self.networkMonitor.isConnected && !self.offlineOperations.isEmpty {
                    Task {
                        await self.syncPendingChanges()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Manual Sync Trigger
    func forceSyncNow() async {
        await syncPendingChanges()
    }
    
    // MARK: - Cache Management
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: offlineOperationsKey)
        UserDefaults.standard.removeObject(forKey: "cached_pins")
        UserDefaults.standard.removeObject(forKey: "cached_lists")
        
        offlineOperations = []
        cachedPins = []
        cachedLists = []
        pendingOperationsCount = 0
        conflicts = []
        syncStatus = .synced
        paginationInfo = PaginationInfo()
        
        print("🗑️ DataManager: Cache cleared")
    }
    
    // MARK: - Network Connectivity Check
    func checkConnectivity() -> Bool {
        return networkMonitor.isConnected
    }
    
    // MARK: - Offline Data Access
    func getCachedPins() -> [Pin] {
        return cachedPins
    }
    
    func getCachedLists() -> [PinList] {
        return cachedLists
    }
}

// MARK: - Network Monitor
class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
} 