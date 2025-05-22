import SwiftUI
import MapKit

struct FriendReviewListView: View {
    let placeName: String
    let latitude: Double
    let longitude: Double
    let allPins: [Pin]
    let friends: [AppUser]
    @Environment(\.dismiss) var dismiss
    @State private var selectedUser: AppUser? = nil

    // Filter pins for this place and by friends
    private var friendPins: [(pin: Pin, user: AppUser)] {
        let placePins = allPins.filter { abs($0.latitude - latitude) < 0.0001 && abs($0.longitude - longitude) < 0.0001 }
        return placePins.compactMap { pin in
            if let user = friends.first(where: { $0.username == pin.authorHandle.replacingOccurrences(of: "@", with: "") }) {
                return (pin, user)
            }
            return nil
        }.sorted { $0.pin.createdAt > $1.pin.createdAt }
    }

    private var averageRating: Double? {
        let ratings = friendPins.compactMap { $0.pin.starRating }
        guard !ratings.isEmpty else { return nil }
        return ratings.reduce(0, +) / Double(ratings.count)
    }

    struct PlaceAnnotation: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                mapView
                Divider()
                reviewListView
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedUser) { user in
                UserProfileView(profileUser: user)
            }
        }
    }

    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(placeName)
                    .font(.title2).bold()
                if let avg = averageRating {
                    Text("Avg: \(String(format: "%.1f", avg)) ★")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                }
            }
            Spacer()
        }
        .padding([.top, .horizontal])
    }

    private var mapView: some View {
        let annotation = PlaceAnnotation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        return Map(
            coordinateRegion: .constant(MKCoordinateRegion(
                center: annotation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            )),
            annotationItems: [annotation]
        ) { item in
            MapAnnotation(coordinate: item.coordinate) {
                Image(systemName: "mappin.circle.fill")
                    .resizable()
                    .frame(width: 22, height: 22)
                    .foregroundColor(.red)
            }
        }
        .frame(width: 70, height: 70)
        .cornerRadius(10)
    }

    private var reviewListView: some View {
        if friendPins.isEmpty {
            return AnyView(
                Text("No friends have reviewed this place yet.")
                    .foregroundColor(.gray)
                    .padding()
            )
        } else {
            return AnyView(
                List {
                    ForEach(friendPins, id: \.pin.id) { item in
                        Button(action: { selectedUser = item.user }) {
                            HStack(alignment: .top, spacing: 12) {
                                if let avatar = item.user.avatarURL, !avatar.isEmpty, let url = URL(string: avatar) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        default:
                                            Image(systemName: "person.circle.fill").resizable().foregroundColor(.gray)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundColor(.gray)
                                        .frame(width: 40, height: 40)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.user.full_name.isEmpty ? "@\(item.user.username)" : item.user.full_name)
                                        .font(.headline)
                                    if let review = item.pin.reviewText, !review.isEmpty {
                                        Text(review)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                    if let rating = item.pin.starRating {
                                        Text("\(String(format: "%.1f", rating)) ★")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                                Spacer()
                                Text(relativeDateString(item.pin.createdAt))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            )
        }
    }

    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 