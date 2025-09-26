//
//  CInterop.swift
//  HarmoniqSyncKit
//
//  Internal helpers for C API interoperability
//

import Foundation

// MARK: - C String Utilities

internal enum CInteropUtilities {
    
    /// Extract string from C tuple (fixed-size char array)
    static func extractString<T>(from tuple: T) -> String {
        return withUnsafeBytes(of: tuple) { bytes in
            let buffer = bytes.bindMemory(to: CChar.self)
            return String(cString: buffer.baseAddress!)
        }
    }
    
    /// Convert Swift string to C string with fixed size
    static func toCString<T>(_ string: String, into tuple: inout T) {
        withUnsafeMutableBytes(of: &tuple) { bytes in
            let buffer = bytes.bindMemory(to: CChar.self)
            let cString = string.cString(using: .utf8) ?? []
            let maxLength = bytes.count - 1 // Reserve space for null terminator
            let copyLength = min(cString.count - 1, maxLength) // Exclude Swift's null terminator
            
            // Copy the string
            for i in 0..<copyLength {
                buffer[i] = cString[i]
            }
            
            // Add null terminator
            buffer[copyLength] = 0
            
            // Zero out remaining bytes
            for i in (copyLength + 1)..<bytes.count {
                buffer[i] = 0
            }
        }
    }
    
    /// Validate C API result and convert error if needed
    static func validateResult<T>(_ result: T, extractError: (T) -> harmoniq_sync_error_t, context: String = "") throws {
        let error = extractError(result)
        if let swiftError = SyncEngineError(from: error, context: context) {
            throw swiftError
        }
    }
}

// MARK: - Memory Management

internal final class CResourceManager<Resource> {
    private let resource: Resource
    private let cleanup: (Resource) -> Void
    private var isReleased = false
    private let lock = NSLock()
    
    init(_ resource: Resource, cleanup: @escaping (Resource) -> Void) {
        self.resource = resource
        self.cleanup = cleanup
    }
    
    func withResource<Result>(_ block: (Resource) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isReleased else {
            fatalError("Attempting to use released C resource")
        }
        
        return try block(resource)
    }
    
    func release() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isReleased else { return }
        
        cleanup(resource)
        isReleased = true
    }
    
    deinit {
        if !isReleased {
            cleanup(resource)
        }
    }
}

// MARK: - Progress Callback Support

internal typealias ProgressCallback = @convention(c) (Double, UnsafePointer<CChar>?, UnsafeMutableRawPointer?) -> Int32

internal final class ProgressCallbackManager {
    private let swiftCallback: (SyncProgress) -> Void
    private var currentStage: SyncProgress.Stage = .loading
    private var startTime: Date = Date()
    private var lastProgressTime: Date = Date()
    private var processedSamples: Int64 = 0
    private var totalSamples: Int64 = 0
    
    init(callback: @escaping (SyncProgress) -> Void) {
        self.swiftCallback = callback
        self.startTime = Date()
    }
    
    func setStage(_ stage: SyncProgress.Stage, totalSamples: Int64 = 0) {
        self.currentStage = stage
        self.totalSamples = totalSamples
        self.processedSamples = 0
        self.lastProgressTime = Date()
    }
    
    // Note: Simplified callback for initial implementation
    // Full progress callback functionality will be added in Week 3
    func reportProgress(_ progress: Double) {
        let syncProgress = SyncProgress(
            stage: currentStage,
            percentage: progress * 100.0,
            estimatedTimeRemaining: nil,
            currentOperation: currentStage.displayName,
            processedSamples: Int64(progress * Double(totalSamples)),
            totalSamples: totalSamples
        )
        
        DispatchQueue.main.async {
            self.swiftCallback(syncProgress)
        }
    }
    
    var callbackPointer: UnsafeMutableRawPointer {
        return Unmanaged.passUnretained(self).toOpaque()
    }
}

// MARK: - Task Cancellation Support

internal final class CancellationToken {
    private var isCancelled = false
    private let lock = NSLock()
    
    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
    }
    
    var cancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelled
    }
    
    /// C-compatible cancellation check function
    lazy var cCancellationCheck: @convention(c) (UnsafeMutableRawPointer?) -> Int32 = { userData in
        guard let userData = userData else { return 0 }
        let token = Unmanaged<CancellationToken>.fromOpaque(userData).takeUnretainedValue()
        return token.cancelled ? 1 : 0
    }
    
    var opaquePointer: UnsafeMutableRawPointer {
        return Unmanaged.passUnretained(self).toOpaque()
    }
}

// MARK: - Array Helpers

internal extension Array where Element == Float {
    /// Create UnsafePointer for C API calls with automatic cleanup
    func withUnsafeBufferPointer<Result>(_ block: (UnsafeBufferPointer<Float>) throws -> Result) rethrows -> Result {
        return try withUnsafeBufferPointer(block)
    }
}

internal extension Array where Element == UnsafePointer<Float> {
    /// Create array of pointers for batch operations
    func withUnsafeMutableBufferPointer<Result>(_ block: (UnsafeMutableBufferPointer<UnsafePointer<Float>>) throws -> Result) rethrows -> Result {
        var mutableSelf = self
        return try mutableSelf.withUnsafeMutableBufferPointer(block)
    }
}

// MARK: - Configuration Validation

internal extension HarmoniqSyncConfiguration {
    /// Validate configuration with C API
    func validateWithCAPI(sampleRate: Double) throws {
        var cConfig = toCConfiguration(sampleRate: sampleRate)
        let result = harmoniq_sync_validate_config(&cConfig)
        
        if let error = SyncEngineError(from: result, context: "Configuration validation") {
            throw error
        }
    }
}

// MARK: - Error Context Enhancement

internal extension SyncEngineError {
    /// Add operation context to error
    static func withContext(_ operation: String, error: SyncEngineError) -> SyncEngineError {
        switch error {
        case .invalidInput(let details):
            return .invalidInput("\(operation): \(details)")
        case .processingFailed(let reason):
            return .processingFailed("\(operation): \(reason)")
        case .outOfMemory(let bytes):
            return .outOfMemory(requestedBytes: bytes)
        case .unsupportedFormat(let format):
            return .unsupportedFormat(formatDescription: "\(operation): \(format)")
        case .insufficientData(let duration):
            return .insufficientData(minimumDuration: duration)
        case .cancelled:
            return .cancelled
        case .configurationError(let details):
            return .configurationError("\(operation): \(details)")
        case .fileAccessError(let details):
            return .fileAccessError("\(operation): \(details)")
        }
    }
}

// MARK: - Debugging Utilities

#if DEBUG
internal enum DebugUtilities {
    static func logCAPICall(_ functionName: String, parameters: [String: Any] = [:]) {
        var paramString = ""
        if !parameters.isEmpty {
            let paramPairs = parameters.map { "\($0.key)=\($0.value)" }
            paramString = " with \(paramPairs.joined(separator: ", "))"
        }
        
        print("[HarmoniqSyncKit] C API Call: \(functionName)\(paramString)")
    }
    
    static func logError(_ error: Error, context: String = "") {
        let contextString = context.isEmpty ? "" : " [\(context)]"
        print("[HarmoniqSyncKit] Error\(contextString): \(error)")
    }
    
    static func logPerformance<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("[HarmoniqSyncKit] Performance: \(operation) took \(String(format: "%.3f", timeElapsed))s")
        return result
    }
}
#endif