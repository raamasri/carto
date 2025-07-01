//
//  LocationHistoryView.swift
//  Project Columbus
//
//  Created by Assistant on 6/30/25.
//

import SwiftUI
import MapKit

struct LocationHistoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var locationHistory: [MockLocationEntry] = []
    @State private var isLoading: Bool = true
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingMap: Bool = false
    @State private var selectedEntry: MockLocationEntry?
    @State private var isLocationHistoryEnabled: Bool = false
    
    enum TimeRange: String, CaseIterable {
        case day = "Today"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time Range Picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if isLoading {
                    ProgressView("Loading location history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if locationHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("No Location History")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Enable location history to see your past locations here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        if !isLocationHistoryEnabled {
                            Button("Enable Location History") {
                                enableLocationHistory()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedLocationHistory, id: \.key) { group in
                            Section(header: Text(group.key)) {
                                ForEach(group.value, id: \.id) { entry in
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
            .navigationTitle("Location History")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            exportLocationHistory()
                        }) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            showDeleteConfirmation()
                        }) {
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
        }
    }
    
    private var groupedLocationHistory: [(key: String, value: [MockLocationEntry])] {
        let grouped = Dictionary(grouping: locationHistory) { entry in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: entry.timestamp)
        }
        
        return grouped.sorted { $0.key > $1.key }
    }
    
    private func loadLocationHistory() {
        isLoading = true
        
        // Simulate loading with mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            locationHistory = generateMockLocationHistory()
            isLoading = false
        }
    }
    
    private func checkLocationHistoryStatus() {
        isLocationHistoryEnabled = UserDefaults.standard.bool(forKey: "locationHistoryEnabled")
    }
    
    private func enableLocationHistory() {
        isLocationHistoryEnabled = true
        UserDefaults.standard.set(true, forKey: "locationHistoryEnabled")
        // TODO: Enable in LocationManager when accessible
    }
    
    private func toggleLocationHistory(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "locationHistoryEnabled")
        // TODO: Toggle in LocationManager when accessible
    }
    
    private func exportLocationHistory() {
        // TODO: Implement export functionality
        print("Exporting location history...")
    }
    
    private func showDeleteConfirmation() {
        // TODO: Show confirmation alert
        print("Delete confirmation...")
    }
    
    private func generateMockLocationHistory() -> [MockLocationEntry] {
        let now = Date()
        var entries: [MockLocationEntry] = []
        
        for i in 0..<20 {
            let timestamp = Calendar.current.date(byAdding: .hour, value: -i * 2, to: now) ?? now
            let entry = MockLocationEntry(
                id: UUID(),
                timestamp: timestamp,
                latitude: 37.7749 + Double.random(in: -0.01...0.01),
                longitude: -122.4194 + Double.random(in: -0.01...0.01),
                locationName: ["Home", "Work", "Coffee Shop", "Gym", "Restaurant"].randomElement() ?? "Unknown",
                activityType: ["walking", "driving", "stationary"].randomElement() ?? "unknown"
            )
            entries.append(entry)
        }
        
        return entries
    }
}

struct MockLocationEntry: Identifiable {
    let id: UUID
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let locationName: String
    let activityType: String
}

struct LocationHistoryRow: View {
    let entry: MockLocationEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Activity Icon
                Image(systemName: activityIcon)
                    .foregroundColor(activityColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.locationName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.activityType.capitalized)
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
        return formatter.string(from: entry.timestamp)
    }
    
    private var activityIcon: String {
        switch entry.activityType {
        case "walking":
            return "figure.walk"
        case "driving":
            return "car.fill"
        case "stationary":
            return "figure.stand"
        default:
            return "location.fill"
        }
    }
    
    private var activityColor: Color {
        switch entry.activityType {
        case "walking":
            return .green
        case "driving":
            return .blue
        case "stationary":
            return .orange
        default:
            return .gray
        }
    }
}

struct LocationHistoryMapView: View {
    let entry: MockLocationEntry
    @Environment(\.presentationMode) var presentationMode
    
    @State private var region: MKCoordinateRegion
    
    init(entry: MockLocationEntry) {
        self.entry = entry
        self._region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: $region, annotationItems: [entry]) { entry in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)) {
                    VStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                        Text(entry.locationName)
                            .font(.caption)
                            .padding(4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
            }
            .navigationTitle(entry.locationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
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