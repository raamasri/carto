import SwiftUI

struct ListSharingView: View {
    let list: PinList
    @State private var selectedSharingType: ListSharingType
    @State private var inviteEmail = ""
    @State private var invitePermission: PermissionType = .view
    @State private var showingInviteForm = false
    @State private var showingShareSheet = false
    @State private var shareURL: URL?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var pinStore: PinStore
    
    init(list: PinList) {
        self.list = list
        self._selectedSharingType = State(initialValue: list.sharingType)
    }
    
    enum PermissionType: String, CaseIterable {
        case view = "view"
        case edit = "edit"
        
        var displayName: String {
            switch self {
            case .view: return "Can View"
            case .edit: return "Can Edit"
            }
        }
        
        var icon: String {
            switch self {
            case .view: return "eye"
            case .edit: return "pencil"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // List Header
                    listHeaderSection
                    
                    // Sharing Options
                    sharingOptionsSection
                    
                    // Invite Section (only for collaborative lists)
                    if selectedSharingType.allowsCollaboration {
                        inviteSection
                    }
                    
                    // Current Collaborators
                    if !list.collaborators.isEmpty || !list.viewers.isEmpty {
                        collaboratorsSection
                    }
                    
                    // Share Link Section
                    if selectedSharingType != .privateList {
                        shareLinkSection
                    }
                    
                    // Statistics Section
                    statisticsSection
                }
                .padding()
            }
            .navigationTitle("Share List")
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
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingInviteForm) {
                inviteFormSheet
            }
            .sheet(isPresented: $showingShareSheet) {
                if let shareURL = shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
        }
    }
    
    // MARK: - List Header Section
    private var listHeaderSection: some View {
        VStack(spacing: 12) {
            // List icon and name
            HStack {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(list.pins.count) pins")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Current sharing status
                Label(selectedSharingType.displayName, systemImage: selectedSharingType.icon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
            }
            
            if let description = list.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Sharing Options Section
    private var sharingOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sharing Options")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(ListSharingType.allCases, id: \.self) { sharingType in
                    SharingOptionRow(
                        sharingType: sharingType,
                        isSelected: selectedSharingType == sharingType,
                        onSelect: {
                            selectedSharingType = sharingType
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Invite Section
    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Invite People")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Invite") {
                    showingInviteForm = true
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            }
            
            if !list.pendingInvites.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pending Invites")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(list.pendingInvites, id: \.self) { email in
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.orange)
                            
                            Text(email)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("Pending")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Collaborators Section
    private var collaboratorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("People with Access")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Collaborators (can edit)
                ForEach(list.collaborators, id: \.self) { userId in
                    CollaboratorRow(userId: userId, permission: .edit)
                }
                
                // Viewers (can view only)
                ForEach(list.viewers, id: \.self) { userId in
                    CollaboratorRow(userId: userId, permission: .view)
                }
            }
        }
    }
    
    // MARK: - Share Link Section
    private var shareLinkSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share Link")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Anyone with the link")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(selectedSharingType == .publicReadOnly ? "Can view" : "Can edit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Share") {
                        generateShareLink()
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                StatisticItem(
                    icon: "eye",
                    value: "\(list.totalViews)",
                    label: "Views"
                )
                
                StatisticItem(
                    icon: "square.and.arrow.up",
                    value: "\(list.totalShares)",
                    label: "Shares"
                )
                
                if list.isTemplate {
                    StatisticItem(
                        icon: "doc.on.doc",
                        value: "\(list.totalForks)",
                        label: "Uses"
                    )
                }
            }
        }
    }
    
    // MARK: - Invite Form Sheet
    private var inviteFormSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Invite Someone")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email Address")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextField("Enter email address", text: $inviteEmail)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permission")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Permission", selection: $invitePermission) {
                            ForEach(PermissionType.allCases, id: \.self) { permission in
                                Label(permission.displayName, systemImage: permission.icon)
                                    .tag(permission)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Invite to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingInviteForm = false
                        inviteEmail = ""
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send Invite") {
                        sendInvite()
                    }
                    .fontWeight(.semibold)
                    .disabled(inviteEmail.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func saveChanges() {
        print("💾 Saving sharing changes for list: \(list.name)")
        print("📤 New sharing type: \(selectedSharingType.displayName)")
        
        Task {
            do {
                // Update the list sharing settings in the database
                let success = await updateListSharingSettings()
                
                await MainActor.run {
                    if success {
                        // Update local list object
                        list.sharingType = selectedSharingType
                        print("✅ List sharing settings updated successfully")
                    } else {
                        print("❌ Failed to update list sharing settings")
                        // Show error alert
                        showingError = true
                        errorMessage = "Failed to update sharing settings. Please try again."
                    }
                    dismiss()
                }
            }
        }
    }
    
    private func sendInvite() {
        print("📧 Sending invite to: \(inviteEmail) with permission: \(invitePermission.displayName)")
        
        Task {
            do {
                let success = await sendListInvitation(email: inviteEmail, permission: invitePermission)
                
                await MainActor.run {
                    if success {
                        print("✅ Invitation sent successfully")
                        showingInviteForm = false
                        inviteEmail = ""
                        
                        // Show success message
                        showingError = true
                        errorMessage = "Invitation sent to \(inviteEmail) successfully!"
                    } else {
                        print("❌ Failed to send invitation")
                        showingError = true
                        errorMessage = "Failed to send invitation. Please check the email address and try again."
                    }
                }
            }
        }
    }
    
    private func generateShareLink() {
        print("🔗 Generating share link for list: \(list.name)")
        
        Task {
            do {
                if let generatedURL = await createShareableLink() {
                    await MainActor.run {
                        shareURL = generatedURL
                        showingShareSheet = true
                        print("✅ Share link generated: \(generatedURL)")
                    }
                } else {
                    await MainActor.run {
                        showingError = true
                        errorMessage = "Failed to generate share link. Please try again."
                    }
                }
            }
        }
    }
    
    // MARK: - Backend Integration
    
    private func updateListSharingSettings() async -> Bool {
        do {
            // In a real implementation, this would update the database
            // For now, simulate the API call
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            // Simulate success/failure
            let success = Bool.random() ? true : true // Always succeed for demo
            return success
        } catch {
            print("❌ Error updating list sharing settings: \(error)")
            return false
        }
    }
    
    private func sendListInvitation(email: String, permission: PermissionType) async -> Bool {
        do {
            // Validate email format
            guard email.contains("@") && email.contains(".") else {
                return false
            }
            
            // In a real implementation, this would:
            // 1. Create an invitation record in the database
            // 2. Send an email invitation
            // 3. Generate a unique invitation link
            
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
            
            print("📨 Would send invitation email to: \(email)")
            print("🔑 Permission level: \(permission.displayName)")
            print("📋 List: \(list.name)")
            
            return true
        } catch {
            print("❌ Error sending invitation: \(error)")
            return false
        }
    }
    
    private func createShareableLink() async -> URL? {
        do {
            // In a real implementation, this would:
            // 1. Create a shareable token in the database
            // 2. Generate a unique URL with the token
            // 3. Set expiration date if needed
            
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            
            let shareToken = UUID().uuidString
            let shareURL = URL(string: "https://app.projectcolumbus.com/shared/list/\(list.id)?token=\(shareToken)")
            
            print("🔗 Generated shareable link with token: \(shareToken)")
            return shareURL
        } catch {
            print("❌ Error creating shareable link: \(error)")
                         return nil
         }
     }
     
     private func removeCollaborator(_ userId: UUID) {
         print("🗑️ Removing collaborator: \(userId)")
         
         Task {
             let success = await removeCollaboratorFromList(userId: userId)
             
             await MainActor.run {
                 if success {
                     // Remove from local collaborators list
                     list.collaborators.removeAll { $0 == userId }
                     list.viewers.removeAll { $0 == userId }
                     print("✅ Collaborator removed successfully")
                 } else {
                     showingError = true
                     errorMessage = "Failed to remove collaborator. Please try again."
                 }
             }
         }
     }
     
     private func removeCollaboratorFromList(userId: UUID) async -> Bool {
         do {
             // In a real implementation, this would:
             // 1. Remove the user from the list_collaborators table
             // 2. Send a notification to the user
             // 3. Update any related permissions
             
             try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
             
             print("🗑️ Would remove collaborator \(userId) from database")
             return true
         } catch {
             print("❌ Error removing collaborator: \(error)")
             return false
         }
     }
 }

// MARK: - Supporting Views

struct SharingOptionRow: View {
    let sharingType: ListSharingType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: sharingType.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(sharingType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(sharingType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? .blue.opacity(0.1) : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? .blue : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CollaboratorRow: View {
    let userId: UUID
    let permission: ListSharingView.PermissionType
    
    var body: some View {
        HStack {
            // Placeholder avatar
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person")
                        .foregroundColor(.secondary)
                        .font(.caption)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("User \(userId.uuidString.prefix(8))") // Placeholder name
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(permission.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Remove") {
                removeCollaborator(userId)
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

struct StatisticItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Extensions

extension ListSharingType {
    var description: String {
        switch self {
        case .privateList:
            return "Only you can see this list"
        case .publicReadOnly:
            return "Anyone can view but not edit"
        case .publicEditable:
            return "Anyone can view and add pins"
        case .friendsOnly:
            return "Only your friends can access"
        case .specificUsers:
            return "Only invited people can access"
        }
    }
    
    var allowsCollaboration: Bool {
        switch self {
        case .privateList:
            return false
        case .publicReadOnly:
            return false
        case .publicEditable:
            return true
        case .friendsOnly:
            return true
        case .specificUsers:
            return true
        }
    }
}

#Preview {
    ListSharingView(list: PinList(
        name: "Favorite Coffee Shops",
        pins: [],
        ownerId: UUID(),
        description: "My go-to spots for great coffee around the city"
    ))
    .environmentObject(PinStore())
} 