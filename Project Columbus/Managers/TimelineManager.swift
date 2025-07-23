//
//  TimelineManager.swift
//  Project Columbus
//
//  Created by Assistant on 1/10/25.
//

import Foundation
import CoreLocation
import SwiftUI
import Combine

/**
 * TimelineManager
 * 
 * Manages the user's timeline by tracking location visits and automatically
 * creating post drafts when users move from place to place.
 */
@MainActor
class TimelineManager: ObservableObject {
    static let shared = TimelineManager()
    
    @Published var timelineEntries: [TimelineEntry] = []
    @Published var postDrafts: [PostDraft] = []
    @Published var isTimelineEnabled: Bool = UserDefaults.standard.bool(forKey: "timelineEnabled")
    
    private var currentTimelineEntry: TimelineEntry?
    private var locationTimer: Timer?
    private var lastKnownLocation: CLLocation?
    private let minimumStayDuration: TimeInterval = 300 // 5 minutes
    private let significantLocationChangeDistance: CLLocationDistance = 100 // 100 meters
    
    private let supabaseManager = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupLocationTracking()
    }
    
    // MARK: - Timeline Control
    
    func enableTimeline() {
        isTimelineEnabled = true
        UserDefaults.standard.set(true, forKey: "timelineEnabled")
        setupLocationTracking()
    }
    
    func disableTimeline() {
        isTimelineEnabled = false
        UserDefaults.standard.set(false, forKey: "timelineEnabled")
        stopLocationTracking()
    }
    
    // MARK: - Location Tracking
    
    private func setupLocationTracking() {
        guard isTimelineEnabled else { return }
        
        // Listen to location updates from the existing LocationManager
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationUpdate),
            name: NSNotification.Name("LocationDidUpdate"),
            object: nil
        )
    }
    
    private func stopLocationTracking() {
        locationTimer?.invalidate()
        locationTimer = nil
        NotificationCenter.default.removeObserver(self)
        
        // Complete current timeline entry if exists
        if let current = currentTimelineEntry {
            completeTimelineEntry(current)
        }
    }
    
    @objc private func handleLocationUpdate(_ notification: Notification) {
        guard isTimelineEnabled,
              let userInfo = notification.userInfo,
              let location = userInfo["location"] as? CLLocation else { return }
        
        processLocationUpdate(location)
    }
    
    private func processLocationUpdate(_ location: CLLocation) {
        // Check if this is a significant location change
        if let lastLocation = lastKnownLocation {
            let distance = location.distance(from: lastLocation)
            if distance < significantLocationChangeDistance {
                return // Not significant enough
            }
        }
        
        // Complete current timeline entry if it exists
        if let current = currentTimelineEntry {
            completeTimelineEntry(current)
        }
        
        // Start new timeline entry
        startNewTimelineEntry(at: location)
        lastKnownLocation = location
    }
    
    // MARK: - Timeline Entry Management
    
    private func startNewTimelineEntry(at location: CLLocation) {
        Task {
            do {
                // Get location name using reverse geocoding
                let geocoder = CLGeocoder()
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                
                guard let placemark = placemarks.first else { return }
                
                let locationName = placemark.name ?? placemark.thoroughfare ?? "Unknown Location"
                let city = placemark.locality ?? placemark.administrativeArea ?? "Unknown City"
                
                // Get current user ID
                guard let userId = await getCurrentUserId() else { return }
                
                let entry = TimelineEntry(
                    userId: userId,
                    locationName: locationName,
                    city: city,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    arrivalTime: Date(),
                    isCurrentLocation: true
                )
                
                currentTimelineEntry = entry
                
                // Start a timer to check if user stays long enough
                locationTimer = Timer.scheduledTimer(withTimeInterval: minimumStayDuration, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.confirmTimelineEntry(entry)
                    }
                }
                
            } catch {
                print("Error getting location name: \(error)")
            }
        }
    }
    
    private func confirmTimelineEntry(_ entry: TimelineEntry) {
        // User has stayed long enough, save the timeline entry
        Task {
            do {
                try await saveTimelineEntry(entry)
                timelineEntries.insert(entry, at: 0) // Add to beginning
                
                // Create automatic post draft
                let draft = PostDraft(from: entry)
                try await savePostDraft(draft)
                postDrafts.insert(draft, at: 0)
                
            } catch {
                print("Error saving timeline entry: \(error)")
            }
        }
    }
    
    private func completeTimelineEntry(_ entry: TimelineEntry) {
        locationTimer?.invalidate()
        locationTimer = nil
        
        // Update the entry with departure time
        var updatedEntry = entry
        updatedEntry.departureTime = Date()
        updatedEntry.isCurrentLocation = false
        
        Task {
            do {
                try await updateTimelineEntry(updatedEntry)
                
                // Update in local array
                if let index = timelineEntries.firstIndex(where: { $0.id == entry.id }) {
                    timelineEntries[index] = updatedEntry
                }
                
                // Update corresponding draft
                if let draftIndex = postDrafts.firstIndex(where: { $0.timelineEntryId == entry.id }) {
                    var updatedDraft = postDrafts[draftIndex]
                    updatedDraft.departureTime = updatedEntry.departureTime
                    updatedDraft.duration = updatedEntry.duration
                    updatedDraft.updatedAt = Date()
                    
                    try await updatePostDraft(updatedDraft)
                    postDrafts[draftIndex] = updatedDraft
                }
                
            } catch {
                print("Error updating timeline entry: \(error)")
            }
        }
        
        currentTimelineEntry = nil
    }
    
    // MARK: - Data Loading
    
    func loadTimelineData() async {
        guard let userId = await getCurrentUserId() else { return }
        
        do {
            let entries = try await loadTimelineEntries(for: userId)
            let drafts = try await loadPostDrafts(for: userId)
            
            await MainActor.run {
                self.timelineEntries = entries
                self.postDrafts = drafts
            }
        } catch {
            print("Error loading timeline data: \(error)")
        }
    }
    
    // MARK: - Database Operations
    
    private func getCurrentUserId() async -> UUID? {
        // Get current user ID from auth manager
        return UUID(uuidString: supabaseManager.client.auth.currentUser?.id.uuidString ?? "")
    }
    
    private func saveTimelineEntry(_ entry: TimelineEntry) async throws {
        let dbModel = entry.toDatabaseModel()
        try await supabaseManager.client
            .from("timeline_entries")
            .insert(dbModel)
            .execute()
    }
    
    private func updateTimelineEntry(_ entry: TimelineEntry) async throws {
        let dbModel = entry.toDatabaseModel()
        try await supabaseManager.client
            .from("timeline_entries")
            .update(dbModel)
            .eq("id", value: entry.id.uuidString)
            .execute()
    }
    
    private func loadTimelineEntries(for userId: UUID) async throws -> [TimelineEntry] {
        let response = try await supabaseManager.client
            .from("timeline_entries")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("arrival_time", ascending: false)
            .execute()
        
        let dbEntries = try response.decode([TimelineEntryDB].self)
        return dbEntries.compactMap { $0.toTimelineEntry() }
    }
    
    private func savePostDraft(_ draft: PostDraft) async throws {
        let dbModel = draft.toDatabaseModel()
        try await supabaseManager.client
            .from("post_drafts")
            .insert(dbModel)
            .execute()
    }
    
    private func updatePostDraft(_ draft: PostDraft) async throws {
        let dbModel = draft.toDatabaseModel()
        try await supabaseManager.client
            .from("post_drafts")
            .update(dbModel)
            .eq("id", value: draft.id.uuidString)
            .execute()
    }
    
    private func loadPostDrafts(for userId: UUID) async throws -> [PostDraft] {
        let response = try await supabaseManager.client
            .from("post_drafts")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
        
        let dbDrafts = try response.decode([PostDraftDB].self)
        return dbDrafts.compactMap { $0.toPostDraft() }
    }
    
    // MARK: - Draft Management
    
    func publishDraft(_ draft: PostDraft) async throws {
        var updatedDraft = draft
        updatedDraft.isPublished = true
        updatedDraft.publishedAt = Date()
        updatedDraft.updatedAt = Date()
        
        try await updatePostDraft(updatedDraft)
        
        // Update local array
        if let index = postDrafts.firstIndex(where: { $0.id == draft.id }) {
            postDrafts[index] = updatedDraft
        }
        
        // Here you would also create the actual post in your posts system
        // This depends on your existing post creation logic
    }
    
    func updateDraft(_ draft: PostDraft) async throws {
        var updatedDraft = draft
        updatedDraft.updatedAt = Date()
        
        try await updatePostDraft(updatedDraft)
        
        // Update local array
        if let index = postDrafts.firstIndex(where: { $0.id == draft.id }) {
            postDrafts[index] = updatedDraft
        }
    }
    
    func deleteDraft(_ draft: PostDraft) async throws {
        try await supabaseManager.client
            .from("post_drafts")
            .delete()
            .eq("id", value: draft.id.uuidString)
            .execute()
        
        // Remove from local array
        postDrafts.removeAll { $0.id == draft.id }
    }
}