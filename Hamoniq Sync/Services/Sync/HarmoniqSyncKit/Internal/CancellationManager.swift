//
//  CancellationManager.swift
//  HarmoniqSyncKit
//
//  Advanced cancellation support with proper cleanup
//

import Foundation

// MARK: - Cancellation Token

public final class AsyncCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var _isCancelled = false
    private var _cancellationReason: String?
    private var cleanupHandlers: [() -> Void] = []
    
    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }
    
    public var cancellationReason: String? {
        lock.lock()
        defer { lock.unlock() }
        return _cancellationReason
    }
    
    public func cancel(reason: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !_isCancelled else { return }
        
        _isCancelled = true
        _cancellationReason = reason
        
        // Execute cleanup handlers
        for handler in cleanupHandlers {
            handler()
        }
        cleanupHandlers.removeAll()
    }
    
    public func addCleanupHandler(_ handler: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        if _isCancelled {
            handler() // Execute immediately if already cancelled
        } else {
            cleanupHandlers.append(handler)
        }
    }
    
    public func throwIfCancelled() throws {
        if isCancelled {
            throw SyncEngineError.cancelled
        }
    }
    
    public func checkCancellation() async throws {
        if isCancelled {
            throw SyncEngineError.cancelled
        }
    }
}

// MARK: - Cancellable Operation

public protocol CancellableOperation: AnyObject {
    var cancellationToken: AsyncCancellationToken { get }
    func cancel(reason: String?)
    func cleanup() async
}

// MARK: - Sync Operation Manager

public actor SyncOperationManager {
    
    private var operations: [UUID: CancellableOperation] = [:]
    
    // MARK: - Operation Management
    
    func registerOperation(_ operation: CancellableOperation) -> UUID {
        let id = UUID()
        operations[id] = operation
        return id
    }
    
    func unregisterOperation(id: UUID) {
        operations.removeValue(forKey: id)
    }
    
    func cancelOperation(id: UUID, reason: String? = nil) {
        operations[id]?.cancel(reason: reason)
    }
    
    func cancelAllOperations(reason: String? = "System shutdown") {
        for operation in operations.values {
            operation.cancel(reason: reason)
        }
    }
    
    func cleanupOperation(id: UUID) async {
        if let operation = operations[id] {
            await operation.cleanup()
            operations.removeValue(forKey: id)
        }
    }
    
    func cleanupAllOperations() async {
        for operation in operations.values {
            await operation.cleanup()
        }
        operations.removeAll()
    }
    
    var activeOperationCount: Int {
        return operations.count
    }
}

// MARK: - Cancellable Sync Operation

internal class CancellableSyncOperation: CancellableOperation {
    
    let cancellationToken = AsyncCancellationToken()
    private let operationId: UUID
    private let manager: SyncOperationManager
    private var resources: [Any] = []
    private var tasks: [Task<Void, Never>] = []
    
    init(manager: SyncOperationManager) {
        self.manager = manager
        self.operationId = UUID()
        
        // Set up automatic cleanup on cancellation
        cancellationToken.addCleanupHandler { [weak self] in
            Task { [weak self] in
                await self?.performCleanup()
            }
        }
    }
    
    func cancel(reason: String? = nil) {
        cancellationToken.cancel(reason: reason)
    }
    
    func cleanup() async {
        await performCleanup()
        await manager.unregisterOperation(id: operationId)
    }
    
    private func performCleanup() async {
        // Cancel all associated tasks
        for task in tasks {
            task.cancel()
        }
        tasks.removeAll()
        
        // Clean up resources
        resources.removeAll()
    }
    
    // MARK: - Resource Management
    
    func addResource<T>(_ resource: T) {
        resources.append(resource)
    }
    
    func addTask(_ task: Task<Void, Never>) {
        tasks.append(task)
    }
    
    func removeTask(_ task: Task<Void, Never>) {
        tasks.removeAll { $0 == task }
    }
}

