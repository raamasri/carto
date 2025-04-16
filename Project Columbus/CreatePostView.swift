//
//  CreatePostView.swift
//  Project Columbus copy
//
//  Created by raama srivatsan on 4/15/25.
//
import SwiftUI
import CoreLocation
import MapKit
import PhotosUI

struct CreatePostView: View {
    @State private var placeName: String = ""
    @State private var location: String = ""
    @State private var rating: Int = 0
    @State private var recommendation: Bool = false
    @State private var recommendedTo: String = "Everyone"
    private let recommendedOptions = ["Everyone", "Family", "Friends"]
    @State private var postContent: String = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showingImagePicker: Bool = false
    @State private var isFollowingUser: Bool = false
    @StateObject private var locationManager = AppLocationManager()
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var completer = MKLocalSearchCompleter()
    @State private var selectedCompletion: MKLocalSearchCompletion? = nil

    var isFormValid: Bool {
        !placeName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !postContent.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create a New Post")
                    .font(.title)
                    .padding(.bottom, 8)

                Group {
                    Text("Place Name")
                        .font(.headline)
                    TextField("Search for a place", text: $placeName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: placeName) { newValue in
                            completer.queryFragment = newValue
                        }
                    Button(action: {
                        if let currentLocation = locationManager.location {
                            let geocoder = CLGeocoder()
                            let location = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                                if let placemark = placemarks?.first {
                                    DispatchQueue.main.async {
                                        placeName = placemark.name ?? placemark.locality ?? "Current Location"
                                    }
                                } else if let error = error {
                                    print("Reverse geocoding failed: \(error.localizedDescription)")
                                } else {
                                    print("No placemarks found.")
                                }
                            }
                        } else {
                            print("Location is not available.")
                        }
                    }) {
                        HStack {
                            Image(systemName: "location.circle")
                            Text("Use Current Location")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    if !searchResults.isEmpty {
                        List {
                            ForEach(searchResults, id: \.self) { completion in
                                VStack(alignment: .leading) {
                                    Text(completion.title)
                                        .font(.body)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCompletion = completion
                                    placeName = completion.title
                                    searchResults = []
                                }
                            }
                        }
                        .frame(height: 150)
                    }
                }

                Group {
                    Text("Rating")
                        .font(.headline)
                    HStack(spacing: 4) {
                        ForEach(1..<11) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    withAnimation {
                                        rating = star
                                    }
                                }
                        }
                        Text("\(rating)/10")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.leading, 8)
                    }
                }

                Group {
                    Toggle("Recommendation", isOn: $recommendation)
                    if recommendation {
                        Picker("Recommended To", selection: $recommendedTo) {
                            ForEach(recommendedOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }

                Group {
                    Text("Post Content")
                        .font(.headline)
                    TextField("Enter your post content", text: $postContent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Group {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Select Images")
                        }
                    }
                    if !selectedImages.isEmpty {
                        TabView {
                            ForEach(selectedImages, id: \.self) { uiImage in
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                            }
                        }
                        .frame(height: 250)
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    }
                }

                Button(action: {
                    // Submit post action
                }) {
                    Text("Post")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1 : 0.6)
            }
            .padding()
        }
        .onAppear {
            completer.resultTypes = .address
            completer.region = locationManager.region
            completer.delegate = SearchCompleterDelegateWrapper { completions in
                searchResults = completions
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            MultiImagePicker(selectedImages: $selectedImages)
        }
    }
}

class SearchCompleterDelegateWrapper: NSObject, MKLocalSearchCompleterDelegate {
    var onUpdate: ([MKLocalSearchCompletion]) -> Void

    init(onUpdate: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onUpdate = onUpdate
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Error with search completer: \(error)")
    }
}

// Placeholder for MultiImagePicker.swift
struct MultiImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 0 // Allow multiple selection
        configuration.filter = .images
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: MultiImagePicker

        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.selectedImages = []
            let dispatchGroup = DispatchGroup()

            for result in results {
                dispatchGroup.enter()
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                        if let image = object as? UIImage {
                            self.parent.selectedImages.append(image)
                        }
                        dispatchGroup.leave()
                    }
                } else {
                    dispatchGroup.leave()
                }
            }

            dispatchGroup.notify(queue: .main) {
                picker.dismiss(animated: true)
            }
        }
    }
}
