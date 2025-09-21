//
//  Clip.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData

@Model
final class Clip {
    @Attribute(.unique) var id: UUID
    var filename: String
    var fileURL: URL
    var bookmarkData: Data? // Security-scoped bookmark for sandboxed access
    
    // Media properties
    var mediaType: MediaType
    var durationSeconds: Double?
    var sampleRate: Int?
    var channelCount: Int?
    var videoFrameRate: Double?
    var videoResolution: String?
    var fileSize: Int64
    var contentHash: String?
    
    // Metadata
    var timecodeIn: String?
    var timecodeOut: String?
    var cameraAngle: Int?
    var recordingDevice: String?
    var cameraModel: String?
    var lensInfo: String?
    var gpsLocation: String?
    var recordingDate: Date?
    var recordingSettings: String?
    
    // Spanning file support (GoPro chapters, etc.)
    var isSpanningFile: Bool
    var spanningParentID: UUID?
    var spanningIndex: Int?
    
    // Import metadata
    var importedAt: Date
    var originalPath: String?
    var importMethod: ImportMethod
    
    // Processing state
    var processingStatus: ProcessingStatus
    var thumbnailGenerated: Bool
    var metadataExtracted: Bool
    var fingerprintGenerated: Bool
    
    // Relationships
    @Relationship var syncResults: [SyncResult]
    @Relationship(inverse: \MediaGroup.clips) var mediaGroup: MediaGroup?
    
    init(url: URL, type: MediaType) {
        self.id = UUID()
        self.filename = url.lastPathComponent
        self.fileURL = url
        self.mediaType = type
        self.fileSize = 0
        self.isSpanningFile = false
        self.importedAt = Date()
        self.importMethod = .dragDrop
        self.processingStatus = .pending
        self.thumbnailGenerated = false
        self.metadataExtracted = false
        self.fingerprintGenerated = false
        self.syncResults = []
    }
    
    // MARK: - Computed Properties
    
    var displayName: String {
        let nameWithoutExtension = filename.replacingOccurrences(of: ".\(fileURL.pathExtension)", with: "")
        return nameWithoutExtension.isEmpty ? "Untitled Clip" : nameWithoutExtension
    }
    
    var fileExtension: String {
        return fileURL.pathExtension.lowercased()
    }
    
    var isVideoFile: Bool {
        return mediaType == .video || mediaType == .mixed
    }
    
    var isAudioFile: Bool {
        return mediaType == .audio || mediaType == .mixed
    }
    
    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var durationFormatted: String {
        guard let duration = durationSeconds else { return "Unknown" }
        
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    var frameRateFormatted: String {
        guard let frameRate = videoFrameRate else { return "N/A" }
        return String(format: "%.2f fps", frameRate)
    }
    
    var isProcessingComplete: Bool {
        return processingStatus == .completed
    }
    
    var hasValidDuration: Bool {
        return durationSeconds != nil && durationSeconds! > 0
    }
    
    var isReadyForSync: Bool {
        return isProcessingComplete && hasValidDuration && (isAudioFile || isVideoFile)
    }
    
    var bestSyncResults: [SyncResult] {
        return syncResults.filter { $0.validationStatus == .valid }
                         .sorted { $0.confidence > $1.confidence }
    }
    
    var hasSyncResults: Bool {
        return !syncResults.isEmpty
    }
    
    var averageSyncConfidence: Double {
        guard !syncResults.isEmpty else { return 0.0 }
        let totalConfidence = syncResults.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Double(syncResults.count)
    }
    
    // MARK: - Methods
    
    func updateFileSize() {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let size = attributes[.size] as? NSNumber {
                fileSize = size.int64Value
            }
        } catch {
            print("Error getting file size for \(filename): \(error)")
        }
    }
    
    func updateMetadata() {
        // This would be called after metadata extraction
        metadataExtracted = true
        
        // Update processing status if all metadata is extracted
        if metadataExtracted && thumbnailGenerated {
            processingStatus = .completed
        }
    }
    
    func generateThumbnail() {
        // This would be called after thumbnail generation
        thumbnailGenerated = true
        
        // Update processing status if all processing is complete
        if metadataExtracted && thumbnailGenerated {
            processingStatus = .completed
        }
    }
    
    func generateFingerprint() {
        // This would be called after audio fingerprint generation
        fingerprintGenerated = true
    }
    
    func addSyncResult(_ result: SyncResult) {
        syncResults.append(result)
        result.sourceClip = self
    }
    
    func removeSyncResult(_ result: SyncResult) {
        syncResults.removeAll { $0.id == result.id }
    }
    
    func clearSyncResults() {
        syncResults.removeAll()
    }
    
    func updateProcessingStatus(_ status: ProcessingStatus) {
        processingStatus = status
    }
    
    func setSpanningInfo(parentID: UUID, index: Int) {
        isSpanningFile = true
        spanningParentID = parentID
        spanningIndex = index
    }
    
    func clearSpanningInfo() {
        isSpanningFile = false
        spanningParentID = nil
        spanningIndex = nil
    }
    
    func createSecurityScopedBookmark() -> Bool {
        do {
            bookmarkData = try fileURL.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return true
        } catch {
            print("Failed to create security-scoped bookmark for \(filename): \(error)")
            return false
        }
    }
    
    func accessSecurityScopedResource<T>(_ block: () throws -> T) rethrows -> T? {
        guard let bookmarkData = bookmarkData else {
            return try block()
        }
        
        do {
            var isStale = false
            let resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            guard resolvedURL.startAccessingSecurityScopedResource() else {
                return nil
            }
            
            defer {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
            
            return try block()
        } catch {
            print("Failed to access security-scoped resource for \(filename): \(error)")
            return nil
        }
    }
}