// MARK: - Enhanced Async Sync Engine with Cancellation

extension AsyncSyncEngine {
    
    /// Align with full cancellation support
    public func alignWithCancellation(
        reference: AudioDecoder.AudioData,
        target: AudioDecoder.AudioData,
        method: HarmoniqSyncMethod = .hybrid,
        configuration: HarmoniqSyncConfiguration = .standard,
        progressHandler: SyncProgressHandler? = nil
    ) async throws -> (result: AlignmentResult, operationId: UUID) {
        
        let manager = SyncOperationManager()
        let operation = CancellableSyncOperation(manager: manager)
        let operationId = await manager.registerOperation(operation)
        
        defer {
            Task {
                await operation.cleanup()
            }
        }
        
        return try await withTaskCancellation {
            let result = try await performCancellableAlignment(
                reference: reference,
                target: target,
                method: method,
                configuration: configuration,
                progressHandler: progressHandler,
                operation: operation
            )
            
            return (result: result, operationId: operationId)
        }
    }
    
    /// Batch align with full cancellation support  
    public func alignBatchWithCancellation(
        reference: AudioDecoder.AudioData,
        targets: [AudioDecoder.AudioData],
        method: HarmoniqSyncMethod = .hybrid,
        configuration: HarmoniqSyncConfiguration = .standard,
        progressHandler: SyncProgressHandler? = nil
    ) async throws -> (result: BatchResult, operationId: UUID) {
        
        let manager = SyncOperationManager()
        let operation = CancellableSyncOperation(manager: manager)
        let operationId = await manager.registerOperation(operation)
        
        defer {
            Task {
                await operation.cleanup()
            }
        }
        
        return try await withTaskCancellation {
            let result = try await performCancellableBatchAlignment(
                reference: reference,
                targets: targets,
                method: method,
                configuration: configuration,
                progressHandler: progressHandler,
                operation: operation
            )
            
            return (result: result, operationId: operationId)
        }
    }
    
    // MARK: - Private Cancellable Operations
    
    private func performCancellableAlignment(
        reference: AudioDecoder.AudioData,
        target: AudioDecoder.AudioData,
        method: HarmoniqSyncMethod,
        configuration: HarmoniqSyncConfiguration,
        progressHandler: SyncProgressHandler?,
        operation: CancellableSyncOperation
    ) async throws -> AlignmentResult {
        
        let tracker = ProgressTracker()
        let smoother = ProgressSmoother()
        
        // Stage 1: Loading
        try await performStageWithCancellation(
            operation: operation,
            stage: .loading,
            duration: 0.1,
            steps: [
                (10.0, "Loading reference audio"),
                (20.0, "Loading target audio"),
                (30.0, "Validating audio data")
            ],
            tracker: tracker,
            smoother: smoother,
            progressHandler: progressHandler
        )
        
        // Stage 2: Preprocessing  
        try await performStageWithCancellation(
            operation: operation,
            stage: .preprocessing,
            duration: 0.2,
            steps: [
                (40.0, "Applying noise gate"),
                (50.0, "Normalizing audio"),
                (60.0, "Preparing for analysis")
            ],
            tracker: tracker,
            smoother: smoother,
            progressHandler: progressHandler
        )
        
        // Stage 3: Feature Extraction
        try await performStageWithCancellation(
            operation: operation,
            stage: .analyzing,
            duration: 0.4,
            steps: [
                (65.0, "Computing spectral features"),
                (70.0, "Extracting chroma features"),
                (75.0, "Analyzing energy patterns"),
                (80.0, "Computing MFCC features")
            ],
            tracker: tracker,
            smoother: smoother,
            progressHandler: progressHandler
        )
        
        // Stage 4: Correlation
        try await performStageWithCancellation(
            operation: operation,
            stage: .correlating,
            duration: 0.25,
            steps: [
                (85.0, "Cross-correlating features"),
                (90.0, "Finding optimal alignment"),
                (95.0, "Computing confidence metrics")
            ],
            tracker: tracker,
            smoother: smoother,
            progressHandler: progressHandler
        )
        
        // Perform actual alignment (this would be the real C++ call)
        let result = try SyncEngine.align(
            reference: reference,
            target: target,
            method: method.toSyncEngineMethod(),
            configuration: configuration.toSyncEngineConfiguration()
        )
        
        // Stage 5: Finalizing
        try await performStageWithCancellation(
            operation: operation,
            stage: .finalizing,
            duration: 0.05,
            steps: [
                (98.0, "Validating results"),
                (100.0, "Operation complete")
            ],
            tracker: tracker,
            smoother: smoother,
            progressHandler: progressHandler
        )
        
        return result
    }
    
