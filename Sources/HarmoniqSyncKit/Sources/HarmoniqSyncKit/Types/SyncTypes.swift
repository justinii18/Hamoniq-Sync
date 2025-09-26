//
//  SyncTypes.swift
//  HarmoniqSyncKit
//
//  Core types for audio synchronization
//

import Foundation
import HarmoniqSyncCore

// MARK: - Alignment Method

public enum AlignmentMethod: String, CaseIterable, Sendable {
    case spectralFlux = "spectral_flux"
    case chroma = "chroma"
    case energy = "energy"
    case mfcc = "mfcc"
    case hybrid = "hybrid"
    
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
    
    public var description: String {
        switch self {
        case .spectralFlux:
            return "Best for general audio with transients and percussive elements"
        case .chroma:
            return "Optimized for musical content with harmonic structure"
        case .energy:
            return "Effective for speech and dynamic content"
        case .mfcc:
            return "Specialized for speech and vocal content"
        case .hybrid:
            return "Combines multiple methods for maximum accuracy"
        }
    }
    
    /// Recommended method for different content types
    public static func recommended(for contentType: AudioContentType) -> AlignmentMethod {
        switch contentType {
        case .music: return .chroma
        case .speech: return .mfcc
        case .ambient: return .energy
        case .mixed: return .hybrid
        case .unknown: return .hybrid
        }
    }
}

// MARK: - Audio Content Type

public enum AudioContentType: String, CaseIterable, Sendable {
    case music = "music"
    case speech = "speech"
    case ambient = "ambient"
    case mixed = "mixed"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .music: return "Music"
        case .speech: return "Speech/Dialogue"
        case .ambient: return "Ambient/Environmental"
        case .mixed: return "Mixed Content"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Alignment Result

public struct AlignmentResult: Sendable {
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
        self.method = String(cString: withUnsafeBytes(of: cResult.method) { bytes in
            bytes.bindMemory(to: CChar.self).baseAddress!
        })
        self.isValid = cResult.error == HARMONIQ_SYNC_SUCCESS
    }
}

// MARK: - Batch Result

public struct BatchResult: Sendable {
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

// MARK: - Progress Information

public struct SyncProgress: Sendable {
    public let stage: Stage
    public let percentage: Double
    public let estimatedTimeRemaining: TimeInterval?
    public let currentOperation: String
    public let processedSamples: Int64
    public let totalSamples: Int64
    
    public enum Stage: String, CaseIterable, Sendable {
        case loading = "loading"
        case preprocessing = "preprocessing"
        case analyzing = "analyzing"
        case correlating = "correlating"
        case finalizing = "finalizing"
        
        public var displayName: String {
            switch self {
            case .loading: return "Loading Audio"
            case .preprocessing: return "Preprocessing"
            case .analyzing: return "Analyzing Features"
            case .correlating: return "Computing Alignment"
            case .finalizing: return "Finalizing Results"
            }
        }
        
        public var estimatedDuration: Double {
            switch self {
            case .loading: return 0.1
            case .preprocessing: return 0.2
            case .analyzing: return 0.4
            case .correlating: return 0.25
            case .finalizing: return 0.05
            }
        }
    }
    
    public init(
        stage: Stage,
        percentage: Double,
        estimatedTimeRemaining: TimeInterval? = nil,
        currentOperation: String,
        processedSamples: Int64 = 0,
        totalSamples: Int64 = 0
    ) {
        self.stage = stage
        self.percentage = max(0, min(100, percentage))
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.currentOperation = currentOperation
        self.processedSamples = processedSamples
        self.totalSamples = totalSamples
    }
}

// MARK: - Quality Assessment

public enum AlignmentQuality: String, CaseIterable, Sendable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    public var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    public var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    public var confidenceRange: ClosedRange<Double> {
        switch self {
        case .excellent: return 0.9...1.0
        case .good: return 0.75...0.9
        case .fair: return 0.6...0.75
        case .poor: return 0.0...0.6
        }
    }
}

// MARK: - Result Extensions

extension AlignmentResult {
    /// Get offset as timecode string (±HH:MM:SS.mmm)
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
    public var quality: AlignmentQuality {
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
    
    /// Detailed analysis of the alignment result
    public var analysis: String {
        var components: [String] = []
        
        components.append("Quality: \(quality.displayName)")
        components.append("Confidence: \(confidencePercentage)")
        components.append("Method: \(method)")
        
        if snrEstimate > 0 {
            components.append("SNR: \(String(format: "%.1f dB", snrEstimate))")
        }
        
        if secondaryPeakRatio < 0.5 {
            components.append("Clear primary peak")
        } else {
            components.append("Multiple potential peaks")
        }
        
        return components.joined(separator: " • ")
    }
}