//
//  ProjectSettings.swift
//  Hamoniq Sync
//
//  Created by Justin Adjei on 20/09/2025.
//

import Foundation
import SwiftData

@Model
final class ProjectSettings {
    @Attribute(.unique) var id: UUID
    
    // Sync settings for this project
    var syncStrategy: SyncStrategy
    var confidenceThreshold: Double
    var enableDriftCorrection: Bool
    var preferredAlgorithms: [AlignmentMethod]
    var algorithmWeights: Data // Encoded algorithm weight preferences
    
    // Timeline settings
    var timelineZoomLevel: Double
    var visibleTracks: [UUID]
    var trackHeights: [UUID: Double]
    var timelineScrollPosition: Double
    var selectedTimeRange: Data? // Encoded time range selection
    
    // Export settings
    var defaultExportConfiguration: UUID?
    var lastExportLocation: URL?
    var exportPresets: Data // Encoded export presets
    
    // Workflow settings
    var autoGroupMedia: Bool
    var groupingCriteria: GroupingCriteria
    var colorCodingScheme: ColorCodingScheme
    var defaultMediaGroupType: MediaGroupType
    
    // UI state
    var sidebarCollapsed: Bool
    var inspectorCollapsed: Bool
    var activeWorkspaceTab: String
    var lastSelectedMediaGroup: UUID?
    var lastSelectedClip: UUID?
    
    // Processing preferences for this project
    var enableParallelProcessing: Bool
    var maxConcurrentOperations: Int
    var cacheIntermediateResults: Bool
    var useHardwareAcceleration: Bool
    
    init() {
        self.id = UUID()
        
        // Sync defaults
        self.syncStrategy = .auto
        self.confidenceThreshold = 0.7
        self.enableDriftCorrection = true
        self.preferredAlgorithms = [.spectralFlux, .chroma, .energy]
        self.algorithmWeights = Data()
        
        // Timeline defaults
        self.timelineZoomLevel = 1.0
        self.visibleTracks = []
        self.trackHeights = [:]
        self.timelineScrollPosition = 0.0
        
        // Export defaults
        self.exportPresets = Data()
        
        // Workflow defaults
        self.autoGroupMedia = true
        self.groupingCriteria = GroupingCriteria()
        self.colorCodingScheme = .confidenceLevel
        self.defaultMediaGroupType = .camera
        
        // UI state defaults
        self.sidebarCollapsed = false
        self.inspectorCollapsed = false
        self.activeWorkspaceTab = "sync"
        
        // Processing defaults
        self.enableParallelProcessing = true
        self.maxConcurrentOperations = 4
        self.cacheIntermediateResults = true
        self.useHardwareAcceleration = true
    }
    
    // MARK: - Computed Properties
    
    var effectiveMaxConcurrentOperations: Int {
        if enableParallelProcessing {
            return min(maxConcurrentOperations, ProcessInfo.processInfo.processorCount)
        } else {
            return 1
        }
    }
    
    var hasCustomAlgorithmWeights: Bool {
        return !algorithmWeights.isEmpty
    }
    
    var hasExportPresets: Bool {
        return !exportPresets.isEmpty
    }
    
    var hasTimelineSelection: Bool {
        return selectedTimeRange != nil
    }
    
    var visibleTrackCount: Int {
        return visibleTracks.count
    }
    
    var hasLastSelection: Bool {
        return lastSelectedMediaGroup != nil || lastSelectedClip != nil
    }
    
    // MARK: - Timeline Management
    
    func updateTimelineZoom(_ zoom: Double) {
        timelineZoomLevel = max(0.1, min(10.0, zoom))
    }
    
    func updateTimelineScrollPosition(_ position: Double) {
        timelineScrollPosition = max(0.0, position)
    }
    
    func addVisibleTrack(_ trackID: UUID) {
        if !visibleTracks.contains(trackID) {
            visibleTracks.append(trackID)
        }
    }
    
    func removeVisibleTrack(_ trackID: UUID) {
        visibleTracks.removeAll { $0 == trackID }
        trackHeights.removeValue(forKey: trackID)
    }
    
    func setTrackHeight(_ height: Double, for trackID: UUID) {
        trackHeights[trackID] = max(50.0, min(300.0, height))
    }
    
    func getTrackHeight(for trackID: UUID) -> Double {
        return trackHeights[trackID] ?? 100.0 // Default height
    }
    
    func clearTimelineSelection() {
        selectedTimeRange = nil
    }
    
    func setTimelineSelection<T: Codable>(_ selection: T) {
        do {
            selectedTimeRange = try JSONEncoder().encode(selection)
        } catch {
            print("Failed to encode timeline selection: \(error)")
        }
    }
    
