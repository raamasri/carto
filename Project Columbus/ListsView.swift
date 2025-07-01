//
//  ListsView.swift
//  Project Columbus
//
//  Created by raama srivatsan on 4/16/25.
//

import SwiftUI
import MapKit

// --- Add these helpers at the top-level (outside any struct) ---
private func iconForCollection(_ name: String) -> String {
    switch name.lowercased() {
    case "favorites": return "heart.fill"
    case "coffee shops": return "cup.and.saucer.fill"
    case "restaurants": return "fork.knife"
    case "bars": return "wineglass.fill"
    case "shopping": return "bag.fill"
    default: return "folder.fill"
    }
}

private func colorForCollection(_ name: String) -> Color {
    switch name.lowercased() {
    case "favorites": return .red
    case "coffee shops": return .brown
    case "restaurants": return .orange
    case "bars": return .purple
    case "shopping": return .pink
    default: return .blue
    }
}

struct ListsView: View {
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @State private var showCreateList = false
    @State private var newListName = ""
    @State private var searchText = ""
    
    // Deduplicate lists by name (case-insensitive)
    var filteredLists: [PinList] {
        let sorted = pinStore.lists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        var seen = Set<String>()
        let deduped = sorted.filter { list in
            let lower = list.name.lowercased()
            if seen.contains(lower) { return false }
            seen.insert(lower)
            return true
        }
        if searchText.isEmpty {
            return deduped
        } else {
            return deduped.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search lists...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                if pinStore.isLoading {
                    VStack {
                        ProgressView("Loading lists...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredLists.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Lists Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start organizing your pins by creating lists!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Create Your First List") {
                            showCreateList = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredLists, id: \.id) { list in
                            NavigationLink(destination: ListDetailView(list: list)) {
                                ListRowView(list: list)
                            }
                        }
                        .onDelete(perform: deleteLists)
                    }
                    .listStyle(.plain)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .refreshable {
                        await pinStore.refresh()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateList = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateList) {
                CreateListSheet(
                    isPresented: $showCreateList,
                    newListName: $newListName
                ) { name in
                    pinStore.createCustomList(name: name)
                }
            }
        }
        .onAppear {
            // Always refresh on appear to ensure we have the latest data
            Task {
                await pinStore.refresh()
            }
        }
    }
    
    private func deleteLists(offsets: IndexSet) {
        for index in offsets {
            let list = filteredLists[index]
            pinStore.deleteList(named: list.name)
        }
    }
}

struct ListRowView: View {
    let list: PinList
    
    var body: some View {
        HStack {
            // List icon with notification dots overlay
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorForCollection(list.name))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: iconForCollection(list.name))
                            .foregroundColor(.white)
                            .font(.title2)
                    )
                
                // Notification dots on top corner of icon
                if !list.pins.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(Array(list.pins.prefix(3)), id: \.id) { pin in
                            Circle()
                                .fill(pin.reaction == .lovedIt ? .red : .blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .offset(x: 5, y: -5) // Position on top corner
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(list.pins.count) pin\(list.pins.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !list.pins.isEmpty {
                    Text("Latest: \(list.pins.first?.locationName ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Just the arrow now
            if !list.pins.isEmpty {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateListSheet: View {
    @Binding var isPresented: Bool
    @Binding var newListName: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create New List")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                Text("Give your list a name to start organizing your pins")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("List name", text: $newListName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("New List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        newListName = ""
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        if !newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(newListName.trimmingCharacters(in: .whitespacesAndNewlines))
                            isPresented = false
                            newListName = ""
                        }
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct ListDetailView: View {
    let list: PinList
    @EnvironmentObject var pinStore: PinStore
    @State private var searchText = ""
    @State private var selectedPin: Pin?
    @State private var showFullPOIView = false
    @State private var selectedMapItem: MKMapItem?
    @EnvironmentObject var locationManager: AppLocationManager
    
    var filteredPins: [Pin] {
        if searchText.isEmpty {
            return list.pins
        } else {
            return list.pins.filter {
                $0.locationName.localizedCaseInsensitiveContains(searchText) ||
                $0.city.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search pins in \(list.name)...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                if filteredPins.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text(searchText.isEmpty ? "No Pins Yet" : "No Matching Pins")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(searchText.isEmpty ? "Start adding pins to this list!" : "Try a different search term")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredPins, id: \.id) { pin in
                            Button(action: {
                                // Convert Pin to MKMapItem for full page POI view
                                let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                                let placemark = MKPlacemark(coordinate: coordinate)
                                let mapItem = MKMapItem(placemark: placemark)
                                mapItem.name = pin.locationName
                                
                                selectedMapItem = mapItem
                                selectedPin = pin
                                showFullPOIView = true
                            }) {
                                PinRowView(pin: pin)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete(perform: deletePins)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(list.name)
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showFullPOIView) {
                if let mapItem = selectedMapItem {
                    LocationDetailView(mapItem: mapItem, onAddPin: { pin in
                        // Add the pin to the current list if user chooses to add it
                        pinStore.addPin(pin, to: list.name)
                    })
                }
            }
        }
    }
    
    private func deletePins(offsets: IndexSet) {
        for index in offsets {
            let pin = filteredPins[index]
            pinStore.removePin(pin, from: list.name)
        }
    }
}

struct PinRowView: View {
    let pin: Pin
    
    var body: some View {
        HStack {
            // Pin reaction icon
            Circle()
                .fill(pin.reaction == .lovedIt ? .red : .blue)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: pin.reaction == .lovedIt ? "heart.fill" : "bookmark.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pin.locationName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !pin.city.isEmpty {
                    Text(pin.city)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let reviewText = pin.reviewText, !reviewText.isEmpty {
                    Text(reviewText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(pin.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let rating = pin.starRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            VStack {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let distance = pin.distance {
                    Text(String(format: "%.1f km", distance))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PinDetailView: View {
    let pin: Pin
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(pin.locationName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if !pin.city.isEmpty {
                            Text(pin.city)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: pin.reaction == .lovedIt ? "heart.fill" : "bookmark.fill")
                                .foregroundColor(pin.reaction == .lovedIt ? .red : .blue)
                            Text(pin.reaction.rawValue)
                                .fontWeight(.medium)
                        }
                    }
                    
                    Divider()
                    
                    // Details
                    if let reviewText = pin.reviewText, !reviewText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Review")
                                .font(.headline)
                            Text(reviewText)
                                .font(.body)
                        }
                        
                        Divider()
                    }
                    
                    // Location details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        Text("Latitude: \(pin.latitude, specifier: "%.6f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Longitude: \(pin.longitude, specifier: "%.6f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let rating = pin.starRating {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rating")
                                .font(.headline)
                            
                            HStack {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                                        .foregroundColor(.yellow)
                                }
                                Text("(\(rating, specifier: "%.1f"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Pin Details")
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