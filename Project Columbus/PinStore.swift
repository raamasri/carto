//
//  PinStore.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/10/25.
//

import Foundation
import SwiftUI

@MainActor
class PinStore: ObservableObject {
    // All pins (master list) - now loaded from database
    @Published var masterPins: [Pin] = []
    // Pins the user has marked as favorites
    @Published var favoritePins: [Pin] = []
    @Published var isLoading: Bool = false
    // @Published var lastError: AppError?
    
    // Named lists of pins - loaded from database
    @Published var lists: [PinList] = []
    
    // Legacy support
    var collections: [PinCollection] { lists }
    
    private let supabaseManager = SupabaseManager.shared
    
    init() {
        // Don't automatically load data - wait for authentication
        print("📱 PinStore: Initialized, waiting for authentication...")
    }
    
    /// Loads all user data from database (lists, pins, etc.)
    func loadFromDatabase() {
        Task {
            isLoading = true
            print("📱 PinStore: Starting to load data from database...")
            
            // Load all user pins
            let allPins = await supabaseManager.getAllUserPins()
            print("📱 PinStore: Loaded \(allPins.count) pins from database")
            
            // Load all user lists with their pins
            let userLists = await supabaseManager.getUserLists()
            print("📱 PinStore: Loaded \(userLists.count) lists from database")
            
            await MainActor.run {
                // Update master pins
                masterPins = allPins
                
                // Update lists
                if userLists.isEmpty {
                    print("📱 PinStore: No lists found, creating default lists...")
                    // Create default lists if none exist
                    createDefaultLists()
                } else {
                    print("📱 PinStore: Setting lists to loaded data")
                    lists = userLists
                }
                
                // Update favorites (pins in "Favorites" list)
                if let favoritesList = lists.first(where: { $0.name == "Favorites" }) {
                    favoritePins = favoritesList.pins
                    print("📱 PinStore: Found \(favoritePins.count) favorite pins")
                } else {
                    favoritePins = []
                    print("📱 PinStore: No favorites list found")
                }
                
                print("📱 PinStore: Finished loading. Final lists count: \(lists.count)")
                isLoading = false
            }
        }
    }
    
    /// Creates default lists for new users
    private func createDefaultLists() {
        let defaultListNames = ["Favorites", "Coffee Shops", "Restaurants", "Bars", "Shopping"]
        print("📱 PinStore: Creating default lists...")
        
        // Create default lists locally first for immediate UI update
        Task {
            let currentUserId = await supabaseManager.getCurrentUserID() ?? UUID()
            await MainActor.run {
                for listName in defaultListNames {
                    if !lists.contains(where: { $0.name.lowercased() == listName.lowercased() }) {
                        lists.append(PinList(name: listName, pins: [], ownerId: currentUserId))
                        print("📱 PinStore: Created local default list: \(listName)")
                    }
                }
                print("📱 PinStore: Created \(lists.count) default lists locally")
            }
        }
        
        // Then create in database asynchronously
        Task {
            for listName in defaultListNames {
                do {
                    _ = try await supabaseManager.createList(name: listName)
                    print("📱 PinStore: Created default list '\(listName)' in database")
                } catch {
                    print("❌ Failed to create default list '\(listName)' in database: \(error)")
                }
            }
            print("📱 PinStore: Finished creating default lists in database")
        }
    }
    
    /// Loads lists from database (legacy method name for backward compatibility)
    @available(*, deprecated, message: "Use loadFromDatabase() instead")
    func loadCollectionsFromDatabase() {
        loadFromDatabase()
    }
    
    /// Adds a pin to the Favorites list if it isn't already present.
    /// - Parameter pin: The `Pin` to add.
    func addToFavorites(_ pin: Pin) {
        guard !favoritePins.contains(where: { $0.id == pin.id }) else { return }
        
        // Update local state
        favoritePins.append(pin)
        if let index = lists.firstIndex(where: { $0.name == "Favorites" }) {
            lists[index].pins.append(pin)
        }
        
        // Save to database
        Task {
            let success = await supabaseManager.addPinToList(pin: pin, listName: "Favorites")
            if success {
                print("✅ Pin added to Favorites in database")
            } else {
                print("❌ Failed to add pin to Favorites in database")
                // Revert local changes on failure
                await MainActor.run {
                    favoritePins.removeAll { $0.id == pin.id }
                    if let index = lists.firstIndex(where: { $0.name == "Favorites" }) {
                        lists[index].pins.removeAll { $0.id == pin.id }
                    }
                }
            }
        }
    }
    
