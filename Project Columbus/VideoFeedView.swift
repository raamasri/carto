// created by raama srivatsan on 4/16/25
import SwiftUI
import AVKit
import CoreLocation
import PhotosUI

struct VideoFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var videos: [VideoContent] = []
    @State private var selectedFilter: VideoFeedFilter = .forYou
    @State private var isLoading = false
    @State private var currentVideoIndex = 0
    @State private var showComments = false
    @State private var selectedVideo: VideoContent?
    @State private var showCreateVideo = false
    @State private var showProfile = false
    @State private var selectedUser: AppUser?
    @State private var showShareSheet = false
    @State private var shareVideoURL: URL?
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading && videos.isEmpty {
                    loadingView
                } else if videos.isEmpty {
                    emptyStateView
                } else {
                    videoFeedContent
                }
                
                // Top overlay with filters and close button
                VStack {
                    topOverlay
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadVideos()
        }
        .sheet(isPresented: $showComments) {
            if let video = selectedVideo {
                VideoCommentsView(video: video)
                    .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showCreateVideo) {
            CreateVideoView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showProfile) {
            if let user = selectedUser {
                UserProfileView(profileUser: user)
                    .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareVideoURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }
    
    private var topOverlay: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VideoFeedFilter.allCases, id: \.self) { filter in
                        FilterPill(
                            filter: filter,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                            loadVideos()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
            
            Button(action: { showCreateVideo = true }) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var videoFeedContent: some View {
        TabView(selection: $currentVideoIndex) {
            ForEach(Array(videos.enumerated()), id: \.offset) { index, video in
                VideoPlayerView(
                    video: video,
                    isCurrentVideo: currentVideoIndex == index
                ) { action in
                    handleVideoAction(action, for: video)
                }
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onChange(of: currentVideoIndex) { _, newIndex in
            // Record view for the new video
            if newIndex < videos.count {
                let video = videos[newIndex]
                recordVideoView(for: video)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading videos...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Videos Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Be the first to share a video with your friends!")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Create Video") {
                showCreateVideo = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func loadVideos() {
        guard let userID = authManager.currentUserID else { return }
        
        isLoading = true
        
        Task {
            do {
                let loadedVideos = try await SupabaseManager.shared.getVideoFeed(
                    filter: selectedFilter,
                    userID: userID,
                    limit: 20
                )
                
                await MainActor.run {
                    self.videos = loadedVideos
                    self.isLoading = false
                    
                    // Start playing the first video
                    if !loadedVideos.isEmpty && currentVideoIndex == 0 {
                        recordVideoView(for: loadedVideos[0])
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load videos: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }
    
    private func handleVideoAction(_ action: VideoAction, for video: VideoContent) {
        switch action {
        case .like:
            toggleLike(for: video)
        case .comment:
            selectedVideo = video
            showComments = true
        case .share:
            shareVideo(video)
        case .bookmark:
            toggleBookmark(for: video)
        case .viewProfile:
            // Create AppUser from video author info
            let user = AppUser(
                id: video.authorId,
                username: video.authorUsername,
                full_name: video.authorUsername,
                email: "",
                bio: "",
                follower_count: 0,
                following_count: 0,
                isFollowedByCurrentUser: false,
                latitude: nil,
                longitude: nil,
                isCurrentUser: false,
                avatarURL: video.authorAvatarURL
            )
            selectedUser = user
            showProfile = true
        case .viewLocation:
            // Handle location view if needed
            break
        }
    }
    
    private func toggleLike(for video: VideoContent) {
        guard let userID = authManager.currentUserID,
              let username = authManager.currentUsername else { return }
        
        Task {
            let isLiked = await SupabaseManager.shared.toggleVideoLike(
                videoId: video.id.uuidString,
                userId: userID,
                username: username,
                userAvatarURL: authManager.currentUser?.avatarURL
            )
            
            // Update local state
            await MainActor.run {
                if let index = videos.firstIndex(where: { $0.id == video.id }) {
                    videos[index].isLikedByCurrentUser = isLiked
                    videos[index].likesCount += isLiked ? 1 : -1
                }
            }
        }
    }
    
    private func toggleBookmark(for video: VideoContent) {
        guard let userID = authManager.currentUserID else { return }
        
        Task {
            let isBookmarked = await SupabaseManager.shared.toggleVideoBookmark(
                videoId: video.id.uuidString,
                userId: userID
            )
            
            // Update local state
            await MainActor.run {
                if let index = videos.firstIndex(where: { $0.id == video.id }) {
                    videos[index].isBookmarkedByCurrentUser = isBookmarked
                }
            }
        }
    }
    
    private func shareVideo(_ video: VideoContent) {
        Task {
            await SupabaseManager.shared.shareVideo(videoId: video.id.uuidString)
            
            // Create share URL (you'd implement deep linking here)
            await MainActor.run {
                if let url = URL(string: "https://projectcolumbus.app/video/\(video.id.uuidString)") {
                    shareVideoURL = url
                    showShareSheet = true
                }
                
                // Update local share count
                if let index = videos.firstIndex(where: { $0.id == video.id }) {
                    videos[index].sharesCount += 1
                }
            }
        }
    }
    
    private func recordVideoView(for video: VideoContent) {
        guard let userID = authManager.currentUserID else { return }
        
        Task {
            await SupabaseManager.shared.recordVideoView(
                videoId: video.id.uuidString,
                userId: userID,
                watchDuration: 0 // You'd track actual watch duration
            )
        }
    }
}

// MARK: - Supporting Views

struct FilterPill: View {
    let filter: VideoFeedFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.white : Color.black.opacity(0.3)
            )
            .foregroundColor(isSelected ? .black : .white)
            .clipShape(Capsule())
        }
    }
}

struct VideoPlayerView: View {
    let video: VideoContent
    let isCurrentVideo: Bool
    let onAction: (VideoAction) -> Void
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showControls = false
    
    var body: some View {
        ZStack {
            // Video player
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControls.toggle()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showControls = false
                            }
                        }
                    }
            } else {
                // Thumbnail or loading state
                AsyncImage(url: URL(string: video.thumbnailURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }
                .ignoresSafeArea()
            }
            
            // Video overlay content
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Video info
                    VStack(alignment: .leading, spacing: 8) {
                        // Author info
                        HStack {
                            AsyncImage(url: URL(string: video.authorAvatarURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .onTapGesture {
                                onAction(.viewProfile)
                            }
                            
                            Text("@\(video.authorUsername)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .onTapGesture {
                                    onAction(.viewProfile)
                                }
                            
                            Spacer()
                        }
                        
                        // Caption
                        if !video.caption.isEmpty {
                            Text(video.caption)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .lineLimit(3)
                        }
                        
                        // Hashtags
                        if !video.hashtags.isEmpty {
                            Text(video.hashtags.map { "#\($0)" }.joined(separator: " "))
                                .font(.caption)
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                        
                        // Location
                        if let location = video.displayLocation {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                Text(location)
                                    .font(.caption)
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .onTapGesture {
                                onAction(.viewLocation)
                            }
                        }
                        
                        // Music info
                        if let musicInfo = video.musicInfo {
                            HStack {
                                Image(systemName: "music.note")
                                    .font(.caption)
                                Text("\(musicInfo.title) - \(musicInfo.artist)")
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.leading, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Action buttons
                    VStack(spacing: 24) {
                        // Like button
                        VStack(spacing: 4) {
                            Button {
                                onAction(.like)
                            } label: {
                                Image(systemName: video.isLikedByCurrentUser ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundColor(video.isLikedByCurrentUser ? .red : .white)
                            }
                            
                            Text("\(video.likesCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        // Comment button
                        VStack(spacing: 4) {
                            Button {
                                onAction(.comment)
                            } label: {
                                Image(systemName: "bubble.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            Text("\(video.commentsCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        
                        // Bookmark button
                        VStack(spacing: 4) {
                            Button {
                                onAction(.bookmark)
                            } label: {
                                Image(systemName: video.isBookmarkedByCurrentUser ? "bookmark.fill" : "bookmark")
                                    .font(.title2)
                                    .foregroundColor(video.isBookmarkedByCurrentUser ? .yellow : .white)
                            }
                        }
                        
                        // Share button
                        VStack(spacing: 4) {
                            Button {
                                onAction(.share)
                            } label: {
                                Image(systemName: "arrowshape.turn.up.right")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            
                            if video.sharesCount > 0 {
                                Text("\(video.sharesCount)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 32)
            }
            
            // Play/pause overlay
            if showControls {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: isCurrentVideo) { _, isCurrent in
            if isCurrent {
                player?.play()
                isPlaying = true
            } else {
                player?.pause()
                isPlaying = false
            }
        }
    }
    
    private func setupPlayer() {
        guard let url = URL(string: video.videoURL) else { return }
        
        player = AVPlayer(url: url)
        
        // Setup looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
        
        if isCurrentVideo {
            player?.play()
            isPlaying = true
        }
    }
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

enum VideoAction {
    case like
    case comment
    case share
    case bookmark
    case viewProfile
    case viewLocation
}

// MARK: - Share Sheet
// ShareSheet is defined in ListSharingView.swift

// MARK: - Preview

struct VideoFeedView_Previews: PreviewProvider {
    static var previews: some View {
        VideoFeedView()
            .environmentObject(AuthManager())
            .previewDevice("iPhone 15 Pro")
    }
}

// MARK: - Video Comments View

struct VideoCommentsView: View {
    let video: VideoContent
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [VideoComment] = []
    @State private var newComment = ""
    @State private var isLoading = false
    @State private var isSubmitting = false
    @State private var replyingTo: VideoComment?
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    
                    Spacer()
                    
                    Text("Comments")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("") { }
                        .disabled(true)
                        .opacity(0)
                }
                .padding()
                .background(Color(.systemBackground))
                
                Divider()
                
                // Comments list
                if isLoading {
                    Spacer()
                    ProgressView("Loading comments...")
                    Spacer()
                } else if comments.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No comments yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Be the first to comment!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List(comments) { comment in
                        VideoCommentRowView(comment: comment) { action in
                            handleCommentAction(action, for: comment)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                }
                
                Divider()
                
                // Comment input
                VStack(spacing: 0) {
                    if let replyingTo = replyingTo {
                        HStack {
                            Text("Replying to @\(replyingTo.authorUsername)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button("Cancel") {
                                self.replyingTo = nil
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                    }
                    
                    HStack {
                        AsyncImage(url: URL(string: authManager.currentUser?.avatarURL ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        TextField("Add a comment...", text: $newComment, axis: .vertical)
                            .textFieldStyle(.plain)
                            .focused($isTextFieldFocused)
                            .lineLimit(1...4)
                        
                        Button("Post") {
                            submitComment()
                        }
                        .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                        .fontWeight(.semibold)
                        .foregroundColor(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .accentColor)
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            loadComments()
        }
    }
    
    private func loadComments() {
        guard let userID = authManager.currentUserID else { return }
        
        isLoading = true
        
        Task {
            do {
                let loadedComments = try await SupabaseManager.shared.getVideoComments(
                    videoId: video.id.uuidString,
                    userId: userID
                )
                
                await MainActor.run {
                    self.comments = loadedComments
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("Failed to load comments: \(error)")
                }
            }
        }
    }
    
    private func submitComment() {
        guard let userID = authManager.currentUserID,
              let username = authManager.currentUsername,
              !newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        
        Task {
            do {
                let comment = try await SupabaseManager.shared.addVideoComment(
                    videoId: video.id.uuidString,
                    authorId: userID,
                    authorUsername: username,
                    authorAvatarURL: authManager.currentUser?.avatarURL,
                    content: newComment.trimmingCharacters(in: .whitespacesAndNewlines),
                    parentCommentId: replyingTo?.id.uuidString
                )
                
                await MainActor.run {
                    self.comments.append(comment)
                    self.newComment = ""
                    self.replyingTo = nil
                    self.isSubmitting = false
                    self.isTextFieldFocused = false
                }
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    print("Failed to submit comment: \(error)")
                }
            }
        }
    }
    
    private func handleCommentAction(_ action: VideoCommentAction, for comment: VideoComment) {
        switch action {
        case .like:
            toggleCommentLike(comment)
        case .reply:
            replyingTo = comment
            isTextFieldFocused = true
        case .viewProfile:
            // Handle profile view
            break
        }
    }
    
    private func toggleCommentLike(_ comment: VideoComment) {
        guard let userID = authManager.currentUserID else { return }
        
        Task {
            let isLiked = await SupabaseManager.shared.toggleCommentLike(
                commentId: comment.id.uuidString,
                userId: userID
            )
            
            await MainActor.run {
                if let index = comments.firstIndex(where: { $0.id == comment.id }) {
                    comments[index].isLikedByCurrentUser = isLiked
                    comments[index].likesCount += isLiked ? 1 : -1
                }
            }
        }
    }
}

// MARK: - Video Comment Action

enum VideoCommentAction {
    case like
    case reply
    case viewProfile
}

// MARK: - Video Comment Row View

struct VideoCommentRowView: View {
    let comment: VideoComment
    let onAction: (VideoCommentAction) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: comment.authorAvatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .onTapGesture {
                onAction(.viewProfile)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(comment.authorUsername)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .onTapGesture {
                            onAction(.viewProfile)
                        }
                    
                    Text(comment.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                Text(comment.content)
                    .font(.subheadline)
                
                HStack(spacing: 16) {
                    Button {
                        onAction(.like)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: comment.isLikedByCurrentUser ? "heart.fill" : "heart")
                                .font(.caption)
                                .foregroundColor(comment.isLikedByCurrentUser ? .red : .secondary)
                            
                            if comment.likesCount > 0 {
                                Text("\(comment.likesCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button("Reply") {
                        onAction(.reply)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    if comment.repliesCount > 0 {
                        Text("\(comment.repliesCount) replies")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Create Video View

struct CreateVideoView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideoURL: URL?
    @State private var showingVideoPicker = false
    @State private var caption = ""
    @State private var hashtags = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var locationName = ""
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    videoSelectionSection
                    captionSection
                    hashtagsSection
                    locationSection
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        uploadVideo()
                    }
                    .disabled(selectedVideoURL == nil || isUploading)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingVideoPicker) {
                SingleVideoPickerView(selectedVideoURL: $selectedVideoURL)
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isUploading {
                    uploadingOverlay
                }
            }
        }
    }
    
    private var videoSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Video")
                .font(.headline)
            
            if let videoURL = selectedVideoURL {
                ZStack {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 300)
                        .cornerRadius(12)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                selectedVideoURL = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding()
                        }
                        Spacer()
                    }
                }
            } else {
                Button {
                    showingVideoPicker = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                        
                        Text("Select Video")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        
                        Text("Choose a video from your library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Caption")
                .font(.headline)
            
            TextField("Write a caption...", text: $caption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(5...10)
        }
    }
    
    private var hashtagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hashtags")
                .font(.headline)
            
            TextField("Enter hashtags separated by spaces", text: $hashtags)
                .textFieldStyle(.roundedBorder)
            
            Text("Example: travel foodie adventure")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location (Optional)")
                .font(.headline)
            
            TextField("Add location", text: $locationName)
                .textFieldStyle(.roundedBorder)
            
            Text("Help others discover places through your video")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: uploadProgress, total: 1.0)
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(2)
                
                Text("Uploading video...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(Int(uploadProgress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
    
    private func uploadVideo() {
        guard let videoURL = selectedVideoURL,
              let userID = authManager.currentUserID,
              let username = authManager.currentUsername else { return }
        
        isUploading = true
        uploadProgress = 0
        
        Task {
            do {
                // Load video data
                let videoData = try Data(contentsOf: videoURL)
                uploadProgress = 0.1
                
                // Create video content object
                let videoID = UUID()
                
                // Upload video file
                let videoURLString = try await SupabaseManager.shared.uploadVideo(videoData, for: videoID.uuidString)
                uploadProgress = 0.7
                
                // Parse hashtags
                let hashtagArray = hashtags
                    .split(separator: " ")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // Create video content
                let video = VideoContent(
                    id: videoID,
                    videoURL: videoURLString,
                    thumbnailURL: nil, // You'd generate a thumbnail here
                    duration: 0, // You'd calculate actual duration
                    authorId: userID,
                    authorUsername: username,
                    authorAvatarURL: authManager.currentUser?.avatarURL,
                    caption: caption,
                    hashtags: hashtagArray,
                    locationName: locationName.isEmpty ? nil : locationName
                )
                
                _ = try await SupabaseManager.shared.createVideoContent(video)
                uploadProgress = 1.0
                
                await MainActor.run {
                    isUploading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = "Failed to upload video: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

// MARK: - Single Video Picker

struct SingleVideoPickerView: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 1
        configuration.filter = .videos
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: SingleVideoPickerView
        
        init(_ parent: SingleVideoPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            if result.itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                    if let url = url {
                        // Copy to temporary location
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                        do {
                            try FileManager.default.copyItem(at: url, to: tempURL)
                            DispatchQueue.main.async {
                                self.parent.selectedVideoURL = tempURL
                            }
                        } catch {
                            print("Failed to copy video: \(error)")
                        }
                    }
                }
            }
        }
    }
}