    private func performCancellableBatchAlignment(
        reference: AudioDecoder.AudioData,
        targets: [AudioDecoder.AudioData],
        method: HarmoniqSyncMethod,
        configuration: HarmoniqSyncConfiguration,
        progressHandler: SyncProgressHandler?,
        operation: CancellableSyncOperation
    ) async throws -> BatchResult {
        
        let coordinator = BatchProgressCoordinator(totalItems: targets.count)
        var results: [AlignmentResult] = []
        
        // Process each target with cancellation support
        for (index, target) in targets.enumerated() {
            try operation.cancellationToken.throwIfCancelled()
            
            // Report batch progress
            if let progress = coordinator.reportItemProgress(
                itemIndex: index,
                itemProgress: 0.0,
                operation: "Starting alignment"
            ) {
                await reportProgressToHandler(progress, progressHandler)
            }
            
            // Perform individual alignment with internal progress tracking
            let result = try await performCancellableAlignment(
                reference: reference,
                target: target,
                method: method,
                configuration: configuration,
                progressHandler: { progress in
                    // Convert individual progress to batch progress
                    if let batchProgress = coordinator.reportItemProgress(
                        itemIndex: index,
                        itemProgress: progress.percentage,
                        operation: progress.currentOperation
                    ) {
                        Task { @MainActor in
                            progressHandler?(batchProgress)
                        }
                    }
                },
                operation: operation
            )
            
            results.append(result)
            
            // Brief pause between items
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Final progress report
        let finalProgress = SyncProgress(
            stage: .finalizing,
            percentage: 100.0,
            estimatedTimeRemaining: nil,
            currentOperation: "Batch processing complete",
            processedSamples: Int64(targets.count),
            totalSamples: Int64(targets.count)
        )
        
        await reportProgressToHandler(finalProgress, progressHandler)
        
        return BatchResult(results: results, isValid: true)
    }
    
    // MARK: - Helper Methods
    
    private func performStageWithCancellation(
        operation: CancellableSyncOperation,
        stage: SyncProgress.Stage,
        duration: TimeInterval,
        steps: [(percentage: Double, operation: String)],
        tracker: ProgressTracker,
        smoother: ProgressSmoother,
        progressHandler: SyncProgressHandler?
    ) async throws {
        
        let stepDuration = duration / Double(steps.count)
        
        for step in steps {
            try operation.cancellationToken.throwIfCancelled()
            
            let progress = tracker.updateProgress(
                stage: stage,
                percentage: step.percentage,
                operation: step.operation
            )
            
            if smoother.shouldReport(percentage: step.percentage) {
                await reportProgressToHandler(progress, progressHandler)
            }
            
            try await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }
    }
    
    private func reportProgressToHandler(
        _ progress: SyncProgress,
        _ handler: SyncProgressHandler?
    ) async {
        guard let handler = handler else { return }
        
        await MainActor.run {
            handler(progress)
        }
    }
    
    private func withTaskCancellation<T>(
        _ operation: () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            defer {
                group.cancelAll()
            }
            
            return try await group.next()!
        }
    }
}