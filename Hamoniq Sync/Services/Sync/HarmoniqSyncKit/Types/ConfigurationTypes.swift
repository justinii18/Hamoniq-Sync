//
//  ConfigurationTypes.swift
//  HarmoniqSyncKit
//
//  Configuration types for audio synchronization
//

import Foundation

// MARK: - Sync Configuration

public struct HarmoniqSyncConfiguration: Sendable {
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
        self.confidenceThreshold = max(0.0, min(1.0, confidenceThreshold))
        self.maxOffsetSeconds = maxOffsetSeconds.map { max(0.0, $0) }
        self.windowSize = max(256, min(8192, windowSize))
        self.hopSize = hopSize.map { max(64, min(windowSize / 2, $0)) }
        self.noiseGateDb = max(-80.0, min(0.0, noiseGateDb))
        self.enableDriftCorrection = enableDriftCorrection
    }
    
    /// Convert to C configuration structure
    internal func toCConfiguration(sampleRate: Double) -> harmoniq_sync_config_t {
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
    
    /// Validate configuration parameters
    public func validate(for sampleRate: Double) throws {
        guard confidenceThreshold >= 0.0 && confidenceThreshold <= 1.0 else {
            throw SyncEngineError.configurationError("Confidence threshold must be between 0.0 and 1.0")
        }
        
        guard windowSize >= 256 && windowSize <= 8192 else {
            throw SyncEngineError.configurationError("Window size must be between 256 and 8192")
        }
        
        if let hopSize = hopSize {
            guard hopSize >= 64 && hopSize <= windowSize / 2 else {
                throw SyncEngineError.configurationError("Hop size must be between 64 and windowSize/2")
            }
        }
        
        guard noiseGateDb >= -80.0 && noiseGateDb <= 0.0 else {
            throw SyncEngineError.configurationError("Noise gate must be between -80.0 and 0.0 dB")
        }
        
        if let maxOffset = maxOffsetSeconds {
            guard maxOffset > 0.0 && maxOffset <= 3600.0 else {
                throw SyncEngineError.configurationError("Max offset must be between 0 and 3600 seconds")
            }
        }
        
        guard sampleRate > 0 else {
            throw SyncEngineError.configurationError("Sample rate must be positive")
        }
    }
    
    // MARK: - Configuration Presets
    
    /// Standard configuration for general use
    public static let standard = HarmoniqSyncConfiguration()
    
    /// High accuracy configuration (slower but more precise)
    public static let highAccuracy = HarmoniqSyncConfiguration(
        confidenceThreshold: 0.85,
        windowSize: 2048,
        hopSize: 512,
        noiseGateDb: -45.0
    )
    
    /// Fast configuration (quicker processing with reduced accuracy)
    public static let fast = HarmoniqSyncConfiguration(
        confidenceThreshold: 0.6,
        windowSize: 512,
        hopSize: 128,
        noiseGateDb: -35.0
    )
}

// MARK: - Audio Decoding Configuration

public struct AudioDecodingConfiguration: Sendable {
    public let targetSampleRate: Double
    public let monoMix: Bool
    public let normalize: Bool
    public let maxDurationSeconds: TimeInterval?
    public let fadeInDuration: TimeInterval
    public let fadeOutDuration: TimeInterval
    
    public init(
        targetSampleRate: Double = 44100.0,
        monoMix: Bool = true,
        normalize: Bool = true,
        maxDurationSeconds: TimeInterval? = nil,
        fadeInDuration: TimeInterval = 0.0,
        fadeOutDuration: TimeInterval = 0.0
    ) {
        self.targetSampleRate = max(8000.0, min(192000.0, targetSampleRate))
        self.monoMix = monoMix
        self.normalize = normalize
        self.maxDurationSeconds = maxDurationSeconds.map { max(0.1, $0) }
        self.fadeInDuration = max(0.0, min(10.0, fadeInDuration))
        self.fadeOutDuration = max(0.0, min(10.0, fadeOutDuration))
    }
    
    /// Standard decoding configuration
    public static let standard = AudioDecodingConfiguration()
    
    /// High quality decoding (48kHz)
    public static let highQuality = AudioDecodingConfiguration(
        targetSampleRate: 48000.0,
        normalize: true
    )
    
    /// Fast decoding for quick processing
    public static let fast = AudioDecodingConfiguration(
        targetSampleRate: 22050.0,
        normalize: true
    )
}