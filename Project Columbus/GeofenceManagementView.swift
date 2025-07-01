//
//  GeofenceManagementView.swift
//  Project Columbus
//
//  Created by Assistant on 6/30/25.
//

import SwiftUI
import MapKit

struct GeofenceManagementView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: AppLocationManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var geofences: [MockGeofence] = []
    @State private var showingCreateGeofence: Bool = false
    @State private var selectedGeofence: MockGeofence?
    @State private var isLoading: Bool = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading geofences...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if geofences.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        
                        Text("No Location Alerts")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create geofences to get notified when you enter or leave specific locations")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Create First Alert") {
                            showingCreateGeofence = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(geofences, id: \.id) { geofence in
                            GeofenceRow(geofence: geofence) {
                                selectedGeofence = geofence
                            }
                        }
                        .onDelete(perform: deleteGeofences)
                    }
                }
            }
            .navigationTitle("Location Alerts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateGeofence = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(geofences.count >= 20) // iOS limit
                }
            }
            .onAppear {
                loadGeofences()
            }
            .sheet(isPresented: $showingCreateGeofence) {
                CreateGeofenceView { newGeofence in
                    geofences.append(newGeofence)
                }
            }
            .sheet(item: $selectedGeofence) { geofence in
                GeofenceDetailView(geofence: geofence) { updatedGeofence in
                    if let index = geofences.firstIndex(where: { $0.id == updatedGeofence.id }) {
                        geofences[index] = updatedGeofence
                    }
                }
            }
        }
    }
    
    private func loadGeofences() {
        isLoading = true
        
        // Simulate loading with mock data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            geofences = generateMockGeofences()
            isLoading = false
        }
    }
    
    private func deleteGeofences(at offsets: IndexSet) {
        geofences.remove(atOffsets: offsets)
    }
    
    private func generateMockGeofences() -> [MockGeofence] {
        return [
            MockGeofence(
                id: UUID(),
                name: "Home",
                description: "Get notified when arriving home",
                latitude: 37.7749,
                longitude: -122.4194,
                radius: 100,
                isActive: true,
                notificationType: "both"
            ),
            MockGeofence(
                id: UUID(),
                name: "Work",
                description: "Track work arrivals and departures",
                latitude: 37.7849,
                longitude: -122.4094,
                radius: 50,
                isActive: true,
                notificationType: "enter"
            )
        ]
    }
}

struct MockGeofence: Identifiable {
    let id: UUID
    var name: String
    var description: String
    var latitude: Double
    var longitude: Double
    var radius: Double
    var isActive: Bool
    var notificationType: String
}

struct GeofenceRow: View {
    let geofence: MockGeofence
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(geofence.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(geofence.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Label("\(Int(geofence.radius))m", systemImage: "location.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(notificationTypeText)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                VStack {
                    Circle()
                        .fill(geofence.isActive ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                    
                    Text(geofence.isActive ? "Active" : "Inactive")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var notificationTypeText: String {
        switch geofence.notificationType {
        case "enter":
            return "Enter"
        case "exit":
            return "Exit"
        case "both":
            return "Enter & Exit"
        default:
            return "Unknown"
        }
    }
}

struct CreateGeofenceView: View {
    @Environment(\.presentationMode) var presentationMode
    let onSave: (MockGeofence) -> Void
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var radius: Double = 100
    @State private var notificationType: String = "both"
    @State private var showingLocationPicker: Bool = false
    
    let notificationTypes = [
        ("enter", "When Entering"),
        ("exit", "When Leaving"),
        ("both", "Enter & Exit")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Location")) {
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Text("Select Location")
                            Spacer()
                            if selectedLocation != nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text("\(Int(radius))m")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $radius, in: 50...1000, step: 10)
                }
                
                Section(header: Text("Notifications")) {
                    ForEach(notificationTypes, id: \.0) { type in
                        Button(action: {
                            notificationType = type.0
                        }) {
                            HStack {
                                Text(type.1)
                                    .foregroundColor(.primary)
                                Spacer()
                                if notificationType == type.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("New Location Alert")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGeofence()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView { coordinate in
                selectedLocation = coordinate
            }
        }
    }
    
    private var canSave: Bool {
        !name.isEmpty && selectedLocation != nil
    }
    
    private func saveGeofence() {
        guard let location = selectedLocation else { return }
        
        let newGeofence = MockGeofence(
            id: UUID(),
            name: name,
            description: description.isEmpty ? "Geofence for \(name)" : description,
            latitude: location.latitude,
            longitude: location.longitude,
            radius: radius,
            isActive: true,
            notificationType: notificationType
        )
        
        onSave(newGeofence)
        presentationMode.wrappedValue.dismiss()
    }
}

struct GeofenceDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    let geofence: MockGeofence
    let onUpdate: (MockGeofence) -> Void
    
    @State private var name: String
    @State private var description: String
    @State private var radius: Double
    @State private var isActive: Bool
    @State private var notificationType: String
    
    init(geofence: MockGeofence, onUpdate: @escaping (MockGeofence) -> Void) {
        self.geofence = geofence
        self.onUpdate = onUpdate
        self._name = State(initialValue: geofence.name)
        self._description = State(initialValue: geofence.description)
        self._radius = State(initialValue: geofence.radius)
        self._isActive = State(initialValue: geofence.isActive)
        self._notificationType = State(initialValue: geofence.notificationType)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    Toggle("Active", isOn: $isActive)
                }
                
                Section(header: Text("Location")) {
                    HStack {
                        Text("Coordinates")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(geofence.latitude, specifier: "%.6f")")
                            Text("\(geofence.longitude, specifier: "%.6f")")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text("\(Int(radius))m")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $radius, in: 50...1000, step: 10)
                }
                
                Section(header: Text("Notifications")) {
                    Picker("Notification Type", selection: $notificationType) {
                        Text("When Entering").tag("enter")
                        Text("When Leaving").tag("exit")
                        Text("Enter & Exit").tag("both")
                    }
                }
            }
            .navigationTitle("Edit Alert")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
        }
    }
    
    private func saveChanges() {
        let updatedGeofence = MockGeofence(
            id: geofence.id,
            name: name,
            description: description,
            latitude: geofence.latitude,
            longitude: geofence.longitude,
            radius: radius,
            isActive: isActive,
            notificationType: notificationType
        )
        
        onUpdate(updatedGeofence)
        presentationMode.wrappedValue.dismiss()
    }
}

struct LocationPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true)
                    .onTapGesture { location in
                        // Convert tap location to coordinate
                        // This is a simplified version - actual implementation would need proper coordinate conversion
                        selectedCoordinate = region.center
                    }
                
                // Center pin
                VStack {
                    Spacer()
                    Image(systemName: "mappin")
                        .font(.title)
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .navigationTitle("Select Location")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select") {
                        if let coordinate = selectedCoordinate {
                            onLocationSelected(coordinate)
                        } else {
                            onLocationSelected(region.center)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct GeofenceManagementView_Previews: PreviewProvider {
    static var previews: some View {
        GeofenceManagementView()
    }
} 