//
//  TimelineView.swift
//  Project Columbus
//
//  Created by Assistant on 1/10/25.
//

import SwiftUI
import MapKit

struct TimelineView: View {
    @StateObject private var timelineManager = TimelineManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingSettings: Bool = false
    @State private var selectedEntry: TimelineEntry?
    @State private var showingDrafts: Bool = false
    
    enum TimeRange: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case all = "All Time"
    }
    
    var filteredEntries: [TimelineEntry] {
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedTimeRange {
        case .day:
            return timelineManager.timelineEntries.filter { entry in
                calendar.isDate(entry.arrivalTime, inSameDayAs: now)
            }
        case .week:
            let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return timelineManager.timelineEntries.filter { entry in
                entry.arrivalTime >= weekAgo
            }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return timelineManager.timelineEntries.filter { entry in
                entry.arrivalTime >= monthAgo
            }
        case .all:
            return timelineManager.timelineEntries
        }
    }
    
    var groupedEntries: [(key: String, value: [TimelineEntry])] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            DateFormatter.dayFormatter.string(from: entry.arrivalTime)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if !timelineManager.isTimelineEnabled {
                    // Timeline Disabled State
                    timelineDisabledView
                } else if timelineManager.timelineEntries.isEmpty {
                    // Empty State
                    emptyStateView
                } else {
                    // Timeline Content
                    timelineContentView
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingDrafts = true }) {
                            Label("Post Drafts", systemImage: "doc.text")
                        }
                        
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await timelineManager.loadTimelineData()
        }
        .sheet(isPresented: $showingSettings) {
            TimelineSettingsView()
        }
        .sheet(isPresented: $showingDrafts) {
            PostDraftsView()
        }
        .sheet(item: $selectedEntry) { entry in
            TimelineEntryDetailView(entry: entry)
        }
    }
    
    // MARK: - Timeline Disabled View
    
    private var timelineDisabledView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Timeline Disabled")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enable timeline to automatically track the places you visit and create post drafts.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Enable Timeline") {
                timelineManager.enableTimeline()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Timeline Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your timeline will show places you visit and how long you stay. Start exploring to build your timeline!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Timeline Content View
    
    private var timelineContentView: some View {
        VStack {
            // Time Range Picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Timeline List
            List {
                ForEach(groupedEntries, id: \.key) { day, entries in
                    Section(header: Text(day)) {
                        ForEach(entries) { entry in
                            TimelineEntryRow(entry: entry) {
                                selectedEntry = entry
                            }
                        }
                    }
                }
            }
            .refreshable {
                await timelineManager.loadTimelineData()
            }
            
            // Draft Count Badge
            if !timelineManager.postDrafts.filter({ !$0.isPublished }).isEmpty {
                Button(action: { showingDrafts = true }) {
                    HStack {
                        Image(systemName: "doc.text.badge")
                        Text("\(timelineManager.postDrafts.filter({ !$0.isPublished }).count) Draft\(timelineManager.postDrafts.filter({ !$0.isPublished }).count == 1 ? "" : "s")")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Timeline Entry Row

struct TimelineEntryRow: View {
    let entry: TimelineEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.locationName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(entry.city)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(DateFormatter.timeFormatter.string(from: entry.arrivalTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let departureTime = entry.departureTime {
                            Text("→")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(DateFormatter.timeFormatter.string(from: departureTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(entry.durationString)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(entry.isCurrentLocation ? .green : .primary)
                    }
                }
                
                Spacer()
                
                VStack {
                    if entry.isCurrentLocation {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timeline Entry Detail View

struct TimelineEntryDetailView: View {
    let entry: TimelineEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Map View
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [entry]) { entry in
                    MapPin(coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude))
                }
                .frame(height: 200)
                .cornerRadius(12)
                
                // Details
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.locationName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(entry.city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Arrival")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(DateFormatter.dateTimeFormatter.string(from: entry.arrivalTime))
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        if let departureTime = entry.departureTime {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Departure")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(DateFormatter.dateTimeFormatter.string(from: departureTime))
                                    .font(.subheadline)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.durationString)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(entry.isCurrentLocation ? .green : .primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Timeline Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Date Formatters

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    TimelineView()
}