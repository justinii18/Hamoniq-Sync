//
//  ModelContainer+Extensions.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData

extension ModelContainer {
    
    /// Create a shared ModelContainer instance for the entire app
    static func createAppContainer() -> ModelContainer {
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
            cloudKitDatabase: .none
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    /// Create an in-memory container for testing
    static func createTestContainer() -> ModelContainer {
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
            isStoredInMemoryOnly: true
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
    }
    
    /// Create a preview container with sample data for SwiftUI previews
    @MainActor
    static func createPreviewContainer() -> ModelContainer {
        let container = createTestContainer()
        let context = container.mainContext
        
        // Create sample data for previews
        createSampleData(in: context)
        
        return container
    }
    
    /// Create sample data for testing and previews
    @MainActor
    private static func createSampleData(in context: ModelContext) {
        // Create sample user preferences
        let preferences = UserPreferences()
        context.insert(preferences)
        
        // Create a sample project
        let project = Project(name: "Sample Multi-Cam Project", type: .multiCam)
        project.projectDescription = "A sample project for testing the sync functionality"
        project.tags = ["sample", "multicam", "test"]
        project.isFavorite = true
        
        // Create project settings
        let settings = ProjectSettings()
        project.projectSettings = settings
        
        // Create sample media groups
        let cameraGroup = MediaGroup(name: "Camera Angles", type: .camera, color: "systemBlue")
        cameraGroup.groupDescription = "All camera angles from the shoot"
        
        let audioGroup = MediaGroup(name: "Audio Tracks", type: .audio, color: "systemGreen")
        audioGroup.groupDescription = "Recorded audio tracks"
        
        // Create sample clips
        let clip1 = Clip(url: URL(fileURLWithPath: "/sample/camera1.mp4"), type: .video)
        clip1.durationSeconds = 120.5
        clip1.recordingDate = Date().addingTimeInterval(-3600)
        clip1.cameraAngle = 1
        clip1.processingStatus = .completed
        
        let clip2 = Clip(url: URL(fileURLWithPath: "/sample/camera2.mp4"), type: .video)
        clip2.durationSeconds = 118.3
        clip2.recordingDate = Date().addingTimeInterval(-3590)
        clip2.cameraAngle = 2
        clip2.processingStatus = .completed
        
        let audioClip = Clip(url: URL(fileURLWithPath: "/sample/audio.wav"), type: .audio)
        audioClip.durationSeconds = 125.0
        audioClip.recordingDate = Date().addingTimeInterval(-3605)
        audioClip.processingStatus = .completed
        
        // Add clips to groups
        cameraGroup.addClip(clip1)
        cameraGroup.addClip(clip2)
        audioGroup.addClip(audioClip)
        
        // Add groups to project
        project.addMediaGroup(cameraGroup)
        project.addMediaGroup(audioGroup)
        
        // Create sample sync results
        let syncResult1 = SyncResult(
            sourceClipID: audioClip.id,
            targetClipID: clip1.id,
            offset: 2205, // 0.05 seconds at 44.1kHz
            confidence: 0.95,
            method: .spectralFlux
        )
        syncResult1.validationStatus = .valid
        syncResult1.peakCorrelation = 0.92
        clip1.addSyncResult(syncResult1)
        
        let syncResult2 = SyncResult(
            sourceClipID: audioClip.id,
            targetClipID: clip2.id,
            offset: -4410, // -0.1 seconds at 44.1kHz
            confidence: 0.87,
            method: .chroma
        )
        syncResult2.validationStatus = .valid
        syncResult2.peakCorrelation = 0.85
        clip2.addSyncResult(syncResult2)
        
        // Create sample sync job
        let syncJob = SyncJob(
            type: .multiCam,
            referenceClipID: audioClip.id,
            targetClipIDs: [clip1.id, clip2.id]
        )
        syncJob.status = .completed
        syncJob.progress = 1.0
        syncJob.statusMessage = "Completed"
        syncJob.startedAt = Date().addingTimeInterval(-300)
        syncJob.completedAt = Date().addingTimeInterval(-60)
        syncJob.addSyncResult(syncResult1)
        syncJob.addSyncResult(syncResult2)
        
        project.syncJobs.append(syncJob)
        
        // Create sample export configuration
        let exportConfig = ExportConfiguration(
            name: "Final Cut Pro Export",
            target: .finalCutPro,
            format: .fcpxml
        )
        exportConfig.includeColorCoding = true
        exportConfig.preserveGrouping = true
        project.exportConfigurations.append(exportConfig)
        
        // Insert all objects into context
        context.insert(project)
        context.insert(settings)
        context.insert(cameraGroup)
        context.insert(audioGroup)
        context.insert(clip1)
        context.insert(clip2)
        context.insert(audioClip)
        context.insert(syncResult1)
        context.insert(syncResult2)
        context.insert(syncJob)
        context.insert(exportConfig)
        
        // Save the context
        do {
            try context.save()
        } catch {
            print("Failed to save sample data: \(error)")
        }
    }
}

// MARK: - ModelContext Extensions

extension ModelContext {
    
    /// Safely save the context with error handling
    func safeSave() {
        do {
            try save()
        } catch {
            print("Failed to save ModelContext: \(error)")
        }
    }
    
    /// Insert multiple objects at once
    func insertAll<T: PersistentModel>(_ objects: [T]) {
        for object in objects {
            insert(object)
        }
    }
    
    /// Delete multiple objects at once
    func deleteAll<T: PersistentModel>(_ objects: [T]) {
        for object in objects {
            delete(object)
        }
    }
    
    /// Fetch with error handling
    func safeFetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            print("Failed to fetch \(T.self): \(error)")
            return []
        }
    }
    
    /// Count with error handling
    func safeCount<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> Int {
        do {
            return try fetchCount(descriptor)
        } catch {
            print("Failed to count \(T.self): \(error)")
            return 0
        }
    }
}