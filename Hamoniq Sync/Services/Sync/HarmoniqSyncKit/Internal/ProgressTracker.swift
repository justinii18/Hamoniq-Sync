//
//  ProgressTracker.swift
//  HarmoniqSyncKit
//
//  Advanced progress tracking with time estimation
//

import Foundation

// MARK: - Progress Tracker

internal class ProgressTracker: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let lock = NSLock()
    private var startTime: Date
    private var lastProgressTime: Date
    private var progressHistory: [(percentage: Double, time: Date)] = []
    private let maxHistorySize = 10
    
    private var _currentStage: SyncProgress.Stage = .loading
    private var _totalSamples: Int64 = 0
    private var _processedSamples: Int64 = 0
    
    // MARK: - Initialization
    
    init() {
        let now = Date()
        self.startTime = now
        self.lastProgressTime = now
    }
    
    // MARK: - Progress Tracking
    
    func updateProgress(
        stage: SyncProgress.Stage,
        percentage: Double,
        operation: String,
        processedSamples: Int64 = 0,
        totalSamples: Int64 = 0
    ) -> SyncProgress {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        _currentStage = stage
        _processedSamples = processedSamples
        _totalSamples = totalSamples
        
        // Update progress history
        progressHistory.append((percentage: percentage, time: now))
        if progressHistory.count > maxHistorySize {
            progressHistory.removeFirst()
        }
        
        lastProgressTime = now
        
        return SyncProgress(
            stage: stage,
            percentage: max(0, min(100, percentage)),
            estimatedTimeRemaining: calculateTimeRemaining(currentPercentage: percentage),
            currentOperation: operation,
            processedSamples: processedSamples,
            totalSamples: totalSamples
        )
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        startTime = now
        lastProgressTime = now
        progressHistory.removeAll()
        _currentStage = .loading
        _processedSamples = 0
        _totalSamples = 0
    }
    
    // MARK: - Time Estimation
    
    private func calculateTimeRemaining(currentPercentage: Double) -> TimeInterval? {
        guard currentPercentage > 0 && currentPercentage < 100 else { return nil }
        guard progressHistory.count >= 2 else {
            // Fallback estimation for early stages
            return estimateFromStage(currentPercentage: currentPercentage)
        }
        
        // Calculate progress rate from recent history
        let recentProgress = progressHistory.suffix(min(5, progressHistory.count))
        guard recentProgress.count >= 2 else { return nil }
        
        let first = recentProgress.first!
        let last = recentProgress.last!
        
        let progressDelta = last.percentage - first.percentage
        let timeDelta = last.time.timeIntervalSince(first.time)
        
        guard progressDelta > 0 && timeDelta > 0 else { return nil }
        
        // Calculate rate (percentage per second)
        let progressRate = progressDelta / timeDelta
        
        // Estimate remaining time
        let remainingPercentage = 100.0 - currentPercentage
        let estimatedTimeRemaining = remainingPercentage / progressRate
        
        // Apply stage-based adjustments
        let adjustedTime = adjustTimeForStage(_currentStage, baseTime: estimatedTimeRemaining)
        
        // Clamp to reasonable bounds
        return max(0.1, min(300.0, adjustedTime)) // Between 0.1s and 5 minutes
    }
    
    private func estimateFromStage(currentPercentage: Double) -> TimeInterval {
        let baseTimeForStage: TimeInterval
        
        switch _currentStage {
        case .loading:
            baseTimeForStage = 0.5
        case .preprocessing:
            baseTimeForStage = 1.0
        case .analyzing:
            baseTimeForStage = 3.0
        case .correlating:
            baseTimeForStage = 2.0
        case .finalizing:
            baseTimeForStage = 0.2
        }
        
        let stageProgress = currentPercentage / 100.0
        return baseTimeForStage * (1.0 - stageProgress)
    }
    
    private func adjustTimeForStage(_ stage: SyncProgress.Stage, baseTime: TimeInterval) -> TimeInterval {
        let multiplier: Double
        
        switch stage {
        case .loading:
            multiplier = 0.8 // Loading is usually faster than estimated
        case .preprocessing:
            multiplier = 1.0 // Preprocessing is fairly predictable
        case .analyzing:
            multiplier = 1.2 // Feature extraction can vary
        case .correlating:
            multiplier = 1.1 // Correlation is slightly unpredictable
        case .finalizing:
            multiplier = 0.9 // Finalizing is usually quick
        }
        
        return baseTime * multiplier
    }
    
    // MARK: - Progress Statistics
    
    var elapsedTime: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return Date().timeIntervalSince(startTime)
    }
    
    var averageProgressRate: Double? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let first = progressHistory.first,
              let last = progressHistory.last,
              progressHistory.count > 1 else { return nil }
        
        let progressDelta = last.percentage - first.percentage
        let timeDelta = last.time.timeIntervalSince(first.time)
        
        guard timeDelta > 0 else { return nil }
        return progressDelta / timeDelta
    }
}

