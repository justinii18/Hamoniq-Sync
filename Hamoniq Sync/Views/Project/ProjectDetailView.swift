//
//  ProjectDetailView.swift
//  Hamoniq Sync
//
//  Created by Claude on 21/09/2025.
//

import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject private var projectService: ProjectService
    @EnvironmentObject private var mediaService: MediaService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: DetailTab = .overview
    @State private var isEditing = false
    @State private var editedProject: ProjectEditModel
    @State private var showingDeleteConfirmation = false
    @State private var showingArchiveConfirmation = false
    @State private var showingSaveChanges = false
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case media = "Media"
        case sync = "Sync"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .overview: return "doc.text"
            case .media: return "photo.stack"
            case .sync: return "arrow.triangle.2.circlepath"
            case .settings: return "gearshape"
            }
        }
    }
    
    init(project: Project) {
        self.project = project
        self._editedProject = State(initialValue: ProjectEditModel(from: project))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                
                tabNavigationSection
                
                Divider()
                
                contentSection
            }
            .navigationTitle(project.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showingSaveChanges = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        HStack {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Save") {
                                saveChanges()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!hasValidChanges)
                        }
                    } else {
                        Button("Edit") {
                            startEditing()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .alert("Save Changes?", isPresented: $showingSaveChanges) {
            Button("Don't Save", role: .destructive) {
                dismiss()
            }
            Button("Save") {
                saveChanges()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes. Do you want to save them before closing?")
        }
        .alert("Delete Project", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteProject()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. All project data will be permanently deleted.")
        }
        .alert("Archive Project", isPresented: $showingArchiveConfirmation) {
            Button("Archive") {
                archiveProject()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will archive the project. You can unarchive it later from the archived projects view.")
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Project icon/color
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorForProject(project))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: iconForProjectType(project.projectType))
                            .foregroundColor(.white)
                            .font(.system(size: 24, weight: .medium))
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if isEditing {
                            TextField("Project Name", text: $editedProject.name)
                                .textFieldStyle(.roundedBorder)
                                .font(.title2)
                                .fontWeight(.bold)
                        } else {
                            Text(project.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        if project.isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                        }
                        
                        if project.isArchived {
                            Text("Archived")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.secondary)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                    
                    Text(project.projectType.displayName)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    if isEditing {
                        TextField("Description", text: $editedProject.description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    } else if !project.projectDescription.isEmpty {
                        Text(project.projectDescription)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Quick stats
                VStack(alignment: .trailing, spacing: 8) {
                    ProjectStatView(
                        title: "Media Files",
                        value: "\(project.totalClips)",
                        icon: "doc.fill"
                    )
                    
                    ProjectStatView(
                        title: "Duration",
                        value: formatDuration(project.totalDuration),
                        icon: "clock.fill"
                    )
                    
                    ProjectStatView(
                        title: "Last Modified",
                        value: project.modifiedAt.formatted(.relative(presentation: .named)),
                        icon: "calendar"
                    )
                }
            }
            
            // Project tags
            if isEditing {
                TagEditView(tags: $editedProject.tags)
            } else if !project.tags.isEmpty {
                TagDisplayView(tags: project.tags)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var tabNavigationSection: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        
                        Text(tab.rawValue)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .blue : .primary)
                    .overlay {
                        Rectangle()
                            .fill(selectedTab == tab ? Color.blue : Color.clear)
                            .frame(height: 2)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private var contentSection: some View {
        ScrollView {
            switch selectedTab {
            case .overview:
                OverviewTabView(project: project, isEditing: isEditing, editedProject: $editedProject)
            case .media:
                MediaTabView(project: project)
            case .sync:
                SyncTabView(project: project, isEditing: isEditing, editedProject: $editedProject)
            case .settings:
                SettingsTabView(
                    project: project,
                    isEditing: isEditing,
                    editedProject: $editedProject,
                    onDelete: { showingDeleteConfirmation = true },
                    onArchive: { showingArchiveConfirmation = true }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var hasUnsavedChanges: Bool {
        editedProject != ProjectEditModel(from: project)
    }
    
    private var hasValidChanges: Bool {
        !editedProject.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func startEditing() {
        editedProject = ProjectEditModel(from: project)
        isEditing = true
    }
    
    private func cancelEditing() {
        editedProject = ProjectEditModel(from: project)
        isEditing = false
    }
    
    private func saveChanges() {
        Task {
            await performSave()
        }
    }
    
    @MainActor
    private func performSave() async {
        // Apply changes to project
        project.name = editedProject.name.trimmingCharacters(in: .whitespacesAndNewlines)
        project.projectDescription = editedProject.description
        project.tags = editedProject.tags
        project.colorLabel = editedProject.colorLabel
        project.syncStrategy = editedProject.syncStrategy
        project.updateModificationDate()
        
        do {
            let _ = try await projectService.update(project)
            isEditing = false
        } catch {
            // Handle error - could show an alert
            print("Failed to save project: \(error)")
        }
    }
    
    private func deleteProject() {
        Task {
            await performDelete()
        }
    }
    
    @MainActor
    private func performDelete() async {
        do {
            try await projectService.delete(project.id)
            dismiss()
        } catch {
            print("Failed to delete project: \(error)")
        }
    }
    
    private func archiveProject() {
        Task {
            await performArchive()
        }
    }
    
    @MainActor
    private func performArchive() async {
        project.archive()
        
        do {
            let _ = try await projectService.update(project)
        } catch {
            print("Failed to archive project: \(error)")
        }
    }
    
    private func colorForProject(_ project: Project) -> Color {
        switch project.colorLabel {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .blue
        }
    }
    
    private func iconForProjectType(_ type: ProjectType) -> String {
        switch type {
        case .singleCam: return "video"
        case .multiCam: return "video.stack"
        case .musicVideo: return "music.note"
        case .documentary: return "film"
        case .podcast: return "mic"
        case .wedding: return "heart"
        case .commercial: return "megaphone"
        case .custom: return "gear"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Supporting Views

struct ProjectStatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TagDisplayView: View {
    let tags: [String]
    
    var body: some View {
        HStack {
            Text("Tags:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 6) {
                ForEach(tags.prefix(5), id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
                
                if tags.count > 5 {
                    Text("+\(tags.count - 5)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

struct TagEditView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 6) {
                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(.caption)
                        
                        Button {
                            tags.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                
                // Add new tag field
                HStack(spacing: 4) {
                    TextField("Add tag", text: $newTag)
                        .textFieldStyle(.plain)
                        .font(.caption)
                        .frame(minWidth: 60)
                        .onSubmit {
                            addTag()
                        }
                    
                    if !newTag.isEmpty {
                        Button {
                            addTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.1))
                .cornerRadius(6)
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
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRowWidth + size.width + spacing > width && currentRowWidth > 0 {
                height += currentRowHeight + spacing
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth += size.width + (currentRowWidth > 0 ? spacing : 0)
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        
        height += currentRowHeight
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var currentRowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentY += currentRowHeight + spacing
                currentX = bounds.minX
                currentRowHeight = 0
            }
            
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

// MARK: - Tab Content Views

struct OverviewTabView: View {
    let project: Project
    let isEditing: Bool
    @Binding var editedProject: ProjectEditModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Project progress section
            ProgressSectionView(project: project)
            
            // Media groups overview
            MediaGroupsOverviewView(project: project)
            
            // Recent activity
            RecentActivityView(project: project)
            
            // Quick actions
            if !isEditing {
                QuickActionsView(project: project)
            }
        }
        .padding()
    }
}

struct MediaTabView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Media Management")
                .font(.headline)
            
            if project.mediaGroups.isEmpty {
                EmptyStateView(
                    configuration: EmptyStateConfiguration(
                        title: "No Media Groups",
                        subtitle: "Import media files to start organizing your project",
                        systemImage: "photo.stack"
                    )
                )
                .frame(height: 200)
            } else {
                ForEach(project.mediaGroups) { group in
                    MediaGroupCardView(group: group)
                }
            }
        }
        .padding()
    }
}

struct SyncTabView: View {
    let project: Project
    let isEditing: Bool
    @Binding var editedProject: ProjectEditModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Synchronization Settings")
                .font(.headline)
            
            // Sync strategy
            VStack(alignment: .leading, spacing: 12) {
                Text("Sync Strategy")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isEditing {
                    Picker("Sync Strategy", selection: $editedProject.syncStrategy) {
                        ForEach(SyncStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    Text(project.syncStrategy.displayName)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sync jobs overview
            SyncJobsOverviewView(project: project)
            
            // Sync results
            if !project.completedSyncJobs.isEmpty {
                SyncResultsOverviewView(project: project)
            }
        }
        .padding()
    }
}

struct SettingsTabView: View {
    let project: Project
    let isEditing: Bool
    @Binding var editedProject: ProjectEditModel
    let onDelete: () -> Void
    let onArchive: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Project Settings")
                .font(.headline)
            
            // Color label
            VStack(alignment: .leading, spacing: 12) {
                Text("Color Label")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isEditing {
                    ColorPickerView(selectedColor: $editedProject.colorLabel)
                } else {
                    HStack {
                        Circle()
                            .fill(colorForLabel(project.colorLabel))
                            .frame(width: 20, height: 20)
                        
                        Text(project.colorLabel.capitalized)
                            .font(.body)
                    }
                }
            }
            
            Divider()
            
            // Project actions
            VStack(alignment: .leading, spacing: 16) {
                Text("Project Actions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(spacing: 12) {
                    if !project.isArchived {
                        Button("Archive Project") {
                            onArchive()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button("Delete Project") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
    }
    
    private func colorForLabel(_ label: String) -> Color {
        switch label {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .blue
        }
    }
}

// MARK: - Component Views (Placeholders for detailed implementation)

struct ProgressSectionView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Project Progress")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 24) {
                ProgressItemView(
                    title: "Media Import",
                    progress: project.hasMedia ? 1.0 : 0.0,
                    isComplete: project.hasMedia
                )
                
                ProgressItemView(
                    title: "Synchronization",
                    progress: project.canSync ? (project.completedSyncJobs.isEmpty ? 0.0 : 0.5) : 0.0,
                    isComplete: !project.completedSyncJobs.isEmpty
                )
                
                ProgressItemView(
                    title: "Export Ready",
                    progress: !project.exportConfigurations.isEmpty ? 1.0 : 0.0,
                    isComplete: !project.exportConfigurations.isEmpty
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ProgressItemView: View {
    let title: String
    let progress: Double
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: isComplete ? .green : .blue))
        }
    }
}

struct MediaGroupsOverviewView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Media Groups (\(project.mediaGroups.count))")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if project.mediaGroups.isEmpty {
                Text("No media groups yet")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(project.mediaGroups.prefix(3)) { group in
                        MediaGroupRowView(group: group)
                    }
                    
                    if project.mediaGroups.count > 3 {
                        Text("and \(project.mediaGroups.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct MediaGroupRowView: View {
    let group: MediaGroup
    
    var body: some View {
        HStack {
            Circle()
                .fill(.blue)
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("\(group.clipCount) clips")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct MediaGroupCardView: View {
    let group: MediaGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(group.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text("\(group.clipCount) clips")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !group.clips.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(group.clips.prefix(6)) { clip in
                        ClipThumbnailView(clip: clip)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ClipThumbnailView: View {
    let clip: Clip
    
    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.gray.opacity(0.3))
                .frame(height: 60)
                .overlay {
                    Image(systemName: clip.mediaType == .video ? "video.fill" : "waveform")
                        .foregroundColor(.white)
                }
            
            Text(clip.displayName)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct RecentActivityView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 8) {
                ActivityItemView(
                    title: "Project created",
                    date: project.createdAt,
                    icon: "plus.circle.fill"
                )
                
                if let lastOpened = project.lastOpenedAt {
                    ActivityItemView(
                        title: "Last opened",
                        date: lastOpened,
                        icon: "eye.fill"
                    )
                }
                
                ActivityItemView(
                    title: "Last modified",
                    date: project.modifiedAt,
                    icon: "pencil.circle.fill"
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ActivityItemView: View {
    let title: String
    let date: Date
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
            
            Spacer()
            
            Text(date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct QuickActionsView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Import Media",
                    icon: "square.and.arrow.down",
                    action: { }
                )
                
                QuickActionButton(
                    title: "Start Sync",
                    icon: "arrow.triangle.2.circlepath",
                    action: { },
                    isEnabled: project.canSync
                )
                
                QuickActionButton(
                    title: "Export Project",
                    icon: "square.and.arrow.up",
                    action: { },
                    isEnabled: !project.completedSyncJobs.isEmpty
                )
                
                QuickActionButton(
                    title: "Duplicate",
                    icon: "doc.on.doc",
                    action: { }
                )
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    let isEnabled: Bool
    
    init(title: String, icon: String, action: @escaping () -> Void, isEnabled: Bool = true) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isEnabled = isEnabled
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? .blue : .secondary)
                
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                
                Spacer()
            }
            .padding()
            .background(isEnabled ? Color(.controlBackgroundColor) : Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separatorColor), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct SyncJobsOverviewView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Jobs (\(project.syncJobs.count))")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if project.syncJobs.isEmpty {
                Text("No sync jobs yet")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(project.syncJobs.prefix(3)) { job in
                        SyncJobRowView(job: job)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct SyncJobRowView: View {
    let job: SyncJob
    
    var body: some View {
        HStack {
            Circle()
                .fill(job.isCompleted ? .green : .orange)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync Job")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(job.isCompleted ? "Completed" : "In Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if job.isCompleted {
                Text("✓")
                    .foregroundColor(.green)
                    .fontWeight(.bold)
            }
        }
    }
}

struct SyncResultsOverviewView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Results")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                Text("Average Confidence:")
                    .font(.body)
                
                Spacer()
                
                Text("\(Int(project.averageSyncConfidence * 100))%")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(project.averageSyncConfidence > 0.8 ? .green : (project.averageSyncConfidence > 0.6 ? .orange : .red))
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ColorPickerView: View {
    @Binding var selectedColor: String
    
    private let colors = [
        ("red", Color.red),
        ("orange", Color.orange),
        ("yellow", Color.yellow),
        ("green", Color.green),
        ("blue", Color.blue),
        ("purple", Color.purple),
        ("pink", Color.pink)
    ]
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(colors, id: \.0) { colorName, color in
                Button {
                    selectedColor = colorName
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selectedColor == colorName {
                                Circle()
                                    .stroke(.white, lineWidth: 3)
                                Circle()
                                    .stroke(.primary, lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Data Model

struct ProjectEditModel: Equatable {
    var name: String
    var description: String
    var tags: [String]
    var colorLabel: String
    var syncStrategy: SyncStrategy
    
    init(from project: Project) {
        self.name = project.name
        self.description = project.projectDescription
        self.tags = project.tags
        self.colorLabel = project.colorLabel
        self.syncStrategy = project.syncStrategy
    }
}

// MARK: - Extensions


#Preview {
    let mockProject = Project(name: "Sample Project", type: .multiCam)
    mockProject.projectDescription = "A sample multi-camera project for preview"
    mockProject.tags = ["wedding", "multicam", "outdoor"]
    mockProject.isFavorite = true
    
    return ProjectDetailView(project: mockProject)
        .environmentObject(ProjectService(dataController: DataController.shared))
        .environmentObject(MediaService(dataController: DataController.shared))
        .frame(width: 900, height: 700)
}