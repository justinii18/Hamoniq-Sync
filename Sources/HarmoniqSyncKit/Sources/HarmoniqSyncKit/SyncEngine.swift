//
//  SyncEngine.swift
//  HarmoniqSyncKit
//
//  Swift wrapper for C++ HarmoniqSync engine
//

import Foundation
import HarmoniqSyncCore

// Helper function to extract method string from C tuple
private func extractMethodString(from tuple: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)) -> String {
    let buffer = withUnsafeBytes(of: tuple) { bytes in
        bytes.bindMemory(to: CChar.self)
    }
    return String(cString: buffer.baseAddress!)
}

/// Swift wrapper for the C++ HarmoniqSync alignment engine
public class SyncEngine {
    
    // MARK: - Types
    
    public struct AlignmentResult {
        public let offsetSamples: Int64
        public let offsetSeconds: Double
        public let confidence: Double
        public let peakCorrelation: Double
        public let secondaryPeakRatio: Double
        public let snrEstimate: Double
        public let noiseFloorDb: Double
        public let method: String
        public let isValid: Bool
        
        internal init(from cResult: harmoniq_sync_result_t, sampleRate: Double) {
            self.offsetSamples = cResult.offset_samples
            self.offsetSeconds = Double(cResult.offset_samples) / sampleRate
            self.confidence = cResult.confidence
            self.peakCorrelation = cResult.peak_correlation
            self.secondaryPeakRatio = cResult.secondary_peak_ratio
            self.snrEstimate = cResult.snr_estimate
            self.noiseFloorDb = cResult.noise_floor_db
            self.method = extractMethodString(from: cResult.method)
            self.isValid = cResult.error == HARMONIQ_SYNC_SUCCESS
        }
    }
    
    public struct BatchResult {
        public let results: [AlignmentResult]
        public let isValid: Bool
        
        internal init(from cResult: harmoniq_sync_batch_result_t, sampleRate: Double) {
            if cResult.error == HARMONIQ_SYNC_SUCCESS && cResult.results != nil {
                let buffer = UnsafeBufferPointer(start: cResult.results, count: Int(cResult.count))
                self.results = buffer.map { AlignmentResult(from: $0, sampleRate: sampleRate) }
                self.isValid = true
            } else {
                self.results = []
                self.isValid = false
            }
        }
    }
    
    public enum Method {
        case spectralFlux
        case chroma
        case energy
        case mfcc
        case hybrid
        
        internal var cValue: harmoniq_sync_method_t {
            switch self {
            case .spectralFlux: return HARMONIQ_SYNC_SPECTRAL_FLUX
            case .chroma: return HARMONIQ_SYNC_CHROMA
            case .energy: return HARMONIQ_SYNC_ENERGY
            case .mfcc: return HARMONIQ_SYNC_MFCC
            case .hybrid: return HARMONIQ_SYNC_HYBRID
            }
        }
        
        public var displayName: String {
            switch self {
            case .spectralFlux: return "Spectral Flux"
            case .chroma: return "Chroma Features"
            case .energy: return "Energy Correlation"
            case .mfcc: return "MFCC"
            case .hybrid: return "Hybrid"
            }
        }
    }
    
    public struct Configuration {
        public let confidenceThreshold: Double
        public let maxOffsetSeconds: Double?
        public let windowSize: Int
        public let hopSize: Int?
        public let noiseGateDb: Double
        public let enableDriftCorrection: Bool
        
        public init(
            confidenceThreshold: Double = 0.7,
            maxOffsetSeconds: Double? = nil,
            windowSize: Int = 1024,
            hopSize: Int? = nil,
            noiseGateDb: Double = -40.0,
            enableDriftCorrection: Bool = true
        ) {
            self.confidenceThreshold = confidenceThreshold
            self.maxOffsetSeconds = maxOffsetSeconds
            self.windowSize = windowSize
            self.hopSize = hopSize
            self.noiseGateDb = noiseGateDb
            self.enableDriftCorrection = enableDriftCorrection
        }
        
