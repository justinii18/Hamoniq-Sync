//
//  DataController.swift
//  Hamoniq Sync
//
//  Created by Justin Adjei on 20/09/2025.
//

import Foundation
import SwiftData

@MainActor
final class DataController: ObservableObject {
    
    static let shared = DataController()
    
    let container: ModelContainer
    
    private init() {
        let schema = Schema([
            Project.self,
            MediaGroup.self,
            Clip.self,
            SyncJob.self,
            SyncResult.self,
            ExportConfiguration.self,
            UserPreferences.self,
            ProjectSettings.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none // Disable CloudKit for now
        )
        
        do {
            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            
            // Perform any necessary setup
            setupDefaultData()
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupDefaultData() {
        let context = container.mainContext
        
        // Create default UserPreferences if none exist
        let fetchDescriptor = FetchDescriptor<UserPreferences>()
        
        do {
            let existingPreferences = try context.fetch(fetchDescriptor)
            if existingPreferences.isEmpty {
                let defaultPreferences = UserPreferences()
                context.insert(defaultPreferences)
                try context.save()
            }
        } catch {
            print("Failed to setup default user preferences: \(error)")
        }
    }
    
    // MARK: - Context Management
    
    var mainContext: ModelContext {
        return container.mainContext
    }
    
    func createBackgroundContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
    
    // MARK: - Save Operations
    
    func save() {
        do {
            try mainContext.save()
        } catch {
            print("Failed to save main context: \(error)")
        }
    }
    
    func saveBackground(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("Failed to save background context: \(error)")
        }
    }
    
    // MARK: - Fetch Operations
    
    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do {
            return try mainContext.fetch(descriptor)
        } catch {
            print("Failed to fetch \(T.self): \(error)")
            return []
        }
    }
    
    func fetchFirst<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> T? {
        do {
            let results = try mainContext.fetch(descriptor)
            return results.first
        } catch {
            print("Failed to fetch first \(T.self): \(error)")
            return nil
        }
    }
    
    func count<T: PersistentModel>(for type: T.Type, predicate: Predicate<T>? = nil) -> Int {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        
        do {
            return try mainContext.fetchCount(descriptor)
        } catch {
            print("Failed to count \(T.self): \(error)")
            return 0
        }
    }
    
    // MARK: - Delete Operations
    
    func delete<T: PersistentModel>(_ object: T) {
        mainContext.delete(object)
    }
    
    func deleteAll<T: PersistentModel>(of type: T.Type, where predicate: Predicate<T>? = nil) {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        
        do {
            let objects = try mainContext.fetch(descriptor)
            for object in objects {
                mainContext.delete(object)
            }
        } catch {
            print("Failed to delete all \(T.self): \(error)")
        }
    }
    
    // MARK: - Project-specific Operations
    
    func createProject(name: String, type: ProjectType) -> Project {
        let project = Project(name: name, type: type)
        
        // Create default project settings
        let settings = ProjectSettings()
        project.projectSettings = settings
        
        mainContext.insert(project)
        mainContext.insert(settings)
        
        save()
        return project
    }
    
    func loadAllProjects() -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return fetch(descriptor)
    }
    
    func loadRecentProjects(limit: Int = 10) -> [Project] {
        var descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { project in
                !project.isArchived
            },
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return fetch(descriptor)
    }
    
    func loadFavoriteProjects() -> [Project] {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { project in
                project.isFavorite && !project.isArchived
            },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return fetch(descriptor)
    }
    
    func searchProjects(query: String) -> [Project] {
        let lowercaseQuery = query.lowercased()
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { project in
                project.name.localizedStandardContains(lowercaseQuery) ||
                project.projectDescription.localizedStandardContains(lowercaseQuery)
            },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return fetch(descriptor)
    }
    
    // MARK: - UserPreferences Operations
    
    func loadUserPreferences() -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        
        if let preferences = fetchFirst(descriptor) {
            return preferences
        } else {
            // Create default preferences if none exist
            let defaultPreferences = UserPreferences()
            mainContext.insert(defaultPreferences)
            save()
            return defaultPreferences
        }
    }
    
    func updateUserPreferences(_ preferences: UserPreferences) {
        save()
    }
    
    // MARK: - Cleanup Operations
    
    func cleanupOrphanedData() {
        // Clean up sync results without associated clips
        let orphanedResults = FetchDescriptor<SyncResult>(
            predicate: #Predicate { result in
                result.sourceClip == nil
            }
        )
        
        do {
            let results = try mainContext.fetch(orphanedResults)
            for result in results {
                mainContext.delete(result)
            }
            
            save()
            print("Cleaned up \(results.count) orphaned sync results")
        } catch {
            print("Failed to cleanup orphaned sync results: \(error)")
        }
    }
    
    func compactDatabase() {
        // This would typically involve more sophisticated cleanup
        // For now, just save to trigger any pending deletions
        save()
    }
    
    // MARK: - Migration Support
    
    func performMigrationIfNeeded() {
        // This will be implemented when we need to handle schema migrations
        // For now, we'll rely on SwiftData's automatic migration
    }
    
    // MARK: - Backup and Restore
    
    func exportProject(_ project: Project) -> URL? {
        // This would create a backup file with the project and all related data
        // Implementation would involve serializing the project to JSON or similar format
        return nil
    }
    
    func importProject(from url: URL) -> Project? {
        // This would restore a project from a backup file
        // Implementation would involve deserializing and recreating the project structure
        return nil
    }
    
    // MARK: - Statistics
    
    func getDatabaseStatistics() -> DatabaseStatistics {
        return DatabaseStatistics(
            projectCount: count(for: Project.self),
            mediaGroupCount: count(for: MediaGroup.self),
            clipCount: count(for: Clip.self),
            syncJobCount: count(for: SyncJob.self),
            syncResultCount: count(for: SyncResult.self),
            exportConfigurationCount: count(for: ExportConfiguration.self)
        )
    }
}

// MARK: - Supporting Types

struct DatabaseStatistics {
    let projectCount: Int
    let mediaGroupCount: Int
    let clipCount: Int
    let syncJobCount: Int
    let syncResultCount: Int
    let exportConfigurationCount: Int
    
    var totalItemCount: Int {
        return projectCount + mediaGroupCount + clipCount + syncJobCount + syncResultCount + exportConfigurationCount
    }
}
