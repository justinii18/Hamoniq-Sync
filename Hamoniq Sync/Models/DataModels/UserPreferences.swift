//
//  UserPreferences.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData

@Model
final class UserPreferences {
    @Attribute(.unique) var id: UUID
    
    // General preferences
    var showWelcomeScreen: Bool
    var autoOpenLastProject: Bool
    var confirmBeforeDeleting: Bool
    var showAdvancedOptions: Bool
    var enableAutoSave: Bool
    var autoSaveInterval: TimeInterval
    
    // Sync preferences
    var defaultSyncStrategy: SyncStrategy
    var defaultConfidenceThreshold: Double
    var enableDriftCorrection: Bool
    var autoSyncOnImport: Bool
    var defaultAlgorithmMask: [AlignmentMethod]
    
    // UI preferences
    var preferredTheme: AppTheme
    var sidebarWidth: Double
    var timelineHeight: Double
    var waveformStyle: WaveformStyle
    var showTimecode: Bool
    var colorCodingScheme: ColorCodingScheme
    
    // Performance preferences
    var maxConcurrentJobs: Int
    var enableBackgroundProcessing: Bool
    var cachePreviewImages: Bool
    var optimizeForBattery: Bool
    var maxMemoryUsageMB: Int
    
    // Export preferences
    var defaultExportLocation: URL?
    var defaultNLETarget: NLETarget
    var autoOpenAfterExport: Bool
    var defaultExportFormat: ExportFormat
    
    // Advanced preferences
    var enableDebugLogging: Bool
    var enableBetaFeatures: Bool
    var sendAnonymousUsageData: Bool
    var checkForUpdatesAutomatically: Bool
    
    // Keyboard shortcuts (stored as JSON)
    var keyboardShortcuts: Data
    
    init() {
        self.id = UUID()
        
        // General defaults
        self.showWelcomeScreen = true
        self.autoOpenLastProject = false
        self.confirmBeforeDeleting = true
        self.showAdvancedOptions = false
        self.enableAutoSave = true
        self.autoSaveInterval = 300 // 5 minutes
        
        // Sync defaults
        self.defaultSyncStrategy = .auto
        self.defaultConfidenceThreshold = 0.7
        self.enableDriftCorrection = true
        self.autoSyncOnImport = false
        self.defaultAlgorithmMask = [.spectralFlux, .chroma, .energy]
        
        // UI defaults
        self.preferredTheme = .system
        self.sidebarWidth = 250.0
        self.timelineHeight = 120.0
        self.waveformStyle = .vertical
        self.showTimecode = true
        self.colorCodingScheme = .confidenceLevel
        
        // Performance defaults
        self.maxConcurrentJobs = 4
        self.enableBackgroundProcessing = true
        self.cachePreviewImages = true
        self.optimizeForBattery = false
        self.maxMemoryUsageMB = 2048
        
        // Export defaults
        self.defaultNLETarget = .finalCutPro
        self.autoOpenAfterExport = false
        self.defaultExportFormat = .fcpxml
        
        // Advanced defaults
        self.enableDebugLogging = false
        self.enableBetaFeatures = false
        self.sendAnonymousUsageData = false
        self.checkForUpdatesAutomatically = true
        
        // Empty keyboard shortcuts (will be populated with defaults)
        self.keyboardShortcuts = Data()
    }
    
    // MARK: - Computed Properties
    
    var effectiveMaxConcurrentJobs: Int {
        let processorCount = ProcessInfo.processInfo.processorCount
        return min(maxConcurrentJobs, max(1, processorCount))
    }
    
    var isMemoryOptimized: Bool {
        return optimizeForBattery || maxMemoryUsageMB < 1024
    }
    
    var shouldShowAdvancedFeatures: Bool {
        return showAdvancedOptions || enableBetaFeatures
    }
    
    var autoSaveIntervalMinutes: Double {
        return autoSaveInterval / 60.0
    }
    
    // MARK: - Methods
    
    func updateSidebarWidth(_ width: Double) {
        sidebarWidth = max(200.0, min(400.0, width))
    }
    
    func updateTimelineHeight(_ height: Double) {
        timelineHeight = max(80.0, min(300.0, height))
    }
    
    func updateConfidenceThreshold(_ threshold: Double) {
        defaultConfidenceThreshold = max(0.0, min(1.0, threshold))
    }
    
    func updateMaxConcurrentJobs(_ count: Int) {
        maxConcurrentJobs = max(1, min(16, count))
    }
    
    func updateMaxMemoryUsage(_ megabytes: Int) {
        maxMemoryUsageMB = max(256, min(16384, megabytes))
    }
    
