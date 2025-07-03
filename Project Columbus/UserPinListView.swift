//
//  UserPinListView.swift
//  Project Columbus
//
//  Created by Assistant on 2025-01-02.
//

import SwiftUI
import MapKit

struct UserPinListView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    @State private var userPins: [Pin] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedReaction: Reaction? = nil
    @State private var showingLocationDetail = false
    @State private var selectedPin: Pin?
    
    let userId: String
    let userName: String
    
    var filteredPins: [Pin] {
        var pins = userPins
        
        // Filter by search text
        if !searchText.isEmpty {
            pins = pins.filter { pin in
                pin.locationName.localizedCaseInsensitiveContains(searchText) ||
                pin.city.localizedCaseInsensitiveContains(searchText) ||
                (pin.reviewText?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Filter by reaction
        if let selectedReaction = selectedReaction {
            pins = pins.filter { $0.reaction == selectedReaction }
        }
        
        return pins.sorted { $0.createdAt > $1.createdAt }
    }
    
    var hasReviews: Bool {
        userPins.contains { pin in
            pin.reviewText != nil && !pin.reviewText!.isEmpty
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading pins...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if userPins.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        filterSection
                        pinsList
                    }
                }
            }
            .navigationTitle("\(userName)'s Pins")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search pins...")
            .sheet(isPresented: $showingLocationDetail) {
                if let selectedPin = selectedPin {
                    NavigationView {
                        LocationDetailView(
                            mapItem: createMapItem(from: selectedPin),
                            onAddPin: { _ in }
                        )
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingLocationDetail = false
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadUserPins()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Pins Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("\(userName) hasn't added any pins to explore yet.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All filter
                UserPinFilterChip(
                    title: "All (\(userPins.count))",
                    isSelected: selectedReaction == nil,
                    action: { selectedReaction = nil }
                )
                
                // Reaction filters
                ForEach(Reaction.allCases, id: \.self) { reaction in
                    let count = userPins.filter { $0.reaction == reaction }.count
                    if count > 0 {
                        UserPinFilterChip(
                            title: "\(reaction.rawValue) (\(count))",
                            isSelected: selectedReaction == reaction,
                            action: { selectedReaction = reaction }
                        )
                    }
                }
                
                // Reviews filter (if user has reviews)
                if hasReviews {
                    let reviewCount = userPins.filter { pin in
                        pin.reviewText != nil && !pin.reviewText!.isEmpty
                    }.count
                    UserPinFilterChip(
                        title: "Reviews (\(reviewCount))",
                        isSelected: false, // This would need additional state
                        action: { /* Add review filter logic */ }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var pinsList: some View {
        List(filteredPins) { pin in
            UserPinRowView(pin: pin) {
                selectedPin = pin
                showingLocationDetail = true
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listStyle(.plain)
    }
    
    private func loadUserPins() {
        isLoading = true
        
        Task {
            // Use the existing getFeedPins method or fetch from pinStore
            let pins = await SupabaseManager.shared.getFeedPins(for: userId, limit: 1000)
            
            await MainActor.run {
                self.userPins = pins
                self.isLoading = false
            }
        }
    }
    
    private func createMapItem(from pin: Pin) -> MKMapItem {
        let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = pin.locationName
        return mapItem
    }
}

struct UserPinFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UserPinRowView: View {
    let pin: Pin
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header with location name and reaction
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pin.locationName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(pin.city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Reaction badge
                    HStack(spacing: 4) {
                        Image(systemName: reactionIcon(for: pin.reaction))
                            .foregroundColor(reactionColor(for: pin.reaction))
                        Text(pin.reaction.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(reactionColor(for: pin.reaction).opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Review text if available
                if let reviewText = pin.reviewText, !reviewText.isEmpty {
                    Text(reviewText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .padding(.top, 4)
                }
                
                // Star rating if available
                if let starRating = pin.starRating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(starRating) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                        Text("(\(starRating, specifier: "%.1f"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                }
                
                // Date
                HStack {
                    Text(pin.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let distance = pin.distance {
                        Text(DistanceFormatter.formatDistance(distance))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func reactionIcon(for reaction: Reaction) -> String {
        switch reaction {
        case .lovedIt:
            return "heart.fill"
        case .wantToGo:
            return "bookmark.fill"
        }
    }
    
    private func reactionColor(for reaction: Reaction) -> Color {
        switch reaction {
        case .lovedIt:
            return .red
        case .wantToGo:
            return .blue
        }
    }
}

#Preview {
    UserPinListView(userId: "sample-user-id", userName: "John Doe")
        .environmentObject(AuthManager())
        .environmentObject(PinStore())
} 