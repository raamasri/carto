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
        // TODO: Implement save changes to update list sharing settings
        print("💾 Saving sharing changes for list: \(list.name)")
        print("📤 New sharing type: \(selectedSharingType.displayName)")
        dismiss()
    }
    
    private func sendInvite() {
        // TODO: Implement send invite functionality
        print("📧 Sending invite to: \(inviteEmail) with permission: \(invitePermission.displayName)")
        showingInviteForm = false
        inviteEmail = ""
    }
    
    private func generateShareLink() {
        // TODO: Generate actual share link
        shareURL = URL(string: "https://app.projectcolumbus.com/list/\(list.id)")
        showingShareSheet = true
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
                // TODO: Implement remove collaborator
                print("🗑️ Removing collaborator: \(userId)")
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