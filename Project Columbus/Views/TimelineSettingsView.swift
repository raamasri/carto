//
//  TimelineSettingsView.swift
//  Project Columbus
//
//  Created by Assistant on 1/10/25.
//

import SwiftUI

struct TimelineSettingsView: View {
    @StateObject private var timelineManager = TimelineManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var minimumStayDuration: Double = 5 // minutes
    @State private var significantLocationDistance: Double = 100 // meters
    @State private var showClearDataAlert: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                // Timeline Control
                Section {
                    Toggle("Enable Timeline", isOn: $timelineManager.isTimelineEnabled)
                        .onChange(of: timelineManager.isTimelineEnabled) { _, newValue in
                            if newValue {
                                timelineManager.enableTimeline()
                            } else {
                                timelineManager.disableTimeline()
                            }
                        }
                } header: {
                    Text("Timeline")
                } footer: {
                    Text("When enabled, your timeline will automatically track places you visit and create post drafts. This feature requires location access.")
                }
                
                if timelineManager.isTimelineEnabled {
                    // Tracking Settings
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Minimum Stay Duration")
                                .font(.subheadline)
                            
                            HStack {
                                Text("\(Int(minimumStayDuration)) minutes")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            Slider(value: $minimumStayDuration, in: 1...30, step: 1)
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location Sensitivity")
                                .font(.subheadline)
                            
                            HStack {
                                Text("\(Int(significantLocationDistance)) meters")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            Slider(value: $significantLocationDistance, in: 50...500, step: 50)
                        }
                        .padding(.vertical, 4)
                        
                    } header: {
                        Text("Tracking Settings")
                    } footer: {
                        Text("Minimum stay duration determines how long you need to be at a location before it's added to your timeline. Location sensitivity controls how far you need to move for a new location to be detected.")
                    }
                    
                    // Privacy Settings
                    Section {
                        NavigationLink(destination: TimelinePrivacySettingsView()) {
                            Label("Privacy Settings", systemImage: "lock")
                        }
                        
                        NavigationLink(destination: TimelineDataManagementView()) {
                            Label("Data Management", systemImage: "folder")
                        }
                        
                    } header: {
                        Text("Privacy & Data")
                    }
                    
                    // Statistics
                    Section {
                        HStack {
                            Text("Timeline Entries")
                            Spacer()
                            Text("\(timelineManager.timelineEntries.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Post Drafts")
                            Spacer()
                            Text("\(timelineManager.postDrafts.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Published Posts")
                            Spacer()
                            Text("\(timelineManager.postDrafts.filter { $0.isPublished }.count)")
                                .foregroundColor(.secondary)
                        }
                        
                    } header: {
                        Text("Statistics")
                    }
                    
                    // Data Management
                    Section {
                        Button(action: {
                            showClearDataAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear All Timeline Data")
                            }
                            .foregroundColor(.red)
                        }
                        
                    } header: {
                        Text("Data Management")
                    } footer: {
                        Text("This will permanently delete all your timeline entries and unpublished post drafts. Published posts will not be affected.")
                    }
                }
            }
            .navigationTitle("Timeline Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Clear Timeline Data", isPresented: $showClearDataAlert) {
            Button("Clear", role: .destructive) {
                clearTimelineData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear all timeline data? This action cannot be undone.")
        }
    }
    
    private func clearTimelineData() {
        // This would implement clearing all timeline data
        // For now, just clear the local arrays
        Task {
            // In a real implementation, you would delete from the database
            await MainActor.run {
                timelineManager.timelineEntries.removeAll()
                timelineManager.postDrafts.removeAll()
            }
        }
    }
}

// MARK: - Timeline Privacy Settings View

struct TimelinePrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var shareTimelineWithFriends: Bool = false
    @State private var allowTimelineDiscovery: Bool = false
    @State private var autoDeleteOldEntries: Bool = true
    @State private var autoDeleteDays: Double = 30
    
    var body: some View {
        List {
            Section {
                Toggle("Share Timeline with Friends", isOn: $shareTimelineWithFriends)
                Toggle("Allow Timeline Discovery", isOn: $allowTimelineDiscovery)
                
            } header: {
                Text("Sharing")
            } footer: {
                Text("When enabled, your friends can see your timeline entries. Timeline discovery allows others to find your public timeline entries in their recommendations.")
            }
            
            Section {
                Toggle("Auto-delete Old Entries", isOn: $autoDeleteOldEntries)
                
                if autoDeleteOldEntries {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Delete entries after")
                            .font(.subheadline)
                        
                        HStack {
                            Text("\(Int(autoDeleteDays)) days")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        Slider(value: $autoDeleteDays, in: 7...365, step: 7)
                    }
                    .padding(.vertical, 4)
                }
                
            } header: {
                Text("Data Retention")
            } footer: {
                Text("Automatically delete timeline entries older than the specified number of days to save storage space.")
            }
        }
        .navigationTitle("Privacy Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Timeline Data Management View

struct TimelineDataManagementView: View {
    @StateObject private var timelineManager = TimelineManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showExportSheet: Bool = false
    @State private var exportFormat: ExportFormat = .json
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                Button(action: {
                    showExportSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Timeline Data")
                    }
                }
                
                Button(action: {
                    // Import functionality would go here
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import Timeline Data")
                    }
                }
                .disabled(true) // Disabled for now
                
            } header: {
                Text("Import/Export")
            } footer: {
                Text("Export your timeline data to backup or transfer to another device.")
            }
            
            Section {
                HStack {
                    Text("Total Storage Used")
                    Spacer()
                    Text("~\(estimatedStorageSize()) MB")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Timeline Entries")
                    Spacer()
                    Text("\(timelineManager.timelineEntries.count)")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Post Drafts")
                    Spacer()
                    Text("\(timelineManager.postDrafts.count)")
                        .foregroundColor(.secondary)
                }
                
            } header: {
                Text("Storage Information")
            }
        }
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExportSheet) {
            ExportDataView(exportFormat: $exportFormat)
        }
    }
    
    private func estimatedStorageSize() -> String {
        // Rough estimate based on number of entries
        let entriesSize = timelineManager.timelineEntries.count * 1024 // ~1KB per entry
        let draftsSize = timelineManager.postDrafts.count * 2048 // ~2KB per draft
        let totalBytes = entriesSize + draftsSize
        let totalMB = Double(totalBytes) / (1024 * 1024)
        return String(format: "%.1f", totalMB)
    }
}

// MARK: - Export Data View

struct ExportDataView: View {
    @Binding var exportFormat: TimelineDataManagementView.ExportFormat
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Export Timeline Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose the format for your exported timeline data.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Picker("Export Format", selection: $exportFormat) {
                    ForEach(TimelineDataManagementView.ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                
                Button(action: {
                    exportData()
                }) {
                    Text("Export Data")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportData() {
        // Export functionality would be implemented here
        // For now, just dismiss
        dismiss()
    }
}

#Preview {
    TimelineSettingsView()
}