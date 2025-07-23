//
//  PostDraftsView.swift
//  Project Columbus
//
//  Created by Assistant on 1/10/25.
//

import SwiftUI
import MapKit

struct PostDraftsView: View {
    @StateObject private var timelineManager = TimelineManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDraft: PostDraft?
    @State private var showingPublishedDrafts: Bool = false
    
    var unpublishedDrafts: [PostDraft] {
        timelineManager.postDrafts.filter { !$0.isPublished }
    }
    
    var publishedDrafts: [PostDraft] {
        timelineManager.postDrafts.filter { $0.isPublished }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if unpublishedDrafts.isEmpty && publishedDrafts.isEmpty {
                    // Empty State
                    emptyStateView
                } else {
                    // Drafts Content
                    draftsContentView
                }
            }
            .navigationTitle("Post Drafts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingPublishedDrafts.toggle() }) {
                            Label(showingPublishedDrafts ? "Hide Published" : "Show Published", 
                                  systemImage: showingPublishedDrafts ? "eye.slash" : "eye")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $selectedDraft) { draft in
            PostDraftEditView(draft: draft)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Post Drafts")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Post drafts are automatically created when you visit places. Enable timeline to start creating drafts.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Drafts Content View
    
    private var draftsContentView: some View {
        List {
            if !unpublishedDrafts.isEmpty {
                Section("Drafts") {
                    ForEach(unpublishedDrafts) { draft in
                        PostDraftRow(draft: draft, onTap: {
                            selectedDraft = draft
                        })
                    }
                }
            }
            
            if showingPublishedDrafts && !publishedDrafts.isEmpty {
                Section("Published") {
                    ForEach(publishedDrafts) { draft in
                        PostDraftRow(draft: draft, onTap: {
                            selectedDraft = draft
                        })
                    }
                }
            }
        }
        .refreshable {
            await timelineManager.loadTimelineData()
        }
    }
}

// MARK: - Post Draft Row

struct PostDraftRow: View {
    let draft: PostDraft
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.title.isEmpty ? draft.locationName : draft.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(draft.city)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !draft.content.isEmpty {
                        Text(draft.content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: draft.sharingType.icon)
                                .font(.caption2)
                            Text(draft.sharingType.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let duration = draft.duration {
                            let hours = Int(duration) / 3600
                            let minutes = (Int(duration) % 3600) / 60
                            let durationString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
                            
                            Text(durationString)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(DateFormatter.dateFormatter.string(from: draft.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack {
                    if draft.isPublished {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Post Draft Edit View

struct PostDraftEditView: View {
    @State var draft: PostDraft
    @StateObject private var timelineManager = TimelineManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @State private var showingPublishAlert: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Location Info
                    locationInfoView
                    
                    // Post Content
                    postContentView
                    
                    // Sharing Settings
                    sharingSettingsView
                    
                    // Action Buttons
                    actionButtonsView
                }
                .padding()
            }
            .navigationTitle("Edit Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isLoading)
                }
            }
        }
        .alert("Delete Draft", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteDraft()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this draft? This action cannot be undone.")
        }
        .alert("Publish Post", isPresented: $showingPublishAlert) {
            Button("Publish") {
                publishDraft()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will publish your post and make it visible to \(draft.sharingType.displayName.lowercased()).")
        }
    }
    
    // MARK: - Location Info View
    
    private var locationInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.locationName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(draft.city)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(DateFormatter.dateTimeFormatter.string(from: draft.arrivalTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let departureTime = draft.departureTime {
                            Text("→")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(DateFormatter.dateTimeFormatter.string(from: departureTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let duration = draft.duration {
                            let hours = Int(duration) / 3600
                            let minutes = (Int(duration) % 3600) / 60
                            let durationString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
                            
                            Text(durationString)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Post Content View
    
    private var postContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Post Content")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Title")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Enter a title for your post", text: $draft.title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Description")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextEditor(text: $draft.content)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            // Rating
            VStack(alignment: .leading, spacing: 8) {
                Text("Rating")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: {
                            draft.rating = Double(star)
                        }) {
                            Image(systemName: (draft.rating ?? 0) >= Double(star) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    if draft.rating != nil {
                        Button("Clear") {
                            draft.rating = nil
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            // Reaction
            VStack(alignment: .leading, spacing: 8) {
                Text("Reaction")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    ForEach(Reaction.allCases, id: \.self) { reaction in
                        Button(action: {
                            draft.reaction = reaction
                        }) {
                            Text(reaction.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(draft.reaction == reaction ? Color.blue : Color(.systemGray5))
                                .foregroundColor(draft.reaction == reaction ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                    
                    if draft.reaction != nil {
                        Button("Clear") {
                            draft.reaction = nil
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Sharing Settings View
    
    private var sharingSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sharing")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(PostDraftSharingType.allCases, id: \.self) { sharingType in
                    Button(action: {
                        draft.sharingType = sharingType
                    }) {
                        HStack {
                            Image(systemName: sharingType.icon)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sharingType.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Text(sharingDescription(for: sharingType))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if draft.sharingType == sharingType {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(draft.sharingType == sharingType ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Action Buttons View
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            if !draft.isPublished {
                Button(action: {
                    showingPublishAlert = true
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Publish Post")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
            
            Button(action: {
                showingDeleteAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Draft")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(12)
            }
            .disabled(isLoading)
        }
    }
    
    // MARK: - Helper Methods
    
    private func sharingDescription(for sharingType: PostDraftSharingType) -> String {
        switch sharingType {
        case .justMe:
            return "Only you can see this post"
        case .closeFriends:
            return "Only your close friends can see this post"
        case .mutuals:
            return "Only people you follow who follow you back can see this post"
        case .publicPost:
            return "Anyone can see this post"
        }
    }
    
    private func saveChanges() {
        isLoading = true
        
        Task {
            do {
                try await timelineManager.updateDraft(draft)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Handle error
                    print("Error saving draft: \(error)")
                }
            }
        }
    }
    
    private func publishDraft() {
        isLoading = true
        
        Task {
            do {
                try await timelineManager.publishDraft(draft)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Handle error
                    print("Error publishing draft: \(error)")
                }
            }
        }
    }
    
    private func deleteDraft() {
        isLoading = true
        
        Task {
            do {
                try await timelineManager.deleteDraft(draft)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    // Handle error
                    print("Error deleting draft: \(error)")
                }
            }
        }
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    PostDraftsView()
}