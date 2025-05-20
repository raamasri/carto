//
//  PinCardView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 5/20/25.
//


import SwiftUI
import MapKit
import Foundation
import Project_Columbus
import AVKit
// Pin is defined in Models.swift in the same module

struct PinCardView: View {
    let pin: Pin
    @State private var showFullMap = false
    @State private var showAddToList = false
    @State private var showAddedAlert = false
    @EnvironmentObject var pinStore: PinStore

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
        for (i, word) in words.enumerated() {
            if i > 0 { result = result + Text(" ") }
            if word.hasPrefix("@") || word.hasPrefix("#") {
                result = result + Text(String(word)).foregroundColor(.blue).bold()
            } else {
                result = result + Text(String(word))
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
                    .frame(width: 24, height: 24)
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
        .padding(.vertical, 2)
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

    private var miniMap: some View {
        Map(
            coordinateRegion: .constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )),
            annotationItems: [pin]
        ) { pin in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                Image(systemName: "mappin.circle.fill")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.red)
                    .shadow(radius: 2)
            }
        }
        .frame(width: 60, height: 60)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue, lineWidth: 2))
        .onTapGesture { showFullMap = true }
        .sheet(isPresented: $showFullMap) {
            VStack {
                Map(
                    coordinateRegion: .constant(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )),
                    annotationItems: [pin]
                ) { pin in
                    MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                        Image(systemName: "mappin.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.red)
                            .shadow(radius: 3)
                    }
                }
                .edgesIgnoringSafeArea(.all)
                Button("Close") { showFullMap = false }
                    .padding()
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                // Header: Place, city, star, mini map
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(pin.locationName)
                                .font(.headline)
                            if let rating = pin.starRating {
                                Text("\(String(format: "%.1f", rating)) ★")
                                    .font(.subheadline).bold()
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text(pin.city)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    miniMap
                }
                // Avatars row (if any)
                if !pin.mentionedFriends.isEmpty {
                    avatarsRow
                }
                // Minimal card (just a pin, no review/media)
                if !hasReviewOrMedia {
                    Text(relativeDateString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                // Full card (review/media)
                if hasReviewOrMedia {
                    if let review = pin.reviewText, !review.isEmpty {
                        styledReview(review)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                    if let media = pin.mediaURLs, !media.isEmpty {
                        TabView {
                            ForEach(media, id: \.self) { urlString in
                                if urlString.hasSuffix(".mp4"), let url = URL(string: urlString) {
                                    VideoPlayer(player: AVPlayer(url: url))
                                        .aspectRatio(16/9, contentMode: .fit)
                                        .clipped()
                                } else if let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .clipped()
                                        } else {
                                            Color.gray
                                        }
                                    }
                                } else {
                                    Color.gray
                                }
                            }
                        }
                        .frame(height: 220)
                        .tabViewStyle(.page)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    HStack(spacing: 8) {
                        tripTag
                        Text(relativeDateString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                // Action icons and author
                HStack {
                    Text(pin.authorHandle)
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
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(hasReviewOrMedia ? 0.12 : 0.05), radius: hasReviewOrMedia ? 5 : 2, x: 0, y: 2)

            // Add to List button
            Button(action: {
                print("Add to List tapped for \(pin.locationName)")
                showAddToList = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .padding(10)
            .shadow(radius: 2)
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showAddToList) {
            AddToListSheet(pin: pin) { list in
                pinStore.addPin(pin, to: list)
                showAddedAlert = true
            }
        }
        .alert("Added to List!", isPresented: $showAddedAlert) {
            Button("OK", role: .cancel) { }
        }
    }
}

struct AddToListSheet: View {
    let pin: Pin
    let lists = ["Favorites", "Coffee Shops", "Restaurants", "Bars", "Shopping"]
    var onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Text("Add to List")
                .font(.title2)
                .bold()
                .padding(.top)
            ForEach(lists, id: \.self) { list in
                Button(action: {
                    onSelect(list)
                    dismiss()
                }) {
                    Text(list)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
                .padding(.top, 8)
        }
        .padding()
    }
}
