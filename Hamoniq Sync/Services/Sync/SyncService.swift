//
//  SyncService.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import Combine

@MainActor
final class SyncService: CancellableService, SyncServiceProtocol {
    
    // MARK: - Type Aliases
    
    typealias SyncSource = Clip
    typealias SyncTarget = [Clip]
    typealias SyncResultModel = Hamoniq_Sync.SyncResult
    typealias SyncResult = [SyncResultModel]
    typealias SyncConfiguration = SyncParameters
    
    // MARK: - State
    
    struct State {
        var currentJob: SyncJob?
        var activeJobs: [SyncJob] = []
        var completedJobs: [SyncJob] = []
        var isProcessing: Bool = false
        var processingProgress: Float = 0.0
        var processingStatus: String = ""
    }
    
    @Published private(set) var syncState = State()
    
    // MARK: - Dependencies
    
    private let dataController: DataController
    
    // MARK: - Publishers
    
    private let resultsSubject = PassthroughSubject<SyncResult, Never>()
    private let errorSubject = PassthroughSubject<Error, Never>()
    
    var resultsPublisher: AnyPublisher<SyncResult, Never> {
        resultsSubject.eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init(dataController: DataController) {
        self.dataController = dataController
        super.init()
    }
    
    func handleError(_ error: Error) {
        errorSubject.send(error)
    }
    
    func clearErrors() {
        // No-op for now
    }
    
    // MARK: - SyncServiceProtocol Implementation
    
    func sync(
        source: Clip,
        target: [Clip],
        configuration: SyncParameters
    ) async throws -> SyncResult {
        try requireInitialized()
        
        guard !isCancelled else {
            throw SyncServiceError.operationCancelled
        }
        
        // Create sync job
        let job = SyncJob(
            type: target.count > 1 ? .multiCam : .singlePair,
            referenceClipID: source.id,
            targetClipIDs: target.map(\.id)
        )
        
        // Store sync parameters
        job.setSyncParameters(configuration)
        
        // Add to active jobs
        syncState.activeJobs.append(job)
        syncState.currentJob = job
        syncState.isProcessing = true
        
        updateProgress(0.0, status: "Starting sync operation...")
        
        do {
            job.start()
            
            let results = try await performSync(
                source: source,
                targets: target,
                configuration: configuration,
                job: job
            )
            
            // Complete the job
            job.complete()
            syncState.completedJobs.append(job)
            syncState.activeJobs.removeAll { $0.id == job.id }
            syncState.currentJob = nil
            syncState.isProcessing = false
            
            // Save results to database
            for result in results {
                source.addSyncResult(result)
                job.addSyncResult(result)
                dataController.mainContext.insert(result)
            }
            dataController.save()
            
            updateProgress(1.0, status: "Sync completed")
            resultsSubject.send(results)
            
            return results
            
        } catch {
            job.fail(with: error.localizedDescription)
            syncState.activeJobs.removeAll { $0.id == job.id }
            syncState.currentJob = nil
            syncState.isProcessing = false
            
            throw error
        }
    }
    
    func batchSync(
        sources: [Clip],
        targets: [[Clip]],
        configuration: SyncParameters
    ) async throws -> [SyncResult] {
        try requireInitialized()
        
        guard !isCancelled else {
            throw SyncServiceError.operationCancelled
        }
        
        let flattenedTargets = targets.flatMap { $0 }
        let job = SyncJob(
            type: .batch,
            referenceClipID: sources.first?.id ?? UUID(),
            targetClipIDs: flattenedTargets.map(\.id)
        )
        
        job.setSyncParameters(configuration)
        
        syncState.activeJobs.append(job)
        syncState.currentJob = job
        syncState.isProcessing = true
        
        updateProgress(0.0, status: "Starting batch sync...")
        
        do {
            job.start()
            var resultsBySource: [SyncResult] = []
            var flattenedResults: SyncResult = []
            
            for (index, source) in sources.enumerated() {
                if isCancelled {
                    throw SyncServiceError.operationCancelled
                }
                
                let progress = Float(index) / Float(sources.count)
                updateProgress(progress, status: "Syncing \(source.filename)...")
                
                let targetCandidates = flattenedTargets.filter { $0.id != source.id }
                let results = try await performSync(
                    source: source,
                    targets: targetCandidates,
                    configuration: configuration,
                    job: job
                )
                
                resultsBySource.append(results)
                flattenedResults.append(contentsOf: results)
            }
            
            job.complete()
            syncState.completedJobs.append(job)
            syncState.activeJobs.removeAll { $0.id == job.id }
            syncState.currentJob = nil
            syncState.isProcessing = false
            
            // Save all results
            for result in flattenedResults {
                job.addSyncResult(result)
                dataController.mainContext.insert(result)
            }
            dataController.save()
            
            updateProgress(1.0, status: "Batch sync completed")
            resultsSubject.send(flattenedResults)
            
            return resultsBySource
            
        } catch {
            job.fail(with: error.localizedDescription)
            syncState.activeJobs.removeAll { $0.id == job.id }
            syncState.currentJob = nil
            syncState.isProcessing = false
            
            throw error
        }
    }
    
    // MARK: - Core Sync Implementation
    
    private func performSync(
        source: Clip,
        targets: [Clip],
        configuration: SyncParameters,
        job: SyncJob
    ) async throws -> SyncResult {
        
        var results: SyncResult = []
        
        for (index, target) in targets.enumerated() {
            if isCancelled {
                throw SyncServiceError.operationCancelled
            }
            
            let progress = Float(index) / Float(targets.count)
            updateProgress(progress, status: "Aligning \(target.filename) with \(source.filename)...")
            
            let result = try await alignClips(
                reference: source,
                target: target,
                configuration: configuration
            )
            
            results.append(result)
        }
        
        return results
    }
    
    private func alignClips(
        reference: Clip,
        target: Clip,
        configuration: SyncParameters
    ) async throws -> SyncResultModel {
        
        // Simulate processing time for now
        for i in 0...10 {
            if isCancelled {
                throw SyncServiceError.operationCancelled
            }
            
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            let progress = Float(i) / 10.0
            updateProgress(progress, status: "Analyzing audio features...")
        }
        
        // For now, create a mock result
        // TODO: Replace with real sync engine implementation
        let mockResult = createMockSyncResult(
            sourceClipID: reference.id,
            targetClipID: target.id,
            configuration: configuration
        )
        
        return mockResult
    }
    
    private func createMockSyncResult(
        sourceClipID: UUID,
        targetClipID: UUID,
        configuration: SyncParameters
    ) -> SyncResultModel {
        
        // Generate a realistic but random sync result
        let offsetSamples = Int64.random(in: -44100...44100) // ±1 second at 44.1kHz
        let confidence = Double.random(in: 0.6...0.95)
        let method = configuration.preferredMethods.randomElement() ?? .spectralFlux
        
        let result = SyncResultModel(
            sourceClipID: sourceClipID,
            targetClipID: targetClipID,
            offset: offsetSamples,
            confidence: confidence,
            method: method
        )
        
        // Add some realistic quality metrics
        result.updateQualityMetrics(
            peakCorrelation: confidence * 0.9 + Double.random(in: 0...0.1),
            secondaryPeakRatio: Double.random(in: 1.5...3.0),
            snrEstimate: Double.random(in: 20...40),
            noiseFloorDb: Double.random(in: -70 ... -50)
        )
        
        // Randomly add drift if enabled
        if configuration.enableDriftCorrection && Double.random(in: 0...1) > 0.7 {
            result.updateDriftInfo(
                detected: true,
                ppm: Double.random(in: -10...10),
                correctionApplied: true
            )
        }
        
        result.validate()
        
        return result
    }
    
    // MARK: - Public API Extensions
    
    func syncMediaGroup(
        _ mediaGroup: MediaGroup,
        in project: Project,
        strategy: SyncStrategy,
        confidenceThreshold: Double
    ) async throws -> SyncResult {
        
        guard let referenceClip = mediaGroup.referenceClip else {
            throw SyncServiceError.noReferenceClip
        }
        
        let targetClips = mediaGroup.clips.filter { $0.id != referenceClip.id }
        
        guard !targetClips.isEmpty else {
            throw SyncServiceError.noTargetClips
        }
        
        let configuration = SyncParameters(
            strategy: strategy,
            confidenceThreshold: confidenceThreshold,
            enableDriftCorrection: project.projectSettings?.enableDriftCorrection ?? true,
            preferredMethods: project.projectSettings?.preferredAlgorithms ?? [.spectralFlux, .chroma, .energy]
        )
        
        return try await sync(
            source: referenceClip,
            target: targetClips,
            configuration: configuration
        )
    }
    
    func cancelCurrentOperation() {
        cancel()
        
        if let currentJob = syncState.currentJob {
            currentJob.cancel()
        }
        
        syncState.currentJob = nil
        syncState.isProcessing = false
        updateProgress(0.0, status: "Cancelled")
    }
    
    // MARK: - Job Management
    
    func getActiveJobs() -> [SyncJob] {
        return syncState.activeJobs
    }
    
    func getCompletedJobs() -> [SyncJob] {
        return syncState.completedJobs
    }
    
    func clearCompletedJobs() {
        syncState.completedJobs.removeAll()
    }
    
    // MARK: - Algorithm Support
    
    func getSupportedAlgorithms() -> [AlignmentMethod] {
        return AlignmentMethod.allCases.filter { $0.isAutomatic }
    }
    
    func getAlgorithmDescription(_ method: AlignmentMethod) -> String {
        return method.description
    }
    
    func validateSyncConfiguration(_ configuration: SyncParameters) -> Bool {
        return configuration.confidenceThreshold > 0 &&
               configuration.confidenceThreshold <= 1.0 &&
               !configuration.preferredMethods.isEmpty
    }
    
}

// MARK: - Sync Parameters

struct SyncParameters: Codable {
    let strategy: SyncStrategy
    let confidenceThreshold: Double
    let enableDriftCorrection: Bool
    let preferredMethods: [AlignmentMethod]
    let maxOffsetSeconds: Double
    let sampleRate: Double
    
