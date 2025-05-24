//
//  CollectionsView.swift
//  Project Columbus copy
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

struct CollectionsView: View {
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @State private var showCreateCollection = false
    @State private var newCollectionName = ""
    @State private var searchText = ""
    
    var filteredCollections: [PinList] {
        let sorted = pinStore.lists.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { 
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
                    TextField("Search collections...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                if pinStore.isLoading {
                    VStack {
                        ProgressView("Loading collections...")
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredCollections.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Collections Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Start organizing your pins by creating collections!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Create Your First Collection") {
                            showCreateCollection = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredCollections, id: \.id) { collection in
                            NavigationLink(destination: CollectionDetailView(collection: collection)) {
                                CollectionRowView(collection: collection)
                            }
                        }
                        .onDelete(perform: deleteCollections)
                    }
                    .listStyle(.plain)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .refreshable {
                        await pinStore.refresh()
                    }
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateCollection = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateCollection) {
                CreateCollectionSheet(
                    isPresented: $showCreateCollection,
                    newCollectionName: $newCollectionName
                ) { name in
                    pinStore.createCustomList(name: name)
                }
            }
        }
        .onAppear {
            if pinStore.lists.isEmpty {
                Task {
                    await pinStore.refresh()
                }
            }
        }
    }
    
    private func deleteCollections(offsets: IndexSet) {
        for index in offsets {
            let collection = filteredCollections[index]
            pinStore.deleteList(named: collection.name)
        }
    }
}

struct CollectionRowView: View {
    let collection: PinList
    
    var body: some View {
        HStack {
            // Collection icon
            RoundedRectangle(cornerRadius: 8)
                .fill(colorForCollection(collection.name))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: iconForCollection(collection.name))
                        .foregroundColor(.white)
                        .font(.title2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(collection.pins.count) pin\(collection.pins.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !collection.pins.isEmpty {
                    Text("Latest: \(collection.pins.first?.locationName ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Preview images/pins
            if !collection.pins.isEmpty {
                VStack {
                    HStack(spacing: 2) {
                        ForEach(Array(collection.pins.prefix(3)), id: \.id) { pin in
                            Circle()
                                .fill(pin.reaction == .lovedIt ? .red : .blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateCollectionSheet: View {
    @Binding var isPresented: Bool
    @Binding var newCollectionName: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create New Collection")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                Text("Give your collection a name to start organizing your pins")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("Collection name", text: $newCollectionName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                        newCollectionName = ""
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        if !newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines))
                            isPresented = false
                            newCollectionName = ""
                        }
                    }
                    .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
} 