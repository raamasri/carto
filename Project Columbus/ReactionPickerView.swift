//
//  ReactionPickerView.swift
//  Project Columbus
//
//  Created by Assistant on Date
//  Feature: Social reactions system for pins and activities
//

import SwiftUI

// MARK: - Reaction Picker View
struct ReactionPickerView: View {
    let contentType: ReactionContentType
    let contentId: UUID
    @Binding var selectedReaction: ReactionType?
    @Binding var reactionCounts: [ReactionType: Int]
    
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var showPicker = false
    @State private var isAnimating = false
    
    enum ReactionContentType {
        case pin
        case activity
        case story
        
        var availableReactions: [ReactionType] {
            switch self {
            case .pin:
                return [.like, .love, .wow, .fire, .star]
            case .activity:
                return [.like, .love, .celebrate, .support]
            case .story:
                return [.like, .love, .fire, .clap]
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Main reaction button
            Button(action: {
                if selectedReaction != nil {
                    removeReaction()
                } else {
                    withAnimation(.spring()) {
                        showPicker.toggle()
                    }
                }
            }) {
                HStack(spacing: 4) {
                    if let reaction = selectedReaction {
                        Text(reaction.emoji)
                            .font(.title3)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "face.smiling")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    
                    if totalReactions > 0 {
                        Text("\(totalReactions)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedReaction != nil ? selectedReaction!.color.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(20)
            }
            
            // Reaction picker
            if showPicker {
                HStack(spacing: 8) {
                    ForEach(contentType.availableReactions, id: \.self) { reaction in
                        Button(action: {
                            selectReaction(reaction)
                        }) {
                            Text(reaction.emoji)
                                .font(.title2)
                                .scaleEffect(isAnimating ? 1.2 : 1.0)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(radius: 5)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Top reactions display
            if !showPicker && totalReactions > 0 {
                HStack(spacing: -8) {
                    ForEach(topReactions.prefix(3), id: \.0) { reaction, count in
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 28, height: 28)
                            
                            Text(reaction.emoji)
                                .font(.callout)
                        }
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: showPicker)
        .animation(.spring(), value: selectedReaction)
        .animation(.spring(), value: reactionCounts)
    }
    
    private var totalReactions: Int {
        reactionCounts.values.reduce(0, +)
    }
    
    private var topReactions: [(ReactionType, Int)] {
        reactionCounts
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }
    
    private func selectReaction(_ reaction: ReactionType) {
        withAnimation(.spring()) {
            isAnimating = true
            showPicker = false
            
            // Remove old reaction if exists
            if let oldReaction = selectedReaction {
                reactionCounts[oldReaction] = max(0, (reactionCounts[oldReaction] ?? 0) - 1)
                if reactionCounts[oldReaction] == 0 {
                    reactionCounts.removeValue(forKey: oldReaction)
                }
            }
            
            // Add new reaction
            selectedReaction = reaction
            reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // Save to database
        Task {
            do {
                switch contentType {
                case .pin:
                    try await supabaseManager.addPinReaction(pinId: contentId, reactionType: reaction)
                case .activity:
                    try await supabaseManager.addActivityReaction(activityId: contentId, reactionType: reaction)
                case .story:
                    try await supabaseManager.addStoryReaction(storyId: contentId, reactionType: reaction)
                }
            } catch {
                print("Failed to save reaction: \(error)")
            }
        }
        
        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
    }
    
    private func removeReaction() {
        guard let reaction = selectedReaction else { return }
        
        withAnimation(.spring()) {
            reactionCounts[reaction] = max(0, (reactionCounts[reaction] ?? 0) - 1)
            if reactionCounts[reaction] == 0 {
                reactionCounts.removeValue(forKey: reaction)
            }
            selectedReaction = nil
        }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        // Remove from database
        Task {
            do {
                switch contentType {
                case .pin:
                    try await supabaseManager.removePinReaction(pinId: contentId)
                case .activity, .story:
                    // For activities and stories, we use upsert so just set to nil
                    break
                }
            } catch {
                print("Failed to remove reaction: \(error)")
            }
        }
    }
}

// MARK: - Reaction Summary View
struct ReactionSummaryView: View {
    let reactions: [ReactionType: Int]
    let onTap: () -> Void
    
    private var topReactions: [(ReactionType, Int)] {
        reactions
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
            .prefix(5)
            .map { ($0.0, $0.1) }
    }
    
    private var totalCount: Int {
        reactions.values.reduce(0, +)
    }
    
    var body: some View {
        if !reactions.isEmpty {
            Button(action: onTap) {
                HStack(spacing: 4) {
                    HStack(spacing: -4) {
                        ForEach(topReactions, id: \.0) { reaction, _ in
                            Text(reaction.emoji)
                                .font(.callout)
                                .padding(2)
                                .background(Circle().fill(Color(.systemBackground)))
                        }
                    }
                    
                    if totalCount > 0 {
                        Text("\(totalCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
            }
        }
    }
}

// MARK: - Reaction Details Sheet
struct ReactionDetailsView: View {
    let contentType: ReactionPickerView.ReactionContentType
    let contentId: UUID
    let reactions: [ReactionType: Int]
    
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var reactionUsers: [ReactionType: [AppUser]] = [:]
    @State private var selectedReactionTab: ReactionType?
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                // Reaction tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(reactions.sorted(by: { $0.value > $1.value }), id: \.key) { reaction, count in
                            Button(action: {
                                selectedReactionTab = reaction
                            }) {
                                VStack(spacing: 4) {
                                    Text(reaction.emoji)
                                        .font(.title2)
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedReactionTab == reaction ? reaction.color.opacity(0.2) : Color.clear)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                Divider()
                
                // Users list
                if isLoading {
                    ProgressView()
                        .padding()
                } else if let selectedReaction = selectedReactionTab,
                          let users = reactionUsers[selectedReaction] {
                    List(users) { user in
                        HStack {
                            AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
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
                                Text(user.username)
                                    .font(.headline)
                                
                                Text(user.full_name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(selectedReaction.emoji)
                                .font(.title3)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let firstReaction = reactions.sorted(by: { $0.value > $1.value }).first?.key {
                    selectedReactionTab = firstReaction
                }
                loadReactionUsers()
            }
        }
    }
    
    private func loadReactionUsers() {
        Task {
            isLoading = true
            
            // TODO: Implement fetching users for each reaction type
            // This would require additional API methods to get users who reacted
            
            isLoading = false
        }
    }
}

// MARK: - Animated Reaction View
struct AnimatedReactionView: View {
    let reaction: ReactionType
    @State private var isAnimating = false
    
    var body: some View {
        Text(reaction.emoji)
            .font(.system(size: 60))
            .scaleEffect(isAnimating ? 1.5 : 1.0)
            .opacity(isAnimating ? 0 : 1)
            .animation(.easeOut(duration: 1.0), value: isAnimating)
            .onAppear {
                withAnimation {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Usage Examples
struct ReactionExampleView: View {
    @State private var pinReaction: ReactionType?
    @State private var pinReactionCounts: [ReactionType: Int] = [
        .like: 5,
        .love: 3,
        .fire: 2
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            // Pin reaction example
            VStack(alignment: .leading) {
                Text("Pin Reactions")
                    .font(.headline)
                
                ReactionPickerView(
                    contentType: .pin,
                    contentId: UUID(),
                    selectedReaction: $pinReaction,
                    reactionCounts: $pinReactionCounts
                )
            }
            
            // Reaction summary example
            VStack(alignment: .leading) {
                Text("Reaction Summary")
                    .font(.headline)
                
                ReactionSummaryView(
                    reactions: pinReactionCounts,
                    onTap: {
                        // Show details sheet
                    }
                )
            }
        }
        .padding()
    }
} 