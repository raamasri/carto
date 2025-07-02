//
//  CommentsAndReactionsView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//

import SwiftUI
import Foundation

struct CommentsAndReactionsView: View {
    let pin: Pin
    @EnvironmentObject var authManager: AuthManager
    @State private var comments: [PinComment] = []
    @State private var reactions: [PinReaction] = []
    @State private var newCommentText = ""
    @State private var isLoadingComments = false
    @State private var isLoadingReactions = false
    @State private var showReactionPicker = false
    @State private var userReaction: PinReactionType? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Pin header
                PinHeaderView(pin: pin)
                
                Divider()
                
                // Reactions section
                ReactionsSection(
                    reactions: reactions,
                    userReaction: userReaction,
                    onReactionTap: { reaction in
                        Task {
                            await toggleReaction(reaction)
                        }
                    },
                    onShowAllReactions: {
                        showReactionPicker = true
                    }
                )
                
                Divider()
                
                // Comments section
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Comments")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        Spacer()
                        
                        Text("\(comments.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                    
                    if isLoadingComments {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if comments.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("No comments yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Be the first to share your thoughts!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        List(comments) { comment in
                            CommentRowView(comment: comment) { commentId in
                                Task {
                                    await toggleCommentLike(commentId)
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(.plain)
                    }
                }
                
                Spacer()
                
                // Comment input
                CommentInputView(
                    text: $newCommentText,
                    onSend: {
                        Task {
                            await addComment()
                        }
                    }
                )
            }
            .navigationTitle("Comments & Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showReactionPicker) {
                ReactionPickerView(
                    currentReaction: userReaction,
                    onReactionSelected: { reaction in
                        Task {
                            await toggleReaction(reaction)
                        }
                        showReactionPicker = false
                    }
                )
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        guard let userId = authManager.currentUserID else { return }
        
        isLoadingComments = true
        isLoadingReactions = true
        
        async let commentsTask = SupabaseManager.shared.getComments(for: pin.id, currentUserId: userId)
        async let reactionsTask = SupabaseManager.shared.getReactions(for: pin.id)
        
        let (fetchedComments, fetchedReactions) = await (commentsTask, reactionsTask)
        
        await MainActor.run {
            comments = fetchedComments
            reactions = fetchedReactions
            userReaction = fetchedReactions.first(where: { $0.userId == userId })?.reactionType
            isLoadingComments = false
            isLoadingReactions = false
        }
    }
    
    private func addComment() async {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let success = await SupabaseManager.shared.addComment(pinId: pin.id, content: newCommentText.trimmingCharacters(in: .whitespacesAndNewlines))
        
        if success {
            await MainActor.run {
                newCommentText = ""
            }
            await loadData()
        }
    }
    
    private func toggleReaction(_ reactionType: PinReactionType) async {
        if userReaction == reactionType {
            // Remove reaction
            let success = await SupabaseManager.shared.removeReaction(pinId: pin.id)
            if success {
                await MainActor.run {
                    userReaction = nil
                }
                await loadData()
            }
        } else {
            // Add/update reaction
            let success = await SupabaseManager.shared.addReaction(pinId: pin.id, reactionType: reactionType)
            if success {
                await MainActor.run {
                    userReaction = reactionType
                }
                await loadData()
            }
        }
    }
    
    private func toggleCommentLike(_ commentId: String) async {
        let success = await SupabaseManager.shared.toggleCommentLike(commentId: commentId)
        if success {
            await loadData()
        }
    }
}

// MARK: - Pin Header View

struct PinHeaderView: View {
    let pin: Pin
    
    var body: some View {
        HStack(spacing: 12) {
            // Pin image or placeholder
            if let mediaURLs = pin.mediaURLs, let firstImageURL = mediaURLs.first, let url = URL(string: firstImageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pin.locationName)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(pin.city)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let rating = pin.starRating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(rating) ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Reactions Section

struct ReactionsSection: View {
    let reactions: [PinReaction]
    let userReaction: PinReactionType?
    let onReactionTap: (PinReactionType) -> Void
    let onShowAllReactions: () -> Void
    
    private var reactionCounts: [PinReactionType: Int] {
        Dictionary(grouping: reactions, by: { $0.reactionType })
            .mapValues { $0.count }
    }
    
    private var topReactions: [PinReactionType] {
        reactionCounts.sorted { $0.value > $1.value }.prefix(6).map { $0.key }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reactions")
                    .font(.headline)
                
                Spacer()
                
                if !reactions.isEmpty {
                    Text("\(reactions.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            if reactions.isEmpty {
                VStack(spacing: 8) {
                    Text("No reactions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Tap below to be the first!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(topReactions, id: \.self) { reactionType in
                            ReactionButton(
                                reactionType: reactionType,
                                count: reactionCounts[reactionType] ?? 0,
                                isSelected: userReaction == reactionType,
                                onTap: {
                                    onReactionTap(reactionType)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Quick reaction buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(PinReactionType.allCases.prefix(6), id: \.self) { reactionType in
                        Button(action: {
                            onReactionTap(reactionType)
                        }) {
                            VStack(spacing: 4) {
                                Text(reactionType.emoji)
                                    .font(.title2)
                                Text(reactionType.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(userReaction == reactionType ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Reaction Button

struct ReactionButton: View {
    let reactionType: PinReactionType
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(reactionType.emoji)
                    .font(.title3)
                Text("\(count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Comment Row View

struct CommentRowView: View {
    let comment: PinComment
    let onLikeTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // User avatar
                AsyncImage(url: URL(string: comment.userAvatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("@\(comment.username)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(timeAgoString(from: comment.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Text(comment.content)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            HStack {
                Spacer()
                
                Button(action: {
                    onLikeTap(comment.id.uuidString)
                }) {
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
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Comment Input View

struct CommentInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Add a comment...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .lineLimit(1...4)
            
            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.accentColor)
                    .clipShape(Circle())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(Color.white)
    }
}

// MARK: - Reaction Picker View

struct ReactionPickerView: View {
    let currentReaction: PinReactionType?
    let onReactionSelected: (PinReactionType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose your reaction")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(PinReactionType.allCases, id: \.self) { reactionType in
                        Button(action: {
                            onReactionSelected(reactionType)
                        }) {
                            VStack(spacing: 8) {
                                Text(reactionType.emoji)
                                    .font(.system(size: 40))
                                Text(reactionType.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 80, height: 80)
                            .background(currentReaction == reactionType ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CommentsAndReactionsView(pin: Pin(
        locationName: "Sample Location",
        city: "Sample City",
        date: "Today",
        latitude: 37.7749,
        longitude: -122.4194,
        reaction: .lovedIt,
        reviewText: "Great place!",
        mediaURLs: nil,
        mentionedFriends: [],
        starRating: 4.5,
        distance: nil,
        authorHandle: "@sample",
        createdAt: Date(),
        tripName: nil
    ))
    .environmentObject(AuthManager())
} 