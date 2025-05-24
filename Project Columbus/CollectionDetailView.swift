//
//  CollectionDetailView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/16/25.
//

import SwiftUI
import MapKit

struct CollectionDetailView: View {
    let collection: PinList
    @EnvironmentObject var pinStore: PinStore
    @State private var searchText = ""
    @State private var selectedPin: Pin?
    @State private var showPinDetail = false
    
    var filteredPins: [Pin] {
        if searchText.isEmpty {
            return collection.pins
        } else {
            return collection.pins.filter {
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
                    TextField("Search pins in \(collection.name)...", text: $searchText)
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
                        
                        Text(searchText.isEmpty ? "Start adding pins to this collection!" : "Try a different search term")
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
                                selectedPin = pin
                                showPinDetail = true
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
            .navigationTitle(collection.name)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPinDetail) {
                if let pin = selectedPin {
                    PinDetailView(pin: pin)
                }
            }
        }
    }
    
    private func deletePins(offsets: IndexSet) {
        for index in offsets {
            let pin = filteredPins[index]
            pinStore.removePin(pin, from: collection.name)
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