//
//  AppViewModel.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
final class AppViewModel: ObservableViewModel<AppViewModel.State, AppViewModel.Action> {
    
    // MARK: - State Definition
    
    struct State {
        var isFirstLaunch: Bool = true
        var showWelcomeScreen: Bool = false
        var selectedProject: Project?
        var recentProjects: [Project] = []
        var userPreferences: UserPreferences?
        var isAppReady: Bool = false
        var showingSettings: Bool = false
        var currentWorkspace: WorkspaceType = .projects
        
        // Navigation state
        var navigationPath: [NavigationDestination] = []
        var selectedSidebarItem: SidebarItem = .projects
        
        // Global UI state
        var sidebarWidth: Double = 250.0
        var isInspectorVisible: Bool = true
        var activeSheet: ActiveSheet?
        var activeAlert: ActiveAlert?
    }
    
    // MARK: - Action Definition
    
    enum Action {
        case appDidLaunch
        case selectProject(Project?)
        case showWelcomeScreen
        case hideWelcomeScreen
        case navigateTo(NavigationDestination)
        case navigateBack
        case selectSidebarItem(SidebarItem)
        case toggleInspector
        case updateSidebarWidth(Double)
        case showSettings
        case hideSettings
        case showSheet(ActiveSheet)
        case hideSheet
        case showAlert(ActiveAlert)
        case hideAlert
        case updateUserPreferences(UserPreferences)
        case refreshRecentProjects
    }
    
    // MARK: - Dependencies
    
    private let dataController: DataController
    
    // MARK: - Initialization
    
    init(dataController: DataController) {
        self.dataController = dataController
        
        let initialState = State()
        super.init(initialState: initialState)
        
        setupInitialData()
    }
    
    // MARK: - Setup
    
    private func setupInitialData() {
        performOperation {
            // Load user preferences
            let preferences = self.dataController.loadUserPreferences()
            
            // Load recent projects
            let recentProjects = self.dataController.loadRecentProjects(limit: 10)
            
            return (preferences, recentProjects)
        } onSuccess: { [weak self] (preferences, recentProjects) in
            self?.updateState { state in
                state.userPreferences = preferences
                state.recentProjects = recentProjects
                state.showWelcomeScreen = preferences.showWelcomeScreen && recentProjects.isEmpty
                state.isFirstLaunch = recentProjects.isEmpty
                state.isAppReady = true
            }
        }
    }
    
    // MARK: - Action Handling
    
