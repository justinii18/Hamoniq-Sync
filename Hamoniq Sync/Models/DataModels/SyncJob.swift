//
//  SyncJob.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData

@Model
final class SyncJob {
    @Attribute(.unique) var id: UUID
    var jobType: SyncJobType
    var status: JobStatus
    var progress: Float
    var statusMessage: String
    
    // Job configuration
    var referenceClipID: UUID
    var targetClipIDs: [UUID]
    var syncParameters: Data // Encoded SyncParameters
    var priority: JobPriority
    
    // Timing
    var createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var estimatedDuration: TimeInterval?
    
    // Results
    var resultsCount: Int
    var averageConfidence: Double?
    var errorMessage: String?
    
    // Relationships
    @Relationship var syncResults: [SyncResult]
    @Relationship(inverse: \Project.syncJobs) var project: Project?
    
    init(type: SyncJobType, referenceClipID: UUID, targetClipIDs: [UUID]) {
        self.id = UUID()
        self.jobType = type
        self.status = .queued
        self.progress = 0.0
        self.statusMessage = "Queued"
        self.referenceClipID = referenceClipID
        self.targetClipIDs = targetClipIDs
        self.syncParameters = Data() // Will be encoded from SyncParameters
        self.priority = .normal
        self.createdAt = Date()
        self.resultsCount = 0
        self.syncResults = []
    }
    
    // MARK: - Computed Properties
    
    var duration: TimeInterval? {
        guard let startedAt = startedAt,
              let completedAt = completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }
    
    var isCompleted: Bool {
        return status == .completed || status == .failed || status == .cancelled
    }
    
    var isRunning: Bool {
        return status == .running
    }
    
    var isPaused: Bool {
        return status == .paused
    }
    
    var isFailed: Bool {
        return status == .failed
    }
    
    var isCancelled: Bool {
        return status == .cancelled
    }
    
    var canStart: Bool {
        return status == .queued
    }
    
    var canPause: Bool {
        return status == .running
    }
    
    var canResume: Bool {
        return status == .paused
    }
    
    var canCancel: Bool {
        return status == .queued || status == .running || status == .paused
    }
    
    var targetClipCount: Int {
        return targetClipIDs.count
    }
    
    var expectedResultCount: Int {
        return targetClipCount
    }
    
    var progressPercentage: String {
        return String(format: "%.1f%%", progress * 100)
    }
    
    var timeRemaining: TimeInterval? {
        guard progress > 0, progress < 1.0,
              let startedAt = startedAt else { return nil }
        
        let elapsed = Date().timeIntervalSince(startedAt)
        let totalEstimated = elapsed / Double(progress)
        return totalEstimated - elapsed
    }
    
    var formattedTimeRemaining: String {
        guard let remaining = timeRemaining else { return "Unknown" }
        
        if remaining < 60 {
            return String(format: "%.0fs", remaining)
        } else if remaining < 3600 {
            return String(format: "%.0fm %.0fs", remaining / 60, remaining.truncatingRemainder(dividingBy: 60))
        } else {
            let hours = Int(remaining / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return String(format: "%dh %dm", hours, minutes)
        }
    }
    
    var statusColor: String {
        return status.color
    }
    
    var priorityOrder: Int {
        return priority.sortOrder
    }
    
    // MARK: - Methods
    
    func start() {
        guard canStart else { return }
        
        status = .running
        startedAt = Date()
        progress = 0.0
        statusMessage = "Starting..."
        errorMessage = nil
    }
    
    func pause() {
        guard canPause else { return }
        
        status = .paused
        statusMessage = "Paused"
    }
    
    func resume() {
        guard canResume else { return }
        
        status = .running
        statusMessage = "Resuming..."
    }
    
    func cancel() {
        guard canCancel else { return }
        
        status = .cancelled
        completedAt = Date()
        statusMessage = "Cancelled"
        progress = 0.0
    }
    
    func complete() {
        status = .completed
        completedAt = Date()
        progress = 1.0
        statusMessage = "Completed"
        
        // Update results count and average confidence
        resultsCount = syncResults.count
        if !syncResults.isEmpty {
            let totalConfidence = syncResults.reduce(0.0) { $0 + $1.confidence }
            averageConfidence = totalConfidence / Double(syncResults.count)
        }
    }
    
    func fail(with error: String) {
        status = .failed
        completedAt = Date()
        statusMessage = "Failed"
        errorMessage = error
    }
    
    func updateProgress(_ newProgress: Float, status: String = "") {
        progress = max(0.0, min(1.0, newProgress))
        if !status.isEmpty {
            statusMessage = status
        }
    }
    
    func addSyncResult(_ result: SyncResult) {
        syncResults.append(result)
        result.syncJob = self
        resultsCount = syncResults.count
        
        // Update average confidence
        if !syncResults.isEmpty {
            let totalConfidence = syncResults.reduce(0.0) { $0 + $1.confidence }
            averageConfidence = totalConfidence / Double(syncResults.count)
        }
    }
    
    func removeSyncResult(_ result: SyncResult) {
        syncResults.removeAll { $0.id == result.id }
        result.syncJob = nil
        resultsCount = syncResults.count
        
        // Update average confidence
        if !syncResults.isEmpty {
            let totalConfidence = syncResults.reduce(0.0) { $0 + $1.confidence }
            averageConfidence = totalConfidence / Double(syncResults.count)
        } else {
            averageConfidence = nil
        }
    }
    
    func clearResults() {
        syncResults.removeAll()
        resultsCount = 0
        averageConfidence = nil
    }
    
    func setPriority(_ newPriority: JobPriority) {
        priority = newPriority
    }
    
    func updateEstimatedDuration(_ duration: TimeInterval) {
        estimatedDuration = duration
    }
    
    func setSyncParameters<T: Codable>(_ parameters: T) {
        do {
            syncParameters = try JSONEncoder().encode(parameters)
        } catch {
            print("Failed to encode sync parameters: \(error)")
        }
    }
    
    func getSyncParameters<T: Codable>(as type: T.Type) -> T? {
        do {
            return try JSONDecoder().decode(type, from: syncParameters)
        } catch {
            print("Failed to decode sync parameters: \(error)")
            return nil
        }
    }
}