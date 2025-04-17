//
//  UserProfileView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//

import SwiftUI
import MapKit
import PhotosUI
import UIKit

struct UserProfileView: View {
    let currentUserID = UUID()
    
    @State var profileUser = User(
        id: UUID(),
        username: "cartographer",
        isPrivate: false,
        followers: Array(repeating: UUID(), count: 5),
        following: Array(repeating: UUID(), count: 10),
        followRequests: [],
        collections: [
            PinCollection(name: "San Francisco", pins: [
                Pin(locationName: "Zuni Café", city: "San Francisco", date: "Mar 26", latitude: 37.7730, longitude: -122.4210, reaction: .lovedIt),
                Pin(locationName: "Tartine Bakery", city: "San Francisco", date: "Mar 25", latitude: 37.7614, longitude: -122.4241, reaction: .lovedIt),
                Pin(locationName: "House of Prime Rib", city: "San Francisco", date: "Mar 24", latitude: 37.7930, longitude: -122.4228, reaction: .wantToGo),
                Pin(locationName: "La Taqueria", city: "San Francisco", date: "Mar 23", latitude: 37.7502, longitude: -122.4185, reaction: .wantToGo),
                Pin(locationName: "Swan Oyster Depot", city: "San Francisco", date: "Mar 22", latitude: 37.7913, longitude: -122.4212, reaction: .lovedIt)
            ]),
            PinCollection(name: "Bday", pins: []),
            PinCollection(name: "Car Tour", pins: []),
            PinCollection(name: "Europe 25", pins: []),
            PinCollection(name: "Psychos", pins: []),
            PinCollection(name: "Pizza", pins: [])
        ],
        favoriteSpots: [],
        activityFeed: []
    )
    
    @State private var bio = "✨ Travel lover. Coffee first. Exploring the world one pin at a time! 🌍"
    @State private var selectedSection = "Just Added"
    let sections = ["Just Added", "Loved", "Want to Go", "Recommendations"]
    
    @EnvironmentObject var pinStore: PinStore
    
    @State private var selectedFilter: Reaction? = nil
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showChangePicturePrompt = false
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedUIImage: UIImage? = nil
    @State private var profileImage: Image? = nil
    @State private var isEditingProfile = false
    @State private var tempBio = ""
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("@\(profileUser.username)")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Profile Header
                    ZStack(alignment: .topTrailing) {
                        HStack(alignment: .center, spacing: 12) {
                        if let profileImage {
                            profileImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 4)
                                .onTapGesture {
                                    showChangePicturePrompt = true
                                }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 4)
                                .onTapGesture {
                                    showChangePicturePrompt = true
                                }
                        }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("@\(profileUser.username)")
                                    .font(.headline)
                                
                                Text(bio)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                                
                                Text("\(profileUser.followers.count) followers • \(profileUser.following.count) following")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal)
                    }
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 16) {
                            Button(action: {
                                tempBio = bio          // preload current bio
                                isEditingProfile = true
                            }) {
                                Text("Edit Profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            Button(action: {}) {
                                Text("Share profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Map Section
                        Map(
                            coordinateRegion: $region,
                            annotationItems: pinStore.masterPins
                        ) { pin in
                            MapAnnotation(
                                coordinate: CLLocationCoordinate2D(
                                    latitude: pin.latitude,
                                    longitude: pin.longitude
                                )
                            ) {
                                Image(systemName: "mappin.circle.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.blue)
                                    .shadow(radius: 3)
                            }
                        }
                        .frame(height: 470)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.top, 4)
        .confirmationDialog(
            "Change profile picture?",
            isPresented: $showChangePicturePrompt,
            titleVisibility: .visible
        ) {
            Button("Change Profile Picture") {
                isShowingPhotoPicker = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(
            isPresented: $isShowingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared())
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    selectedUIImage = uiImage
                }
            }
        }
        .sheet(item: $selectedUIImage) { uiImage in
            CircleCropperView(image: uiImage) { cropped in
                profileImage = Image(uiImage: cropped)
                selectedUIImage = nil          // dismiss after cropping
            }
        }
        .sheet(isPresented: $isEditingProfile) {
            EditProfileSheet(bio: $tempBio,
                             onSave: {
                                 bio = tempBio
                                 isEditingProfile = false
                             },
                             onCancel: {
                                 isEditingProfile = false
                             })
        }
    }
}

// Allow UIImage to be used with .sheet(item:)
extension UIImage: Identifiable {
    public var id: UUID {
        // use the object identifier so the same image isn't re‑presented repeatedly
        UUID()
    }
}

struct CircleCropperView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var onCrop: (UIImage) -> Void
    
    init(image: UIImage, onCrop: @escaping (UIImage) -> Void) {
        _image = State(initialValue: image)
        self.onCrop = onCrop
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                GeometryReader { geo in
                    ZStack {
                        Color.black.opacity(0.85).ignoresSafeArea()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / scale
                                        scale *= delta
                                    }
                                    .simultaneously(with:
                                        DragGesture().onChanged { value in
                                            offset = value.translation
                                        }
                                    )
                            )
                            .clipShape(Circle())
                            .frame(
                                width: min(geo.size.width, geo.size.height) * 0.8,
                                height: min(geo.size.width, geo.size.height) * 0.8
                            )
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
                .frame(
                    height: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) * 0.8
                )
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Done") {
                        let cropped = cropToCircle()
                        onCrop(cropped)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func cropToCircle() -> UIImage {
        let side = min(image.size.width, image.size.height)
        let origin = CGPoint(x: (image.size.width - side) / 2,
                             y: (image.size.height - side) / 2)
        let cropRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        guard let cgCropped = image.cgImage?.cropping(to: cropRect) else { return image }
        let square = UIImage(cgImage: cgCropped)
        
        let renderer = UIGraphicsImageRenderer(size: square.size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: square.size)
            UIBezierPath(ovalIn: rect).addClip()
            square.draw(in: rect)
        }
    }
}

struct EditProfileSheet: View {
    @Binding var bio: String
    var onSave: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Bio")) {
                    TextEditor(text: $bio)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                }
            }
        }
    }
}
