//
//  ProjectBrowserView.swift
//  Hamoniq Sync
//
//  Created by Claude on 21/09/2025.
//

import SwiftUI

struct ProjectBrowserView: View {
    @EnvironmentObject private var projectService: ProjectService
    @EnvironmentObject private var appViewModel: AppViewModel
    
    @State private var selectedProjects: Set<UUID> = []
    @State private var showingProjectDetail = false
    @State private var selectedProject: Project?
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode: CaseIterable {
        case list, grid
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            if projectService.currentState.projects.isEmpty {
                emptyStateSection
            } else {
                projectListSection
            }
        }
        .sheet(isPresented: $showingProjectDetail) {
            if let project = selectedProject {
                ProjectDetailView(project: project)
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text("Projects")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            HStack(spacing: 12) {
                // View mode toggle
                Picker("View Mode", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
                
                Button("New Project") {
                    appViewModel.showNewProjectSheet()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyStateSection: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                title: "No Projects Yet",
                subtitle: "Create your first project to get started with Harmoniq Sync",
                systemImage: "folder.badge.plus"
            ),
            primaryAction: { appViewModel.showNewProjectSheet() }
        )
    }
    
    @ViewBuilder
    private var projectListSection: some View {
        SearchableListView(
            items: projectService.currentState.projects,
            configuration: SearchListConfiguration(
                showFilterButton: true,
                showSortButton: true,
                allowsMultipleSelection: true,
                searchPlaceholder: "Search projects..."
            ),
            onItemSelected: { project in
                selectedProject = project
                showingProjectDetail = true
            },
            onItemsSelected: { projects in
                selectedProjects = Set(projects.map(\.id))
            }
        ) { project in
            if viewMode == .list {
                ProjectListRowView(project: project)
            } else {
                ProjectGridItemView(project: project)
            }
        }
    }
}

// MARK: - Project Row Views

struct ProjectListRowView: View {
    let project: Project
    
    var body: some View {
        HStack(spacing: 16) {
            // Project icon and color indicator
            RoundedRectangle(cornerRadius: 8)
                .fill(colorForProject(project))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: iconForProjectType(project.projectType))
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .medium))
                }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if project.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    if project.isArchived {
                        Text("Archived")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(project.projectType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if project.hasMedia {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(project.totalClips) clips")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !project.tags.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(project.tags.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !project.projectDescription.isEmpty {
                    Text(project.projectDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(project.modifiedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let lastOpened = project.lastOpenedAt {
                    Text("Opened \(lastOpened, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Never opened")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
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
}

struct ProjectGridItemView: View {
    let project: Project
    
    var body: some View {
        VStack(spacing: 12) {
            // Large project icon
            RoundedRectangle(cornerRadius: 12)
                .fill(colorForProject(project))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: iconForProjectType(project.projectType))
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .medium))
                }
            
            VStack(spacing: 4) {
                HStack {
                    Text(project.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if project.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Text(project.projectType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if project.hasMedia {
                    Text("\(project.totalClips) clips")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(project.modifiedAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 120, height: 140)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
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
}


#Preview {
    let mockService = ProjectService(dataController: DataController.shared)
    
    ProjectBrowserView()
        .environmentObject(mockService)
        .environmentObject(AppViewModel(dataController: DataController.shared))
        .frame(width: 800, height: 600)
}