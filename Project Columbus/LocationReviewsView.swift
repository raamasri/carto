//
//  LocationReviewsView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//  Feature: Detailed location reviews with rich media and ratings
//

import SwiftUI
import PhotosUI

struct LocationReviewsView: View {
    let pin: Pin
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @State private var reviews: [LocationReview] = []
    @State private var isLoading = false
    @State private var showWriteReview = false
    @State private var sortOption: ReviewSortOption = .mostHelpful
    @State private var userReview: LocationReview?
    
    enum ReviewSortOption: String, CaseIterable {
        case mostHelpful = "Most Helpful"
        case newest = "Newest"
        case highest = "Highest Rated"
        case lowest = "Lowest Rated"
    }
    
    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }
    
    var ratingDistribution: [Int: Int] {
        var distribution: [Int: Int] = [:]
        for rating in 1...5 {
            distribution[rating] = reviews.filter { $0.rating == rating }.count
        }
        return distribution
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with ratings summary
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(pin.locationName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack {
                                RatingStars(rating: averageRating, size: 20)
                                Text(String(format: "%.1f", averageRating))
                                    .font(.headline)
                                Text("(\(reviews.count) reviews)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { showWriteReview = true }) {
                            Label("Write Review", systemImage: "square.and.pencil")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(userReview != nil)
                    }
                    
                    // Rating distribution
                    VStack(spacing: 8) {
                        ForEach((1...5).reversed(), id: \.self) { rating in
                            HStack(spacing: 8) {
                                Text("\(rating)")
                                    .font(.caption)
                                    .frame(width: 20)
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                            .cornerRadius(4)
                                        
                                        Rectangle()
                                            .fill(Color.yellow)
                                            .frame(
                                                width: geometry.size.width * CGFloat(ratingDistribution[rating] ?? 0) / CGFloat(max(reviews.count, 1)),
                                                height: 8
                                            )
                                            .cornerRadius(4)
                                    }
                                }
                                .frame(height: 8)
                                
                                Text("\(ratingDistribution[rating] ?? 0)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // Sort options
                Picker("Sort by", selection: $sortOption) {
                    ForEach(ReviewSortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Reviews list
                if isLoading {
                    ProgressView()
                        .padding()
                } else if reviews.isEmpty {
                    EmptyReviewsView(onWriteReview: { showWriteReview = true })
                        .padding()
                } else {
                    ForEach(sortedReviews) { review in
                        ReviewCard(
                            review: review,
                            isOwnReview: review.userId == authManager.currentUserID,
                            onHelpfulVote: { isHelpful in
                                voteHelpful(reviewId: review.id, isHelpful: isHelpful)
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Reviews")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadReviews()
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView(pin: pin) { review in
                reviews.insert(review, at: 0)
                userReview = review
            }
            .environmentObject(authManager)
            .environmentObject(supabaseManager)
        }
    }
    
    private var sortedReviews: [LocationReview] {
        switch sortOption {
        case .mostHelpful:
            return reviews.sorted { $0.helpfulCount > $1.helpfulCount }
        case .newest:
            return reviews.sorted { $0.createdAt > $1.createdAt }
        case .highest:
            return reviews.sorted { $0.rating > $1.rating }
        case .lowest:
            return reviews.sorted { $0.rating < $1.rating }
        }
    }
    
    private func loadReviews() {
        Task {
            isLoading = true
            do {
                reviews = try await supabaseManager.getLocationReviews(pinId: pin.id)
                userReview = reviews.first { $0.userId == authManager.currentUserID }
            } catch {
                print("Failed to load reviews: \(error)")
            }
            isLoading = false
        }
    }
    
    private func voteHelpful(reviewId: UUID, isHelpful: Bool) {
        Task {
            do {
                try await supabaseManager.voteReviewHelpful(reviewId: reviewId, isHelpful: isHelpful)
                
                // Update local state
                if let index = reviews.firstIndex(where: { $0.id == reviewId }) {
                    var updatedReview = reviews[index]
                    if isHelpful {
                        updatedReview = LocationReview(
                            id: updatedReview.id,
                            pinId: updatedReview.pinId,
                            userId: updatedReview.userId,
                            username: updatedReview.username,
                            userAvatarURL: updatedReview.userAvatarURL,
                            rating: updatedReview.rating,
                            title: updatedReview.title,
                            content: updatedReview.content,
                            pros: updatedReview.pros,
                            cons: updatedReview.cons,
                            mediaURLs: updatedReview.mediaURLs,
                            visitDate: updatedReview.visitDate,
                            priceRange: updatedReview.priceRange,
                            tags: updatedReview.tags,
                            helpfulCount: updatedReview.helpfulCount + 1,
                            replyCount: updatedReview.replyCount,
                            isVerifiedVisit: updatedReview.isVerifiedVisit,
                            isEdited: updatedReview.isEdited,
                            createdAt: updatedReview.createdAt,
                            updatedAt: updatedReview.updatedAt
                        )
                        reviews[index] = updatedReview
                    }
                }
            } catch {
                print("Failed to vote: \(error)")
            }
        }
    }
}

// MARK: - Review Card
struct ReviewCard: View {
    let review: LocationReview
    let isOwnReview: Bool
    let onHelpfulVote: (Bool) -> Void
    
    @State private var showFullReview = false
    @State private var hasVoted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                AsyncImage(url: URL(string: review.userAvatarURL ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading) {
                    HStack {
                        Text(review.username)
                            .font(.headline)
                        
                        if review.isVerifiedVisit {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        
                        if isOwnReview {
                            Text("You")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    
                    HStack {
                        RatingStars(rating: Double(review.rating), size: 14)
                        
                        if let visitDate = review.visitDate {
                            Text("• Visited \(visitDate, style: .date)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if review.isEdited {
                    Text("Edited")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Title
            if let title = review.title {
                Text(title)
                    .font(.headline)
            }
            
            // Content
            Text(review.content)
                .lineLimit(showFullReview ? nil : 3)
                .font(.body)
            
            if review.content.count > 150 && !showFullReview {
                Button("Read more") {
                    withAnimation {
                        showFullReview = true
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Pros and Cons
            if !review.pros.isEmpty || !review.cons.isEmpty {
                HStack(alignment: .top, spacing: 20) {
                    if !review.pros.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Pros", systemImage: "plus.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            
                            ForEach(review.pros, id: \.self) { pro in
                                Text("• \(pro)")
                                    .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if !review.cons.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Cons", systemImage: "minus.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            
                            ForEach(review.cons, id: \.self) { con in
                                Text("• \(con)")
                                    .font(.caption)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Media
            if !review.mediaURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(review.mediaURLs, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Tags and price
            HStack {
                if review.priceRange != nil {
                    Text(review.priceRangeDisplay)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
                
                ForEach(review.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            // Actions
            HStack {
                Button(action: { 
                    if !hasVoted && !isOwnReview {
                        onHelpfulVote(true)
                        hasVoted = true
                    }
                }) {
                    HStack {
                        Image(systemName: hasVoted ? "hand.thumbsup.fill" : "hand.thumbsup")
                        Text("Helpful (\(review.helpfulCount))")
                    }
                    .font(.caption)
                    .foregroundColor(hasVoted ? .blue : .secondary)
                }
                .disabled(isOwnReview || hasVoted)
                
                Spacer()
                
                if review.replyCount > 0 {
                    Text("\(review.replyCount) replies")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Write Review View
struct WriteReviewView: View {
    let pin: Pin
    let onReviewCreated: (LocationReview) -> Void
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @State private var rating = 5
    @State private var title = ""
    @State private var content = ""
    @State private var pros: [String] = []
    @State private var cons: [String] = []
    @State private var currentPro = ""
    @State private var currentCon = ""
    @State private var visitDate = Date()
    @State private var priceRange: Int? = nil
    @State private var selectedTags: Set<String> = []
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var isSubmitting = false
    
    let availableTags = ["Family Friendly", "Romantic", "Business", "Casual", "Trendy", "Classic", "Outdoor Seating", "Vegetarian Options", "Parking Available", "Reservations Recommended"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Rating
                    VStack(alignment: .leading) {
                        Text("Your Rating")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title)
                                    .foregroundColor(star <= rating ? .yellow : .gray)
                                    .onTapGesture {
                                        rating = star
                                    }
                            }
                        }
                    }
                    
                    // Title
                    VStack(alignment: .leading) {
                        Text("Title (Optional)")
                            .font(.headline)
                        
                        TextField("Summarize your experience", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Review content
                    VStack(alignment: .leading) {
                        Text("Your Review")
                            .font(.headline)
                        
                        TextEditor(text: $content)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Pros
                    VStack(alignment: .leading) {
                        Text("Pros (Optional)")
                            .font(.headline)
                        
                        ForEach(pros, id: \.self) { pro in
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                Text(pro)
                                Spacer()
                                Button(action: { pros.removeAll { $0 == pro } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .font(.subheadline)
                        }
                        
                        HStack {
                            TextField("Add a pro", text: $currentPro)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Add") {
                                if !currentPro.isEmpty {
                                    pros.append(currentPro)
                                    currentPro = ""
                                }
                            }
                            .disabled(currentPro.isEmpty)
                        }
                    }
                    
                    // Cons
                    VStack(alignment: .leading) {
                        Text("Cons (Optional)")
                            .font(.headline)
                        
                        ForEach(cons, id: \.self) { con in
                            HStack {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                Text(con)
                                Spacer()
                                Button(action: { cons.removeAll { $0 == con } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .font(.subheadline)
                        }
                        
                        HStack {
                            TextField("Add a con", text: $currentCon)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Add") {
                                if !currentCon.isEmpty {
                                    cons.append(currentCon)
                                    currentCon = ""
                                }
                            }
                            .disabled(currentCon.isEmpty)
                        }
                    }
                    
                    // Visit date
                    VStack(alignment: .leading) {
                        Text("Visit Date (Optional)")
                            .font(.headline)
                        
                        DatePicker("When did you visit?", selection: $visitDate, displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                    
                    // Price range
                    VStack(alignment: .leading) {
                        Text("Price Range (Optional)")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(1...4, id: \.self) { price in
                                Button(action: { priceRange = price }) {
                                    Text(String(repeating: "$", count: price))
                                        .font(.title3)
                                        .foregroundColor(priceRange == price ? .white : .primary)
                                        .frame(width: 60, height: 40)
                                        .background(priceRange == price ? Color.green : Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Tags
                    VStack(alignment: .leading) {
                        Text("Tags (Optional)")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                            ForEach(availableTags, id: \.self) { tag in
                                Button(action: {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }) {
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selectedTags.contains(tag) ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedTags.contains(tag) ? .white : .primary)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }
                    
                    // Photos
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Photos (Optional)")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: { showImagePicker = true }) {
                                Label("Add Photos", systemImage: "photo")
                                    .font(.subheadline)
                            }
                        }
                        
                        if !selectedImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(selectedImages.indices, id: \.self) { index in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: selectedImages[index])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .cornerRadius(8)
                                            
                                            Button(action: { selectedImages.remove(at: index) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.5))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Write Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitReview()
                    }
                    .disabled(content.isEmpty || isSubmitting)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                                        ImagePicker(sourceType: .photoLibrary) { image in
                            // Handle image selection if needed
                        }
            }
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView("Submitting review...")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func submitReview() {
        Task {
            isSubmitting = true
            do {
                // TODO: Upload images and get URLs
                let mediaURLs: [String] = []
                
                let review = try await supabaseManager.createLocationReview(
                    pinId: pin.id,
                    rating: rating,
                    title: title.isEmpty ? nil : title,
                    content: content,
                    pros: pros,
                    cons: cons,
                    mediaURLs: mediaURLs,
                    visitDate: visitDate,
                    priceRange: priceRange,
                    tags: Array(selectedTags)
                )
                
                onReviewCreated(review)
                dismiss()
            } catch {
                print("Failed to submit review: \(error)")
            }
            isSubmitting = false
        }
    }
}

// MARK: - Supporting Views
struct RatingStars: View {
    let rating: Double
    let size: CGFloat
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starType(for: star))
                    .font(.system(size: size))
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private func starType(for position: Int) -> String {
        let filled = Int(rating)
        let hasHalf = rating - Double(filled) >= 0.5
        
        if position <= filled {
            return "star.fill"
        } else if position == filled + 1 && hasHalf {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

struct EmptyReviewsView: View {
    let onWriteReview: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No reviews yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Be the first to share your experience!")
                .foregroundColor(.secondary)
            
            Button(action: onWriteReview) {
                Label("Write a Review", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
} 