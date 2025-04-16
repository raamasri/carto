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
    @State private var recommendationComment: String = ""

    var isFormValid: Bool {
        !placeName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !postContent.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        // Wrapping the entire interface in a NavigationView (optional)
        NavigationView {
            // Using a Form creates a more “iOS-native” grouping style.
            Form {
                // MARK: - Place Name Section
                Section(header: Text("Place Name")) {
                    TextField("Search for a place", text: $placeName)
                        .onChange(of: placeName) { newValue in
                            completer.queryFragment = newValue
                        }
                    
                    // Inline button for current location
                    Button {
                        useCurrentLocation()
                    } label: {
                        Label("Use Current Location", systemImage: "location.circle")
                            .foregroundColor(.blue)
                    }
                    
                    // Displaying search results in a list
                    if !searchResults.isEmpty {
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
                }
                
                // MARK: - Rating Section
                Section(header: Text("Rating")) {
                    HStack {
                        // Adjust star size and spacing as desired
                        ForEach(1..<11) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .onTapGesture {
                                    withAnimation {
                                        rating = star
                                    }
                                }
                        }
                        Spacer()
                        Text("\(rating)/10")
                            .foregroundColor(.gray)
                    }
                }
                
                // MARK: - Recommendation Section
                Section {
                    Toggle("Recommendation", isOn: $recommendation)
                    if recommendation {
                        Picker("Recommended To", selection: $recommendedTo) {
                            ForEach(recommendedOptions, id: \.self) { option in
                                Text(option)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())

                        // New TextEditor for additional recommendation comments
                        TextEditor(text: $recommendationComment)
                            .frame(height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray, lineWidth: 1))
                            .padding(.top, 8)
                    }
                }
                
                // MARK: - Post Content Section
                Section(header: Text("Post Content")) {
                    TextField("Enter your post content", text: $postContent)
                }
                
                // MARK: - Images Section
                Section {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Select Images", systemImage: "photo.on.rectangle")
                    }
                    
                    // Display selected images horizontally
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedImages, id: \.self) { image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // MARK: - Submit Button
                Section {
                    Button(action: {
                        // Submit post action here
                    }) {
                        Text("Post")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(!isFormValid)
                    .listRowBackground(Color.clear) // optional style tweak
                }
            }
            .navigationTitle("Create a New Post")
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
    
    // Helper to use current location
    private func useCurrentLocation() {
        if let currentLocation = locationManager.location {
            let geocoder = CLGeocoder()
            let userCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            geocoder.reverseGeocodeLocation(userCLLocation) { placemarks, error in
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
