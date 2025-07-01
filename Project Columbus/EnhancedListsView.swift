import SwiftUI

// MARK: - Enhanced Create List View
struct CreateListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    
    @State private var listName = ""
    @State private var listDescription = ""
    @State private var selectedSharingType: ListSharingType = .privateList
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var isTemplate = false
    @State private var templateCategory = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Information Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Information")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("List Name")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Enter list name", text: $listName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description (Optional)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            TextField("Describe your list", text: $listDescription, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                    }
                    
                    // Sharing Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy Settings")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(ListSharingType.allCases, id: \.self) { sharingType in
                            CreateListSharingRow(
                                sharingType: sharingType,
                                isSelected: selectedSharingType == sharingType
                            ) {
                                selectedSharingType = sharingType
                            }
                        }
                    }
                    
                    // Tags Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tags")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if !tags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    TagChip(tag: tag) {
                                        tags.removeAll { $0 == tag }
                                    }
                                }
                            }
                        }
                        
                        HStack {
                            TextField("Add tag", text: $newTag)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    addTag()
                                }
                            
                            Button("Add") {
                                addTag()
                            }
                            .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    
                    // Template Settings Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Template Settings")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Toggle("Make this a template", isOn: $isTemplate)
                        
                        if isTemplate {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Template Category")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                TextField("e.g., Travel, Food, Shopping", text: $templateCategory)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Create List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(listName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                }
            }
        }
    }
    
    private func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func createList() {
        isCreating = true
        
        // Create the list with enhanced properties
        let trimmedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
        // let trimmedDescription = listDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // For now, use the existing createCustomList method
        // TODO: Enhance this to support the new properties when backend is updated
        pinStore.createCustomList(name: trimmedName)
        
        // Close the sheet
        dismiss()
    }
}

// Supporting Views for CreateListView
struct CreateListSharingRow: View {
    let sharingType: ListSharingType
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(sharingType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(sharingTypeDescription(sharingType))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: sharingType.icon)
                    .foregroundColor(.gray)
                    .font(.title3)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func sharingTypeDescription(_ type: ListSharingType) -> String {
        switch type {
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
}

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(8)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
}

struct FlowResult {
    let size: CGSize
    let frames: [CGRect]
    
    init(in maxWidth: CGFloat, subviews: LayoutSubviews, spacing: CGFloat) {
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        self.frames = frames
        self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
    }
}

struct ListTemplatesView: View {
    var body: some View {
        Text("List Templates View - Coming Soon")
            .navigationTitle("Templates")
    }
}

struct SharedListsView: View {
    var body: some View {
        Text("Shared Lists View - Coming Soon")
            .navigationTitle("Shared Lists")
    }
}

struct ImportExportView: View {
    var body: some View {
        Text("Import/Export View - Coming Soon")
            .navigationTitle("Import/Export")
    }
}

// ShareListView is now replaced by ListSharingView in ListSharingView.swift

struct ListSettingsView: View {
    let list: PinList
    var body: some View {
        Text("List Settings View - Coming Soon")
            .navigationTitle("Settings")
    }
}

struct EnhancedListsView: View {
    @EnvironmentObject var pinStore: PinStore
    @EnvironmentObject var authManager: AuthManager
    @State private var showingCreateList = false
    @State private var showingTemplates = false
    @State private var showingSharedLists = false
    @State private var showingImportExport = false
    @State private var selectedList: PinList?
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with action buttons
                headerView
                
                // Search bar
                searchBar
                
                // Lists content
                listsContent
            }
            .navigationTitle("My Lists")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCreateList) {
                CreateListView()
                    .environmentObject(pinStore)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingTemplates) {
                ListTemplatesView()
                    .environmentObject(pinStore)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingSharedLists) {
                SharedListsView()
                    .environmentObject(pinStore)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingImportExport) {
                ImportExportView()
                    .environmentObject(pinStore)
                    .environmentObject(authManager)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text("My Lists")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                
                // Profile button
                Button(action: {}) {
                    AsyncImage(url: URL(string: authManager.currentUser?.avatarURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                }
            }
            
            // Action buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ActionButton(
                        icon: "plus.circle.fill",
                        title: "Create List",
                        color: .blue
                    ) {
                        showingCreateList = true
                    }
                    
                    ActionButton(
                        icon: "square.grid.2x2",
                        title: "Templates",
                        color: .purple
                    ) {
                        showingTemplates = true
                    }
                    
                    ActionButton(
                        icon: "person.2.circle",
                        title: "Shared",
                        color: .green
                    ) {
                        showingSharedLists = true
                    }
                    
                    ActionButton(
                        icon: "arrow.up.arrow.down.circle",
                        title: "Import/Export",
                        color: .orange
                    ) {
                        showingImportExport = true
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search lists...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .foregroundColor(.blue)
                .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private var listsContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredLists) { list in
                    EnhancedListCard(list: list) {
                        selectedList = list
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var filteredLists: [PinList] {
        if searchText.isEmpty {
            return pinStore.lists
        } else {
            return pinStore.lists.filter { list in
                list.name.localizedCaseInsensitiveContains(searchText) ||
                list.description?.localizedCaseInsensitiveContains(searchText) == true ||
                list.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(width: 80, height: 60)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
}

struct EnhancedListCard: View {
    let list: PinList
    let onTap: () -> Void
    @State private var showingShareSheet = false
    @State private var showingListSettings = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with name and sharing status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(list.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if let description = list.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        // Sharing status
                        HStack(spacing: 4) {
                            Image(systemName: list.sharingType.icon)
                                .font(.caption)
                            Text(list.displaySharingStatus)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(list.sharingType == .privateList ? .gray : .blue)
                        
                        // Pin count
                        Text("\(list.pins.count) pins")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Tags
                if !list.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(list.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    if list.canBeShared {
                        Button(action: { showingShareSheet = true }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: { showingListSettings = true }) {
                        Label("Settings", systemImage: "gear")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Last activity
                    Text(timeAgoString(from: list.lastActivityAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingShareSheet) {
            ListSharingView(list: list)
        }
        .sheet(isPresented: $showingListSettings) {
            ListSettingsView(list: list)
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    EnhancedListsView()
        .environmentObject(PinStore())
        .environmentObject(AuthManager())
} 