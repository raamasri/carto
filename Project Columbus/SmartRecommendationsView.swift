//
//  SmartRecommendationsView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import SwiftUI
import MapKit

struct SmartRecommendationsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var pinStore: PinStore
    @StateObject private var locationManager = AppLocationManager()
    
    @State private var recommendations: [FriendRecommendation] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var selectedRecommendation: FriendRecommendation?
    @State private var showRecommendationDetail = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSettings = false
    
    // Filter states
    @State private var selectedCategory: RecommendationCategory = .all
    @State private var selectedDistance: DistanceFilter = .all
    @State private var showOnlyNew = false
    
    enum RecommendationCategory: String, CaseIterable {
        case all = "All"
        case friendBased = "From Friends"
        case trending = "Trending"
        case nearby = "Nearby"
        case personalized = "For You"
        
        var icon: String {
            switch self {
            case .all: return "sparkles"
            case .friendBased: return "person.2.fill"
            case .trending: return "flame.fill"
            case .nearby: return "location.fill"
            case .personalized: return "heart.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .purple
            case .friendBased: return .blue
            case .trending: return .orange
            case .nearby: return .green
            case .personalized: return .pink
            }
        }
    }
    
    enum DistanceFilter: String, CaseIterable {
        case all = "All Distances"
        case walking = "Walking (1km)"
        case biking = "Biking (5km)"
        case driving = "Driving (25km)"
        
        var maxDistance: Double? {
            switch self {
            case .all: return nil
            case .walking: return 1.0
            case .biking: return 5.0
            case .driving: return 25.0
            }
        }
    }
    
    var filteredRecommendations: [FriendRecommendation] {
        var filtered = recommendations
        
        // Filter by category
        if selectedCategory != .all {
            // This would need to be implemented based on recommendation type
            // For now, showing all recommendations
        }
        
        // Filter by distance
        if let maxDistance = selectedDistance.maxDistance,
           let userLocation = locationManager.location {
            filtered = filtered.filter { rec in
                let distance = CLLocation(latitude: rec.recommendedPlace.latitude, longitude: rec.recommendedPlace.longitude)
                    .distance(from: CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)) / 1000.0 // Convert to km
                return distance <= maxDistance
            }
        }
        
        // Filter by new recommendations
        if showOnlyNew {
            let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
            filtered = filtered.filter { rec in
                rec.recentVisits.contains { $0 > oneDayAgo }
            }
        }
        
        return filtered.sorted { $0.confidence > $1.confidence }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Header
                filterHeader
                
                // Recommendations Content
                if isLoading && recommendations.isEmpty {
                    loadingView
                } else if recommendations.isEmpty {
                    emptyStateView
                } else {
                    recommendationsListView
                }
            }
            .navigationTitle("Smart Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                    
                    Button(action: refreshRecommendations) {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRefreshing)
                    }
                }
            }
            .refreshable {
                await refreshRecommendationsAsync()
            }
            .sheet(isPresented: $showRecommendationDetail) {
                if let recommendation = selectedRecommendation {
                    RecommendationDetailView(recommendation: recommendation)
                        .environmentObject(authManager)
                        .environmentObject(supabaseManager)
                        .environmentObject(pinStore)
                }
            }
            .sheet(isPresented: $showSettings) {
                RecommendationSettingsView()
                    .environmentObject(authManager)
                    .environmentObject(supabaseManager)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Unknown error occurred")
            }
            .onAppear {
                loadRecommendations()
                locationManager.requestLocationPermission()
            }
        }
    }
    
    // MARK: - Filter Header
    private var filterHeader: some View {
        VStack(spacing: 12) {
            // Category filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(RecommendationCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            // Additional filters
            HStack(spacing: 12) {
                Menu {
                    ForEach(DistanceFilter.allCases, id: \.self) { distance in
                        Button(distance.rawValue) {
                            selectedDistance = distance
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.circle")
                        Text(selectedDistance.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Toggle("New Only", isOn: $showOnlyNew)
                    .font(.caption)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Spacer()
                
                Text("\(filteredRecommendations.count) places")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Recommendations List
    private var recommendationsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredRecommendations) { recommendation in
                    SmartRecommendationCard(recommendation: recommendation) {
                        selectedRecommendation = recommendation
                        showRecommendationDetail = true
                        
                        // Track view interaction
                        Task {
                            try? await supabaseManager.trackUserInteraction(
                                type: "recommendation_view",
                                targetPinId: recommendation.recommendedPlace.id,
                                locationName: recommendation.recommendedPlace.locationName,
                                locationLatitude: recommendation.recommendedPlace.latitude,
                                locationLongitude: recommendation.recommendedPlace.longitude,
                                value: 1.0
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                if filteredRecommendations.count >= 20 {
                    loadMoreButton
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Finding perfect places for you...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No Recommendations Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Follow friends and rate places to get personalized recommendations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button("Explore Nearby") {
                    // Navigate to nearby places
                }
                .buttonStyle(.borderedProminent)
                
                Button("Find Friends") {
                    // Navigate to find friends
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Load More Button
    private var loadMoreButton: some View {
        Button("Load More Recommendations") {
            loadMoreRecommendations()
        }
        .font(.subheadline)
        .foregroundColor(.blue)
        .padding()
    }
    
    // MARK: - Methods
    private func loadRecommendations() {
        guard let currentUserID = authManager.currentUserID else { return }
        
        isLoading = true
        
        Task {
            do {
                let fetchedRecommendations = try await supabaseManager.generatePlaceRecommendations(
                    for: currentUserID,
                    limit: 20
                )
                
                await MainActor.run {
                    self.recommendations = fetchedRecommendations
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func refreshRecommendations() {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        Task {
            await refreshRecommendationsAsync()
        }
    }
    
    @MainActor
    private func refreshRecommendationsAsync() async {
        guard let currentUserID = authManager.currentUserID else { return }
        
        isRefreshing = true
        
        do {
            let fetchedRecommendations = try await supabaseManager.generatePlaceRecommendations(
                for: currentUserID,
                limit: 20
            )
            
            self.recommendations = fetchedRecommendations
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
        
        isRefreshing = false
    }
    
    private func loadMoreRecommendations() {
        // Implementation for loading more recommendations
        // This would typically involve pagination
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let category: SmartRecommendationsView.RecommendationCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? category.color : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Recommendation Card
struct SmartRecommendationCard: View {
    let recommendation: FriendRecommendation
    let onTap: () -> Void
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var isSaved = false
    @State private var isDismissed = false
    
    var body: some View {
        if !isDismissed {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header with confidence and actions
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                confidenceIndicator
                                
                                Text("Confidence: \(Int(recommendation.confidence * 100))%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            
                            if !recommendation.recommendingFriendUsernames.isEmpty {
                                Text("Recommended by \(friendsText)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: saveRecommendation) {
                                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                    .font(.caption)
                                    .foregroundColor(isSaved ? .blue : .secondary)
                            }
                            
                            Button(action: dismissRecommendation) {
                                Image(systemName: "xmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Place info
                    HStack(spacing: 12) {
                        // Place image
                        AsyncImage(url: URL(string: recommendation.recommendedPlace.mediaURLs?.first ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundColor(.secondary)
                                )
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(recommendation.recommendedPlace.locationName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                            
                            HStack(spacing: 4) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < Int(recommendation.averageRating) ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundColor(.yellow)
                                }
                                
                                Text("\(recommendation.averageRating, specifier: "%.1f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(recommendation.recommendedPlace.city)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(recommendation.reasonText)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                    }
                    
                    // Friend endorsements
                    if !recommendation.recommendingFriendUsernames.isEmpty {
                        friendEndorsements
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var confidenceIndicator: some View {
        Circle()
            .fill(confidenceColor)
            .frame(width: 12, height: 12)
    }
    
    private var confidenceColor: Color {
        if recommendation.confidence >= 0.8 {
            return .green
        } else if recommendation.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var friendsText: String {
        let count = recommendation.recommendingFriendUsernames.count
        if count == 1 {
            return recommendation.recommendingFriendUsernames.first!
        } else if count == 2 {
            return "\(recommendation.recommendingFriendUsernames[0]) and \(recommendation.recommendingFriendUsernames[1])"
        } else {
            return "\(recommendation.recommendingFriendUsernames[0]) and \(count - 1) others"
        }
    }
    
    private var friendEndorsements: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Friend Activity")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("\(recommendation.totalVisits) visits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    
                    Text("\(recommendation.averageRating, specifier: "%.1f") avg rating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if recommendation.recentVisits.count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("Recent activity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.top, 8)
        .overlay(
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    private func saveRecommendation() {
        isSaved.toggle()
        
        Task {
            try? await supabaseManager.trackUserInteraction(
                type: "recommendation_save",
                targetPinId: recommendation.recommendedPlace.id,
                locationName: recommendation.recommendedPlace.locationName,
                value: isSaved ? 1.0 : -1.0
            )
        }
    }
    
    private func dismissRecommendation() {
        withAnimation(.easeOut(duration: 0.3)) {
            isDismissed = true
        }
        
        Task {
            try? await supabaseManager.trackUserInteraction(
                type: "recommendation_dismiss",
                targetPinId: recommendation.recommendedPlace.id,
                locationName: recommendation.recommendedPlace.locationName,
                value: -1.0
            )
        }
    }
}

// MARK: - Recommendation Detail View
struct RecommendationDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @EnvironmentObject var pinStore: PinStore
    
    let recommendation: FriendRecommendation
    @State private var showDirections = false
    @State private var isSaved = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Place header
                    placeHeader
                    
                    // Recommendation details
                    recommendationDetails
                    
                    // Friend endorsements
                    if !recommendation.recommendingFriendUsernames.isEmpty {
                        friendEndorsementsSection
                    }
                    
                    // Map section
                    mapSection
                    
                    // Action buttons
                    actionButtons
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Recommendation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isSaved.toggle() }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    }
                }
            }
        }
    }
    
    private var placeHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Place image
            AsyncImage(url: URL(string: recommendation.recommendedPlace.mediaURLs?.first ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    )
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            VStack(alignment: .leading, spacing: 8) {
                Text(recommendation.recommendedPlace.locationName)
                    .font(.title)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(recommendation.averageRating) ? "star.fill" : "star")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                    }
                    
                    Text("\(recommendation.averageRating, specifier: "%.1f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("• \(recommendation.totalVisits) visits")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                    
                    Text(recommendation.recommendedPlace.city)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var recommendationDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Why We Recommend This")
                .font(.headline)
            
            Text(recommendation.reasonText)
                .font(.body)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(recommendation.confidence * 100))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Friend Rating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(recommendation.averageRating, specifier: "%.1f") ★")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private var friendEndorsementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Friends Who've Been Here")
                .font(.headline)
            
            ForEach(recommendation.recommendingFriendUsernames.prefix(5), id: \.self) { username in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("@\(username)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Visited this place")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            if recommendation.recommendingFriendUsernames.count > 5 {
                Text("And \(recommendation.recommendingFriendUsernames.count - 5) more friends")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
            
            // Simple map placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("Map View")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                )
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("Get Directions") {
                showDirections = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            
            HStack(spacing: 12) {
                Button("Add to List") {
                    // Add to list action
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                
                Button("Share") {
                    // Share action
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Recommendation Settings View
struct RecommendationSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @State private var preferredCategories: Set<String> = ["restaurants", "cafes"]
    @State private var maxDistance: Double = 10.0
    @State private var priceRange: ClosedRange<Double> = 1.0...4.0
    @State private var recommendationFrequency = "daily"
    
    let categories = ["restaurants", "cafes", "bars", "parks", "shopping", "entertainment", "fitness", "services"]
    let frequencies = ["disabled", "daily", "weekly"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Preferred Categories") {
                    ForEach(categories, id: \.self) { category in
                        HStack {
                            Text(category.capitalized)
                            Spacer()
                            if preferredCategories.contains(category) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if preferredCategories.contains(category) {
                                preferredCategories.remove(category)
                            } else {
                                preferredCategories.insert(category)
                            }
                        }
                    }
                }
                
                Section("Distance Preference") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum Distance: \(Int(maxDistance)) km")
                            .font(.subheadline)
                        
                        Slider(value: $maxDistance, in: 1...50, step: 1)
                    }
                }
                
                Section("Price Range") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price Range: $\(Int(priceRange.lowerBound)) - $\(Int(priceRange.upperBound))")
                            .font(.subheadline)
                        
                        // Simple price range selector
                        HStack {
                            ForEach(1...4, id: \.self) { price in
                                Button(action: {
                                    if price == Int(priceRange.lowerBound) && price < Int(priceRange.upperBound) {
                                        priceRange = Double(price + 1)...priceRange.upperBound
                                    } else if price == Int(priceRange.upperBound) && price > Int(priceRange.lowerBound) {
                                        priceRange = priceRange.lowerBound...Double(price - 1)
                                    } else {
                                        priceRange = Double(price)...Double(price)
                                    }
                                }) {
                                    Text(String(repeating: "$", count: price))
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(priceRange.contains(Double(price)) ? Color.blue : Color(.systemGray6))
                                        )
                                        .foregroundColor(priceRange.contains(Double(price)) ? .white : .primary)
                                }
                            }
                        }
                    }
                }
                
                Section("Recommendation Frequency") {
                    Picker("Frequency", selection: $recommendationFrequency) {
                        ForEach(frequencies, id: \.self) { frequency in
                            Text(frequency.capitalized).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Recommendation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                }
            }
        }
    }
    
    private func saveSettings() {
        // Save settings to backend
        Task {
            // Implementation for saving user preferences
            presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Preview
struct SmartRecommendationsView_Previews: PreviewProvider {
    static var previews: some View {
        SmartRecommendationsView()
            .environmentObject(AuthManager())
            .environmentObject(SupabaseManager.shared)
            .environmentObject(PinStore())
    }
} 