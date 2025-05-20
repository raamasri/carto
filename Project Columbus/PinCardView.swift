//
//  PinCardView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 5/20/25.
//


import SwiftUI

struct PinCardView: View {
    let pin: Pin

    // Helper: Relative date string
    private var relativeDateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: pin.createdAt, relativeTo: Date())
    }

    // Helper: Styled review text with mentions
    private func styledReview(_ text: String) -> Text {
        let words = text.split(separator: " ")
        var result = Text("")
        for word in words {
            if word.hasPrefix("@") || word.hasPrefix("#") {
                result = result + Text(" " + word).foregroundColor(.blue).bold()
            } else {
                result = result + Text(" " + word)
            }
        }
        return result
    }

    // Helper: Avatars for mentioned friends (placeholder)
    private var avatarsRow: some View {
        HStack(spacing: -10) {
            ForEach(pin.mentionedFriends.prefix(3), id: \ .self) { _ in
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
            if pin.mentionedFriends.count > 3 {
                Text("+\(pin.mentionedFriends.count - 3)")
                    .font(.caption)
                    .padding(.leading, 4)
            }
        }
    }

    // Helper: Trip tag
    private var tripTag: some View {
        Group {
            if let trip = pin.tripName, !trip.isEmpty {
                Text(trip)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
    }

    var hasReviewOrMedia: Bool {
        (pin.reviewText?.isEmpty == false) || !(pin.mediaURLs?.isEmpty ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.locationName)
                        .font(.headline)
                    Text(pin.city)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let rating = pin.starRating {
                    Text("⭐️ \(String(format: "%.1f", rating))")
                        .font(.subheadline)
                }
                tripTag
            }

            // Avatars row
            if !pin.mentionedFriends.isEmpty {
                avatarsRow
            }

            // Photo carousel
            if let media = pin.mediaURLs, !media.isEmpty {
                TabView {
                    ForEach(media, id: \ .self) { url in
                        AsyncImage(url: URL(string: url)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                            } else {
                                Color.gray
                            }
                        }
                    }
                }
                .frame(height: 200)
                .tabViewStyle(.page)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Review/comment
            if let review = pin.reviewText, !review.isEmpty {
                styledReview(review)
                    .font(.body)
            }

            // MAP button, distance, date
            HStack {
                Button(action: {
                    // Handle map tap
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                        Text("MAP")
                        if let distance = pin.distance {
                            Text("· \(String(format: "%.1f", distance)) mi")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                Spacer()
                Text(relativeDateString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Action icons and author
            HStack {
                Text("@\(pin.authorHandle)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 18) {
                    Image(systemName: "heart")
                    Image(systemName: "message")
                    Image(systemName: "square.and.arrow.up")
                    Image(systemName: "bookmark")
                }
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(hasReviewOrMedia ? Color(.systemBackground) : Color(.secondarySystemBackground))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(hasReviewOrMedia ? 0.12 : 0.05), radius: hasReviewOrMedia ? 5 : 2, x: 0, y: 2)
    }
}