    init(
        strategy: SyncStrategy,
        confidenceThreshold: Double = 0.7,
        enableDriftCorrection: Bool = true,
        preferredMethods: [AlignmentMethod] = [.spectralFlux, .chroma, .energy],
        maxOffsetSeconds: Double = 300.0,
        sampleRate: Double = 44100.0
    ) {
        self.strategy = strategy
        self.confidenceThreshold = confidenceThreshold
        self.enableDriftCorrection = enableDriftCorrection
        self.preferredMethods = preferredMethods
        self.maxOffsetSeconds = maxOffsetSeconds
        self.sampleRate = sampleRate
    }
}

// MARK: - Error Types

enum SyncServiceError: LocalizedError {
    case operationCancelled
    case noReferenceClip
    case noTargetClips
    case invalidConfiguration
    case processingFailed(String)
    case insufficientAudioData
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .operationCancelled:
            return "Sync operation was cancelled"
        case .noReferenceClip:
            return "No reference clip found for synchronization"
        case .noTargetClips:
            return "No target clips found for synchronization"
        case .invalidConfiguration:
            return "Invalid sync configuration provided"
        case .processingFailed(let reason):
            return "Sync processing failed: \(reason)"
        case .insufficientAudioData:
            return "Insufficient audio data for synchronization"
        case .unsupportedFormat:
            return "Unsupported audio format for synchronization"
        }
    }
}
