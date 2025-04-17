//
//  LocationDetailView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//

import MapKit
import SwiftUI

struct LocationDetailView: View {
    let mapItem: MKMapItem
    let onAddPin: (Pin) -> Void

    @State private var showCollectionSheet = false
    @State private var region: MKCoordinateRegion
    @EnvironmentObject var pinStore: PinStore

    init(mapItem: MKMapItem, onAddPin: @escaping (Pin) -> Void) {
        self.mapItem = mapItem
        self.onAddPin = onAddPin
        _region = State(initialValue: MKCoordinateRegion(
            center: mapItem.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        ScrollView {
            content
                .padding()
        }
        .navigationTitle("Details")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleSection
            Map(coordinateRegion: $region, annotationItems: [mapItem]) { item in
                MapMarker(coordinate: item.placemark.coordinate, tint: .red)
            }
                .frame(height: 250)
                .cornerRadius(12)
            LookAroundPreview(coordinate: mapItem.placemark.coordinate)
                .frame(height: 250)
                .cornerRadius(12)
            infoSection
            addButton
        }
    }

    private var titleSection: some View {
        Text(mapItem.name ?? "Unknown Place")
            .font(.largeTitle)
            .bold()
    }

    private var infoSection: some View {
        Group {
            if let category = mapItem.pointOfInterestCategory {
                Label(category.displayName, systemImage: "tag")
            }

            if let phone = mapItem.phoneNumber {
                Label(phone, systemImage: "phone")
            }

            if let url = mapItem.url {
                Link("Website", destination: url)
            }

            if let address = mapItem.placemark.title {
                Label(address, systemImage: "mappin.circle")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label("Lat: \(mapItem.placemark.coordinate.latitude), Lon: \(mapItem.placemark.coordinate.longitude)", systemImage: "location")

            if let tz = mapItem.timeZone {
                Label(tz.identifier, systemImage: "clock")
            }
        }
    }

    private var addButton: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    showCollectionSheet = true
                }) {
                    HStack {
                        Spacer()
                        Label("Pins", systemImage: "plus.circle.fill")
                            .font(.title2)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: {
                    let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                    mapItem.openInMaps(launchOptions: launchOptions)
                    print("Opening directions for \(mapItem.name ?? "unknown location") in Apple Maps.")
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "car.fill")
                            .font(.title2)
                        Spacer()
                    }
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .sheet(isPresented: $showCollectionSheet) {
                collectionPickerSheet
            }
        }
    }

    private var collectionPickerSheet: some View {
        NavigationView {
            collectionList
                .navigationTitle("Select a Collection")
        }
    }

    private var collectionList: some View {
        List {
            ForEach(pinStore.collections) { collection in
                Button(action: {
                    addPin(to: collection)
                    showCollectionSheet = false
                }) {
                    Text("Add to \(collection.name)")
                }
            }
        }
    }

    private func addPin(to collection: PinCollection) {
        let newPin = Pin(
            locationName: mapItem.name ?? "Unknown Place",
            city: mapItem.placemark.locality ?? "Unknown City",
            date: formattedDate(),
            latitude: mapItem.placemark.coordinate.latitude,
            longitude: mapItem.placemark.coordinate.longitude,
            reaction: .wantToGo
        )
        if let index = pinStore.collections.firstIndex(where: { $0.id == collection.id }) {
            pinStore.collections[index] = PinCollection(
                name: pinStore.collections[index].name,
                pins: pinStore.collections[index].pins + [newPin]
            )
        }
    }
}

struct LookAroundPreview: UIViewControllerRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let controller = MKLookAroundViewController()
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        Task {
            if let scene = try? await request.scene {
                controller.scene = scene
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: MKLookAroundViewController, context: Context) {}
}