// MARK: - Progress Smoothing

internal class ProgressSmoother {
    private var lastReportedPercentage: Double = 0
    private var lastReportTime: Date = Date()
    private let minimumInterval: TimeInterval = 0.1 // 10 Hz max
    private let smoothingFactor: Double = 0.3
    
    func shouldReport(percentage: Double) -> Bool {
        let now = Date()
        let timeSinceLastReport = now.timeIntervalSince(lastReportTime)
        
        // Always report significant progress jumps or final completion
        if percentage >= 100.0 || abs(percentage - lastReportedPercentage) > 5.0 {
            updateLastReport(percentage: percentage, time: now)
            return true
        }
        
        // Throttle frequent updates
        if timeSinceLastReport < minimumInterval {
            return false
        }
        
        updateLastReport(percentage: percentage, time: now)
        return true
    }
    
    func smoothedPercentage(_ newPercentage: Double) -> Double {
        // Apply exponential smoothing to reduce jitter
        let smoothed = (smoothingFactor * newPercentage) + 
                      ((1.0 - smoothingFactor) * lastReportedPercentage)
        return min(newPercentage, smoothed) // Never go backwards
    }
    
    private func updateLastReport(percentage: Double, time: Date) {
        lastReportedPercentage = percentage
        lastReportTime = time
    }
    
    func reset() {
        lastReportedPercentage = 0
        lastReportTime = Date()
    }
}

// MARK: - Batch Progress Coordinator

internal class BatchProgressCoordinator {
    private let totalItems: Int
    private let tracker = ProgressTracker()
    private let smoother = ProgressSmoother()
    
    init(totalItems: Int) {
        self.totalItems = totalItems
    }
    
    func reportItemProgress(
        itemIndex: Int,
        itemProgress: Double,
        operation: String
    ) -> SyncProgress? {
        // Calculate overall progress
        let itemWeight = 100.0 / Double(totalItems)
        let completedItems = Double(itemIndex)
        let currentItemProgress = itemProgress / 100.0
        
        let overallPercentage = (completedItems + currentItemProgress) * itemWeight
        
        // Determine stage based on item progress
        let stage: SyncProgress.Stage
        if itemProgress < 10 {
            stage = .loading
        } else if itemProgress < 30 {
            stage = .preprocessing
        } else if itemProgress < 80 {
            stage = .analyzing
        } else if itemProgress < 95 {
            stage = .correlating
        } else {
            stage = .finalizing
        }
        
        // Check if we should report this progress
        guard smoother.shouldReport(percentage: overallPercentage) else {
            return nil
        }
        
        let smoothedPercentage = smoother.smoothedPercentage(overallPercentage)
        
        let batchOperation = "Processing item \(itemIndex + 1) of \(totalItems): \(operation)"
        
        return tracker.updateProgress(
            stage: stage,
            percentage: smoothedPercentage,
            operation: batchOperation,
            processedSamples: Int64(itemIndex + 1),
            totalSamples: Int64(totalItems)
        )
    }
    
    func reset() {
        tracker.reset()
        smoother.reset()
    }
}