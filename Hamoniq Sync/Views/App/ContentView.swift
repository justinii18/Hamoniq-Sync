//
//  ContentView.swift
//  Hamoniq Sync
//
//  Created by Justin Adjei on 20/09/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dataController: DataController
    @StateObject private var appViewModel: AppViewModel
    
    // Initialize services
    @StateObject private var projectService: ProjectService
    @StateObject private var mediaService: MediaService
    @StateObject private var syncService: SyncService
    
    init() {
        // This approach allows us to initialize services with dependencies
        let dataController = DataController.shared
        
        let projectService = ProjectService(dataController: dataController)
        let mediaService = MediaService(dataController: dataController)
        let syncService = SyncService(dataController: dataController)
        
        self._projectService = StateObject(wrappedValue: projectService)
        self._mediaService = StateObject(wrappedValue: mediaService)
        self._syncService = StateObject(wrappedValue: syncService)
        self._appViewModel = StateObject(wrappedValue: AppViewModel(dataController: dataController))
    }

    var body: some View {
        Group {
            if appViewModel.state.isAppReady {
                if appViewModel.state.showWelcomeScreen {
                    WelcomeView()
                } else {
                    MainWorkspaceView()
                }
            } else {
                SplashScreenView()
            }
        }
        .environmentObject(appViewModel)
        .environmentObject(projectService)
        .environmentObject(mediaService)
        .environmentObject(syncService)
        .task {
            await initializeServices()
            appViewModel.handle(.appDidLaunch)
        }
        .sheet(item: Binding<ActiveSheet?>(
            get: { appViewModel.state.activeSheet },
            set: { _ in appViewModel.handle(.hideSheet) }
        )) { sheet in
            SheetContentView(sheet: sheet)
        }
        .alert(item: Binding<ActiveAlert?>(
            get: { appViewModel.state.activeAlert },
            set: { _ in appViewModel.handle(.hideAlert) }
        )) { alert in
            createAlert(for: alert)
        }
    }
    
    private func createAlert(for activeAlert: ActiveAlert) -> Alert {
        switch activeAlert {
        case .deleteProject:
            return Alert(
                title: Text("Delete Project"),
                message: Text("Are you sure you want to delete this project? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    // Handle deletion
                },
                secondaryButton: .cancel()
            )
        case .unsavedChanges:
            return Alert(
                title: Text("Unsaved Changes"),
                message: Text("You have unsaved changes. Do you want to save before continuing?"),
                primaryButton: .default(Text("Save")) {
                    // Handle save
                },
                secondaryButton: .destructive(Text("Discard"))
            )
        case .error(let message):
            return Alert(
                title: Text("Error"),
                message: Text(message),
                dismissButton: .default(Text("OK"))
            )
        case .networkUnavailable:
            return Alert(
                title: Text("Network Unavailable"),
                message: Text("Please check your internet connection and try again."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func initializeServices() async {
        do {
            try await projectService.initialize()
            try await mediaService.initialize()
            try await syncService.initialize()
        } catch {
            print("Failed to initialize services: \(error)")
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "waveform.path")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to Harmoniq Sync")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Professional audio and video synchronization for multicam workflows")
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                Button("Create New Project") {
                    appViewModel.showNewProjectSheet()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Skip Welcome") {
                    appViewModel.handle(.hideWelcomeScreen)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Splash Screen View

struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.path")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Harmoniq Sync")
                .font(.title)
                .fontWeight(.semibold)
            
            ProgressView()
                .scaleEffect(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Main Workspace View

struct MainWorkspaceView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(width: appViewModel.state.sidebarWidth)
        } detail: {
            WorkspaceDetailView()
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var projectService: ProjectService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project selection header
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Project")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let project = appViewModel.state.selectedProject {
                    HStack {
                        Image(systemName: project.projectType.icon)
                            .foregroundColor(.blue)
                        Text(project.displayName)
                            .fontWeight(.medium)
                        Spacer()
                        Button("Close") {
                            appViewModel.closeProject()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                        .font(.caption)
                    }
                } else {
                    Button("Select Project") {
                        appViewModel.handle(.selectSidebarItem(.projects))
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            
            Divider()
            
            // Navigation items
            List(SidebarItem.allCases, id: \.rawValue, selection: Binding<SidebarItem?>(
                get: { appViewModel.state.selectedSidebarItem },
                set: { if let item = $0 { appViewModel.handle(.selectSidebarItem(item)) } }
            )) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
                .disabled(item != .projects && appViewModel.state.selectedProject == nil)
            }
            .listStyle(.sidebar)
            
            Spacer()
            
            // Recent projects
            if !projectService.currentState.recentProjects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Text("Recent Projects")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(projectService.currentState.recentProjects.prefix(5), id: \.id) { project in
                        Button {
                            appViewModel.openProject(project)
                        } label: {
                            HStack {
                                Image(systemName: project.projectType.icon)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(project.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom)
            }
        }
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Workspace Detail View

struct WorkspaceDetailView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        switch appViewModel.state.selectedSidebarItem {
        case .projects:
            ProjectBrowserView()
        case .import:
            MediaImportView()
        case .sync:
            if appViewModel.hasSelectedProject {
                SyncWorkspaceView()
            } else {
                EmptyProjectView(message: "Select a project to begin syncing")
            }
        case .results:
            if appViewModel.hasSelectedProject {
                SyncResultsView()
            } else {
                EmptyProjectView(message: "Select a project to view results")
            }
        case .export:
            if appViewModel.hasSelectedProject {
                ExportConfigurationView()
            } else {
                EmptyProjectView(message: "Select a project to configure exports")
            }
        }
    }
}

// MARK: - Placeholder Views

struct ProjectBrowserView: View {
    @EnvironmentObject private var projectService: ProjectService
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        VStack {
            HStack {
                Text("Projects")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("New Project") {
                    appViewModel.showNewProjectSheet()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            if projectService.currentState.projects.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("No Projects Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Create your first project to get started with Harmoniq Sync")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Create Project") {
                        appViewModel.showNewProjectSheet()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Project list would go here
                Text("Project list coming soon...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct MediaImportView: View {
    var body: some View {
        Text("Media Import View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(.secondary)
    }
}

struct SyncWorkspaceView: View {
    var body: some View {
        Text("Sync Workspace View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(.secondary)
    }
}

struct SyncResultsView: View {
    var body: some View {
        Text("Sync Results View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(.secondary)
    }
}

struct ExportConfigurationView: View {
    var body: some View {
        Text("Export Configuration View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundColor(.secondary)
    }
}

struct EmptyProjectView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sheet and Alert Content

struct SheetContentView: View {
    let sheet: ActiveSheet
    
    var body: some View {
        switch sheet {
        case .newProject:
            NewProjectView()
        case .importMedia:
            Text("Import Media Sheet")
        case .exportConfiguration:
            Text("Export Configuration Sheet")
        case .preferences:
            Text("Preferences Sheet")
        }
    }
}



struct NewProjectView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var projectName = ""
    @State private var selectedType: ProjectType = .multiCam
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $projectName)
                    
                    Picker("Project Type", selection: $selectedType) {
                        ForEach(ProjectType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
            }
            .navigationTitle("New Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        appViewModel.createNewProject(name: projectName, type: selectedType)
                        dismiss()
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
        .modelContainer(ModelContainer.createPreviewContainer())
}
