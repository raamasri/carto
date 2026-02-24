//
//  LocationStoriesView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//  Feature: Location-based Stories/Moments with 24hr expiry
//

import SwiftUI
import MapKit
import PhotosUI

struct LocationStoriesView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @StateObject private var locationManager = AppLocationManager()
    
    @State private var stories: [LocationStory] = []
    @State private var myStories: [LocationStory] = []
    @State private var isLoading = false
    @State private var selectedStory: LocationStory?
    @State private var showCreateStory = false
    @State private var showStoryViewer = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Map state
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map with story markers
                Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: stories) { story in
                    MapAnnotation(coordinate: story.coordinate) {
                        StoryMapMarker(story: story) {
                            selectedStory = story
                            showStoryViewer = true
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
                
                // Stories carousel at top
                VStack {
                    StoriesCarousel(
                        stories: stories,
                        myStories: myStories,
                        onStoryTap: { story in
                            selectedStory = story
                            showStoryViewer = true
                        },
                        onCreateTap: {
                            showCreateStory = true
                        }
                    )
                    .padding(.top, 50)
                    
                    Spacer()
                    
                    // Create story button
                    Button(action: { showCreateStory = true }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Create Story")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(25)
                        .shadow(radius: 5)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadStories()
                updateRegionToUserLocation()
            }
            .sheet(isPresented: $showCreateStory) {
                CreateStoryView(onStoryCreated: { story in
                    myStories.insert(story, at: 0)
                    stories.insert(story, at: 0)
                })
                .environmentObject(authManager)
                .environmentObject(supabaseManager)
            }
            .sheet(item: $selectedStory) { story in
                StoryViewerView(story: story, onDismiss: {
                    selectedStory = nil
                })
                .environmentObject(authManager)
                .environmentObject(supabaseManager)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }
    
    private func loadStories() {
        Task {
            isLoading = true
            do {
                let allStories = try await supabaseManager.fetchFriendStories()
                
                // Separate my stories and friend stories
                let userId = authManager.currentUserID ?? ""
                myStories = allStories.filter { $0.userId == userId }
                stories = allStories
                
                // Remove expired stories
                removeExpiredStories()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
    
    private func removeExpiredStories() {
        stories.removeAll { $0.isExpired }
        myStories.removeAll { $0.isExpired }
    }
    
    private func updateRegionToUserLocation() {
        if let location = locationManager.location {
                          region = MKCoordinateRegion(
                  center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
    }
}

// MARK: - Stories Carousel
struct StoriesCarousel: View {
    let stories: [LocationStory]
    let myStories: [LocationStory]
    let onStoryTap: (LocationStory) -> Void
    let onCreateTap: () -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Add story button
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Your Story")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .onTapGesture(perform: onCreateTap)
                
                // My stories
                ForEach(myStories) { story in
                    StoryThumbnail(story: story, isOwn: true) {
                        onStoryTap(story)
                    }
                }
                
                // Friend stories
                ForEach(stories.filter { story in
                    !myStories.contains(where: { $0.id == story.id })
                }) { story in
                    StoryThumbnail(story: story, isOwn: false) {
                        onStoryTap(story)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 100)
        .background(Color.black.opacity(0.7))
    }
}

// MARK: - Story Thumbnail
struct StoryThumbnail: View {
    let story: LocationStory
    let isOwn: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack {
            ZStack {
                // User avatar with story ring
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: isOwn ? [.blue, .purple] : [.pink, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 70, height: 70)
                
                AsyncImage(url: URL(string: story.userAvatarURL ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                
                // View count badge
                if story.viewCount > 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(story.viewCount)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Text(story.username)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Story Map Marker
struct StoryMapMarker: View {
    let story: LocationStory
    let onTap: () -> Void
    
    var body: some View {
        ZStack {
            // Pulsing animation for active stories
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 60, height: 60)
                .scaleEffect(1.5)
                .opacity(0.5)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: true)
            
            // Story marker
            VStack(spacing: 0) {
                AsyncImage(url: URL(string: story.userAvatarURL ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2)
                )
                
                Image(systemName: "triangle.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(180))
                    .offset(y: -5)
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Create Story View
struct CreateStoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @StateObject private var locationManager = AppLocationManager()
    
    let onStoryCreated: (LocationStory) -> Void
    
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var caption = ""
    @State private var visibility: StoryVisibility = .friends
    @State private var contentType: StoryContentType = .photo
    @State private var locationName = ""
    @State private var isUploading = false
    @State private var showImagePicker = false
    @State private var showCamera = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Content preview
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                } else {
                    // Content type selector
                    HStack(spacing: 20) {
                        ForEach([StoryContentType.photo, .video, .text], id: \.self) { type in
                            Button(action: { contentType = type }) {
                                VStack {
                                    Image(systemName: type.icon)
                                        .font(.largeTitle)
                                    Text(type.rawValue.capitalized)
                                        .font(.caption)
                                }
                                .foregroundColor(contentType == type ? .white : .blue)
                                .frame(width: 100, height: 100)
                                .background(contentType == type ? Color.blue : Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
                
                // Caption input
                TextField("Add a caption...", text: $caption)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // Location name
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    TextField("Location name", text: $locationName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Visibility selector
                Picker("Visibility", selection: $visibility) {
                    ForEach(StoryVisibility.allCases, id: \.self) { vis in
                        Label(vis.displayName, systemImage: vis.icon)
                            .tag(vis)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Media selection buttons
                if contentType != .text {
                    HStack(spacing: 20) {
                        Button(action: { showCamera = true }) {
                            Label("Camera", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: { showImagePicker = true }) {
                            Label("Library", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Create Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        createStory()
                    }
                    .disabled(isUploading || (contentType != .text && selectedImage == nil))
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    selectedImage = image
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
            }
            .overlay {
                if isUploading {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView("Creating story...")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func createStory() {
        guard let location = locationManager.location else { return }
        
        Task {
            isUploading = true
            do {
                var mediaURL: String? = nil

                if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
                    let fileName = "story_\(UUID().uuidString).jpg"
                    let path = "story-images/\(fileName)"
                    mediaURL = try await SupabaseManager.shared.storageService.uploadImage(imageData, to: "story-images", path: path)
                }
                
                let story = try await supabaseManager.createLocationStory(
                    locationName: locationName.isEmpty ? "Current Location" : locationName,
                                      latitude: location.latitude,
                  longitude: location.longitude,
                    contentType: contentType,
                    mediaURL: mediaURL,
                    caption: caption.isEmpty ? nil : caption,
                    visibility: visibility
                )
                
                onStoryCreated(story)
                dismiss()
            } catch {
                print("Failed to create story: \(error)")
            }
            isUploading = false
        }
    }
}

// MARK: - Story Viewer View
struct StoryViewerView: View {
    let story: LocationStory
    let onDismiss: () -> Void
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var viewers: [AppUser] = []
    @State private var showViewers = false
    @State private var selectedReaction: ReactionType?
    @State private var progress: Double = 0
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Story content
            VStack {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal)
                .padding(.top, 50)
                
                // User info
                HStack {
                    AsyncImage(url: URL(string: story.userAvatarURL ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text(story.username)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(story.locationName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Time remaining
                    Text(timeRemainingText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                // Story content
                if let mediaURL = story.mediaURL {
                    AsyncImage(url: URL(string: mediaURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                } else if story.contentType == .text {
                    Text(story.caption ?? "")
                        .font(.title)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                Spacer()
                
                // Caption
                if let caption = story.caption, story.contentType != .text {
                    Text(caption)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding()
                }
                
                // Interaction bar
                HStack(spacing: 20) {
                    // Reactions
                    HStack(spacing: 12) {
                        ForEach([ReactionType.like, .love, .fire, .clap], id: \.self) { reaction in
                            Button(action: { reactToStory(reaction) }) {
                                Text(reaction.emoji)
                                    .font(.title2)
                                    .scaleEffect(selectedReaction == reaction ? 1.3 : 1.0)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // View count
                    if story.userId == authManager.currentUserID {
                        Button(action: { showViewers = true }) {
                            HStack {
                                Image(systemName: "eye")
                                Text("\(story.viewCount)")
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            recordView()
            startProgress()
        }
        .onReceive(timer) { _ in
            updateProgress()
        }
        .sheet(isPresented: $showViewers) {
            StoryViewersListView(storyId: story.id)
                .environmentObject(supabaseManager)
        }
    }
    
    private var timeRemainingText: String {
        let hours = Int(story.timeRemaining) / 3600
        let minutes = Int(story.timeRemaining) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func recordView() {
        Task {
            try? await supabaseManager.recordStoryView(storyId: story.id)
        }
    }
    
    private func reactToStory(_ reaction: ReactionType) {
        selectedReaction = reaction
        Task {
            try? await supabaseManager.addStoryReaction(storyId: story.id, reactionType: reaction)
        }
    }
    
    private func startProgress() {
        progress = 0
    }
    
    private func updateProgress() {
        withAnimation(.linear(duration: 0.1)) {
            progress += 0.01
        }
        
        if progress >= 1.0 {
            onDismiss()
        }
    }
}

// MARK: - Story Viewers List
struct StoryViewersListView: View {
    let storyId: UUID
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var viewers: [AppUser] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            List(viewers) { viewer in
                HStack {
                    AsyncImage(url: URL(string: viewer.avatarURL ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text(viewer.username)
                            .font(.headline)
                        
                        Text(viewer.full_name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Story Views")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadViewers()
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }
    
    private func loadViewers() {
        Task {
            isLoading = true
            do {
                viewers = try await supabaseManager.getStoryViewers(storyId: storyId)
            } catch {
                print("Failed to load viewers: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - Camera View Placeholder
struct CameraView: View {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        // TODO: Implement actual camera view
        VStack {
            Text("Camera View")
                .font(.largeTitle)
            
            Button("Cancel") {
                dismiss()
            }
        }
    }
}

// Note: ImagePicker is defined in ProfileEditView.swift and shared across the app 