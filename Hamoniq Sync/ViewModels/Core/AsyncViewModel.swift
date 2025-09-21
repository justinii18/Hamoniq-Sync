//
//  AsyncViewModel.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class AsyncViewModel: BaseViewModel, AsyncOperationHandling {
    
    // MARK: - Additional Published Properties
    
    @Published var operationProgress: Float = 0.0
    @Published var operationStatus: String = ""
    @Published var isProcessing: Bool = false
    
    // MARK: - Private Properties
    
    private var currentTask: Task<Void, Never>?
    private var operationStartTime: Date?
    private var estimatedDuration: TimeInterval?
    
    // MARK: - Cleanup
    
    override func cleanup() {
        super.cleanup()
        cancelCurrentOperation()
    }
    
    // MARK: - Async Operation Handling
    
    func performAsyncOperation<T>(
        _ operation: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void = { _ in },
        onFailure: @escaping (Error) -> Void = { _ in }
    ) {
        cancelCurrentOperation()
        
        currentTask = Task {
            await setProcessingState(true)
            
            do {
                let result = try await operation()
                
                if !Task.isCancelled {
                    onSuccess(result)
                    await setProcessingState(false)
                }
            } catch {
                if !Task.isCancelled {
                    handleError(error)
                    onFailure(error)
                    await setProcessingState(false)
                }
            }
        }
    }
    
    func performAsyncOperationWithProgress<T>(
        _ operation: @escaping (@escaping (Float, String) -> Void) async throws -> T,
        estimatedDuration: TimeInterval? = nil,
        onSuccess: @escaping (T) -> Void = { _ in },
        onFailure: @escaping (Error) -> Void = { _ in }
    ) {
        cancelCurrentOperation()
        
        self.estimatedDuration = estimatedDuration
        
        currentTask = Task {
            await setProcessingState(true)
            
            do {
                let result = try await operation { progress, status in
                    Task { @MainActor in
                        self.updateOperationProgress(progress, status: status)
                    }
                }
                
                if !Task.isCancelled {
                    onSuccess(result)
                    await setProcessingState(false)
                }
            } catch {
                if !Task.isCancelled {
                    handleError(error)
                    onFailure(error)
                    await setProcessingState(false)
                }
            }
        }
    }
    
    func cancelCurrentOperation() {
        currentTask?.cancel()
        
        Task { @MainActor in
            setProcessingState(false)
            operationStatus = "Cancelled"
            
            // Clear status after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if !self.isProcessing {
                    self.operationStatus = ""
                }
            }
        }
    }
    
    // MARK: - Progress Management
    
    func updateOperationProgress(_ progress: Float, status: String = "") {
        operationProgress = max(0.0, min(1.0, progress))
        
        if !status.isEmpty {
            operationStatus = status
        }
        
        // Update estimated time remaining
        updateTimeEstimate(progress: progress)
    }
    
    private func updateTimeEstimate(progress: Float) {
        guard let startTime = operationStartTime,
              progress > 0.05, // Only estimate after 5% progress
              progress < 0.95 else { return } // Don't estimate when nearly complete
        
        let elapsed = Date().timeIntervalSince(startTime)
        let estimatedTotal = elapsed / Double(progress)
        let remaining = estimatedTotal - elapsed
        
        if remaining > 5 { // Only show if more than 5 seconds remaining
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.minute, .second]
            formatter.unitsStyle = .abbreviated
            
            if let timeString = formatter.string(from: remaining) {
                operationStatus += " • \(timeString) remaining"
            }
        }
    }
    
    private func setProcessingState(_ processing: Bool) {
        isProcessing = processing
        isLoading = processing
        
        if processing {
            operationStartTime = Date()
            clearError()
        } else {
            operationStartTime = nil
            operationProgress = 0.0
            
            if operationStatus != "Cancelled" {
                operationStatus = ""
            }
        }
    }
    
    // MARK: - Batch Operations
    
    func performBatchOperation<T, U>(
        items: [T],
        operation: @escaping (T, @escaping (Float, String) -> Void) async throws -> U,
        onItemComplete: @escaping (U, Int) -> Void = { _, _ in },
        onAllComplete: @escaping ([U]) -> Void = { _ in },
        onFailure: @escaping (Error, Int) -> Void = { _, _ in }
    ) {
        cancelCurrentOperation()
        
        currentTask = Task {
            await setProcessingState(true)
            var results: [U] = []
            
            for (index, item) in items.enumerated() {
                if Task.isCancelled { break }
                
                do {
                    let result = try await operation(item) { itemProgress, status in
                        let overallProgress = (Float(index) + itemProgress) / Float(items.count)
                        let itemStatus = "Processing item \(index + 1) of \(items.count): \(status)"
                        
                        Task { @MainActor in
                            self.updateOperationProgress(overallProgress, status: itemStatus)
                        }
                    }
                    
                    results.append(result)
                    onItemComplete(result, index)
                    
                } catch {
                    onFailure(error, index)
                    
                    // Continue with remaining items or break based on error severity
                    if shouldStopBatchOnError(error) {
                        break
                    }
                }
            }
            
            if !Task.isCancelled {
                onAllComplete(results)
                await setProcessingState(false)
            }
        }
    }
    
    private func shouldStopBatchOnError(_ error: Error) -> Bool {
        // Override in subclasses to define error handling strategy
        // Default: continue processing remaining items
        return false
    }
    
    // MARK: - Retry Logic
    
    func performAsyncOperationWithRetry<T>(
        _ operation: @escaping () async throws -> T,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        onSuccess: @escaping (T) -> Void = { _ in },
        onFailure: @escaping (Error) -> Void = { _ in },
        onRetry: @escaping (Int, Error) -> Void = { _, _ in }
    ) {
        cancelCurrentOperation()
        
        currentTask = Task {
            await setProcessingState(true)
            
            var lastError: Error?
            
            for attempt in 0...maxRetries {
                if Task.isCancelled { break }
                
                do {
                    let result = try await operation()
                    onSuccess(result)
                    await setProcessingState(false)
                    return
                } catch {
                    lastError = error
                    
                    if attempt < maxRetries {
                        onRetry(attempt + 1, error)
                        
                        // Update status to show retry
                        operationStatus = "Retrying... (attempt \(attempt + 2) of \(maxRetries + 1))"
                        
                        // Wait before retrying
                        try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    }
                }
            }
            
            // All retries failed
            if let error = lastError {
                handleError(error)
                onFailure(error)
            }
            
            await setProcessingState(false)
        }
    }
    
    // MARK: - Timeout Support
    
    func performAsyncOperationWithTimeout<T>(
        _ operation: @escaping () async throws -> T,
        timeout: TimeInterval,
        onSuccess: @escaping (T) -> Void = { _ in },
        onFailure: @escaping (Error) -> Void = { _ in }
    ) {
        cancelCurrentOperation()
        
        currentTask = Task {
            await setProcessingState(true)
            
            do {
                let result = try await withTimeout(timeout) {
                    try await operation()
                }
                
                if !Task.isCancelled {
                    onSuccess(result)
                    await setProcessingState(false)
                }
            } catch {
                if !Task.isCancelled {
                    handleError(error)
                    onFailure(error)
                    await setProcessingState(false)
                }
            }
        }
    }
    
    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw AsyncOperationError.timeout
            }
            
            guard let result = try await group.next() else {
                throw AsyncOperationError.operationFailed
            }
            
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Error Types

enum AsyncOperationError: LocalizedError {
    case timeout
    case cancelled
    case operationFailed
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Operation timed out"
        case .cancelled:
            return "Operation was cancelled"
        case .operationFailed:
            return "Operation failed"
        }
    }
}