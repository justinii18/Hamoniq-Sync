//
//  MediaService.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData
import Combine
import UniformTypeIdentifiers

@MainActor
final class MediaService: ObservableService<MediaService.State> {
    
    // MARK: - State Definition
    
    struct State {
        var importedClips: [Clip] = []
        var processingClips: [Clip] = []
        var isProcessing: Bool = false
        var importProgress: Float = 0.0
        var importStatus: String = ""
        var supportedFormats: [UTType] = []
    }
    
    // MARK: - Dependencies
    
    private let dataController: DataController
    
    // MARK: - Publishers
    
    private let clipImportedSubject = PassthroughSubject<Clip, Never>()
    private let clipProcessedSubject = PassthroughSubject<Clip, Never>()
    private let importProgressSubject = PassthroughSubject<(Float, String), Never>()
    
    var clipImportedPublisher: AnyPublisher<Clip, Never> {
        clipImportedSubject.eraseToAnyPublisher()
    }
    
    var clipProcessedPublisher: AnyPublisher<Clip, Never> {
        clipProcessedSubject.eraseToAnyPublisher()
    }
    
    var importProgressPublisher: AnyPublisher<(Float, String), Never> {
        importProgressSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(dataController: DataController) {
        self.dataController = dataController
        super.init(initialState: State())
    }
    
    // MARK: - Service Lifecycle
    
    override func performInitialization() async throws {
        await setupSupportedFormats()
    }
    
    private func setupSupportedFormats() async {
        let videoTypes: [UTType] = [
            .mpeg4Movie, .quickTimeMovie, .avi, .movie
        ]
        
        let audioTypes: [UTType] = [
            .wav, .aiff, .mp3, .mpeg4Audio, .audio
        ]
        
        updateState { state in
            state.supportedFormats = videoTypes + audioTypes
        }
    }
    
    // MARK: - Import Operations
    
    func importFiles(_ urls: [URL], to mediaGroup: MediaGroup) async throws -> [Clip] {
        try requireInitialized()
        
        updateState { state in
            state.isProcessing = true
            state.importProgress = 0.0
            state.importStatus = "Starting import..."
        }
        
        var importedClips: [Clip] = []
        
        do {
            for (index, url) in urls.enumerated() {
                let progress = Float(index) / Float(urls.count)
                updateImportProgress(progress, status: "Importing \(url.lastPathComponent)...")
                
                if let clip = try await importFile(url, to: mediaGroup) {
                    importedClips.append(clip)
                    clipImportedSubject.send(clip)
                }
            }
            
            updateImportProgress(1.0, status: "Import complete")
            
            updateState { state in
                state.importedClips.append(contentsOf: importedClips)
                state.isProcessing = false
            }
            
            // Start background processing for metadata extraction
            await startBackgroundProcessing(for: importedClips)
            
            return importedClips
            
        } catch {
            updateState { state in
                state.isProcessing = false
                state.importStatus = "Import failed"
            }
            throw error
        }
    }
    
    private func importFile(_ url: URL, to mediaGroup: MediaGroup) async throws -> Clip? {
        // Validate file format
        guard isFormatSupported(url) else {
            throw MediaServiceError.unsupportedFormat(url.pathExtension)
        }
        
        // Determine media type
        let mediaType = MediaType.detectType(from: url)
        
        // Create clip
        let clip = Clip(url: url, type: mediaType)
        clip.importMethod = .dragDrop
        clip.originalPath = url.path
        
        // Create security-scoped bookmark
        _ = clip.createSecurityScopedBookmark()
        
        // Get basic file info
        updateBasicFileInfo(for: clip)
        
        // Add to media group
        mediaGroup.addClip(clip)
        
        // Save to database
        dataController.mainContext.insert(clip)
        dataController.save()
        
        return clip
    }
    
    private func updateBasicFileInfo(for clip: Clip) {
        do {
            let resourceValues = try clip.fileURL.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .creationDateKey
            ])
            
            if let fileSize = resourceValues.fileSize {
                clip.fileSize = Int64(fileSize)
            }
            
            if let modificationDate = resourceValues.contentModificationDate {
                clip.recordingDate = modificationDate
            }
        } catch {
            print("Failed to get basic file info for \(clip.filename): \(error)")
        }
    }
    
    // MARK: - Background Processing
    
    private func startBackgroundProcessing(for clips: [Clip]) async {
        updateState { state in
            state.processingClips.append(contentsOf: clips)
        }
        
        for clip in clips {
            await processClipMetadata(clip)
        }
    }
    
    private func processClipMetadata(_ clip: Clip) async {
        clip.updateProcessingStatus(.processing)
        
        // Extract metadata (placeholder implementation)
        await extractMetadata(for: clip)
        
        // Generate thumbnail (placeholder implementation)
        await generateThumbnail(for: clip)
        
        clip.updateProcessingStatus(.completed)
        
        updateState { state in
            state.processingClips.removeAll { $0.id == clip.id }
        }
        
        dataController.save()
        clipProcessedSubject.send(clip)
    }
    
    private func extractMetadata(for clip: Clip) async {
        // This would use AVFoundation to extract detailed metadata
        // For now, we'll simulate the process
        
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Placeholder metadata extraction
        if clip.isVideoFile {
            clip.videoFrameRate = 29.97
            clip.videoResolution = "1920x1080"
            clip.durationSeconds = 120.0 // Placeholder
        }
        
        if clip.isAudioFile {
            clip.sampleRate = 48000
            clip.channelCount = 2
            clip.durationSeconds = 120.0 // Placeholder
        }
        
        clip.updateMetadata()
    }
    
    private func generateThumbnail(for clip: Clip) async {
        // This would generate actual thumbnails for video files
        // For now, we'll simulate the process
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        clip.generateThumbnail()
    }
    
    // MARK: - Format Support
    
    func isFormatSupported(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        let supportedExtensions = MediaType.allCases.flatMap { $0.supportedExtensions }
        return supportedExtensions.contains(fileExtension)
    }
    
    func getSupportedFormats() -> [String] {
        return MediaType.allCases.flatMap { $0.supportedExtensions }
    }
    
    func getFormatDescription(for url: URL) -> String {
        let mediaType = MediaType.detectType(from: url)
        return mediaType.displayName
    }
    
    // MARK: - File Operations
    
    func validateFileAccess(_ urls: [URL]) -> [URL] {
        return urls.filter { url in
            FileManager.default.fileExists(atPath: url.path) &&
            FileManager.default.isReadableFile(atPath: url.path)
        }
    }
    
    func analyzeFiles(_ urls: [URL]) async -> [FileAnalysisResult] {
        var results: [FileAnalysisResult] = []
        
        for url in urls {
            let result = await analyzeFile(url)
            results.append(result)
        }
        
        return results
    }
    
    private func analyzeFile(_ url: URL) async -> FileAnalysisResult {
        var result = FileAnalysisResult(url: url)
        
        // Check if file exists and is readable
        result.isAccessible = FileManager.default.fileExists(atPath: url.path) &&
                            FileManager.default.isReadableFile(atPath: url.path)
        
        guard result.isAccessible else {
            result.error = "File is not accessible"
            return result
        }
        
        // Check format support
        result.isSupported = isFormatSupported(url)
        
        if !result.isSupported {
            result.error = "Unsupported file format"
            return result
        }
        
        // Get basic file info
        do {
            let resourceValues = try url.resourceValues(forKeys: [
                .fileSizeKey,
                .contentModificationDateKey
            ])
            
            result.fileSize = resourceValues.fileSize
            result.modificationDate = resourceValues.contentModificationDate
            result.mediaType = MediaType.detectType(from: url)
            
        } catch {
            result.error = error.localizedDescription
        }
        
        return result
    }
    
    // MARK: - Grouping Suggestions
    
    func suggestGrouping(for clips: [Clip], criteria: GroupingCriteria) -> [MediaGroupSuggestion] {
        var suggestions: [MediaGroupSuggestion] = []
        
        if criteria.byTimestamp {
            suggestions.append(contentsOf: groupByTimestamp(clips, tolerance: criteria.timeTolerance))
        }
        
        if criteria.byDevice {
            suggestions.append(contentsOf: groupByDevice(clips))
        }
        
        if criteria.byNamingPattern && !criteria.namingPattern.isEmpty {
            suggestions.append(contentsOf: groupByNamingPattern(clips, pattern: criteria.namingPattern))
        }
        
        return suggestions
    }
    
    private func groupByTimestamp(_ clips: [Clip], tolerance: TimeInterval) -> [MediaGroupSuggestion] {
        let sortedClips = clips.sorted { clip1, clip2 in
            (clip1.recordingDate ?? Date.distantPast) < (clip2.recordingDate ?? Date.distantPast)
        }
        
        var groups: [[Clip]] = []
        var currentGroup: [Clip] = []
        var lastDate: Date?
        
        for clip in sortedClips {
            guard let recordingDate = clip.recordingDate else {
                continue
            }
            
            if let last = lastDate, recordingDate.timeIntervalSince(last) > tolerance {
                if !currentGroup.isEmpty {
                    groups.append(currentGroup)
                    currentGroup = []
                }
            }
            
            currentGroup.append(clip)
            lastDate = recordingDate
        }
        
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }
        
        return groups.enumerated().map { index, clips in
            MediaGroupSuggestion(
                name: "Time Group \(index + 1)",
                clips: clips,
                groupType: .camera,
                confidence: 0.8,
                reason: "Files recorded within \(Int(tolerance)) seconds of each other"
            )
        }
    }
    
    private func groupByDevice(_ clips: [Clip]) -> [MediaGroupSuggestion] {
        let groupedByDevice = Dictionary(grouping: clips) { clip in
            clip.recordingDevice ?? "Unknown Device"
        }
        
        return groupedByDevice.map { device, clips in
            MediaGroupSuggestion(
                name: device,
                clips: clips,
                groupType: clips.first?.isVideoFile == true ? .camera : .audio,
                confidence: 0.9,
                reason: "Files from the same recording device"
            )
        }
    }
    
    private func groupByNamingPattern(_ clips: [Clip], pattern: String) -> [MediaGroupSuggestion] {
        // This would implement more sophisticated pattern matching
        // For now, we'll group by file name prefix
        
        let groupedByPrefix = Dictionary(grouping: clips) { clip in
            String(clip.filename.prefix(while: { !$0.isNumber }))
        }
        
        return groupedByPrefix.compactMap { prefix, clips in
            guard clips.count > 1 else { return nil }
            
            return MediaGroupSuggestion(
                name: "\(prefix) Group",
                clips: clips,
                groupType: .camera,
                confidence: 0.7,
                reason: "Files with similar naming pattern"
            )
        }
    }
    
    // MARK: - Progress Reporting
    
    private func updateImportProgress(_ progress: Float, status: String) {
        updateState { state in
            state.importProgress = progress
            state.importStatus = status
        }
        
        importProgressSubject.send((progress, status))
    }
}

// MARK: - Supporting Types

struct FileAnalysisResult {
    let url: URL
    var isAccessible: Bool = false
    var isSupported: Bool = false
    var fileSize: Int?
    var modificationDate: Date?
    var mediaType: MediaType?
    var error: String?
    
    var filename: String {
        url.lastPathComponent
    }
    
    var isValid: Bool {
        isAccessible && isSupported && error == nil
    }
}

struct MediaGroupSuggestion {
    let name: String
    let clips: [Clip]
    let groupType: MediaGroupType
    let confidence: Double
    let reason: String
    
    var clipCount: Int {
        clips.count
    }
}

enum MediaServiceError: LocalizedError {
    case unsupportedFormat(String)
    case fileNotAccessible(URL)
    case metadataExtractionFailed(String)
    case importCancelled
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported file format: \(format)"
        case .fileNotAccessible(let url):
            return "Cannot access file: \(url.lastPathComponent)"
        case .metadataExtractionFailed(let reason):
            return "Failed to extract metadata: \(reason)"
        case .importCancelled:
            return "Import operation was cancelled"
        }
    }
}