    /// Adds a pin to the specified list, creating the list if it doesn't exist.
    /// - Parameters:
    ///   - pin: The `Pin` to save.
    ///   - listName: The name of the list.
    func addPin(_ pin: Pin, to listName: String) {
        // Update master list locally if not present
        if !masterPins.contains(where: { $0.id == pin.id }) {
            masterPins.append(pin)
        }
        // Special handling for Favorites
        if listName == "Favorites" {
            addToFavorites(pin)
            return
        }
        // Find the list by name (case-insensitive)
        if let index = lists.firstIndex(where: { $0.name.lowercased() == listName.lowercased() }) {
            // Append only if the pin is not already present
            if !lists[index].pins.contains(where: { $0.id == pin.id }) {
                lists[index].pins.append(pin)
            }
            // Save to database using list ID
            let listId = lists[index].id.uuidString
            Task {
                let success = await supabaseManager.addPinToListById(pin: pin, listId: listId)
                if success {
                    print("✅ Pin added to list '\(listName)' in database")
                    await refresh()
                } else {
                    print("❌ Failed to add pin to list '\(listName)' in database")
                    // Revert local changes on failure
                    await MainActor.run {
                        lists[index].pins.removeAll { $0.id == pin.id }
                        // Remove empty lists that were just created
                        if lists[index].pins.isEmpty && !["Favorites", "Coffee Shops", "Restaurants", "Bars", "Shopping"].contains(listName) {
                            lists.remove(at: index)
                        }
                    }
                }
            }
        } else {
            // Create a new list locally (will be created in database automatically)
            Task {
                let currentUserId = await supabaseManager.getCurrentUserID() ?? UUID()
                await MainActor.run {
                    let newList = PinList(name: listName, pins: [pin], ownerId: currentUserId)
                    lists.append(newList)
                }
            }
            // Save to database
            Task {
                do {
                    let newListId = try await supabaseManager.createList(name: listName)
                    let success = await supabaseManager.addPinToListById(pin: pin, listId: newListId)
                    if success {
                        print("✅ Pin added to new list '\(listName)' in database")
                        await refresh()
                    } else {
                        print("❌ Failed to add pin to new list '\(listName)' in database")
                        await MainActor.run {
                            lists.removeAll { $0.name == listName }
                        }
                    }
                } catch {
                    print("❌ Failed to create new list '\(listName)': \(error)")
                    await MainActor.run {
                        lists.removeAll { $0.name == listName }
                    }
                }
            }
        }
    }
    
    /// Removes a pin from a specific list
    /// - Parameters:
    ///   - pin: The pin to remove
    ///   - listName: The name of the list to remove from
    func removePin(_ pin: Pin, from listName: String) {
        // Update local state
        if listName == "Favorites" {
            favoritePins.removeAll { $0.id == pin.id }
        }
        if let index = lists.firstIndex(where: { $0.name.lowercased() == listName.lowercased() }) {
            lists[index].pins.removeAll { $0.id == pin.id }
            // Remove from database using list ID
            let listId = lists[index].id.uuidString
            Task {
                let success = await supabaseManager.removePinFromListById(pin: pin, listId: listId)
                if success {
                    print("✅ Pin removed from list '\(listName)' in database")
                    await refresh()
                } else {
                    print("❌ Failed to remove pin from list '\(listName)' in database")
                    // Revert local changes on failure
                    await MainActor.run {
                        lists[index].pins.append(pin)
                    }
                }
            }
        }
        // Remove from master list if not in any other list
        let isInAnyList = lists.contains { list in
            list.pins.contains { $0.id == pin.id }
        }
        if !isInAnyList {
            masterPins.removeAll { $0.id == pin.id }
        }
    }
    
    /// Fetches fresh data from database
    func fetchPins() async {
        await loadFromDatabase()
    }
    
    /// Creates a new custom list
    func createCustomList(name: String) {
        // Prevent duplicate custom lists (case-insensitive)
        guard !lists.contains(where: { $0.name.lowercased() == name.lowercased() }) else {
            print("⚠️ List '\(name)' already exists")
            return
        }
        // Add locally (with proper user ID)
        Task {
            let currentUserId = await supabaseManager.getCurrentUserID() ?? UUID()
            await MainActor.run {
                lists.append(PinList(name: name, pins: [], ownerId: currentUserId))
            }
        }
        // Save to database
        Task {
            do {
                _ = try await supabaseManager.createList(name: name)
                print("✅ Created list '\(name)' in database")
                await refresh() // Always refresh after add
            } catch {
                print("❌ Failed to create list '\(name)': \(error)")
                // Revert local changes on failure
                await MainActor.run {
                    lists.removeAll { $0.name == name }
                }
            }
        }
    }
    
    /// Legacy method name for backward compatibility
    @available(*, deprecated, message: "Use createCustomList(name:) instead")
    func createCustomCollection(name: String) {
        createCustomList(name: name)
    }
    
    /// Deletes a custom list (won't delete default lists)
    func deleteList(named listName: String) {
        // Don't allow deletion of default lists
        let defaultLists = ["Favorites", "Coffee Shops", "Restaurants", "Bars", "Shopping"]
        guard !defaultLists.contains(listName) else {
            print("⚠️ Cannot delete default list '\(listName)'")
            return
        }
        
        // Find the list to delete
        guard let listToDelete = lists.first(where: { $0.name == listName }) else {
            print("⚠️ List '\(listName)' not found")
            return
        }
        
        // Remove locally
        lists.removeAll { $0.name == listName }
        
        // Remove from database
        Task {
            let success = await supabaseManager.deleteList(listId: listToDelete.id.uuidString)
            if success {
                print("✅ Deleted list '\(listName)' from database")
            } else {
                print("❌ Failed to delete list '\(listName)' from database")
                // Revert local changes on failure
                await MainActor.run {
                    lists.append(listToDelete)
                }
            }
        }
    }
    
    /// Refreshes all data from database
    func refresh() async {
        await loadFromDatabase()
    }
    
    /// Legacy method name for backward compatibility
    @available(*, deprecated, message: "Use refresh() instead")
    func refreshCollections() async {
        await refresh()
    }
    
    /// Gets pins for a specific list by name
    func getPins(for listName: String) -> [Pin] {
        return lists.first(where: { $0.name == listName })?.pins ?? []
    }
    
    /// Gets a list by name
    func getList(named listName: String) -> PinList? {
        return lists.first(where: { $0.name == listName })
    }
    
    // TODO: Implement when DataManager is integrated
    // func searchPins(query: String) async -> [Pin] {
    //     guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    //         return masterPins
    //     }
    //     return await dataManager.searchPins(query: query)
    // }
}
