//
//  ProjectService.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ProjectService: ObservableService<ProjectService.State>, DataServiceProtocol {
    
    // MARK: - State Definition
    
    struct State {
        var projects: [Project] = []
        var selectedProject: Project?
        var recentProjects: [Project] = []
        var favoriteProjects: [Project] = []
        var isLoading: Bool = false
        var lastUpdated: Date?
    }
    
    // MARK: - Type Aliases
    
    typealias DataType = Project
    typealias IDType = UUID
    
    // MARK: - Dependencies
    
    private let dataController: DataController
    
    // MARK: - State Access
    
    private var projectState: State {
        observableState
    }
    
    var currentState: State {
        observableState
    }
    
    // MARK: - Publishers
    
    private let projectUpdatedSubject = PassthroughSubject<Project, Never>()
    private let projectDeletedSubject = PassthroughSubject<UUID, Never>()
    
    var projectUpdatedPublisher: AnyPublisher<Project, Never> {
        projectUpdatedSubject.eraseToAnyPublisher()
    }
    
    var projectDeletedPublisher: AnyPublisher<UUID, Never> {
        projectDeletedSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(dataController: DataController) {
        self.dataController = dataController
        super.init(initialState: State())
    }
    
    // MARK: - Service Lifecycle
    
    override func performInitialization() async throws {
        try await loadAllProjects()
    }
    
    // MARK: - DataServiceProtocol Implementation
    
    func create(_ project: Project) async throws -> Project {
        try requireInitialized()
        
        updateState { state in
            state.isLoading = true
        }
        
        do {
            // Insert into data store
            dataController.mainContext.insert(project)
            dataController.save()
            
            // Update local state
            updateState { state in
                state.projects.append(project)
                state.projects.sort { $0.modifiedAt > $1.modifiedAt }
                state.lastUpdated = Date()
                state.isLoading = false
            }
            
            // Refresh related data
            await loadRecentProjects()
            
            // Notify observers
            projectUpdatedSubject.send(project)
            
            return project
            
        } catch {
            updateState { state in
                state.isLoading = false
            }
            throw error
        }
    }
    
    func read(_ id: UUID) async throws -> Project? {
        try requireInitialized()
        
        // Check local state first
        if let project = projectState.projects.first(where: { $0.id == id }) {
            return project
        }
        
        // Fetch from database
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { project in
                project.id == id
            }
        )
        
        let projects = dataController.fetch(descriptor)
        return projects.first
    }
    
    func update(_ project: Project) async throws -> Project {
        try requireInitialized()
        
        updateState { state in
            state.isLoading = true
        }
        
        do {
            // Update modification date
            project.updateModificationDate()
            
            // Save to data store
            dataController.save()
            
            // Update local state
            updateState { state in
                if let index = state.projects.firstIndex(where: { $0.id == project.id }) {
                    state.projects[index] = project
                    state.projects.sort { $0.modifiedAt > $1.modifiedAt }
                }
                state.lastUpdated = Date()
                state.isLoading = false
            }
            
            // Refresh related data
            await loadRecentProjects()
            if project.isFavorite {
                await loadFavoriteProjects()
            }
            
            // Notify observers
            projectUpdatedSubject.send(project)
            
            return project
            
        } catch {
            updateState { state in
                state.isLoading = false
            }
            throw error
        }
    }
    
    func delete(_ id: UUID) async throws {
        try requireInitialized()
        
        updateState { state in
            state.isLoading = true
        }
        
        do {
            guard let project = try await read(id) else {
                throw ProjectServiceError.projectNotFound(id)
            }
            
            // Remove from data store
            dataController.delete(project)
            dataController.save()
            
            // Update local state
            updateState { state in
                state.projects.removeAll { $0.id == id }
                if state.selectedProject?.id == id {
                    state.selectedProject = nil
                }
                state.lastUpdated = Date()
                state.isLoading = false
            }
            
            // Refresh related data
            await loadRecentProjects()
            await loadFavoriteProjects()
            
            // Notify observers
            projectDeletedSubject.send(id)
            
        } catch {
            updateState { state in
                state.isLoading = false
            }
            throw error
        }
    }
    
    func list() async throws -> [Project] {
        try requireInitialized()
        
        if projectState.projects.isEmpty || shouldRefreshData() {
            try await loadAllProjects()
        }
        
        return projectState.projects
    }
    
    // MARK: - Extended Operations
    
    func loadAllProjects() async throws {
        updateState { state in
            state.isLoading = true
        }
        
        do {
            let projects = dataController.loadAllProjects()
            
            updateState { state in
                state.projects = projects
                state.lastUpdated = Date()
                state.isLoading = false
            }
            
            // Load related data
            await loadRecentProjects()
            await loadFavoriteProjects()
            
        } catch {
            updateState { state in
                state.isLoading = false
            }
            throw error
        }
    }
    
    func loadRecentProjects(limit: Int = 10) async {
        let recentProjects = dataController.loadRecentProjects(limit: limit)
        
        updateState { state in
            state.recentProjects = recentProjects
        }
    }
    
    func loadFavoriteProjects() async {
        let favoriteProjects = dataController.loadFavoriteProjects()
        
        updateState { state in
            state.favoriteProjects = favoriteProjects
        }
    }
    
    func searchProjects(query: String) async throws -> [Project] {
        try requireInitialized()
        
        if query.isEmpty {
            return projectState.projects
        }
        
        let searchResults = dataController.searchProjects(query: query)
        return searchResults
    }
    
    func createProject(name: String, type: ProjectType) async throws -> Project {
        let project = Project(name: name, type: type)
        return try await create(project)
    }
    
    func duplicateProject(_ project: Project) async throws -> Project {
        let duplicatedProject = Project(name: "\(project.name) Copy", type: project.projectType)
        
        // Copy project properties
        duplicatedProject.projectDescription = project.projectDescription
        duplicatedProject.tags = project.tags
        duplicatedProject.syncStrategy = project.syncStrategy
        duplicatedProject.targetFrameRate = project.targetFrameRate
        
        // Copy project settings
        if let originalSettings = project.projectSettings {
            let newSettings = ProjectSettings()
            newSettings.syncStrategy = originalSettings.syncStrategy
            newSettings.confidenceThreshold = originalSettings.confidenceThreshold
            newSettings.enableDriftCorrection = originalSettings.enableDriftCorrection
            newSettings.preferredAlgorithms = originalSettings.preferredAlgorithms
            newSettings.groupingCriteria = originalSettings.groupingCriteria
            newSettings.colorCodingScheme = originalSettings.colorCodingScheme
            
            duplicatedProject.projectSettings = newSettings
        }
        
        return try await create(duplicatedProject)
    }
    
    func deleteProjects(_ projects: [Project]) async throws {
        updateState { state in
            state.isLoading = true
        }
        
        do {
            for project in projects {
                dataController.delete(project)
            }
            dataController.save()
            
            let deletedIDs = projects.map(\.id)
            
            updateState { state in
                state.projects.removeAll { project in
                    deletedIDs.contains(project.id)
                }
                
                if let selectedID = state.selectedProject?.id,
                   deletedIDs.contains(selectedID) {
                    state.selectedProject = nil
                }
                
                state.lastUpdated = Date()
                state.isLoading = false
            }
            
            // Refresh related data
            await loadRecentProjects()
            await loadFavoriteProjects()
            
            // Notify observers
            for id in deletedIDs {
                projectDeletedSubject.send(id)
            }
            
        } catch {
            updateState { state in
                state.isLoading = false
            }
            throw error
        }
    }
    
    func archiveProject(_ project: Project) async throws {
        project.archive()
        _ = try await update(project)
    }
    
    func unarchiveProject(_ project: Project) async throws {
        project.unarchive()
        _ = try await update(project)
    }
    
    func toggleProjectFavorite(_ project: Project) async throws {
        project.toggleFavorite()
        _ = try await update(project)
    }
    
    func addTagToProject(_ project: Project, tag: String) async throws {
        project.addTag(tag)
        _ = try await update(project)
    }
    
    func removeTagFromProject(_ project: Project, tag: String) async throws {
        project.removeTag(tag)
        _ = try await update(project)
    }
    
    func selectProject(_ project: Project?) {
        updateState { state in
            state.selectedProject = project
        }
        
        // Update last opened date if selecting a project
        if let project = project {
            project.updateLastOpenedDate()
            dataController.save()
            
            Task { [weak self] in
                await self?.loadRecentProjects()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func shouldRefreshData() -> Bool {
        guard let lastUpdated = projectState.lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > 300 // 5 minutes
    }
    
    func refreshIfNeeded() async throws {
        if shouldRefreshData() {
            try await loadAllProjects()
        }
    }
    
    // MARK: - Statistics
    
    func getProjectStatistics() -> ProjectStatistics {
        return ProjectStatistics(
            totalProjects: projectState.projects.count,
            archivedProjects: projectState.projects.filter { $0.isArchived }.count,
            favoriteProjects: projectState.favoriteProjects.count,
            projectsByType: Dictionary(grouping: projectState.projects, by: { $0.projectType })
                .mapValues { $0.count }
        )
    }
}

// MARK: - Supporting Types

struct ProjectStatistics {
    let totalProjects: Int
    let archivedProjects: Int
    let favoriteProjects: Int
    let projectsByType: [ProjectType: Int]
    
    var activeProjects: Int {
        totalProjects - archivedProjects
    }
}

enum ProjectServiceError: LocalizedError {
    case projectNotFound(UUID)
    case invalidProjectData
    case duplicateProjectName(String)
    
    var errorDescription: String? {
        switch self {
        case .projectNotFound(let id):
            return "Project with ID \(id) not found"
        case .invalidProjectData:
            return "Invalid project data provided"
        case .duplicateProjectName(let name):
            return "A project with the name '\(name)' already exists"
        }
    }
}