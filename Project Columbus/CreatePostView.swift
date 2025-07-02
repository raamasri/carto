import SwiftUI
import CoreLocation
import MapKit
import PhotosUI
import AVKit

struct CreatePostView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var pinStore: PinStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var placeName: String = ""
    @State private var location: String = ""
    @State private var rating: Int = 0
    @State private var recommendation: Bool? = nil
    @State private var recommendedTo: String = "Everyone"
    private let recommendedOptions = ["Everyone", "Family", "Friends"]
    @State private var postContent: String = ""
    @State private var selectedImages: [UIImage] = []
    @State private var selectedVideos: [URL] = []
    @State private var showingImagePicker: Bool = false
    @State private var showingVideoPicker: Bool = false
    @State private var isFollowingUser: Bool = false
    @StateObject private var locationManager = AppLocationManager()
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var completer = MKLocalSearchCompleter()
    @State private var selectedCompletion: MKLocalSearchCompletion? = nil
    @State private var recommendationComment: String = ""
    @State private var showPreview: Bool = false
    @State private var selectedMapItem: MKMapItem? = nil
    @State private var completerDelegateWrapper: SearchCompleterDelegateWrapper? = nil
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion()
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isCreatingPost: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false
    @State private var reaction: Reaction = .lovedIt
    @State private var tripName: String = ""
    @State private var isPrivatePost: Bool = false
    @State private var selectedListName: String = ""
    @State private var newListName: String = ""
    
    @FocusState private var isPlaceFieldFocused: Bool
    @FocusState private var isPostContentFocused: Bool

    var isFormValid: Bool {
        !placeName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !postContent.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedMapItem != nil
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Place Selection Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Location")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                    TextField("Search for a place", text: $placeName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isPlaceFieldFocused)
                        .onChange(of: placeName) { oldValue, newValue in
                            completer.queryFragment = newValue
                        }
                    
                    if isPlaceFieldFocused && !searchResults.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(searchResults, id: \.self) { completion in
                                        Button(action: {
                                            selectPlace(completion)
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(completion.title)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                if !completion.subtitle.isEmpty {
                                                    Text(completion.subtitle)
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .background(Color(.systemGray6))
                                        
                                        if completion != searchResults.last {
                                        Divider()
                                    }
                            }
                        }
                                .background(Color(.systemBackground))
                        .cornerRadius(8)
                                .shadow(radius: 2)
                    }
                    
                    Button {
                        useCurrentLocation()
                    } label: {
                        Label("Use Current Location", systemImage: "location.circle")
                            .foregroundColor(.blue)
                    }
                }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // MARK: - Post Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Post Details")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Reaction Selection
                        HStack(spacing: 16) {
                            Button(action: { reaction = .lovedIt }) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                    Text("Loved It")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(reaction == .lovedIt ? Color.red : Color(.systemGray5))
                                .foregroundColor(reaction == .lovedIt ? .white : .primary)
                                .cornerRadius(20)
                            }
                            Button(action: { reaction = .wantToGo }) {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                    Text("Want to Go")
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(reaction == .wantToGo ? Color.blue : Color(.systemGray5))
                                .foregroundColor(reaction == .wantToGo ? .white : .primary)
                                .cornerRadius(20)
                            }
                        }
                        
                        // Rating Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rating")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                    HStack {
                        ForEach(1..<11) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                        .font(.title3)
                                .onTapGesture {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        rating = star
                                    }
                                }
                        }
                        Spacer()
                        Text("\(rating)/10")
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                        }
                        
                        // Trip Name (Optional)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Trip Name (Optional)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("e.g., Weekend Getaway, Business Trip", text: $tripName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                
                // MARK: - Add to List Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add to List")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Picker("Select Existing List", selection: $selectedListName) {
                        Text("None").tag("")
                        ForEach(pinStore.lists.map { $0.name }, id: \.self) { listName in
                            Text(listName).tag(listName)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    HStack {
                        TextField("Or create new list", text: $newListName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Add") {
                            if !newListName.trimmingCharacters(in: .whitespaces).isEmpty {
                                pinStore.createCustomList(name: newListName.trimmingCharacters(in: .whitespaces))
                                selectedListName = newListName.trimmingCharacters(in: .whitespaces)
                                newListName = ""
                            }
                        }
                        .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                
                // MARK: - Recommendation Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendation")
                            .font(.headline)
                            .foregroundColor(.primary)
                        HStack(spacing: 24) {
                            Button(action: { recommendation = true }) {
                                HStack {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .foregroundColor(recommendation == true ? .green : .gray)
                                    Text("Recommend")
                                        .foregroundColor(recommendation == true ? .green : .primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(recommendation == true ? Color.green.opacity(0.2) : Color(.systemGray5))
                                .cornerRadius(20)
                            }
                            Button(action: { recommendation = false }) {
                                HStack {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .foregroundColor(recommendation == false ? .red : .gray)
                                    Text("Don't Recommend")
                                        .foregroundColor(recommendation == false ? .red : .primary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(recommendation == false ? Color.red.opacity(0.2) : Color(.systemGray5))
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                
                // MARK: - Post Content Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Experience")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $postContent)
                            .focused($isPostContentFocused)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            if postContent.isEmpty {
                                Text("Share your experience, what you loved, tips for others...")
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                            }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // MARK: - Media Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Photos & Videos")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 12) {
                            PhotosPicker(
                                selection: $selectedPhotoItems,
                                maxSelectionCount: 10,
                                matching: .images
                            ) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                    Text("Add Photos")
                                        .fontWeight(.medium)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                    
                            Button {
                                showingVideoPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "video.circle")
                                        .font(.title2)
                                    Text("Add Videos")
                                        .fontWeight(.medium)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(10)
                            }
                        }
                        
                        // Display selected media
                        if !selectedImages.isEmpty || !selectedVideos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // Display images
                                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .cornerRadius(8)
                                                .clipped()
                                            
                                            Button {
                                                selectedImages.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                    
                                    // Display videos
                                    ForEach(Array(selectedVideos.enumerated()), id: \.offset) { index, videoURL in
                                        ZStack(alignment: .topTrailing) {
                                            VideoPlayer(player: AVPlayer(url: videoURL))
                                        .frame(width: 100, height: 100)
                                                .cornerRadius(8)
                                                .clipped()
                                            
                                            Button {
                                                selectedVideos.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    
                    // MARK: - Privacy Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Toggle("Private Post", isOn: $isPrivatePost)
                        
                        if isPrivatePost {
                            Text("Only your followers will be able to see this post")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                
                // MARK: - Submit Button
                    Button(action: createPost) {
                        HStack {
                            if isCreatingPost {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 8)
                            }
                            Text(isCreatingPost ? "Creating Post..." : "Create Post")
                            .fontWeight(.semibold)
                        }
                            .frame(maxWidth: .infinity)
                            .padding()
                        .background(isFormValid && !isCreatingPost ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isFormValid || isCreatingPost)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        clearForm()
                    }
                }
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                await loadSelectedPhotos(newItems)
            }
        }
        .onAppear {
            setupLocationServices()
        }
        .sheet(isPresented: $showingVideoPicker) {
            VideoPickerView(selectedVideos: $selectedVideos)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Post created successfully!")
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupLocationServices() {
            completer.resultTypes = [.address, .pointOfInterest]
            completer.region = locationManager.region
            let wrapper = SearchCompleterDelegateWrapper { completions in
                searchResults = completions
            }
            completerDelegateWrapper = wrapper
            completer.delegate = wrapper
            mapRegion = locationManager.region
        }
    
    private func selectPlace(_ completion: MKLocalSearchCompletion) {
        isPlaceFieldFocused = false
        selectedCompletion = completion
        placeName = completion.title
        searchResults = []
        
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, error in
            if let mapItem = response?.mapItems.first {
                DispatchQueue.main.async {
                    selectedMapItem = mapItem
                    mapRegion = MKCoordinateRegion(
                        center: mapItem.placemark.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
        }
    }
        }
    }
    
    private func useCurrentLocation() {
        if let currentLocation = locationManager.location {
            let geocoder = CLGeocoder()
            let userCLLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
            geocoder.reverseGeocodeLocation(userCLLocation) { placemarks, error in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        placeName = placemark.name ?? placemark.locality ?? "Current Location"
                        // Create a map item from current location
                        let mapItem = MKMapItem(placemark: MKPlacemark(placemark: placemark))
                        selectedMapItem = mapItem
                        mapRegion = MKCoordinateRegion(
                            center: currentLocation,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
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
    
    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        selectedImages = []
        
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        selectedImages.append(uiImage)
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
            }
        }
    }
    
    private func createPost() {
        guard let mapItem = selectedMapItem,
              let userID = authManager.currentUserID else {
            errorMessage = "Missing required information"
            showError = true
            return
        }
        
        isCreatingPost = true
        
        Task {
            do {
                // Create the pin first
                let pin = Pin(
                    id: UUID(),
                    locationName: placeName,
                    city: mapItem.placemark.locality ?? "",
                    date: DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none),
                    latitude: mapItem.placemark.coordinate.latitude,
                    longitude: mapItem.placemark.coordinate.longitude,
                    reaction: reaction,
                    reviewText: postContent.isEmpty ? nil : postContent,
                    mediaURLs: [], // Will be populated with uploaded media URLs
                    mentionedFriends: [],
                    starRating: rating > 0 ? Double(rating) : nil,
                    distance: nil,
                    authorHandle: "@\(authManager.currentUsername ?? "user")",
                    createdAt: Date(),
                    tripName: tripName.isEmpty ? nil : tripName
                )
                
                // Upload media and get URLs
                var mediaURLs: [String] = []
                
                // Upload images
                for (index, image) in selectedImages.enumerated() {
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        do {
                            let imageURL = try await SupabaseManager.shared.uploadPinImage(imageData, for: pin.id.uuidString)
                            mediaURLs.append(imageURL)
                            print("✅ Uploaded image \(index + 1)/\(selectedImages.count)")
                        } catch {
                            print("❌ Failed to upload image \(index + 1): \(error)")
                        }
                    }
                }
                
                // Upload videos (if any)
                for (index, videoURL) in selectedVideos.enumerated() {
                    do {
                        let videoData = try Data(contentsOf: videoURL)
                        // For now, we'll treat videos as large media files
                        // In a real implementation, you'd want video-specific upload handling
                        print("📹 Video upload not yet implemented for video \(index + 1)")
                    } catch {
                        print("❌ Failed to process video \(index + 1): \(error)")
                    }
                }
                
                // Create final pin with media URLs
                let finalPin = Pin(
                    id: pin.id,
                    locationName: pin.locationName,
                    city: pin.city,
                    date: pin.date,
                    latitude: pin.latitude,
                    longitude: pin.longitude,
                    reaction: pin.reaction,
                    reviewText: pin.reviewText,
                    mediaURLs: mediaURLs,
                    mentionedFriends: pin.mentionedFriends,
                    starRating: pin.starRating,
                    distance: pin.distance,
                    authorHandle: pin.authorHandle,
                    createdAt: pin.createdAt,
                    tripName: pin.tripName
                )
                
                // Create the pin in database
                let pinId = try await SupabaseManager.shared.createPin(pin: finalPin)
                print("✅ Created pin with ID: \(pinId)")
                
                // Add to selected or new list if specified
                if !selectedListName.isEmpty {
                    pinStore.addPin(finalPin, to: selectedListName)
                }
                
                // Create friend activity for this new pin
                await SupabaseManager.shared.createFriendActivity(
                    activityType: reaction == .lovedIt ? .ratedPlace : .visitedPlace,
                    relatedPinId: finalPin.id,
                    locationName: finalPin.locationName,
                    description: reaction == .lovedIt ? "loved \(finalPin.locationName)" : "visited \(finalPin.locationName)"
                )
                
                // Save offline if needed
                if !DataManager.shared.checkConnectivity() {
                    await DataManager.shared.savePinOffline(finalPin)
                }
                
                await MainActor.run {
                    isCreatingPost = false
                    showSuccess = true
                }
                
            } catch {
                await MainActor.run {
                    isCreatingPost = false
                    errorMessage = "Failed to create post: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func clearForm() {
        placeName = ""
        location = ""
        rating = 0
        recommendation = nil
        recommendedTo = "Everyone"
        postContent = ""
        selectedImages = []
        selectedVideos = []
        selectedPhotoItems = []
        selectedMapItem = nil
        reaction = .lovedIt
        tripName = ""
        isPrivatePost = false
        recommendationComment = ""
        selectedListName = ""
        newListName = ""
        // Reset focus
        isPlaceFieldFocused = false
        isPostContentFocused = false
    }
}

// MARK: - Supporting Views and Classes

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

struct VideoPickerView: UIViewControllerRepresentable {
    @Binding var selectedVideos: [URL]
    @Environment(\.presentationMode) var presentationMode

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 5 // Limit video selection
        configuration.filter = .videos
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: VideoPickerView

        init(_ parent: VideoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.selectedVideos = []
            let dispatchGroup = DispatchGroup()

            for result in results {
                dispatchGroup.enter()
                if result.itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
                    result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                        if let url = url {
                            // Copy to temporary location
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                            do {
                                try FileManager.default.copyItem(at: url, to: tempURL)
                                DispatchQueue.main.async {
                                    self.parent.selectedVideos.append(tempURL)
                                }
                            } catch {
                                print("Failed to copy video: \(error)")
                            }
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
