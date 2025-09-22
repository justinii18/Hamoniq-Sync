//
//  Project.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData

@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var projectType: ProjectType
    var createdAt: Date
    var modifiedAt: Date
    var lastOpenedAt: Date?
    
    // Workflow configuration
    var syncStrategy: SyncStrategy
    var masterTrackID: UUID?
    var targetFrameRate: Double?
    var workingDirectory: URL?
    
    // Project metadata
    var projectDescription: String
    var tags: [String]
    var colorLabel: String
    var isArchived: Bool
    var isFavorite: Bool
    
    // Relationships
    @Relationship(deleteRule: .cascade) var mediaGroups: [MediaGroup]
    @Relationship(deleteRule: .cascade) var syncJobs: [SyncJob]
    @Relationship(deleteRule: .cascade) var exportConfigurations: [ExportConfiguration]
    @Relationship(deleteRule: .cascade) var projectSettings: ProjectSettings?
    
    init(name: String, type: ProjectType) {
        self.id = UUID()
        self.name = name
        self.projectType = type
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.syncStrategy = type.defaultSyncStrategy
        self.projectDescription = ""
        self.tags = []
        self.colorLabel = "blue"
        self.isArchived = false
        self.isFavorite = false
        self.mediaGroups = []
        self.syncJobs = []
        self.exportConfigurations = []
    }
    
    // MARK: - Computed Properties
    
    var displayName: String {
        return name.isEmpty ? "Untitled Project" : name
    }
    
    var totalClips: Int {
        return mediaGroups.reduce(0) { $0 + $1.clips.count }
    }
    
    var totalDuration: TimeInterval {
        return mediaGroups.reduce(0) { $0 + $1.totalDuration }
    }
    
    var hasMedia: Bool {
        return totalClips > 0
    }
    
    var canSync: Bool {
        return totalClips > 1
    }
    
    var completedSyncJobs: [SyncJob] {
        return syncJobs.filter { $0.isCompleted }
    }
    
    var activeSyncJobs: [SyncJob] {
        return syncJobs.filter { !$0.isCompleted }
    }
    
    var averageSyncConfidence: Double {
        let allResults = syncJobs.flatMap { $0.syncResults }
        guard !allResults.isEmpty else { return 0.0 }
        
        let totalConfidence = allResults.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Double(allResults.count)
    }
    
    // MARK: - Methods
    
    func updateModificationDate() {
        modifiedAt = Date()
    }
    
    func updateLastOpenedDate() {
        lastOpenedAt = Date()
        updateModificationDate()
    }
    
    func addMediaGroup(_ group: MediaGroup) {
        mediaGroups.append(group)
        updateModificationDate()
    }
    
    func removeMediaGroup(_ group: MediaGroup) {
        mediaGroups.removeAll { $0.id == group.id }
        updateModificationDate()
    }
    
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
            updateModificationDate()
        }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        updateModificationDate()
    }
    
    func archive() {
        isArchived = true
        updateModificationDate()
    }
    
    func unarchive() {
        isArchived = false
        updateModificationDate()
    }
    
    func toggleFavorite() {
        isFavorite.toggle()
        updateModificationDate()
    }
}

// MARK: - Searchable Conformance

extension Project: Searchable {
    var searchableContent: String {
        let tagString = tags.joined(separator: " ")
        return "\(name) \(projectDescription) \(projectType.rawValue) \(tagString)"
    }
}