    func getTimelineSelection<T: Codable>(as type: T.Type) -> T? {
        guard let data = selectedTimeRange else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to decode timeline selection: \(error)")
            return nil
        }
    }
    
    // MARK: - Algorithm Management
    
    func addPreferredAlgorithm(_ method: AlignmentMethod) {
        if !preferredAlgorithms.contains(method) {
            preferredAlgorithms.append(method)
        }
    }

    func removePreferredAlgorithm(_ method: AlignmentMethod) {
        preferredAlgorithms.removeAll { $0 == method }
    }

    func setAlgorithmWeight(_ weight: Double, for method: AlignmentMethod) {
        var weights = getAlgorithmWeights() ?? [:]
        weights[method.rawValue] = max(0.0, min(1.0, weight))
        setAlgorithmWeights(weights)
    }

    func getAlgorithmWeight(for method: AlignmentMethod) -> Double {
        let weights = getAlgorithmWeights() ?? [:]
        return weights[method.rawValue] ?? 1.0
    }
    
    private func setAlgorithmWeights(_ weights: [String: Double]) {
        do {
            algorithmWeights = try JSONEncoder().encode(weights)
        } catch {
            print("Failed to encode algorithm weights: \(error)")
        }
    }
    
    private func getAlgorithmWeights() -> [String: Double]? {
        guard !algorithmWeights.isEmpty else { return nil }
        
        do {
            return try JSONDecoder().decode([String: Double].self, from: algorithmWeights)
        } catch {
            print("Failed to decode algorithm weights: \(error)")
            return nil
        }
    }
    
    // MARK: - Export Management
    
    func setDefaultExportConfiguration(_ configID: UUID) {
        defaultExportConfiguration = configID
    }
    
    func clearDefaultExportConfiguration() {
        defaultExportConfiguration = nil
    }
    
    func updateLastExportLocation(_ location: URL) {
        lastExportLocation = location
    }
    
    func addExportPreset<T: Codable>(_ preset: T, name: String) {
        var presets = getExportPresets() ?? [:]
        presets[name] = preset
        setExportPresets(presets)
    }
    
    func removeExportPreset(_ name: String) {
        var presets = getExportPresets() ?? [:]
        presets.removeValue(forKey: name)
        setExportPresets(presets)
    }
    
    func getExportPreset<T: Codable>(_ name: String, as type: T.Type) -> T? {
        let presets = getExportPresets() ?? [:]
        guard let presetData = presets[name] as? T else { return nil }
        
        do {
            let data = try JSONEncoder().encode(presetData)
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to decode export preset: \(error)")
            return nil
        }
    }
    
    private func setExportPresets(_ presets: [String: Any]) {
        do {
            exportPresets = try JSONSerialization.data(withJSONObject: presets)
        } catch {
            print("Failed to encode export presets: \(error)")
        }
    }
    
    private func getExportPresets() -> [String: Any]? {
        guard !exportPresets.isEmpty else { return nil }
        
        do {
            return try JSONSerialization.jsonObject(with: exportPresets) as? [String: Any]
        } catch {
            print("Failed to decode export presets: \(error)")
            return nil
        }
    }
    
    // MARK: - UI State Management
    
    func updateLastSelection(mediaGroup: UUID?, clip: UUID?) {
        lastSelectedMediaGroup = mediaGroup
        lastSelectedClip = clip
    }
    
    func clearLastSelection() {
        lastSelectedMediaGroup = nil
        lastSelectedClip = nil
    }
    
    func setActiveWorkspaceTab(_ tab: String) {
        activeWorkspaceTab = tab
    }
    
    func toggleSidebar() {
        sidebarCollapsed.toggle()
    }
    
    func toggleInspector() {
        inspectorCollapsed.toggle()
    }
    
    func collapseSidebar() {
        sidebarCollapsed = true
    }
    
    func expandSidebar() {
        sidebarCollapsed = false
    }
    
    func collapseInspector() {
        inspectorCollapsed = true
    }
    
    func expandInspector() {
        inspectorCollapsed = false
    }
    
    // MARK: - Processing Settings
    
    func updateProcessingSettings(
        parallel: Bool,
        maxOperations: Int,
        cacheResults: Bool,
        useHardware: Bool
    ) {
        enableParallelProcessing = parallel
        maxConcurrentOperations = max(1, min(16, maxOperations))
        cacheIntermediateResults = cacheResults
        useHardwareAcceleration = useHardware
    }
    
    func toggleParallelProcessing() {
        enableParallelProcessing.toggle()
    }
    
    func toggleCacheResults() {
        cacheIntermediateResults.toggle()
    }
    
    func toggleHardwareAcceleration() {
        useHardwareAcceleration.toggle()
    }
    
    // MARK: - Workflow Settings
    
    func updateGroupingCriteria(_ criteria: GroupingCriteria) {
        groupingCriteria = criteria
    }
    
    func toggleAutoGroupMedia() {
        autoGroupMedia.toggle()
    }
    
    func setColorCodingScheme(_ scheme: ColorCodingScheme) {
        colorCodingScheme = scheme
    }
    
    func setDefaultMediaGroupType(_ type: MediaGroupType) {
        defaultMediaGroupType = type
    }
}