    func updateAutoSaveInterval(_ seconds: TimeInterval) {
        autoSaveInterval = max(60.0, min(3600.0, seconds)) // 1 minute to 1 hour
    }
    
    func setExportDefaults(target: NLETarget, format: ExportFormat, location: URL?) {
        defaultNLETarget = target
        defaultExportFormat = format
        defaultExportLocation = location
    }
    
    func toggleWelcomeScreen() {
        showWelcomeScreen.toggle()
    }
    
    func toggleAutoOpenLastProject() {
        autoOpenLastProject.toggle()
    }
    
    func toggleConfirmBeforeDeleting() {
        confirmBeforeDeleting.toggle()
    }
    
    func toggleAdvancedOptions() {
        showAdvancedOptions.toggle()
    }
    
    func toggleAutoSave() {
        enableAutoSave.toggle()
    }
    
    func toggleDriftCorrection() {
        enableDriftCorrection.toggle()
    }
    
    func toggleAutoSyncOnImport() {
        autoSyncOnImport.toggle()
    }
    
    func toggleBackgroundProcessing() {
        enableBackgroundProcessing.toggle()
    }
    
    func toggleCachePreviewImages() {
        cachePreviewImages.toggle()
    }
    
    func toggleOptimizeForBattery() {
        optimizeForBattery.toggle()
    }
    
    func toggleAutoOpenAfterExport() {
        autoOpenAfterExport.toggle()
    }
    
    func toggleDebugLogging() {
        enableDebugLogging.toggle()
    }
    
    func toggleBetaFeatures() {
        enableBetaFeatures.toggle()
    }
    
    func toggleAnonymousUsageData() {
        sendAnonymousUsageData.toggle()
    }
    
    func toggleAutomaticUpdates() {
        checkForUpdatesAutomatically.toggle()
    }
    
    func addAlgorithmToDefault(_ method: AlignmentMethod) {
        if !defaultAlgorithmMask.contains(method) {
            defaultAlgorithmMask.append(method)
        }
    }
    
    func removeAlgorithmFromDefault(_ method: AlignmentMethod) {
        defaultAlgorithmMask.removeAll { $0 == method }
    }
    
    func setDefaultAlgorithms(_ methods: [AlignmentMethod]) {
        defaultAlgorithmMask = methods
    }
    
    func resetToDefaults() {
        let defaults = UserPreferences()
        
        // Copy default values
        showWelcomeScreen = defaults.showWelcomeScreen
        autoOpenLastProject = defaults.autoOpenLastProject
        confirmBeforeDeleting = defaults.confirmBeforeDeleting
        showAdvancedOptions = defaults.showAdvancedOptions
        enableAutoSave = defaults.enableAutoSave
        autoSaveInterval = defaults.autoSaveInterval
        
        defaultSyncStrategy = defaults.defaultSyncStrategy
        defaultConfidenceThreshold = defaults.defaultConfidenceThreshold
        enableDriftCorrection = defaults.enableDriftCorrection
        autoSyncOnImport = defaults.autoSyncOnImport
        defaultAlgorithmMask = defaults.defaultAlgorithmMask
        
        preferredTheme = defaults.preferredTheme
        sidebarWidth = defaults.sidebarWidth
        timelineHeight = defaults.timelineHeight
        waveformStyle = defaults.waveformStyle
        showTimecode = defaults.showTimecode
        colorCodingScheme = defaults.colorCodingScheme
        
        maxConcurrentJobs = defaults.maxConcurrentJobs
        enableBackgroundProcessing = defaults.enableBackgroundProcessing
        cachePreviewImages = defaults.cachePreviewImages
        optimizeForBattery = defaults.optimizeForBattery
        maxMemoryUsageMB = defaults.maxMemoryUsageMB
        
        defaultNLETarget = defaults.defaultNLETarget
        autoOpenAfterExport = defaults.autoOpenAfterExport
        defaultExportFormat = defaults.defaultExportFormat
        
        enableDebugLogging = defaults.enableDebugLogging
        enableBetaFeatures = defaults.enableBetaFeatures
        sendAnonymousUsageData = defaults.sendAnonymousUsageData
        checkForUpdatesAutomatically = defaults.checkForUpdatesAutomatically
    }
    
    func setKeyboardShortcuts<T: Codable>(_ shortcuts: T) {
        do {
            keyboardShortcuts = try JSONEncoder().encode(shortcuts)
        } catch {
            print("Failed to encode keyboard shortcuts: \(error)")
        }
    }
    
    func getKeyboardShortcuts<T: Codable>(as type: T.Type) -> T? {
        guard !keyboardShortcuts.isEmpty else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: keyboardShortcuts)
        } catch {
            print("Failed to decode keyboard shortcuts: \(error)")
            return nil
        }
    }
}