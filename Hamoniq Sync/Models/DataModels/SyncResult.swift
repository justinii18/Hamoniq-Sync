//
//  SyncResult.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData

@Model
final class SyncResult {
    @Attribute(.unique) var id: UUID
    var sourceClipID: UUID
    var targetClipID: UUID
    
    // Primary results
    var offsetSamples: Int64
    var offsetSeconds: Double
    var offsetMilliseconds: Double
    var confidence: Double
    var driftPpm: Double
    
    // Algorithm information
    var alignmentMethod: AlignmentMethod
    var primaryAlgorithm: String
    var algorithmDetails: String?
    
    // Quality metrics
    var peakCorrelation: Double
    var secondaryPeakRatio: Double
    var snrEstimate: Double
    var noiseFloorDb: Double
    
    // Drift correction
    var driftDetected: Bool
    var keyframesData: Data? // Encoded keyframe information
    var driftCorrectionApplied: Bool
    
    // Validation and manual adjustment
    var validationStatus: ValidationStatus
    var manuallyAdjusted: Bool
    var manualOffsetAdjustment: Double
    var userNotes: String?
    var isLocked: Bool // Prevent automatic re-sync
    
    // Metadata
    var createdAt: Date
    var lastValidatedAt: Date?
    var processingDuration: TimeInterval
    
    // Relationships
    @Relationship(inverse: \Clip.syncResults) var sourceClip: Clip?
    @Relationship(inverse: \SyncJob.syncResults) var syncJob: SyncJob?
    
    init(sourceClipID: UUID, targetClipID: UUID, offset: Int64, confidence: Double, method: AlignmentMethod) {
        self.id = UUID()
        self.sourceClipID = sourceClipID
        self.targetClipID = targetClipID
        self.offsetSamples = offset
        self.offsetSeconds = Double(offset) / 44100.0 // TODO: Use actual sample rate
        self.offsetMilliseconds = Double(offset) / 44100.0 * 1000.0
        self.confidence = confidence
        self.driftPpm = 0.0
        self.alignmentMethod = method
        self.primaryAlgorithm = method.rawValue
        self.peakCorrelation = 0.0
        self.secondaryPeakRatio = 0.0
        self.snrEstimate = 0.0
        self.noiseFloorDb = -60.0
        self.driftDetected = false
        self.driftCorrectionApplied = false
        self.validationStatus = .pending
        self.manuallyAdjusted = false
        self.manualOffsetAdjustment = 0.0
        self.isLocked = false
        self.createdAt = Date()
        self.processingDuration = 0.0
    }
    
    // MARK: - Computed Properties
    
    var confidenceLevel: ConfidenceLevel {
        return ConfidenceLevel.from(confidence: confidence)
    }
    
    var totalOffset: Double {
        return offsetSeconds + manualOffsetAdjustment
    }
    
    var totalOffsetSamples: Int64 {
        let adjustmentSamples = Int64(manualOffsetAdjustment * 44100.0) // TODO: Use actual sample rate
        return offsetSamples + adjustmentSamples
    }
    
    var totalOffsetMilliseconds: Double {
        return totalOffset * 1000.0
    }
    
    var isHighConfidence: Bool {
        return confidenceLevel == .high
    }
    
    var needsValidation: Bool {
        return validationStatus == .pending || confidenceLevel == .veryLow
    }
    
    var isValid: Bool {
        return validationStatus == .valid && confidence >= 0.4
    }
    
    var hasWarnings: Bool {
        return validationStatus == .warning || (confidence < 0.6 && confidence >= 0.4)
    }
    
    var hasErrors: Bool {
        return validationStatus == .error || confidence < 0.4
    }
    
    var formattedOffset: String {
        let absOffset = abs(totalOffsetMilliseconds)
        let sign = totalOffsetMilliseconds >= 0 ? "+" : "-"
        
        if absOffset >= 1000 {
            return String(format: "%@%.2fs", sign, absOffset / 1000.0)
        } else {
            return String(format: "%@%.0fms", sign, absOffset)
        }
    }
    
    var formattedConfidence: String {
        return String(format: "%.1f%%", confidence * 100)
    }
    
    var qualityScore: Double {
        // Composite quality score based on multiple factors
        var score = confidence * 0.6
        
        // Bonus for high correlation
        if peakCorrelation > 0.8 {
            score += 0.2
        } else if peakCorrelation > 0.6 {
            score += 0.1
        }
        
        // Bonus for good secondary peak ratio
        if secondaryPeakRatio > 2.0 {
            score += 0.1
        }
        
        // Penalty for drift
        if driftDetected {
            score -= 0.1
        }
        
        return min(1.0, max(0.0, score))
    }
    
    // MARK: - Methods
    
    func updateOffset(samples: Int64, sampleRate: Double = 44100.0) {
        offsetSamples = samples
        offsetSeconds = Double(samples) / sampleRate
        offsetMilliseconds = offsetSeconds * 1000.0
        lastValidatedAt = Date()
    }
    
    func updateConfidence(_ newConfidence: Double) {
        confidence = max(0.0, min(1.0, newConfidence))
        lastValidatedAt = Date()
    }
    
    func addManualAdjustment(_ adjustmentSeconds: Double) {
        manualOffsetAdjustment += adjustmentSeconds
        manuallyAdjusted = true
        lastValidatedAt = Date()
    }
    
    func setManualAdjustment(_ adjustmentSeconds: Double) {
        manualOffsetAdjustment = adjustmentSeconds
        manuallyAdjusted = true
        lastValidatedAt = Date()
    }
    
    func clearManualAdjustment() {
        manualOffsetAdjustment = 0.0
        manuallyAdjusted = false
        lastValidatedAt = Date()
    }
    
    func validate() {
        if confidence >= 0.8 {
            validationStatus = .valid
        } else if confidence >= 0.6 {
            validationStatus = .warning
        } else if confidence >= 0.4 {
            validationStatus = .warning
        } else {
            validationStatus = .error
        }
        
        lastValidatedAt = Date()
    }
    
    func setValidationStatus(_ status: ValidationStatus) {
        validationStatus = status
        lastValidatedAt = Date()
    }
    
    func lock() {
        isLocked = true
    }
    
    func unlock() {
        isLocked = false
    }
    
    func addUserNote(_ note: String) {
        if let existingNotes = userNotes, !existingNotes.isEmpty {
            userNotes = existingNotes + "\n" + note
        } else {
            userNotes = note
        }
        lastValidatedAt = Date()
    }
    
    func clearUserNotes() {
        userNotes = nil
        lastValidatedAt = Date()
    }
    
    func updateQualityMetrics(
        peakCorrelation: Double,
        secondaryPeakRatio: Double,
        snrEstimate: Double,
        noiseFloorDb: Double
    ) {
        self.peakCorrelation = peakCorrelation
        self.secondaryPeakRatio = secondaryPeakRatio
        self.snrEstimate = snrEstimate
        self.noiseFloorDb = noiseFloorDb
        lastValidatedAt = Date()
    }
    
    func updateDriftInfo(detected: Bool, ppm: Double, correctionApplied: Bool = false) {
        driftDetected = detected
        driftPpm = ppm
        driftCorrectionApplied = correctionApplied
        lastValidatedAt = Date()
    }
    
    func setProcessingDuration(_ duration: TimeInterval) {
        processingDuration = duration
    }
    
    func setKeyframesData(_ data: Data?) {
        keyframesData = data
    }
}