    override func handle(_ action: Action) {
        switch action {
        case .appDidLaunch:
            handleAppDidLaunch()
            
        case .selectProject(let project):
            handleSelectProject(project)
            
        case .showWelcomeScreen:
            updateState { state in
                state.showWelcomeScreen = true
            }
            
        case .hideWelcomeScreen:
            updateState { state in
                state.showWelcomeScreen = false
            }
            
        case .navigateTo(let destination):
            updateState { state in
                state.navigationPath.append(destination)
            }
            
        case .navigateBack:
            updateState { state in
                if !state.navigationPath.isEmpty {
                    state.navigationPath.removeLast()
                }
            }
            
        case .selectSidebarItem(let item):
            updateState { state in
                state.selectedSidebarItem = item
                // Clear navigation when switching sidebar sections
                state.navigationPath.removeAll()
            }
            
        case .toggleInspector:
            updateState { state in
                state.isInspectorVisible.toggle()
            }
            
        case .updateSidebarWidth(let width):
            updateState { state in
                state.sidebarWidth = max(200, min(400, width))
            }
            
        case .showSettings:
            updateState { state in
                state.showingSettings = true
            }
            
        case .hideSettings:
            updateState { state in
                state.showingSettings = false
            }
            
        case .showSheet(let sheet):
            updateState { state in
                state.activeSheet = sheet
            }
            
        case .hideSheet:
            updateState { state in
                state.activeSheet = nil
            }
            
        case .showAlert(let alert):
            updateState { state in
                state.activeAlert = alert
            }
            
        case .hideAlert:
            updateState { state in
                state.activeAlert = nil
            }
            
        case .updateUserPreferences(let preferences):
            handleUpdateUserPreferences(preferences)
            
        case .refreshRecentProjects:
            handleRefreshRecentProjects()
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleAppDidLaunch() {
        // Perform any necessary startup tasks
        performOperation {
            // Could include checking for updates, validating licenses, etc.
            try await Task.sleep(nanoseconds: 100_000_000) // Small delay for smooth startup
        } onSuccess: { [weak self] _ in
            // App is fully initialized
            self?.updateState { state in
                state.isAppReady = true
            }
        }
    }
    
    private func handleSelectProject(_ project: Project?) {
        updateState { state in
            state.selectedProject = project
            if project != nil {
                state.currentWorkspace = .sync
                state.selectedSidebarItem = .sync
            }
        }
        
        // Update project's last opened date
        if let project = project {
            project.updateLastOpenedDate()
            dataController.save()
            
            // Refresh recent projects list
            handle(.refreshRecentProjects)
        }
    }
    
    private func handleUpdateUserPreferences(_ preferences: UserPreferences) {
        updateState { state in
            state.userPreferences = preferences
        }
        
        // Save preferences to database
        dataController.updateUserPreferences(preferences)
    }
    
    private func handleRefreshRecentProjects() {
        performOperation {
            self.dataController.loadRecentProjects(limit: 10)
        } onSuccess: { [weak self] recentProjects in
            self?.updateState { state in
                state.recentProjects = recentProjects
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var hasSelectedProject: Bool {
        state.selectedProject != nil
    }
    
    var canShowWelcomeScreen: Bool {
        state.isFirstLaunch && state.recentProjects.isEmpty
    }
    
    var effectiveTheme: AppTheme {
        state.userPreferences?.preferredTheme ?? .system
    }
    
    // MARK: - Convenience Methods
    
    func createNewProject(name: String, type: ProjectType) {
        let project = dataController.createProject(name: name, type: type)
        handle(.selectProject(project))
        handle(.hideSheet)
    }
    
    func openProject(_ project: Project) {
        handle(.selectProject(project))
    }
    
    func closeProject() {
        handle(.selectProject(nil))
        updateState { state in
            state.currentWorkspace = .projects
            state.selectedSidebarItem = .projects
        }
    }
    
    func showNewProjectSheet() {
        handle(.showSheet(.newProject))
    }
    
    func showPreferences() {
        handle(.showSettings)
    }
    
    func quit() {
        // Save any pending changes
        if let project = state.selectedProject {
            project.updateModificationDate()
        }
        dataController.save()
    }
}

// MARK: - Supporting Types

enum WorkspaceType {
    case projects
    case sync
    case results
    case export
}

enum SidebarItem: String, CaseIterable {
    case projects = "Projects"
    case `import` = "Import"
    case sync = "Sync"
    case results = "Results"
    case export = "Export"
    
    var icon: String {
        switch self {
        case .projects: return "folder.fill"
        case .`import`: return "square.and.arrow.down"
        case .sync: return "waveform.path"
        case .results: return "chart.bar.fill"
        case .export: return "square.and.arrow.up"
        }
    }
}

enum NavigationDestination: Hashable {
    case projectDetail(Project.ID)
    case syncWorkspace(Project.ID)
    case results(Project.ID)
    case exportConfiguration(Project.ID)
    case settings
}

enum ActiveSheet: Identifiable {
    case newProject
    case importMedia
    case exportConfiguration
    case preferences
    
    var id: String {
        switch self {
        case .newProject: return "newProject"
        case .importMedia: return "importMedia"
        case .exportConfiguration: return "exportConfiguration"
        case .preferences: return "preferences"
        }
    }
}

enum ActiveAlert: Identifiable {
    case deleteProject(UUID)
    case unsavedChanges
    case error(String)
    case networkUnavailable
    
    var id: String {
        switch self {
        case .deleteProject(let id): return "deleteProject-\(id)"
        case .unsavedChanges: return "unsavedChanges"
        case .error: return "error"
        case .networkUnavailable: return "networkUnavailable"
        }
    }
}