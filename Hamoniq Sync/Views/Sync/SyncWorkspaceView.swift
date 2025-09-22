//
//  SyncWorkspaceView.swift
//  Hamoniq Sync
//
//  Created by Claude on 21/09/2025.
//

import SwiftUI
import AVFoundation

struct SyncWorkspaceView: View {
    let project: Project?
    
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var projectService: ProjectService
    @EnvironmentObject private var mediaService: MediaService
    
    @State private var selectedMediaGroup: MediaGroup?
    @State private var syncConfiguration = SyncConfiguration.default
    @State private var isPerformingSync = false
    @State private var syncProgress = 0.0
    @State private var currentSyncJob: SyncJob?
    @State private var syncResults: [SyncResult] = []
    @State private var showingSyncSettings = false
    @State private var selectedClips: Set<UUID> = []
    @State private var timelinePosition: TimeInterval = 0
    @State private var isPlaying = false
    @State private var showingAdvancedOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with project info and controls
            headerSection
            
            Divider()
            
            if let project = project, !project.mediaGroups.isEmpty {
                HSplitView {
                    // Left panel: Media groups and sync configuration
                    leftPanelSection
                        .frame(minWidth: 300, maxWidth: 400)
                    
                    // Main area: Timeline and waveforms
                    mainWorkspaceSection
                        .frame(minWidth: 500)
                    
                    // Right panel: Sync results and analysis
                    if !syncResults.isEmpty || isPerformingSync {
                        rightPanelSection
                            .frame(minWidth: 250, maxWidth: 350)
                    }
                }
            } else {
                emptyStateSection
            }
        }
        .sheet(isPresented: $showingSyncSettings) {
            SyncSettingsView(configuration: $syncConfiguration)
        }
        .sheet(isPresented: $showingAdvancedOptions) {
            AdvancedSyncOptionsView(
                configuration: $syncConfiguration,
                mediaGroup: selectedMediaGroup
            )
        }
        .onAppear {
            setupWorkspace()
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                // Project info
                if let project = project {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(colorForProject(project))
                            .frame(width: 32, height: 32)
                            .overlay {
                                Image(systemName: iconForProjectType(project.projectType))
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .medium))
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.displayName)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("\(project.totalClips) media files • \(project.syncStrategy.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Sync Workspace")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Main action buttons
                HStack(spacing: 12) {
                    if isPerformingSync {
                        Button("Cancel Sync") {
                            cancelSync()
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    } else {
                        Button("Settings") {
                            showingSyncSettings = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Advanced") {
                            showingAdvancedOptions = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Start Sync") {
                            startSyncProcess()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canStartSync)
                    }
                }
            }
            
            // Sync progress bar (when active)
            if isPerformingSync {
                VStack(spacing: 6) {
                    HStack {
                        Text("Synchronizing...")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(syncProgress * 100))%")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: syncProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    if let job = currentSyncJob {
                        Text("Processing: \(job.id.uuidString.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var leftPanelSection: some View {
        VStack(spacing: 0) {
            // Media groups selector
            VStack(alignment: .leading, spacing: 12) {
                Text("Media Groups")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                    .padding(.top)
                
                if let project = project {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(project.mediaGroups) { group in
                                MediaGroupSelectorView(
                                    group: group,
                                    isSelected: selectedMediaGroup?.id == group.id,
                                    onSelect: { selectMediaGroup(group) }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Divider()
                .padding(.vertical)
            
            // Sync configuration
            SyncConfigurationPanelView(
                configuration: $syncConfiguration,
                selectedClips: selectedClips
            )
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color(.windowBackgroundColor))
    }
    
    @ViewBuilder
    private var mainWorkspaceSection: some View {
        VStack(spacing: 0) {
            // Timeline controls
            timelineControlsSection
            
            Divider()
            
            // Main content area
            if let mediaGroup = selectedMediaGroup {
                ScrollView {
                    VStack(spacing: 16) {
                        // Clips overview
                        ClipsTimelineView(
                            clips: mediaGroup.clips,
                            selectedClips: $selectedClips,
                            timelinePosition: $timelinePosition,
                            configuration: syncConfiguration
                        )
                        
                        // Waveform visualization
                        if !mediaGroup.clips.isEmpty {
                            WaveformStackView(
                                clips: mediaGroup.clips,
                                timelinePosition: timelinePosition,
                                syncResults: syncResults
                            )
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text("Select a media group to begin")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Choose a media group from the left panel to start synchronization")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    @ViewBuilder
    private var rightPanelSection: some View {
        VStack(spacing: 0) {
            // Results header
            VStack(alignment: .leading, spacing: 8) {
                Text("Sync Results")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if !syncResults.isEmpty {
                    HStack {
                        Text("\(syncResults.count) results")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        let avgConfidence = syncResults.reduce(0.0) { $0 + $1.confidence } / Double(syncResults.count)
                        Text("Avg: \(Int(avgConfidence * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(avgConfidence > 0.8 ? .green : (avgConfidence > 0.6 ? .orange : .red))
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Results list
            if isPerformingSync && syncResults.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Analyzing audio patterns...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(syncResults) { result in
                            SyncResultCardView(
                                result: result,
                                onApply: { applySyncResult(result) },
                                onReject: { rejectSyncResult(result) }
                            )
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
        .background(Color(.windowBackgroundColor))
    }
    
    @ViewBuilder
    private var timelineControlsSection: some View {
        HStack(spacing: 16) {
            // Playback controls
            HStack(spacing: 8) {
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                
                Button {
                    resetTimeline()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
            }
            
            // Timeline scrubber
            VStack(spacing: 4) {
                HStack {
                    Text(formatTime(timelinePosition))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    if let duration = selectedMediaGroup?.totalDuration, duration > 0 {
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                
                if let duration = selectedMediaGroup?.totalDuration, duration > 0 {
                    Slider(value: $timelinePosition, in: 0...duration) { editing in
                        if !editing {
                            seekToPosition(timelinePosition)
                        }
                    }
                }
            }
            
            // Zoom controls
            HStack(spacing: 8) {
                Button {
                    zoomOut()
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                
                Button {
                    zoomIn()
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
                
                Button {
                    fitToWindow()
                } label: {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.title2)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var emptyStateSection: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                title: "No Media to Sync",
                subtitle: "Import media files to your project first, then return here to begin synchronization",
                systemImage: "waveform.and.mic",
            )
        )
    }
    
    // MARK: - Event Handlers
    
    private func setupWorkspace() {
        // Initialize with first media group if available
        if let firstGroup = project?.mediaGroups.first {
            selectedMediaGroup = firstGroup
        }
        
        // Set up sync configuration based on project settings
        if let project = project {
            syncConfiguration.strategy = project.syncStrategy
            syncConfiguration.alignmentMethod = .spectralFlux // Default
        }
    }
    
    private func selectMediaGroup(_ group: MediaGroup) {
        selectedMediaGroup = group
        selectedClips.removeAll()
        timelinePosition = 0
        resetSyncResults()
    }
    
    private var canStartSync: Bool {
        guard let group = selectedMediaGroup else { return false }
        return group.clips.count >= 2 && !isPerformingSync
    }
    
    private func startSyncProcess() {
        guard let group = selectedMediaGroup else { return }
        
        Task {
            await performSync(group: group)
        }
    }
    
    @MainActor
    private func performSync(group: MediaGroup) async {
        isPerformingSync = true
        syncProgress = 0.0
        syncResults.removeAll()
        
        do {
            // Create sync job
            let job = SyncJob(
                type: .multiCam,
                referenceClipID: group.clips.first?.id ?? UUID(),
                targetClipIDs: Array(group.clips.dropFirst().map { $0.id })
            )
            currentSyncJob = job
            
            // Perform sync using service
            let results = try await syncService.sync(
                source: group.clips.first!,
                target: Array(group.clips.dropFirst()),
                configuration: SyncParameters(
                    strategy: syncConfiguration.strategy,
                    confidenceThreshold: syncConfiguration.sensitivity,
                    enableDriftCorrection: true,
                    preferredMethods: [syncConfiguration.alignmentMethod],
                    maxOffsetSeconds: syncConfiguration.maxOffset,
                    sampleRate: 48000.0
                )
            )
            
            // Simulate progressive results (in real implementation, this would be streaming)
            for (index, result) in results.enumerated() {
                syncProgress = Double(index + 1) / Double(results.count)
                syncResults.append(result)
                
                // Add small delay to show progress
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
            
            syncProgress = 1.0
            currentSyncJob = nil
            isPerformingSync = false
            
        } catch {
            print("Sync failed: \(error)")
            isPerformingSync = false
            currentSyncJob = nil
        }
    }
    
    private func cancelSync() {
        // Cancel current sync operation
        currentSyncJob = nil
        isPerformingSync = false
        syncProgress = 0.0
    }
    
    private func resetSyncResults() {
        syncResults.removeAll()
        currentSyncJob = nil
        isPerformingSync = false
        syncProgress = 0.0
    }
    
    private func applySyncResult(_ result: SyncResult) {
        // Apply the sync result - this would update the timeline positions
        print("Applying sync result: \(result.id)")
    }
    
    private func rejectSyncResult(_ result: SyncResult) {
        // Remove the result from consideration
        syncResults.removeAll { $0.id == result.id }
    }
    
    private func togglePlayback() {
        isPlaying.toggle()
        // Implement playback logic
    }
    
    private func resetTimeline() {
        timelinePosition = 0
        isPlaying = false
        seekToPosition(0)
    }
    
    private func seekToPosition(_ position: TimeInterval) {
        timelinePosition = position
        // Implement seek logic
    }
    
    private func zoomIn() {
        // Implement zoom in logic
    }
    
    private func zoomOut() {
        // Implement zoom out logic
    }
    
    private func fitToWindow() {
        // Implement fit to window logic
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let centiseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, secs, centiseconds)
        } else {
            return String(format: "%d:%02d.%02d", minutes, secs, centiseconds)
        }
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
    
    private func iconForProjectType(_ type: ProjectType) -> String {
        switch type {
        case .singleCam: return "video"
        case .multiCam: return "video.stack"
        case .musicVideo: return "music.note"
        case .documentary: return "film"
        case .podcast: return "mic"
        case .wedding: return "heart"
        case .commercial: return "megaphone"
        case .custom: return "gear"
        }
    }
}

// MARK: - Supporting Views

struct MediaGroupSelectorView: View {
    let group: MediaGroup
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(isSelected ? .blue : .secondary)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.displayName)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? .blue : .primary)
                    
                    Text("\(group.clipCount) clips")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            
            if isSelected && !group.clips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(group.clips.prefix(3)) { clip in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(clip.mediaType.color)
                                .frame(width: 12, height: 12)
                            
                            Text(clip.displayName)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                    
                    if group.clips.count > 3 {
                        Text("and \(group.clips.count - 3) more...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.controlBackgroundColor))
        .cornerRadius(8)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color(.separatorColor), lineWidth: isSelected ? 2 : 1)
        }
        .onTapGesture {
            onSelect()
        }
    }
}

struct SyncConfigurationPanelView: View {
    @Binding var configuration: SyncConfiguration
    let selectedClips: Set<UUID>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Strategy selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Strategy")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Strategy", selection: $configuration.strategy) {
                    ForEach(SyncStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Alignment method
            VStack(alignment: .leading, spacing: 8) {
                Text("Alignment Method")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Method", selection: $configuration.alignmentMethod) {
                    ForEach(AlignmentMethod.allCases, id: \.self) { method in
                        Text(method.displayName).tag(method)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Sensitivity slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensitivity")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(Int(configuration.sensitivity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                SliderControlView(
                    value: $configuration.sensitivity,
                    configuration: SliderConfiguration(
                        trackHeight: 4,
                        thumbSize: 16
                    )
                )
            }
            
            // Quality vs Speed
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quality vs Speed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(configuration.qualityLevel.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                SliderControlView(
                    value: Binding(
                        get: { Double(configuration.qualityLevel.rawValue) },
                        set: { configuration.qualityLevel = QualityLevel(rawValue: Int($0)) ?? .balanced }
                    ),
                    configuration: SliderConfiguration(
                        trackHeight: 4,
                        thumbSize: 16
                    )
                )
            }
            
            Divider()
            
            // Selected clips info
            if !selectedClips.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Clips")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(selectedClips.count) clips selected for sync")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ClipsTimelineView: View {
    let clips: [Clip]
    @Binding var selectedClips: Set<UUID>
    @Binding var timelinePosition: TimeInterval
    let configuration: SyncConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            if clips.isEmpty {
                Text("No clips in this media group")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(clips) { clip in
                        ClipTimelineRowView(
                            clip: clip,
                            isSelected: selectedClips.contains(clip.id),
                            timelinePosition: timelinePosition,
                            onToggleSelection: {
                                if selectedClips.contains(clip.id) {
                                    selectedClips.remove(clip.id)
                                } else {
                                    selectedClips.insert(clip.id)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ClipTimelineRowView: View {
    let clip: Clip
    let isSelected: Bool
    let timelinePosition: TimeInterval
    let onToggleSelection: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button {
                onToggleSelection()
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            // Clip info
            VStack(alignment: .leading, spacing: 4) {
                Text(clip.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(clip.mediaType.displayName, systemImage: clip.mediaType.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let duration = clip.durationSeconds {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Mini waveform or video preview
            RoundedRectangle(cornerRadius: 4)
                .fill(clip.mediaType.color.opacity(0.3))
                .frame(width: 80, height: 30)
                .overlay {
                    Image(systemName: clip.mediaType.icon)
                        .foregroundColor(clip.mediaType.color)
                        .font(.caption)
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct WaveformStackView: View {
    let clips: [Clip]
    let timelinePosition: TimeInterval
    let syncResults: [SyncResult]
    
    private var audioClips: [Clip] {
        clips.filter { $0.mediaType == .audio || $0.mediaType == .mixed }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Waveform Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                if audioClips.isEmpty {
                    Text("No audio clips to visualize")
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text("\\(audioClips.count) audio clips ready for sync")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func generateMockWaveformData() -> [Float] {
        // Generate mock waveform data for preview
        return (0..<200).map { _ in Float.random(in: 0...1) }
    }
}

struct SyncResultCardView: View {
    let result: SyncResult
    let onApply: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sync Match")
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                ConfidenceIndicatorView(
                    confidence: result.confidence,
                    configuration: ConfidenceConfiguration(
                        style: .badge,
                        showPercentage: true
                    )
                )
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Offset: \(formatOffset(result.offsetSeconds))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Method: \(result.alignmentMethod.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if result.confidence > 0.8 {
                    Label("High confidence match", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if result.confidence > 0.6 {
                    Label("Medium confidence", systemImage: "questionmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Label("Low confidence", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            HStack(spacing: 8) {
                Button("Apply") {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                Button("Reject") {
                    onReject()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func formatOffset(_ offset: Double) -> String {
        let absOffset = abs(offset)
        let sign = offset >= 0 ? "+" : "-"
        let seconds = Int(absOffset)
        let milliseconds = Int((absOffset.truncatingRemainder(dividingBy: 1)) * 1000)
        return "\(sign)\(seconds).\(milliseconds)s"
    }
}

// MARK: - Supporting Types

struct SyncConfiguration {
    var strategy: SyncStrategy
    var alignmentMethod: AlignmentMethod
    var sensitivity: Double
    var qualityLevel: QualityLevel
    var maxOffset: TimeInterval
    var windowSize: TimeInterval
    
    static let `default` = SyncConfiguration(
        strategy: .auto,
        alignmentMethod: .spectralFlux,
        sensitivity: 0.7,
        qualityLevel: .balanced,
        maxOffset: 60.0,
        windowSize: 5.0
    )
}

enum QualityLevel: Int, CaseIterable {
    case fast = 0
    case balanced = 1
    case high = 2
    
    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .balanced: return "Balanced"
        case .high: return "High Quality"
        }
    }
}

struct EmptyStateAction {
    let title: String
    let action: () -> Void
}

// MARK: - Placeholder Views

struct SyncSettingsView: View {
    @Binding var configuration: SyncConfiguration
    
    var body: some View {
        Text("Sync Settings")
            .frame(width: 400, height: 300)
    }
}

struct AdvancedSyncOptionsView: View {
    @Binding var configuration: SyncConfiguration
    let mediaGroup: MediaGroup?
    
    var body: some View {
        Text("Advanced Sync Options")
            .frame(width: 500, height: 400)
    }
}

#Preview {
    let mockProject = Project(name: "Sample Project", type: .multiCam)
    let mockGroup = MediaGroup(name: "Camera Angles", type: .camera, color: "blue")
    
    // Add some mock clips
    let clip1 = Clip(url: URL(fileURLWithPath: "/tmp/audio1.wav"), type: .audio)
    let clip2 = Clip(url: URL(fileURLWithPath: "/tmp/video1.mov"), type: .video)
    
    mockGroup.clips = [clip1, clip2]
    mockProject.addMediaGroup(mockGroup)
    
    return SyncWorkspaceView(project: mockProject)
        .environmentObject(SyncService(dataController: DataController.shared))
        .environmentObject(ProjectService(dataController: DataController.shared))
        .environmentObject(MediaService(dataController: DataController.shared))
        .frame(width: 1200, height: 800)
}