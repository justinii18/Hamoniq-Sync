//
//  ExportConfiguration.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData

@Model
final class ExportConfiguration {
    @Attribute(.unique) var id: UUID
    var name: String
    var nleTarget: NLETarget
    var exportFormat: ExportFormat
    var isDefault: Bool
    
    // Export settings
    var includeColorCoding: Bool
    var preserveGrouping: Bool
    var exportTimecode: Bool
    var exportMetadata: Bool
    var exportKeyframes: Bool
    
    // File organization
    var outputDirectory: URL?
    var filenameTemplate: String
    var createSubfolders: Bool
    var folderStructure: String
    
    // Advanced settings
    var customSettings: Data // JSON blob for NLE-specific options
    var postExportActions: [PostExportAction]
    
    // Metadata
    var createdAt: Date
    var lastUsedAt: Date?
    var useCount: Int
    
    // Relationships
    @Relationship(inverse: \Project.exportConfigurations) var project: Project?
    
    init(name: String, target: NLETarget, format: ExportFormat) {
        self.id = UUID()
        self.name = name
        self.nleTarget = target
        self.exportFormat = format
        self.isDefault = false
        self.includeColorCoding = true
        self.preserveGrouping = true
        self.exportTimecode = true
        self.exportMetadata = true
        self.exportKeyframes = true
        self.filenameTemplate = "{projectName}_{timestamp}"
        self.createSubfolders = false
        self.folderStructure = "flat"
        self.customSettings = Data()
        self.postExportActions = []
        self.createdAt = Date()
        self.useCount = 0
    }
    
    // MARK: - Computed Properties
    
    var displayName: String {
        return name.isEmpty ? "Untitled Configuration" : name
    }
    
    var targetDisplayName: String {
        return nleTarget.displayName
    }
    
    var formatDisplayName: String {
        return exportFormat.displayName
    }
    
    var hasBeenUsed: Bool {
        return useCount > 0
    }
    
    var isRecentlyUsed: Bool {
        guard let lastUsed = lastUsedAt else { return false }
        return Date().timeIntervalSince(lastUsed) < 7 * 24 * 60 * 60 // 7 days
    }
    
    var outputFileExtension: String {
        return exportFormat.fileExtension
    }
    
    var hasCustomSettings: Bool {
        return !customSettings.isEmpty
    }
    
    var hasPostExportActions: Bool {
        return !postExportActions.isEmpty
    }
    
    var estimatedOutputFilename: String {
        let timestamp = DateFormatter.filenameSafe.string(from: Date())
        let projectName = project?.name ?? "Project"
        
        return filenameTemplate
            .replacingOccurrences(of: "{projectName}", with: projectName)
            .replacingOccurrences(of: "{timestamp}", with: timestamp)
            .replacingOccurrences(of: "{target}", with: nleTarget.rawValue)
            .replacingOccurrences(of: "{format}", with: exportFormat.rawValue)
    }
    
    // MARK: - Methods
    
    func incrementUseCount() {
        useCount += 1
        lastUsedAt = Date()
    }
    
    func setAsDefault() {
        isDefault = true
    }
    
    func removeAsDefault() {
        isDefault = false
    }
    
    func updateOutputDirectory(_ directory: URL) {
        outputDirectory = directory
    }
    
    func updateFilenameTemplate(_ template: String) {
        filenameTemplate = template
    }
    
    func toggleColorCoding() {
        includeColorCoding.toggle()
    }
    
    func togglePreserveGrouping() {
        preserveGrouping.toggle()
    }
    
    func toggleExportTimecode() {
        exportTimecode.toggle()
    }
    
    func toggleExportMetadata() {
        exportMetadata.toggle()
    }
    
    func toggleExportKeyframes() {
        exportKeyframes.toggle()
    }
    
    func toggleCreateSubfolders() {
        createSubfolders.toggle()
    }
    
    func addPostExportAction(_ action: PostExportAction) {
        if !postExportActions.contains(action) {
            postExportActions.append(action)
        }
    }
    
    func removePostExportAction(_ action: PostExportAction) {
        postExportActions.removeAll { $0 == action }
    }
    
    func clearPostExportActions() {
        postExportActions.removeAll()
    }
    
    func setCustomSettings<T: Codable>(_ settings: T) {
        do {
            customSettings = try JSONEncoder().encode(settings)
        } catch {
            print("Failed to encode custom settings: \(error)")
        }
    }
    
    func getCustomSettings<T: Codable>(as type: T.Type) -> T? {
        guard !customSettings.isEmpty else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: customSettings)
        } catch {
            print("Failed to decode custom settings: \(error)")
            return nil
        }
    }
    
    func clearCustomSettings() {
        customSettings = Data()
    }
    
    func duplicate(withName newName: String) -> ExportConfiguration {
        let duplicate = ExportConfiguration(
            name: newName,
            target: nleTarget,
            format: exportFormat
        )
        
        duplicate.includeColorCoding = includeColorCoding
        duplicate.preserveGrouping = preserveGrouping
        duplicate.exportTimecode = exportTimecode
        duplicate.exportMetadata = exportMetadata
        duplicate.exportKeyframes = exportKeyframes
        duplicate.outputDirectory = outputDirectory
        duplicate.filenameTemplate = filenameTemplate
        duplicate.createSubfolders = createSubfolders
        duplicate.folderStructure = folderStructure
        duplicate.customSettings = customSettings
        duplicate.postExportActions = postExportActions
        
        return duplicate
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let filenameSafe: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}