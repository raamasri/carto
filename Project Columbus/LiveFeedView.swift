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
    @State private var selectedTab = 0
    @State private var showDetail = false
    @State private var showVideoFeed = false
    let tabs = ["Friends", "Following", "For You"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Tabs", selection: $selectedTab) {
                    ForEach(0..<tabs.count, id: \.self) { index in
                        Text(tabs[index]).tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                TabView(selection: $selectedTab) {
                    // Friends Tab
                    List(pinStore.masterPins.reversed()) { pin in
                        PinRowView(
                            pin: pin,
                            isLoved: lovedPins.contains(pin.id),
                            toggleLove: {
                                if lovedPins.contains(pin.id) {
                                    lovedPins.remove(pin.id)
                                } else {
                                    lovedPins.insert(pin.id)
                                }
                            },
                            share: {
                                sharePin(pin)
                            },
                            selectedPin: $selectedPin,
                            showDetail: $showDetail
                        )
                        .onTapGesture {
                            selectedPin = pin
                            region = MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showMap = true
                                showDetail = true // ← ADD THIS
                            }
                        }
                    }
                    .tag(0)

                    // Following Tab Placeholder
                    Text("Following content goes here")
                        .tag(1)

                    // For You Tab Placeholder
                    Text("For You content goes here")
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Live Feed")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showVideoFeed = true
                    }) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.accentColor))
                            .shadow(radius: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .sheet(isPresented: $showMap) {
                if let pin = selectedPin {
                    ZStack(alignment: .topTrailing) {
                        Map(coordinateRegion: $region, annotationItems: [pin]) { pin in
                            MapMarker(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude), tint: .red)
                        }
                        .edgesIgnoringSafeArea(.all)

                        Button(action: {
                            showMap = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
            }
            .sheet(isPresented: $showDetail) {
                if let pin = selectedPin {
                    LocationDetailView(
                        mapItem: MKMapItem(placemark: MKPlacemark(
                            coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
                        )),
                        onAddPin: { _ in }
                    )
                }
            }
            .sheet(isPresented: $showVideoFeed) {
                VideoFeedView()
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

struct PinRowView: View {
    let pin: Pin
    let isLoved: Bool
    let toggleLove: () -> Void
    let share: () -> Void
    @Binding var selectedPin: Pin?
    @Binding var showDetail: Bool

    var body: some View {
        
        HStack {
            Button(action: {
                selectedPin = pin
                showDetail = true
            }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pin.locationName)
                        .font(.headline)
                    Text("Posted by @mojojojo")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 20) {
                        Button(action: toggleLove) {
                            Label("", systemImage: isLoved ? "heart.fill" : "heart")
                        }
                        Button(action: {
                            print("Comment tapped for \(pin.locationName)")
                        }) {
                            Label("", systemImage: "bubble.right")
                        }
                        Button(action: share) {
                            Label("", systemImage: "square.and.arrow.up")
                        }
                        Button(action: {
                            print("Saved \(pin.locationName) to collection")
                        }) {
                            Label("", systemImage: "bookmark")
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
                .padding(.top, 6) // Added padding for vertical balance
                .padding(.leading, 4) // Added padding to the leading edge
            }

            Spacer()

            NavigationLink(destination: POIView(pin: pin)) {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )), interactionModes: [])
                    .frame(width: 100, height: 80)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16) // Updated horizontal padding
        .padding(.vertical, 8) // Updated vertical padding
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)) // Updated list row insets
    }
}

struct POIView: View {
    let pin: Pin
    @State private var region: MKCoordinateRegion

    init(pin: Pin) {
        self.pin = pin
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        VStack {
            Map(coordinateRegion: $region, annotationItems: [pin]) { pin in
                MapMarker(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude), tint: .red)
            }
            .edgesIgnoringSafeArea(.all)

            Text(pin.locationName)
                .font(.headline)
                .padding()
            // Additional POI details can be added here
        }
        .navigationTitle(pin.locationName)
    }
}

