//
//  LocationHistoryView.swift
//  Project Columbus
//
//  Created by Assistant on 6/30/25.
//

import SwiftUI
import MapKit
import UIKit

struct LocationHistoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var locationHistory: [LocationHistoryEntry] = []
    @State private var isLoading: Bool = true
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingMap: Bool = false
    @State private var selectedEntry: LocationHistoryEntry?
    @State private var isLocationHistoryEnabled: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var exportURL: URL?
    
    enum TimeRange: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if !isLocationHistoryEnabled {
                    // Location History Disabled State
                    VStack(spacing: 20) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Location History Disabled")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Enable location history to track and view your location data over time.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Enable Location History") {
                            enableLocationHistory()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isLoading {
                    ProgressView("Loading location history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if locationHistory.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "location")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Location History")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Your location history will appear here as you use the app.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Location History Content
                    VStack {
                        // Time Range Picker
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases, id: \.self) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        
                        // Location History List
                        List {
                            ForEach(groupedLocationHistory, id: \.key) { day, entries in
                                Section(header: Text(day)) {
                                    ForEach(entries) { entry in
                                        LocationHistoryRow(entry: entry) {
                                            selectedEntry = entry
                                            showingMap = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Location History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: exportLocationHistory) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: showDeleteConfirmation) {
                            Label("Delete All", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                        
                        Toggle("Enable History Tracking", isOn: $isLocationHistoryEnabled)
                            .onChange(of: isLocationHistoryEnabled) { _, newValue in
                                toggleLocationHistory(newValue)
                            }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                loadLocationHistory()
                checkLocationHistoryStatus()
            }
            .onChange(of: selectedTimeRange) { _, _ in
                loadLocationHistory()
            }
            .sheet(isPresented: $showingMap) {
                if let entry = selectedEntry {
                    LocationHistoryMapView(entry: entry)
                }
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Delete All Location History", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllLocationHistory()
                }
            } message: {
                Text("This will permanently delete all your location history. This action cannot be undone.")
            }
        }
    }
    
    private var groupedLocationHistory: [(key: String, value: [LocationHistoryEntry])] {
        let grouped = Dictionary(grouping: locationHistory) { entry in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: entry.createdAt)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
    
    private func loadLocationHistory() {
        guard isLocationHistoryEnabled else {
            locationHistory = []
            isLoading = false
            return
        }
        
        isLoading = true
        
        Task {
            do {
                guard let session = try? await SupabaseManager.shared.client.auth.session else {
                    await MainActor.run {
                        locationHistory = []
                        isLoading = false
                    }
                    return
                }
                
                let userId = session.user.id.uuidString
                let iso8601Formatter = ISO8601DateFormatter()
                iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let dateFilter: String? = {
                    switch selectedTimeRange {
                    case .day:
                        let todayStart = Calendar.current.startOfDay(for: Date())
                        return iso8601Formatter.string(from: todayStart)
                    case .week:
                        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        return iso8601Formatter.string(from: sevenDaysAgo)
                    case .month:
                        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                        return iso8601Formatter.string(from: thirtyDaysAgo)
                    case .all:
                        return nil
                    }
                }()
                
                var query = SupabaseManager.shared.client
                    .from("location_history")
                    .select("*")
                    .eq("user_id", value: userId)
                
                if let filterDate = dateFilter {
                    query = query.gte("created_at", value: filterDate)
                }
                
                let entries: [LocationHistoryEntry] = try await query
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                
                await MainActor.run {
                    locationHistory = entries
                    isLoading = false
                }
            } catch {
                print("❌ Failed to load location history: \(error)")
                await MainActor.run {
                    locationHistory = []
                    isLoading = false
                }
            }
        }
    }
    
    private func checkLocationHistoryStatus() {
        isLocationHistoryEnabled = UserDefaults.standard.bool(forKey: "locationHistoryEnabled")
    }
    
    private func enableLocationHistory() {
        isLocationHistoryEnabled = true
        UserDefaults.standard.set(true, forKey: "locationHistoryEnabled")
        locationManager.enableLocationHistory()
        loadLocationHistory()
    }
    
    private func toggleLocationHistory(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "locationHistoryEnabled")
        if enabled {
            locationManager.enableLocationHistory()
        } else {
            locationManager.disableLocationHistory()
        }
        loadLocationHistory()
    }
    
    private func exportLocationHistory() {
        guard !locationHistory.isEmpty else { return }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(locationHistory)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("location_history_\(Date().timeIntervalSince1970).json")
            try data.write(to: tempURL)
            
            exportURL = tempURL
            showExportSheet = true
        } catch {
            print("❌ Failed to export location history: \(error)")
        }
    }
    
    private func showDeleteConfirmation() {
        showDeleteAlert = true
    }
    
    private func deleteAllLocationHistory() {
        Task {
            do {
                guard let session = try? await SupabaseManager.shared.client.auth.session else { return }
                
                let userId = session.user.id.uuidString
                
                try await SupabaseManager.shared.client
                    .from("location_history")
                    .delete()
                    .eq("user_id", value: userId)
                    .execute()
                
                await MainActor.run {
                    locationHistory = []
                }
            } catch {
                print("❌ Failed to delete location history: \(error)")
            }
        }
    }
}

struct LocationHistoryRow: View {
    let entry: LocationHistoryEntry
    let onTap: () -> Void
    
    private var displayLocationName: String {
        entry.locationName ?? "Unknown Location"
    }
    
    private var displayActivityType: String {
        entry.activityType ?? "unknown"
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Activity Icon
                Image(systemName: activityIcon)
                    .foregroundColor(activityColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayLocationName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayActivityType.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: entry.createdAt)
    }
    
    private var activityIcon: String {
        switch displayActivityType.lowercased() {
        case "walking":
            return "figure.walk"
        case "driving", "automotive":
            return "car.fill"
        case "stationary":
            return "figure.stand"
        case "running":
            return "figure.run"
        case "cycling":
            return "bicycle"
        default:
            return "location.fill"
        }
    }
    
    private var activityColor: Color {
        switch displayActivityType.lowercased() {
        case "walking":
            return .green
        case "driving", "automotive":
            return .blue
        case "stationary":
            return .orange
        case "running":
            return .purple
        case "cycling":
            return .cyan
        default:
            return .gray
        }
    }
}

struct LocationHistoryMapView: View {
    let entry: LocationHistoryEntry
    @Environment(\.dismiss) private var dismiss
    
    @State private var region: MKCoordinateRegion
    
    private var displayLocationName: String {
        entry.locationName ?? "Unknown Location"
    }
    
    init(entry: LocationHistoryEntry) {
        self.entry = entry
        self._region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationView {
            Map(position: .constant(.region(region))) {
                Annotation(displayLocationName, coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)) {
                    VStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        Text(displayLocationName)
                            .font(.caption)
                            .padding(4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
            }
            .navigationTitle(displayLocationName)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LocationHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        LocationHistoryView()
    }
}
