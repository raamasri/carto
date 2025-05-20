//
//  PinCardView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 5/20/25.
//


import SwiftUI

struct PinCardView: View {
    let pin: Pin

    var hasReviewOrMedia: Bool {
        (pin.reviewText?.isEmpty == false) || !(pin.mediaURLs?.isEmpty ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            if hasReviewOrMedia {
                fullContent
            } else {
                minimalContent
            }

            footerSection
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 3)
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
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
        }
    }

    private var minimalContent: some View {
        HStack {
            if let distance = pin.distance {
                Text("\(String(format: "%.1f", distance)) mi")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("MAP") {
                // Handle map tap
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
        }
    }

    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let review = pin.reviewText {
                Text(review)
                    .font(.body)
            }

            if let media = pin.mediaURLs, !media.isEmpty {
                TabView {
                    ForEach(media, id: \.self) { url in
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

            if let distance = pin.distance {
                Text("\(String(format: "%.1f", distance)) mi • \(pin.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Text("@\(pin.authorHandle)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 16) {
                Image(systemName: "heart")
                Image(systemName: "message")
                Image(systemName: "square.and.arrow.up")
                Image(systemName: "bookmark")
            }
            .foregroundColor(.gray)
        }
    }
}
