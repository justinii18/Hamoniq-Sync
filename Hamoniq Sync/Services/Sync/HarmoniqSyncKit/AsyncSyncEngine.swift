//
//  AsyncSyncEngine.swift
//  HarmoniqSyncKit
//
//  Modern async/await API for audio synchronization
//

import Foundation

// MARK: - Progress Handler Type

public typealias SyncProgressHandler = @Sendable (SyncProgress) -> Void

// MARK: - Async Sync Engine

public actor AsyncSyncEngine {
    
    // MARK: - Properties
    
    private var isProcessing = false
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Async Alignment Operations
    
    /// Async alignment of two audio clips with progress reporting
    /// - Parameters:
    ///   - reference: Reference audio data
    ///   - target: Target audio data to align
    ///   - method: Alignment method to use
    ///   - configuration: Sync configuration
    ///   - progressHandler: Optional progress callback
    /// - Returns: Alignment result
    /// - Throws: SyncEngineError on failure
    public func align(
        reference: AudioDecoder.AudioData,
        target: AudioDecoder.AudioData,
        method: HarmoniqSyncMethod = .hybrid,
        configuration: HarmoniqSyncConfiguration = .standard,
        progressHandler: SyncProgressHandler? = nil
    ) async throws -> AlignmentResult {
        
        // Check if already processing
        guard !isProcessing else {
            throw SyncEngineError.processingFailed("Another sync operation is already in progress")
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        return try await withTaskCancellation {
            try await performAlignment(
                reference: reference,
                target: target,
                method: method,
                configuration: configuration,
                progressHandler: progressHandler
            )
        }
    }
    
    /// Async batch alignment with progress reporting
    /// - Parameters:
    ///   - reference: Reference audio data
    ///   - targets: Array of target audio data to align
    ///   - method: Alignment method to use
    ///   - configuration: Sync configuration
    ///   - progressHandler: Optional progress callback
    /// - Returns: Batch alignment results
    /// - Throws: SyncEngineError on failure
    public func alignBatch(
        reference: AudioDecoder.AudioData,
        targets: [AudioDecoder.AudioData],
        method: HarmoniqSyncMethod = .hybrid,
        configuration: HarmoniqSyncConfiguration = .standard,
        progressHandler: SyncProgressHandler? = nil
    ) async throws -> BatchResult {
        
        guard !isProcessing else {
            throw SyncEngineError.processingFailed("Another sync operation is already in progress")
        }
        
        guard !targets.isEmpty else {
            throw SyncEngineError.invalidInput("Target list cannot be empty")
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        return try await withTaskCancellation {
            try await performBatchAlignment(
                reference: reference,
                targets: targets,
                method: method,
                configuration: configuration,
                progressHandler: progressHandler
            )
        }
    }
    
    /// Cancel current operation if running
    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    // MARK: - Private Implementation
    
    private func performAlignment(
        reference: AudioDecoder.AudioData,
        target: AudioDecoder.AudioData,
        method: HarmoniqSyncMethod,
        configuration: HarmoniqSyncConfiguration,
        progressHandler: SyncProgressHandler?
    ) async throws -> AlignmentResult {
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Task {
                do {
                    // Stage 1: Loading (10%)
                    await reportProgress(.loading, 0.0, "Loading audio data", progressHandler)
                    try Task.checkCancellation()
                    
                    // Simulate loading delay
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    await reportProgress(.loading, 10.0, "Audio loaded", progressHandler)
                    try Task.checkCancellation()
                    
                    // Stage 2: Preprocessing (20%)  
                    await reportProgress(.preprocessing, 20.0, "Preprocessing audio", progressHandler)
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    try Task.checkCancellation()
                    
                    // Stage 3: Analyzing (60%)
                    await reportProgress(.analyzing, 40.0, "Extracting features", progressHandler)
                    try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                    try Task.checkCancellation()
                    
                    // Stage 4: Correlating (90%)
                    await reportProgress(.correlating, 70.0, "Computing alignment", progressHandler)
                    try await Task.sleep(nanoseconds: 150_000_000) // 150ms
                    try Task.checkCancellation()
                    
                    // Perform the actual sync operation (using existing sync method)
                    let syncResult = try SyncEngine.align(
                        reference: reference,
                        target: target,
                        method: method.toSyncEngineMethod(),
                        configuration: configuration.toSyncEngineConfiguration()
                    )
                    
                    // Stage 5: Finalizing (100%)
                    await reportProgress(.finalizing, 95.0, "Finalizing results", progressHandler)
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    await reportProgress(.finalizing, 100.0, "Complete", progressHandler)
                    
                    continuation.resume(returning: syncResult.toHarmoniqSyncResult())
                    
                } catch is CancellationError {
                    continuation.resume(throwing: SyncEngineError.cancelled)
                } catch {
                    if let syncError = error as? SyncEngineError {
                        continuation.resume(throwing: syncError)
                    } else {
                        continuation.resume(throwing: SyncEngineError.processingFailed(error.localizedDescription))
                    }
                }
            }
            
            currentTask = task
        }
    }
    
    private func performBatchAlignment(
        reference: AudioDecoder.AudioData,
        targets: [AudioDecoder.AudioData],
        method: HarmoniqSyncMethod,
        configuration: HarmoniqSyncConfiguration,
        progressHandler: SyncProgressHandler?
    ) async throws -> BatchResult {
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Task {
                do {
                    // Stage 1: Loading (5%)
                    await reportProgress(.loading, 0.0, "Loading reference audio", progressHandler)
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 50_000_000)
                    
                    await reportProgress(.loading, 5.0, "Loading target audio files", progressHandler)
                    try await Task.sleep(nanoseconds: UInt64(targets.count * 25_000_000)) // 25ms per target
                    try Task.checkCancellation()
                    
                    // Stage 2: Processing each target (5% to 90%)
                    var results: [AlignmentResult] = []
                    let progressPerTarget = 85.0 / Double(targets.count)
                    
                    for (index, target) in targets.enumerated() {
                        let baseProgress = 5.0 + (Double(index) * progressPerTarget)
                        let targetProgress = baseProgress + (progressPerTarget * 0.5)
                        
                        await reportProgress(.analyzing, targetProgress, 
                                           "Processing target \(index + 1) of \(targets.count)", progressHandler)
                        
                        // Process individual target
                        let result = try SyncEngine.align(
                            reference: reference,
                            target: target,
                            method: method.toSyncEngineMethod(),
                            configuration: configuration.toSyncEngineConfiguration()
                        )
                        results.append(result)
                        
                        try Task.checkCancellation()
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms per result
                    }
                    
                    // Stage 3: Finalizing (90% to 100%)
                    await reportProgress(.finalizing, 90.0, "Aggregating results", progressHandler)
                    try await Task.sleep(nanoseconds: 100_000_000)
                    
                    let batchResult = BatchResult(results: results, isValid: true)
                    
                    await reportProgress(.finalizing, 100.0, "Batch processing complete", progressHandler)
                    
                    continuation.resume(returning: batchResult)
                    
                } catch is CancellationError {
                    continuation.resume(throwing: SyncEngineError.cancelled)
                } catch {
                    if let syncError = error as? SyncEngineError {
                        continuation.resume(throwing: syncError)
                    } else {
                        continuation.resume(throwing: SyncEngineError.processingFailed(error.localizedDescription))
                    }
                }
            }
            
            currentTask = task
        }
    }
    
    // MARK: - Progress Reporting
    
    private func reportProgress(
        _ stage: SyncProgress.Stage,
        _ percentage: Double,
        _ operation: String,
        _ handler: SyncProgressHandler?
    ) async {
        guard let handler = handler else { return }
        
        let progress = SyncProgress(
            stage: stage,
            percentage: percentage,
            estimatedTimeRemaining: calculateTimeRemaining(percentage: percentage),
            currentOperation: operation
        )
        
        // Dispatch to main queue for UI updates
        await MainActor.run {
            handler(progress)
        }
    }
    
    private func calculateTimeRemaining(percentage: Double) -> TimeInterval? {
        guard percentage > 0 && percentage < 100 else { return nil }
        
        // Simple time estimation based on current progress
        // In real implementation, this would be more sophisticated
        let estimatedTotalTime: TimeInterval = 2.0 // seconds
        let elapsed = estimatedTotalTime * (percentage / 100.0)
        let remaining = estimatedTotalTime - elapsed
        
        return remaining > 0.1 ? remaining : nil
    }
}

