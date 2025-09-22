//
//  SmartStartView.swift
//  Hamoniq Sync
//
//  Created by Claude on 21/09/2025.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SmartStartView: View {
    @EnvironmentObject private var projectService: ProjectService
    @EnvironmentObject private var mediaService: MediaService
    @EnvironmentObject private var appViewModel: AppViewModel
    
    @State private var analysisResults: SmartAnalysisResult?
    @State private var isAnalyzing = false
    @State private var analysisProgress = 0.0
    @State private var selectedSuggestion: ProjectSuggestion?
    @State private var showingCustomization = false
    @State private var detectedFiles: [DetectedFile] = []
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            if detectedFiles.isEmpty {
                emptyStateSection
            } else if isAnalyzing {
                analysisSection
            } else if let results = analysisResults {
                resultsSection(results)
            } else {
                detectedFilesSection
            }
        }
        .sheet(isPresented: $showingCustomization) {
            if let suggestion = selectedSuggestion {
                ProjectCustomizationView(
                    suggestion: suggestion,
                    detectedFiles: detectedFiles,
                    onCreateProject: handleProjectCreation
                )
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Start")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Drop your files and we'll suggest the optimal project setup")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !detectedFiles.isEmpty {
                    Menu("Options") {
                        Button("Clear All Files") {
                            clearAllFiles()
                        }
                        
                        Button("Manual Analysis") {
                            analyzeFiles()
                        }
                        
                        if analysisResults != nil {
                            Button("Show Advanced Options") {
                                showingCustomization = true
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyStateSection: some View {
        SmartDropZoneView(
            configuration: DropZoneConfiguration(
                title: "Drop your media files here",
                subtitle: "We'll analyze your files and suggest the perfect project setup",
                iconName: "brain.head.profile",
                minSize: CGSize(width: 500, height: 350),
                acceptedTypes: [.audio, .movie, .video],
                supportedFormats: [
                    "wav", "aiff", "mp3", "m4a", "mov", "mp4", "avi", "mkv", "mxf"
                ],
                allowsMultipleFiles: true,
                allowsDirectories: true
            ),
            onDrop: handleFileDrop
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var analysisSection: some View {
        VStack(spacing: 24) {
            // Analysis progress
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .scaleEffect(isAnalyzing ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnalyzing)
                
                Text("Analyzing your media files...")
                    .font(.title2)
                    .fontWeight(.medium)
                
                ProgressView(value: analysisProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(maxWidth: 300)
                
                Text(analysisStatusText)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // File analysis preview
            if !detectedFiles.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(detectedFiles.prefix(5))) { file in
                            DetectedFileRowView(file: file)
                        }
                        
                        if detectedFiles.count > 5 {
                            Text("and \(detectedFiles.count - 5) more files...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func resultsSection(_ results: SmartAnalysisResult) -> some View {
        VStack(spacing: 20) {
            // Analysis summary
            analysisHeader(results)
            
            // Project suggestions
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(results.suggestions) { suggestion in
                        ProjectSuggestionCardView(
                            suggestion: suggestion,
                            isSelected: selectedSuggestion?.id == suggestion.id,
                            onSelect: { selectSuggestion(suggestion) }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Action buttons
            if let selected = selectedSuggestion {
                HStack(spacing: 16) {
                    Button("Customize Project") {
                        showingCustomization = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Create Project") {
                        createProject(with: selected)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private var detectedFilesSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(detectedFiles.count) files detected")
                    .font(.headline)
                
                Spacer()
                
                Button("Analyze Files") {
                    analyzeFiles()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(detectedFiles) { file in
                        DetectedFileRowView(file: file)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private func analysisHeader(_ results: SmartAnalysisResult) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analysis Complete")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text(results.summary)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Quick stats
            HStack(spacing: 24) {
                StatView(
                    title: "Files",
                    value: "\(results.totalFiles)",
                    icon: "doc.fill"
                )
                
                StatView(
                    title: "Duration", 
                    value: formatDuration(results.totalDuration),
                    icon: "clock.fill"
                )
                
                StatView(
                    title: "Types",
                    value: "\(results.detectedTypes.count)",
                    icon: "square.grid.2x2.fill"
                )
                
                StatView(
                    title: "Confidence",
                    value: "\(Int(results.confidence * 100))%",
                    icon: "brain.head.profile.fill"
                )
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleFileDrop(_ urls: [URL]) -> Bool {
        Task {
            await processDroppedFiles(urls)
        }
        return true
    }
    
    @MainActor
    private func processDroppedFiles(_ urls: [URL]) async {
        for url in urls {
            if !detectedFiles.contains(where: { $0.url == url }) {
                do {
                    let file = try await analyzeDroppedFile(url)
                    detectedFiles.append(file)
                } catch {
                    print("Failed to analyze file \(url.lastPathComponent): \(error)")
                }
            }
        }
        
        // Auto-analyze if we have enough files
        if detectedFiles.count >= 2 {
            try? await Task.sleep(nanoseconds: 500_000_000) // Brief delay
            analyzeFiles()
        }
    }
    
    private func analyzeDroppedFile(_ url: URL) async throws -> DetectedFile {
        let resourceValues = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .typeIdentifierKey,
            .creationDateKey
        ])
        
        let fileSize = resourceValues.fileSize ?? 0
        let modificationDate = resourceValues.contentModificationDate ?? Date()
        let creationDate = resourceValues.creationDate ?? Date()
        let typeIdentifier = resourceValues.typeIdentifier ?? ""
        
        // Determine media type
        let mediaType = MediaType.detectType(from: url)
        
        // Get duration and technical details for audio/video files
        var duration: TimeInterval = 0
        var technicalInfo: TechnicalInfo?
        
        if mediaType == .audio || mediaType == .video {
            let asset = AVAsset(url: url)
            duration = try await asset.load(.duration).seconds
            technicalInfo = try await extractTechnicalInfo(from: asset)
        }
        
        return DetectedFile(
            url: url,
            name: url.lastPathComponent,
            mediaType: mediaType,
            fileSize: fileSize,
            duration: duration,
            creationDate: creationDate,
            modificationDate: modificationDate,
            technicalInfo: technicalInfo
        )
    }
    
    private func extractTechnicalInfo(from asset: AVAsset) async throws -> TechnicalInfo {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        var frameRate: Float?
        var resolution: CGSize?
        var codecType: String?
        
        if let videoTrack = tracks.first {
            frameRate = try await videoTrack.load(.nominalFrameRate)
            let naturalSize = try await videoTrack.load(.naturalSize)
            resolution = naturalSize
            
            // Try to get codec information
            let formatDescriptions = try await videoTrack.load(.formatDescriptions)
            if let formatDescription = formatDescriptions.first {
                let codecCode = CMFormatDescriptionGetMediaSubType(formatDescription)
                codecType = fourCharCodeToString(codecCode)
            }
        }
        
        return TechnicalInfo(
            frameRate: frameRate,
            resolution: resolution,
            codecType: codecType
        )
    }
    
    private func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF)
        ]
        return String(bytes: bytes, encoding: .utf8) ?? "Unknown"
    }
    
    private func analyzeFiles() {
        Task {
            await performSmartAnalysis()
        }
    }
    
    @MainActor
    private func performSmartAnalysis() async {
        isAnalyzing = true
        analysisProgress = 0.0
        
        // Simulate progressive analysis
        let steps = [
            "Analyzing file formats...",
            "Detecting camera patterns...",
            "Analyzing timestamps...",
            "Checking audio sync patterns...",
            "Generating recommendations..."
        ]
        
        for (index, step) in steps.enumerated() {
            analysisProgress = Double(index) / Double(steps.count)
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds per step
        }
        
        analysisProgress = 1.0
        
        // Generate analysis results
        let results = generateAnalysisResults()
        analysisResults = results
        
        // Auto-select the first (best) suggestion
        if let firstSuggestion = results.suggestions.first {
            selectedSuggestion = firstSuggestion
        }
        
        isAnalyzing = false
    }
    
    private func generateAnalysisResults() -> SmartAnalysisResult {
        let totalFiles = detectedFiles.count
        let totalDuration = detectedFiles.reduce(0) { $0 + $1.duration }
        let detectedTypes = Set(detectedFiles.map { $0.mediaType })
        
        // Analyze patterns and generate suggestions
        let suggestions = generateProjectSuggestions()
        
        // Calculate overall confidence based on file patterns
        let confidence = calculateConfidence()
        
        let summary = generateSummary(totalFiles: totalFiles, types: detectedTypes)
        
        return SmartAnalysisResult(
            totalFiles: totalFiles,
            totalDuration: totalDuration,
            detectedTypes: Array(detectedTypes),
            suggestions: suggestions,
            confidence: confidence,
            summary: summary
        )
    }
    
    private func generateProjectSuggestions() -> [ProjectSuggestion] {
        var suggestions: [ProjectSuggestion] = []
        
        let videoFiles = detectedFiles.filter { $0.mediaType == .video }
        let audioFiles = detectedFiles.filter { $0.mediaType == .audio }
        
        // Multi-camera project suggestion
        if videoFiles.count >= 2 {
            let confidence = calculateMultiCamConfidence(videoFiles)
            suggestions.append(ProjectSuggestion(
                projectType: .multiCam,
                title: "Multi-Camera Project",
                description: "Detected \(videoFiles.count) video files that appear to be from different cameras",
                confidence: confidence,
                syncStrategy: .auto,
                estimatedSyncTime: estimateMultiCamSyncTime(videoFiles),
                features: [
                    "Automatic camera angle detection",
                    "Timeline synchronization",
                    "Audio-based alignment",
                    "Multi-cam editing export"
                ]
            ))
        }
        
        // Music video suggestion
        if audioFiles.count >= 1 && videoFiles.count >= 1 {
            let confidence = calculateMusicVideoConfidence(audioFiles, videoFiles)
            suggestions.append(ProjectSuggestion(
                projectType: .musicVideo,
                title: "Music Video Project",
                description: "Detected audio track with multiple video sources - perfect for music video sync",
                confidence: confidence,
                syncStrategy: .hybrid,
                estimatedSyncTime: estimateMusicVideoSyncTime(audioFiles, videoFiles),
                features: [
                    "Beat-based synchronization",
                    "Audio waveform matching",
                    "Creative sync options",
                    "Professional export formats"
                ]
            ))
        }
        
        // Podcast suggestion
        if audioFiles.count >= 2 && videoFiles.isEmpty {
            suggestions.append(ProjectSuggestion(
                projectType: .podcast,
                title: "Podcast Project", 
                description: "Multiple audio sources detected - ideal for podcast synchronization",
                confidence: 0.9,
                syncStrategy: .auto,
                estimatedSyncTime: 60,
                features: [
                    "Voice isolation",
                    "Automatic level matching",
                    "Cross-talk detection",
                    "Podcast export formats"
                ]
            ))
        }
        
        // Single camera fallback
        if suggestions.isEmpty && !detectedFiles.isEmpty {
            suggestions.append(ProjectSuggestion(
                projectType: .singleCam,
                title: "Single Source Project",
                description: "Basic project setup for your media files",
                confidence: 0.7,
                syncStrategy: .manual,
                estimatedSyncTime: 30,
                features: [
                    "Simple timeline",
                    "Basic sync tools",
                    "Standard export options"
                ]
            ))
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    private func calculateMultiCamConfidence(_ videoFiles: [DetectedFile]) -> Double {
        // Higher confidence for more cameras and similar timestamps
        let baseConfidence = min(0.9, 0.3 + Double(videoFiles.count) * 0.15)
        
        // Check for temporal clustering (files recorded around the same time)
        let creationTimes = videoFiles.compactMap { $0.creationDate }
        if creationTimes.count >= 2 {
            let timeSpread = creationTimes.max()!.timeIntervalSince(creationTimes.min()!)
            let temporalBonus = timeSpread < 3600 ? 0.2 : 0.0 // Within 1 hour
            return min(1.0, baseConfidence + temporalBonus)
        }
        
        return baseConfidence
    }
    
    private func calculateMusicVideoConfidence(_ audioFiles: [DetectedFile], _ videoFiles: [DetectedFile]) -> Double {
        // Check if we have exactly one audio file and multiple video files
        if audioFiles.count == 1 && videoFiles.count >= 2 {
            return 0.85
        } else if audioFiles.count <= 2 && videoFiles.count >= 1 {
            return 0.7
        }
        return 0.5
    }
    
    private func estimateMultiCamSyncTime(_ videoFiles: [DetectedFile]) -> Int {
        // Base time + additional time per camera
        return 120 + (videoFiles.count - 2) * 30
    }
    
    private func estimateMusicVideoSyncTime(_ audioFiles: [DetectedFile], _ videoFiles: [DetectedFile]) -> Int {
        return 90 + videoFiles.count * 15
    }
    
    private func calculateConfidence() -> Double {
        // Calculate overall confidence based on file patterns and technical quality
        let fileCount = detectedFiles.count
        let hasMultipleTypes = Set(detectedFiles.map { $0.mediaType }).count > 1
        let hasGoodQuality = detectedFiles.allSatisfy { $0.duration > 10 } // At least 10 seconds each
        
        var confidence = 0.5
        
        if fileCount >= 2 { confidence += 0.2 }
        if hasMultipleTypes { confidence += 0.2 }
        if hasGoodQuality { confidence += 0.1 }
        
        return min(1.0, confidence)
    }
    
    private func generateSummary(totalFiles: Int, types: Set<MediaType>) -> String {
        let typeNames = types.map { $0.displayName }.joined(separator: ", ")
        return "Found \(totalFiles) files (\(typeNames)) ready for synchronization"
    }
    
    private func clearAllFiles() {
        detectedFiles.removeAll()
        analysisResults = nil
        selectedSuggestion = nil
        isAnalyzing = false
    }
    
    private func selectSuggestion(_ suggestion: ProjectSuggestion) {
        selectedSuggestion = suggestion
    }
    
    private func createProject(with suggestion: ProjectSuggestion) {
        Task {
            await handleProjectCreation(suggestion: suggestion, files: detectedFiles, customization: nil)
        }
    }
    
    private func handleProjectCreation(
        suggestion: ProjectSuggestion,
        files: [DetectedFile],
        customization: ProjectCustomization?
    ) {
        Task {
            await performProjectCreation(suggestion: suggestion, files: files, customization: customization)
        }
    }
    
    @MainActor
    private func performProjectCreation(
        suggestion: ProjectSuggestion,
        files: [DetectedFile],
        customization: ProjectCustomization?
    ) async {
        // Create project with suggested settings
        let projectName = customization?.name ?? "\(suggestion.title) - \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none))"
        
        do {
            // Save project
            let project = try await projectService.createProject(name: projectName, type: suggestion.projectType)
            project.syncStrategy = suggestion.syncStrategy
            
            // Import files to project
            let mediaGroup = MediaGroup(name: "Imported Media", type: .mixed, color: "blue")
            project.addMediaGroup(mediaGroup)
            
            let urls = files.map { $0.url }
            let _ = try await mediaService.importFiles(urls, to: mediaGroup)
            
            // Navigate to project workspace
            // This would typically trigger navigation to the main workspace
            
        } catch {
            print("Failed to create project: \(error)")
        }
    }
    
    private var analysisStatusText: String {
        let progress = Int(analysisProgress * 100)
        let steps = [
            "Analyzing file formats...",
            "Detecting camera patterns...",
            "Analyzing timestamps...",
            "Checking audio sync patterns...",
            "Generating recommendations..."
        ]
        
        let stepIndex = min(Int(analysisProgress * Double(steps.count)), steps.count - 1)
        return steps[stepIndex]
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Supporting Views

struct DetectedFileRowView: View {
    let file: DetectedFile
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(file.mediaType.color)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: file.mediaType.icon)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(file.mediaType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if file.duration > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatDuration(file.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let resolution = file.technicalInfo?.resolution {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(resolution.width))x\(Int(resolution.height))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct ProjectSuggestionCardView: View {
    let suggestion: ProjectSuggestion
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(suggestion.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Image(systemName: "brain.head.profile.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("\(Int(suggestion.confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Text("~\(suggestion.estimatedSyncTime)s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Features list
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(suggestion.features, id: \.self) { feature in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(feature)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.controlBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color(.separatorColor), lineWidth: isSelected ? 2 : 1)
        }
        .cornerRadius(12)
        .onTapGesture {
            onSelect()
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Types

struct DetectedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let mediaType: MediaType
    let fileSize: Int
    let duration: TimeInterval
    let creationDate: Date
    let modificationDate: Date
    let technicalInfo: TechnicalInfo?
}

struct TechnicalInfo {
    let frameRate: Float?
    let resolution: CGSize?
    let codecType: String?
}

struct SmartAnalysisResult {
    let totalFiles: Int
    let totalDuration: TimeInterval
    let detectedTypes: [MediaType]
    let suggestions: [ProjectSuggestion]
    let confidence: Double
    let summary: String
}

struct ProjectSuggestion: Identifiable {
    let id = UUID()
    let projectType: ProjectType
    let title: String
    let description: String
    let confidence: Double
    let syncStrategy: SyncStrategy
    let estimatedSyncTime: Int // seconds
    let features: [String]
}

struct ProjectCustomization {
    let name: String
    let description: String
    let syncStrategy: SyncStrategy
    let organizationPreferences: [String: Any]
}

// MARK: - Placeholder Views

struct ProjectCustomizationView: View {
    let suggestion: ProjectSuggestion
    let detectedFiles: [DetectedFile]
    let onCreateProject: (ProjectSuggestion, [DetectedFile], ProjectCustomization?) -> Void
    
    var body: some View {
        Text("Project Customization")
            .frame(width: 600, height: 400)
    }
}

#Preview {
    let mockProjectService = ProjectService(dataController: DataController.shared)
    let mockMediaService = MediaService(dataController: DataController.shared)
    let mockAppViewModel = AppViewModel(dataController: DataController.shared)
    
    SmartStartView()
        .environmentObject(mockProjectService)
        .environmentObject(mockMediaService)
        .environmentObject(mockAppViewModel)
        .frame(width: 900, height: 700)
}