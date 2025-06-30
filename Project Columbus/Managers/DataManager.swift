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

// MARK: - Offline Operation
struct OfflineOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let data: Data
    let timestamp: Date
    let retryCount: Int
    
    enum OperationType: String, Codable {
        case createPin = "create_pin"
        case updatePin = "update_pin"
        case deletePin = "delete_pin"
        case createList = "create_list"
        case updateProfile = "update_profile"
        case followUser = "follow_user"
        case sendMessage = "send_message"
    }
    
    init(id: UUID = UUID(), type: OperationType, data: Data, timestamp: Date = Date(), retryCount: Int = 0) {
        self.id = id
        self.type = type
        self.data = data
        self.timestamp = timestamp
        self.retryCount = retryCount
    }
}

// MARK: - Data Manager
@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var syncStatus: SyncStatus = .synced
    @Published var isOfflineMode: Bool = false
    @Published var lastSyncDate: Date?
    @Published var pendingOperationsCount: Int = 0
    
    private let networkMonitor = NetworkMonitor()
    private var cancellables = Set<AnyCancellable>()
    private let maxRetries = 3
    private let syncInterval: TimeInterval = 30 // 30 seconds
    
    // Offline storage
    private var offlineOperations: [OfflineOperation] = []
    private let offlineOperationsKey = "offline_operations"
    
    // Supabase manager reference
    private let supabaseManager = SupabaseManager.shared
    
    private init() {
        setupNetworkMonitoring()
        loadOfflineOperations()
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
    
    // MARK: - Pin Operations
    func savePinOffline(_ pin: Pin) async {
        do {
            let pinData = try JSONEncoder().encode(pin)
            let operation = OfflineOperation(type: .createPin, data: pinData)
            addOfflineOperation(operation)
            
            print("📝 DataManager: Pin saved offline - \(pin.locationName)")
            
            // If online, try to sync immediately
            if networkMonitor.isConnected {
                await syncPendingChanges()
            }
        } catch {
            print("❌ Failed to encode pin for offline storage: \(error)")
        }
    }
    
    func loadPins() async -> [Pin] {
        // Load from Supabase if online, otherwise return empty array
        // The PinStore handles the actual pin loading logic
        if networkMonitor.isConnected {
            return await SupabaseManager.shared.getAllUserPins()
        } else {
            print("📱 DataManager: Loading pins - offline mode")
            return []
        }
    }
    
    // MARK: - Profile Operations
    func saveProfileOffline(userID: String, username: String, fullName: String, email: String, bio: String, avatarURL: String) async {
        let profileData: [String: String] = [
            "userID": userID,
            "username": username,
            "fullName": fullName,
            "email": email,
            "bio": bio,
            "avatarURL": avatarURL
        ]
        
        do {
            let data = try JSONEncoder().encode(profileData)
            let operation = OfflineOperation(type: .updateProfile, data: data)
            addOfflineOperation(operation)
            
            print("📝 DataManager: Profile update saved offline")
            
            if networkMonitor.isConnected {
                await syncPendingChanges()
            }
        } catch {
            print("❌ Failed to encode profile data for offline storage: \(error)")
        }
    }
    
    // MARK: - Sync Operations
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
        
        for operation in offlineOperations {
            let success = await syncOperation(operation)
            
            if success {
                print("✅ Synced operation: \(operation.type.rawValue)")
            } else {
                if operation.retryCount < maxRetries {
                    let retryOperation = OfflineOperation(
                        id: operation.id,
                        type: operation.type,
                        data: operation.data,
                        timestamp: operation.timestamp,
                        retryCount: operation.retryCount + 1
                    )
                    failedOperations.append(retryOperation)
                } else {
                    print("❌ Max retries exceeded for operation: \(operation.type.rawValue)")
                }
            }
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
    
    private func syncOperation(_ operation: OfflineOperation) async -> Bool {
        do {
            switch operation.type {
            case .createPin:
                let pin = try JSONDecoder().decode(Pin.self, from: operation.data)
                _ = try await SupabaseManager.shared.createPin(pin: pin)
                return true
                
            case .updateProfile:
                let profileData = try JSONDecoder().decode([String: String].self, from: operation.data)
                guard let userID = profileData["userID"],
                      let username = profileData["username"],
                      let fullName = profileData["fullName"],
                      let email = profileData["email"],
                      let bio = profileData["bio"],
                      let avatarURL = profileData["avatarURL"] else {
                    return false
                }
                
                try await SupabaseManager.shared.updateUserProfile(
                    userID: userID,
                    username: username,
                    fullName: fullName,
                    email: email,
                    bio: bio,
                    avatarURL: avatarURL
                )
                return true
                
            case .followUser:
                let userIdData = try JSONDecoder().decode([String: String].self, from: operation.data)
                guard let userIdString = userIdData["userId"],
                      let userId = UUID(uuidString: userIdString) else {
                    return false
                }
                
                return await SupabaseManager.shared.followUser(followingID: userId)
                
            default:
                print("⚠️ Sync not implemented for operation type: \(operation.type.rawValue)")
                return false
            }
        } catch {
            print("❌ Failed to sync operation \(operation.type.rawValue): \(error)")
            return false
        }
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
        offlineOperations = []
        pendingOperationsCount = 0
        syncStatus = .synced
        print("🗑️ DataManager: Cache cleared")
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