        public static let standard = Configuration()
        public static let highAccuracy = Configuration(confidenceThreshold: 0.85, windowSize: 2048)
        public static let fast = Configuration(confidenceThreshold: 0.6, windowSize: 512)
        
        internal func toCConfig(sampleRate: Double) -> harmoniq_sync_config_t {
            let maxOffsetSamples = maxOffsetSeconds.map { Int64($0 * sampleRate) } ?? 0
            let actualHopSize = hopSize ?? (windowSize / 4)
            
            return harmoniq_sync_config_t(
                confidence_threshold: confidenceThreshold,
                max_offset_samples: maxOffsetSamples,
                window_size: Int32(windowSize),
                hop_size: Int32(actualHopSize),
                noise_gate_db: noiseGateDb,
                enable_drift_correction: enableDriftCorrection ? 1 : 0
            )
        }
    }
    
    public enum SyncEngineError: LocalizedError {
        case invalidInput
        case insufficientData
        case processingFailed(String)
        case outOfMemory
        case unsupportedFormat
        
        internal init?(from cError: harmoniq_sync_error_t) {
            switch cError {
            case HARMONIQ_SYNC_SUCCESS:
                return nil
            case HARMONIQ_SYNC_ERROR_INVALID_INPUT:
                self = .invalidInput
            case HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA:
                self = .insufficientData
            case HARMONIQ_SYNC_ERROR_PROCESSING_FAILED:
                self = .processingFailed("Processing failed")
            case HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY:
                self = .outOfMemory
            case HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT:
                self = .unsupportedFormat
            default:
                self = .processingFailed("Unknown error")
            }
        }
        
        public var errorDescription: String? {
            switch self {
            case .invalidInput:
                return "Invalid input data provided"
            case .insufficientData:
                return "Insufficient audio data for alignment"
            case .processingFailed(let reason):
                return "Processing failed: \(reason)"
            case .outOfMemory:
                return "Out of memory during processing"
            case .unsupportedFormat:
                return "Unsupported audio format"
            }
        }
    }
    
    // MARK: - Public API
    
    /// Align two audio clips
    public static func align(
        reference: AudioDecoder.AudioData,
        target: AudioDecoder.AudioData,
        method: Method = .hybrid,
        configuration: Configuration = .standard
    ) throws -> AlignmentResult {
        
        // Validate input
        guard reference.isValid && target.isValid else {
            throw SyncEngineError.invalidInput
        }
        
        guard reference.sampleRate == target.sampleRate else {
            throw SyncEngineError.invalidInput
        }
        
        // Convert configuration
        var config = configuration.toCConfig(sampleRate: reference.sampleRate)
        
        // Call C function
        let result = reference.samples.withUnsafeBufferPointer { refBuf in
            target.samples.withUnsafeBufferPointer { targetBuf in
                harmoniq_sync_align(
                    refBuf.baseAddress, refBuf.count,
                    targetBuf.baseAddress, targetBuf.count,
                    reference.sampleRate,
                    method.cValue,
                    &config
                )
            }
        }
        
        // Check for errors
        if let error = SyncEngineError(from: result.error) {
            throw error
        }
        
        return AlignmentResult(from: result, sampleRate: reference.sampleRate)
    }
    
