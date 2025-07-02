//
//  FriendRecommendationsView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import SwiftUI
import Foundation

struct FriendRecommendationsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    @State private var recommendations: [FriendRecommendation] = []
    @State private var isLoading = false
    @State private var selectedPin: Pin? = nil
    @State private var showPinDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Finding recommendations...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recommendations.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "star.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Recommendations Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Follow friends and they'll start sharing great places that you might love too!")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        NavigationLink(destination: FindFriendsView()) {
                            Text("Find Friends")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .cornerRadius(25)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header with explanation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommended for You")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Places your friends loved that you might enjoy too")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // Recommendations list
                        List(recommendations) { recommendation in
                            RecommendationCard(recommendation: recommendation) { pin in
                                selectedPin = pin
                                showPinDetail = true
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await loadRecommendations()
                        }
                    }
                }
            }
            .navigationTitle("Friend Recommendations")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await loadRecommendations()
                        }
                    }
                }
            }
            .sheet(isPresented: $showPinDetail) {
                if let pin = selectedPin {
                    LocationDetailView(
                        mapItem: pin.toMapItem(),
                        onAddPin: { _ in }
                    )
                    .environmentObject(pinStore)
                    .environmentObject(authManager)
                }
            }
        }
        .task {
            await loadRecommendations()
        }
    }
    
    private func loadRecommendations() async {
        guard let userId = authManager.currentUserID else { return }
        
        isLoading = true
        let fetchedRecommendations = await SupabaseManager.shared.getFriendRecommendations(for: userId, limit: 20)
        
        await MainActor.run {
            recommendations = fetchedRecommendations
            isLoading = false
        }
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: FriendRecommendation
    let onPinTap: (Pin) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pin preview
            Button(action: {
                onPinTap(recommendation.recommendedPlace)
            }) {
                HStack(spacing: 12) {
                    // Pin image or placeholder
                    if let mediaURLs = recommendation.recommendedPlace.mediaURLs,
                       let firstImageURL = mediaURLs.first,
                       let url = URL(string: firstImageURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                    } else {
                        Image(systemName: "location.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color.accentColor)
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recommendation.recommendedPlace.locationName)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(recommendation.recommendedPlace.city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // Star rating
                        HStack(spacing: 4) {
                            ForEach(0..<5) { index in
                                Image(systemName: index < Int(recommendation.averageRating) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                            Text(String(format: "%.1f", recommendation.averageRating))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Confidence indicator
                        ConfidenceIndicator(confidence: recommendation.confidence)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Recommendation reason
            VStack(alignment: .leading, spacing: 8) {
                Text("Why we recommend this")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(recommendation.reasonText)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Friends who recommended
            VStack(alignment: .leading, spacing: 8) {
                Text("Friends who've been here")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recommendation.recommendingFriendUsernames.prefix(5), id: \.self) { username in
                            FriendBadge(username: username)
                        }
                        
                        if recommendation.recommendingFriendUsernames.count > 5 {
                            Text("+\(recommendation.recommendingFriendUsernames.count - 5)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Add to Want to Go list
                    Task {
                        await SupabaseManager.shared.addPinToList(pin: recommendation.recommendedPlace, listName: "Want to Go")
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Add to List")
                            .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(20)
                }
                
                Spacer()
                
                // Recent activity indicator
                if let mostRecentVisit = recommendation.recentVisits.max() {
                    Text("Last visit \(timeAgoString(from: mostRecentVisit))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Confidence Indicator

struct ConfidenceIndicator: View {
    let confidence: Double
    
    private var confidenceLevel: String {
        switch confidence {
        case 0.8...1.0: return "Highly Recommended"
        case 0.6..<0.8: return "Recommended"
        case 0.4..<0.6: return "Worth Considering"
        default: return "Suggested"
        }
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            
            Text(confidenceLevel)
                .font(.caption)
                .foregroundColor(confidenceColor)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Friend Badge

struct FriendBadge: View {
    let username: String
    
    var body: some View {
        Text("@\(username)")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.2))
            .foregroundColor(.accentColor)
            .cornerRadius(12)
    }
}

// MARK: - Recommendation Stats View

struct RecommendationStatsView: View {
    let recommendation: FriendRecommendation
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .center, spacing: 4) {
                Text("\(recommendation.totalVisits)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Visits")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .center, spacing: 4) {
                Text(String(format: "%.1f", recommendation.averageRating))
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Rating")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .center, spacing: 4) {
                Text("\(recommendation.recommendingFriendUsernames.count)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Friends")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    FriendRecommendationsView()
        .environmentObject(AuthManager())
        .environmentObject(PinStore())
} 