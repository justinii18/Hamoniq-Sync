//
//  MediaImportView.swift
//  Hamoniq Sync
//
//  Created by Claude on 21/09/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct MediaImportView: View {
    @EnvironmentObject private var projectService: ProjectService
    @EnvironmentObject private var mediaService: MediaService
    @EnvironmentObject private var appViewModel: AppViewModel
    
    @State private var selectedProject: Project?
    @State private var importedFiles: [ImportedFile] = []
    @State private var isImporting = false
    @State private var importProgress = 0.0
    @State private var showingNewProjectSheet = false
    @State private var showingProjectPicker = false
    @State private var importError: String?
    @State private var showingImportOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            if importedFiles.isEmpty {
                emptyStateSection
            } else {
                importedFilesSection
            }
        }
        .sheet(isPresented: $showingNewProjectSheet) {
            NewProjectSheetView()
        }
        .sheet(isPresented: $showingProjectPicker) {
            ProjectPickerView(selectedProject: $selectedProject)
        }
        .sheet(isPresented: $showingImportOptions) {
            ImportOptionsView(
                files: importedFiles,
                selectedProject: selectedProject,
                onImport: handleFinalImport
            )
        }
        .alert("Import Error", isPresented: .constant(importError != nil)) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Import Media")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                if !importedFiles.isEmpty {
                    Button("Clear All") {
                        importedFiles.removeAll()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            // Project selection
            HStack {
                Text("Import to:")
                    .font(.headline)
                
                if let project = selectedProject {
                    HStack {
                        Circle()
                            .fill(colorForProject(project))
                            .frame(width: 20, height: 20)
                        
                        Text(project.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Button("Change") {
                            showingProjectPicker = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    Menu("Select Project") {
                        ForEach(projectService.currentState.projects) { project in
                            Button(project.displayName) {
                                selectedProject = project
                            }
                        }
                        
                        Divider()
                        
                        Button("New Project...") {
                            showingNewProjectSheet = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyStateSection: some View {
        SmartDropZoneView(
            configuration: DropZoneConfiguration(
                title: "Drop your media files here",
                subtitle: "Audio and video files will be analyzed and prepared for synchronization",
                iconName: "waveform.and.mic",
                minSize: CGSize(width: 400, height: 300),
                acceptedTypes: [.audio, .movie, .video],
                supportedFormats: [
                    // Audio formats
                    "wav", "aiff", "aif", "mp3", "m4a", "aac", "flac", "ogg",
                    // Video formats  
                    "mov", "mp4", "avi", "mkv", "mxf", "prores", "avchd"
                ],
                allowsMultipleFiles: true,
                allowsDirectories: true
            ),
            onDrop: handleFileDrop
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var importedFilesSection: some View {
        VStack(spacing: 16) {
            // Import summary
            HStack {
                Text("\(importedFiles.count) files imported")
                    .font(.headline)
                
                Spacer()
                
                if !isImporting {
                    Button("Process Files") {
                        if selectedProject != nil {
                            showingImportOptions = true
                        } else {
                            showingProjectPicker = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(importedFiles.isEmpty)
                }
            }
            .padding(.horizontal)
            
            if isImporting {
                ImportProgressView(progress: importProgress)
                    .padding(.horizontal)
            }
            
            // File list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(importedFiles) { file in
                        ImportedFileRowView(file: file) {
                            removeFile(file)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func handleFileDrop(_ urls: [URL]) -> Bool {
        Task {
            await processDroppedFiles(urls)
        }
        return true
    }
    
    @MainActor
    private func processDroppedFiles(_ urls: [URL]) async {
        for url in urls {
            // Check if file already imported
            if importedFiles.contains(where: { $0.url == url }) {
                continue
            }
            
            do {
                let file = try await analyzeFile(url)
                importedFiles.append(file)
            } catch {
                importError = "Failed to import \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }
    
    private func analyzeFile(_ url: URL) async throws -> ImportedFile {
        let resourceValues = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .typeIdentifierKey
        ])
        
        let fileSize = resourceValues.fileSize ?? 0
        let modificationDate = resourceValues.contentModificationDate ?? Date()
        let typeIdentifier = resourceValues.typeIdentifier ?? ""
        
        // Determine media type
        let mediaType: MediaType
        if UTType(typeIdentifier)?.conforms(to: .audio) == true {
            mediaType = .audio
        } else if UTType(typeIdentifier)?.conforms(to: .video) == true {
            mediaType = .video
        } else {
            mediaType = .mixed  // Default fallback
        }
        
        // Get duration for audio/video files
        var duration: TimeInterval = 0
        if mediaType == .audio || mediaType == .video {
            let asset = AVAsset(url: url)
            duration = try await asset.load(.duration).seconds
        }
        
        return ImportedFile(
            url: url,
            name: url.lastPathComponent,
            mediaType: mediaType,
            fileSize: fileSize,
            duration: duration,
            modificationDate: modificationDate,
            status: .pending
        )
    }
    
    private func removeFile(_ file: ImportedFile) {
        importedFiles.removeAll { $0.id == file.id }
    }
    
    private func handleFinalImport(
        files: [ImportedFile],
        project: Project,
        options: ImportOptions
    ) {
        Task {
            await performImport(files: files, project: project, options: options)
        }
    }
    
    @MainActor
    private func performImport(
        files: [ImportedFile],
        project: Project,
        options: ImportOptions
    ) async {
        isImporting = true
        importProgress = 0.0
        
        for (index, file) in files.enumerated() {
            do {
                // Update progress
                importProgress = Double(index) / Double(files.count)
                
                // Create or get media group for this import
                let mediaGroup = getOrCreateMediaGroup(for: project, options: options)
                
                // Import file via MediaService
                let importedClips = try await mediaService.importFiles([file.url], to: mediaGroup)
                
                // Update project if clips were imported
                if !importedClips.isEmpty {
                    project.updateModificationDate()
                }
                
                // Update file status
                if let fileIndex = importedFiles.firstIndex(where: { $0.id == file.id }) {
                    importedFiles[fileIndex].status = .imported
                }
                
            } catch {
                // Update file status
                if let fileIndex = importedFiles.firstIndex(where: { $0.id == file.id }) {
                    importedFiles[fileIndex].status = .failed
                    importedFiles[fileIndex].errorMessage = error.localizedDescription
                }
            }
        }
        
        importProgress = 1.0
        isImporting = false
        
        // Show completion or navigate to project
        if options.navigateToProjectAfterImport {
            // Navigate to project workspace
            selectedProject = project
        }
    }
    
    private func getOrCreateMediaGroup(for project: Project, options: ImportOptions) -> MediaGroup {
        // Create a new media group for this import session
        let groupName = "Import \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
        let mediaGroup = MediaGroup(name: groupName, type: .mixed, color: "blue")
        
        // Add to project
        project.addMediaGroup(mediaGroup)
        
        return mediaGroup
    }
    
    private func colorForProject(_ project: Project) -> Color {
        switch project.colorLabel {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        default: return .blue
        }
    }
}

// MARK: - Supporting Views

struct ImportedFileRowView: View {
    let file: ImportedFile
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Circle()
                .fill(file.mediaType.color)
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: file.mediaType.icon)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .medium))
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(file.mediaType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatFileSize(file.fileSize))
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
                }
                
                if let error = file.errorMessage {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Status indicator
            HStack {
                statusIcon
                
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch file.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.orange)
        case .importing:
            ProgressView()
                .controlSize(.small)
        case .imported:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct ImportProgressView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("Importing files... \(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Types

struct ImportedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let mediaType: MediaType
    let fileSize: Int
    let duration: TimeInterval
    let modificationDate: Date
    var status: ImportStatus = .pending
    var errorMessage: String?
}

enum ImportStatus {
    case pending
    case importing  
    case imported
    case failed
}

struct ImportOptions {
    let createMediaGroups: Bool
    let autoDetectRelatedFiles: Bool
    let navigateToProjectAfterImport: Bool
    let copyFilesToProject: Bool
    
    static let `default` = ImportOptions(
        createMediaGroups: true,
        autoDetectRelatedFiles: true,
        navigateToProjectAfterImport: true,
        copyFilesToProject: false
    )
}

// MARK: - Supporting Views (Placeholders for now)

struct NewProjectSheetView: View {
    var body: some View {
        Text("New Project Creation")
            .frame(width: 400, height: 300)
    }
}

struct ProjectPickerView: View {
    @Binding var selectedProject: Project?
    
    var body: some View {
        Text("Project Picker")
            .frame(width: 400, height: 300)
    }
}

struct ImportOptionsView: View {
    let files: [ImportedFile]
    let selectedProject: Project?
    let onImport: (([ImportedFile], Project, ImportOptions) -> Void)
    
    var body: some View {
        Text("Import Options")
            .frame(width: 400, height: 300)
    }
}

// MARK: - Extensions

extension MediaType {
    var color: Color {
        switch self {
        case .audio: return .blue
        case .video: return .green
        case .mixed: return .purple
        }
    }
}

#Preview {
    let mockProjectService = ProjectService(dataController: DataController.shared)
    let mockMediaService = MediaService(dataController: DataController.shared)
    let mockAppViewModel = AppViewModel(dataController: DataController.shared)
    
    MediaImportView()
        .environmentObject(mockProjectService)
        .environmentObject(mockMediaService)
        .environmentObject(mockAppViewModel)
        .frame(width: 800, height: 600)
}