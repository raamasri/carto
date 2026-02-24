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
    @Environment(\.dismiss) private var dismiss
    
    @State private var geofences: [Geofence] = []
    @State private var showingCreateGeofence: Bool = false
    @State private var selectedGeofence: Geofence?
    @State private var isLoading: Bool = true
    @State private var loadError: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading geofences...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)
                        Text("Failed to Load")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            loadError = nil
                            loadGeofences()
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
                        dismiss()
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
                CreateGeofenceView {
                    loadGeofences()
                }
            }
            .sheet(item: $selectedGeofence) { geofence in
                GeofenceDetailView(geofence: geofence) {
                    loadGeofences()
                }
            }
        }
    }
    
    private func loadGeofences() {
        Task {
            isLoading = true
            loadError = nil
            
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                let userId = session.user.id.uuidString
                
                let fetched: [Geofence] = try await SupabaseManager.shared.client
                    .from("geofences")
                    .select()
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
                
                await MainActor.run {
                    geofences = fetched
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadError = error.localizedDescription
                    geofences = []
                    isLoading = false
                }
            }
        }
    }
    
    private func deleteGeofences(at offsets: IndexSet) {
        let geofencesToDelete = offsets.map { geofences[$0] }
        
        Task {
            let client = SupabaseManager.shared.client
            for geofence in geofencesToDelete {
                _ = try? await client
                    .from("geofences")
                    .delete()
                    .eq("id", value: geofence.id)
                    .execute()
            }
            await MainActor.run {
                geofences.remove(atOffsets: offsets)
            }
        }
    }
}

struct GeofenceRow: View {
    let geofence: Geofence
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(geofence.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = geofence.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
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
    @Environment(\.dismiss) private var dismiss
    let onSaveComplete: () -> Void
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var radius: Double = 100
    @State private var notificationType: String = "both"
    @State private var showingLocationPicker: Bool = false
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    
    let notificationTypes = [
        ("enter", "When Entering"),
        ("exit", "When Leaving"),
        ("both", "Enter & Exit")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
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
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGeofence()
                    }
                    .disabled(!canSave || isSaving)
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
        
        isSaving = true
        saveError = nil
        
        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session
                
                let insert = GeofenceInsert(
                    user_id: session.user.id.uuidString,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    radius: radius,
                    notification_type: notificationType
                )
                
                _ = try await SupabaseManager.shared.client
                    .from("geofences")
                    .insert(insert)
                    .execute()
                
                await MainActor.run {
                    onSaveComplete()
                    dismiss()
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

/// Payload for updating geofence fields in Supabase
private struct GeofenceUpdatePayload: Encodable {
    let name: String
    let description: String?
    let radius: Double
    let is_active: Bool
    let notification_type: String
}

struct GeofenceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let geofence: Geofence
    let onUpdateComplete: () -> Void
    
    @State private var name: String
    @State private var description: String
    @State private var radius: Double
    @State private var isActive: Bool
    @State private var notificationType: String
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    
    init(geofence: Geofence, onUpdateComplete: @escaping () -> Void) {
        self.geofence = geofence
        self.onUpdateComplete = onUpdateComplete
        self._name = State(initialValue: geofence.name)
        self._description = State(initialValue: geofence.description ?? "")
        self._radius = State(initialValue: geofence.radius)
        self._isActive = State(initialValue: geofence.isActive)
        self._notificationType = State(initialValue: geofence.notificationType)
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
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
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
    
    private func saveChanges() {
        isSaving = true
        saveError = nil
        
        Task {
            do {
                let payload = GeofenceUpdatePayload(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    radius: radius,
                    is_active: isActive,
                    notification_type: notificationType
                )
                
                _ = try await SupabaseManager.shared.client
                    .from("geofences")
                    .update(payload)
                    .eq("id", value: geofence.id)
                    .execute()
                
                await MainActor.run {
                    onUpdateComplete()
                    dismiss()
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onLocationSelected: (CLLocationCoordinate2D) -> Void
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationView {
            ZStack {
                Map(position: .constant(.region(region))) {
                    UserAnnotation()
                }
                .onTapGesture {
                    // Use center as selected coordinate; tap location would require MapReader for proper conversion
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
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select") {
                        if let coordinate = selectedCoordinate {
                            onLocationSelected(coordinate)
                        } else {
                            onLocationSelected(region.center)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Geofence Hashable for sheet(item:)
extension Geofence: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Geofence, rhs: Geofence) -> Bool {
        lhs.id == rhs.id
    }
}

struct GeofenceManagementView_Previews: PreviewProvider {
    static var previews: some View {
        GeofenceManagementView()
    }
}