// MARK: - Task Cancellation Support

extension AsyncSyncEngine {
    private func withTaskCancellation<T>(
        _ operation: () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            // Add cancellation monitoring
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64.max)
                throw SyncEngineError.cancelled
            }
            
            defer {
                group.cancelAll()
            }
            
            return try await group.next()!
        }
    }
}

// MARK: - Convenience Extensions

extension AsyncSyncEngine {
    
    /// Quick align with default parameters
    public func quickAlign(
        reference: AudioDecoder.AudioData,
        target: AudioDecoder.AudioData,
        progressHandler: SyncProgressHandler? = nil
    ) async throws -> AlignmentResult {
        return try await align(
            reference: reference,
            target: target,
            method: .hybrid,
            configuration: .standard,
            progressHandler: progressHandler
        )
    }
    
    /// High accuracy alignment
    public func preciseAlign(
        reference: AudioDecoder.AudioData,
        target: AudioDecoder.AudioData,
        progressHandler: SyncProgressHandler? = nil
    ) async throws -> AlignmentResult {
        return try await align(
            reference: reference,
            target: target,
            method: .hybrid,
            configuration: .highAccuracy,
            progressHandler: progressHandler
        )
    }
    
    /// Fast alignment for real-time use
    public func fastAlign(
        reference: AudioDecoder.AudioData,
        target: AudioDecoder.AudioData,
        progressHandler: SyncProgressHandler? = nil
    ) async throws -> AlignmentResult {
        return try await align(
            reference: reference,
            target: target,
            method: .spectralFlux,
            configuration: .fast,
            progressHandler: progressHandler
        )
    }
}

// MARK: - Batch Result Extensions

extension BatchResult {
    /// Create from individual results
    internal init(results: [AlignmentResult], isValid: Bool) {
        self.results = results
        self.isValid = isValid
    }
    
    /// Get results with confidence above threshold
    public func resultsAboveConfidence(_ threshold: Double) -> [AlignmentResult] {
        return results.filter { $0.confidence >= threshold }
    }
    
    /// Average confidence across all results
    public var averageConfidence: Double {
        guard !results.isEmpty else { return 0.0 }
        return results.map { $0.confidence }.reduce(0, +) / Double(results.count)
    }
    
    /// Best result (highest confidence)
    public var bestResult: AlignmentResult? {
        return results.max { $0.confidence < $1.confidence }
    }
}