    /// Align multiple target clips against a single reference
    public static func alignBatch(
        reference: AudioDecoder.AudioData,
        targets: [AudioDecoder.AudioData],
        method: Method = .hybrid,
        configuration: Configuration = .standard
    ) throws -> BatchResult {
        
        // Validate input
        guard reference.isValid, !targets.isEmpty, targets.allSatisfy({ $0.sampleRate == reference.sampleRate && $0.isValid }) else {
            throw SyncEngineError.invalidInput
        }
        
        var config = configuration.toCConfig(sampleRate: reference.sampleRate)
        
        var targetPointers = targets.map { UnsafePointer($0.samples) }
        let targetLengths = targets.map { $0.samples.count }
        
        var result: harmoniq_sync_batch_result_t!
        reference.samples.withUnsafeBufferPointer { refBuf in
            targetPointers.withUnsafeMutableBufferPointer { targetsBuf in
                targetLengths.withUnsafeBufferPointer { lengthsBuf in
                    result = harmoniq_sync_align_batch(
                        refBuf.baseAddress, refBuf.count,
                        UnsafePointer(targetsBuf.baseAddress),
                        lengthsBuf.baseAddress, 
                        targets.count,
                        reference.sampleRate,
                        method.cValue,
                        &config
                    )
                }
            }
        }
        
        // Free C memory for the results array
        defer {
            if result != nil {
                harmoniq_sync_free_batch_result(&result)
            }
        }
        
        // Check for errors
        if let error = SyncEngineError(from: result.error) {
            throw error
        }
        
        return BatchResult(from: result, sampleRate: reference.sampleRate)
    }
    
    // MARK: - Utility Functions
    
    /// Get minimum recommended audio length for reliable alignment
    public static func minimumAudioLength(for method: Method, sampleRate: Double) -> TimeInterval {
        let samples = harmoniq_sync_min_audio_length(method.cValue, sampleRate)
        return Double(samples) / sampleRate
    }
    
    /// Validate configuration
    public static func validate(configuration: Configuration, sampleRate: Double) -> Bool {
        var config = configuration.toCConfig(sampleRate: sampleRate)
        return harmoniq_sync_validate_config(&config) == HARMONIQ_SYNC_SUCCESS
    }
    
    /// Get library version
    public static var version: String {
        guard let cString = harmoniq_sync_version() else { return "Unknown" }
        return String(cString: cString)
    }
    
    /// Get build information
    public static var buildInfo: String {
        guard let cString = harmoniq_sync_build_info() else { return "Unknown" }
        return String(cString: cString)
    }
    
    /// Get supported methods
    public static var supportedMethods: [Method] {
        return [.spectralFlux, .chroma, .energy, .mfcc, .hybrid]
    }
}

// MARK: - Configuration Presets

extension SyncEngine.Configuration {
    /// Configuration optimized for music content
    public static let music = SyncEngine.Configuration(
        confidenceThreshold: 0.75,
        windowSize: 4096,
        hopSize: 1024,
        noiseGateDb: -50.0
    )
    
    /// Configuration optimized for speech/dialogue
    public static let speech = SyncEngine.Configuration(
        confidenceThreshold: 0.7,
        windowSize: 1024,
        hopSize: 256,
        noiseGateDb: -35.0
    )
    
    /// Configuration optimized for ambient/environmental audio
    public static let ambient = SyncEngine.Configuration(
        confidenceThreshold: 0.6,
        windowSize: 2048,
        hopSize: 512,
        noiseGateDb: -45.0
    )
}

// MARK: - Result Extensions

extension SyncEngine.AlignmentResult {
    /// Get offset as timecode string (HH:MM:SS.mmm)
    public var offsetTimecode: String {
        let absSeconds = abs(offsetSeconds)
        let hours = Int(absSeconds) / 3600
        let minutes = Int(absSeconds) % 3600 / 60
        let seconds = absSeconds.truncatingRemainder(dividingBy: 60)
        let sign = offsetSeconds < 0 ? "-" : "+"
        
        return String(format: "%@%02d:%02d:%06.3f", sign, hours, minutes, seconds)
    }
    
    /// Get confidence as percentage string
    public var confidencePercentage: String {
        return String(format: "%.1f%%", confidence * 100)
    }
    
    /// Quality assessment based on confidence and correlation
    public var quality: Quality {
        if confidence >= 0.9 && peakCorrelation >= 0.8 {
            return .excellent
        } else if confidence >= 0.75 && peakCorrelation >= 0.6 {
            return .good
        } else if confidence >= 0.6 && peakCorrelation >= 0.4 {
            return .fair
        } else {
            return .poor
        }
    }
    
    public enum Quality: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        
        public var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }
}