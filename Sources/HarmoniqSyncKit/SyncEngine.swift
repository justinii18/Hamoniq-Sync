//
//  SyncEngine.swift
//  HarmoniqSyncKit
//
//  Swift wrapper for C++ HarmoniqSync engine
//

import Foundation

// Import the C API
// For now we'll use a local import until the module is properly configured
// import HarmoniqSyncCore

// MARK: - C API Declarations (temporary until module is configured)

// For now, we'll stub the C API calls to make the Swift code compile
// These will be replaced with actual C function calls once the build system is configured

private enum HARMONIQ_SYNC_METHOD: Int32 {
    case spectralFlux = 0
    case chroma = 1
    case energy = 2
    case mfcc = 3
    case hybrid = 4
}

private enum HARMONIQ_SYNC_ERROR: Int32 {
    case success = 0
    case invalidInput = -1
    case insufficientData = -2
    case processingFailed = -3
    case outOfMemory = -4
    case unsupportedFormat = -5
}

private struct harmoniq_sync_result_t {
    var offset_samples: Int64
    var confidence: Double
    var peak_correlation: Double
    var secondary_peak_ratio: Double
    var snr_estimate: Double
    var noise_floor_db: Double
    var method: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)
    var error: Int32
}

private struct harmoniq_sync_config_t {
    var confidence_threshold: Double
    var max_offset_samples: Int64
    var window_size: Int32
    var hop_size: Int32
    var noise_gate_db: Double
    var enable_drift_correction: Int32
}

private struct harmoniq_sync_batch_result_t {
    var results: UnsafeMutablePointer<harmoniq_sync_result_t>?
    var count: Int
    var error: Int32
}

// Stub implementations for compilation
private func harmoniq_sync_align(
    _ reference_audio: UnsafePointer<Float>, _ ref_length: Int,
    _ target_audio: UnsafePointer<Float>, _ target_length: Int,
    _ sample_rate: Double,
    _ method: Int32,
    _ config: UnsafePointer<harmoniq_sync_config_t>
) -> harmoniq_sync_result_t {
    // Stub implementation - generates mock results
    let randomOffset = Int64.random(in: -44100...44100)
    let randomConfidence = Double.random(in: 0.6...0.95)
    
    return harmoniq_sync_result_t(
        offset_samples: randomOffset,
        confidence: randomConfidence,
        peak_correlation: randomConfidence * 0.9,
        secondary_peak_ratio: 2.0,
        snr_estimate: 20.0 + randomConfidence * 15.0,
        noise_floor_db: -60.0,
        method: (83, 116, 117, 98, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), // "Stub"
        error: HARMONIQ_SYNC_ERROR.success.rawValue
    )
}

private func harmoniq_sync_version() -> UnsafePointer<CChar> {
    return "1.0.0-stub".withCString { $0 }
}

private func harmoniq_sync_build_info() -> UnsafePointer<CChar> {
    return "Stub implementation".withCString { $0 }
}

private func harmoniq_sync_min_audio_length(_ method: Int32, _ sampleRate: Double) -> Int {
    return Int(2.0 * sampleRate) // 2 seconds minimum
}

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
            self.isValid = cResult.error == HARMONIQ_SYNC_ERROR.success.rawValue
        }
    }
    
    public struct BatchResult {
        public let results: [AlignmentResult]
        public let isValid: Bool
        
        internal init(from cResult: harmoniq_sync_batch_result_t, sampleRate: Double) {
            if cResult.error == HARMONIQ_SYNC_ERROR.success.rawValue && cResult.results != nil {
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
        
        internal var cValue: Int32 {
            switch self {
            case .spectralFlux: return HARMONIQ_SYNC_METHOD.spectralFlux.rawValue
            case .chroma: return HARMONIQ_SYNC_METHOD.chroma.rawValue
            case .energy: return HARMONIQ_SYNC_METHOD.energy.rawValue
            case .mfcc: return HARMONIQ_SYNC_METHOD.mfcc.rawValue
            case .hybrid: return HARMONIQ_SYNC_METHOD.hybrid.rawValue
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
        
        internal init(from cError: Int32) {
            switch cError {
            case HARMONIQ_SYNC_ERROR.invalidInput.rawValue:
                self = .invalidInput
            case HARMONIQ_SYNC_ERROR.insufficientData.rawValue:
                self = .insufficientData
            case HARMONIQ_SYNC_ERROR.processingFailed.rawValue:
                self = .processingFailed("Processing failed")
            case HARMONIQ_SYNC_ERROR.outOfMemory.rawValue:
                self = .outOfMemory
            case HARMONIQ_SYNC_ERROR.unsupportedFormat.rawValue:
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
        let config = configuration.toCConfig(sampleRate: reference.sampleRate)
        
        // Call C function
        let result = reference.withUnsafeFloatPointer { refPtr in
            target.withUnsafeFloatPointer { targetPtr in
                harmoniq_sync_align(
                    refPtr, reference.samples.count,
                    targetPtr, target.samples.count,
                    reference.sampleRate,
                    method.cValue,
                    &config
                )
            }
        }
        
        // Check for errors
        if result.error != HARMONIQ_SYNC_ERROR.success.rawValue {
            throw SyncEngineError(from: result.error)
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
        guard reference.isValid else {
            throw SyncEngineError.invalidInput
        }
        
        guard !targets.isEmpty else {
            throw SyncEngineError.invalidInput
        }
        
        // Validate all targets have same sample rate
        guard targets.allSatisfy({ $0.sampleRate == reference.sampleRate && $0.isValid }) else {
            throw SyncEngineError.invalidInput
        }
        
        // Convert configuration
        let config = configuration.toCConfig(sampleRate: reference.sampleRate)
        
        // Prepare target data
        let targetPointers = targets.map { target in
            target.samples.withUnsafeBufferPointer { $0.baseAddress! }
        }
        
        let targetLengths = targets.map { size_t($0.samples.count) }
        
        // Call C function
        let result = reference.withUnsafeFloatPointer { refPtr in
            targetPointers.withUnsafeBufferPointer { targetsPtr in
                targetLengths.withUnsafeBufferPointer { lengthsPtr in
                    harmoniq_sync_align_batch(
                        refPtr, reference.samples.count,
                        targetsPtr.baseAddress!, lengthsPtr.baseAddress!, targets.count,
                        reference.sampleRate,
                        method.cValue,
                        &config
                    )
                }
            }
        }
        
        // Convert result
        let batchResult = BatchResult(from: result, sampleRate: reference.sampleRate)
        
        // Free C memory
        harmoniq_sync_free_batch_result(&result)
        
        // Check for errors
        if !batchResult.isValid {
            throw SyncEngineError.processingFailed("Batch alignment failed")
        }
        
        return batchResult
    }
    
    // MARK: - Utility Functions
    
    /// Get minimum recommended audio length for reliable alignment
    public static func minimumAudioLength(for method: Method, sampleRate: Double) -> TimeInterval {
        let samples = harmoniq_sync_min_audio_length(method.cValue, sampleRate)
        return Double(samples) / sampleRate
    }
    
    /// Validate configuration
    public static func validate(configuration: Configuration, sampleRate: Double) -> Bool {
        // For stub implementation, just validate basic constraints
        return configuration.confidenceThreshold > 0.0 && 
               configuration.confidenceThreshold <= 1.0 &&
               configuration.windowSize > 0
    }
    
    /// Get library version
    public static var version: String {
        return String(cString: harmoniq_sync_version())
    }
    
    /// Get build information
    public static var buildInfo: String {
        return String(cString: harmoniq_sync_build_info())
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