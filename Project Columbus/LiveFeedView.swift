import SwiftUI
import MapKit

struct LiveFeedView: View {
    @EnvironmentObject var pinStore: PinStore
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedPin: Pin? = nil
    @State private var showMap = false
    @State private var lovedPins: Set<UUID> = []

    var body: some View {
        NavigationView {
            List(pinStore.masterPins.reversed()) { pin in
                VStack(alignment: .leading, spacing: 6) {
                    Text(pin.locationName)
                        .font(.headline)
                    Text("City: \(pin.city) • \(pin.date)")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text("Posted by @mojojojo23")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        Button(action: {
                            if lovedPins.contains(pin.id) {
                                lovedPins.remove(pin.id)
                            } else {
                                lovedPins.insert(pin.id)
                            }
                        }) {
                            Label("Love", systemImage: lovedPins.contains(pin.id) ? "heart.fill" : "heart")
                        }

                        Button(action: {
                            print("Comment tapped for \(pin.locationName)")
                        }) {
                            Label("Comment", systemImage: "bubble.right")
                        }

                        Button(action: {
                            sharePin(pin)
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button(action: {
                            print("Saved \(pin.locationName) to collection")
                        }) {
                            Label("Save", systemImage: "bookmark")
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
                .padding(.vertical, 4)
                .onTapGesture {
                    selectedPin = pin
                    region.center = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                    showMap = true
                }
            }
            .navigationTitle("Live Feed")
            .sheet(isPresented: $showMap) {
                if let pin = selectedPin {
                    Map(coordinateRegion: $region, annotationItems: [pin]) { pin in
                        MapMarker(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude), tint: .red)
                    }
                    .edgesIgnoringSafeArea(.all)
                }
            }
        }
    }

    func sharePin(_ pin: Pin) {
        let text = "Check out \(pin.locationName) in \(pin.city)!"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
}
