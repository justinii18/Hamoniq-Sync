//
//  ConfigurationTypes.swift
//  HarmoniqSyncKit
//
//  Configuration types for audio synchronization
//

import Foundation
import HarmoniqSyncCore

// MARK: - Sync Configuration

public struct SyncConfiguration: Sendable {
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
    
    /// Validate decoding configuration
    public func validate() throws {
        guard targetSampleRate >= 8000.0 && targetSampleRate <= 192000.0 else {
            throw AudioDecoderError.unsupportedFormat("Sample rate must be between 8kHz and 192kHz")
        }
        
        if let maxDuration = maxDurationSeconds {
            guard maxDuration > 0.1 else {
                throw AudioDecoderError.insufficientData(minimumSamples: Int(targetSampleRate * 0.1))
            }
        }
        
        guard fadeInDuration >= 0.0 && fadeInDuration <= 10.0 else {
            throw AudioDecoderError.decodingFailed("Fade-in duration must be between 0 and 10 seconds")
        }
        
        guard fadeOutDuration >= 0.0 && fadeOutDuration <= 10.0 else {
            throw AudioDecoderError.decodingFailed("Fade-out duration must be between 0 and 10 seconds")
        }
    }
}

// MARK: - Configuration Presets

extension SyncConfiguration {
    /// Standard configuration for general use
    public static let standard = SyncConfiguration()
    
    /// High accuracy configuration (slower but more precise)
    public static let highAccuracy = SyncConfiguration(
        confidenceThreshold: 0.85,
        windowSize: 2048,
        hopSize: 512,
        noiseGateDb: -45.0
    )
    
    /// Fast configuration (quicker processing with reduced accuracy)
    public static let fast = SyncConfiguration(
        confidenceThreshold: 0.6,
        windowSize: 512,
        hopSize: 128,
        noiseGateDb: -35.0
    )
    
    /// Configuration optimized for music content
    public static let music = SyncConfiguration(
        confidenceThreshold: 0.75,
        windowSize: 4096,
        hopSize: 1024,
        noiseGateDb: -50.0
    )
    
    /// Configuration optimized for speech/dialogue
    public static let speech = SyncConfiguration(
        confidenceThreshold: 0.7,
        windowSize: 1024,
        hopSize: 256,
        noiseGateDb: -35.0
    )
    
    /// Configuration optimized for ambient/environmental audio
    public static let ambient = SyncConfiguration(
        confidenceThreshold: 0.6,
        windowSize: 2048,
        hopSize: 512,
        noiseGateDb: -45.0,
        enableDriftCorrection: true
    )
    
    /// Configuration for long-form content with drift correction
    public static let longForm = SyncConfiguration(
        confidenceThreshold: 0.75,
        maxOffsetSeconds: 600.0, // 10 minutes
        windowSize: 2048,
        hopSize: 512,
        noiseGateDb: -40.0,
        enableDriftCorrection: true
    )
    
    /// Configuration for short clips or samples
    public static let shortClips = SyncConfiguration(
        confidenceThreshold: 0.8,
        maxOffsetSeconds: 30.0,
        windowSize: 1024,
        hopSize: 256,
        noiseGateDb: -30.0,
        enableDriftCorrection: false
    )
}

extension AudioDecodingConfiguration {
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
    
    /// Configuration for broadcast content
    public static let broadcast = AudioDecodingConfiguration(
        targetSampleRate: 48000.0,
        monoMix: false,
        normalize: false
    )
    
    /// Configuration for podcasts and voice content
    public static let podcast = AudioDecodingConfiguration(
        targetSampleRate: 44100.0,
        monoMix: true,
        normalize: true,
        fadeInDuration: 0.1,
        fadeOutDuration: 0.1
    )
}

// MARK: - Configuration Builder

public struct SyncConfigurationBuilder {
    private var config: SyncConfiguration
    
    public init(base: SyncConfiguration = .standard) {
        self.config = base
    }
    
    public func confidenceThreshold(_ threshold: Double) -> SyncConfigurationBuilder {
        var builder = self
        builder.config = SyncConfiguration(
            confidenceThreshold: threshold,
            maxOffsetSeconds: config.maxOffsetSeconds,
            windowSize: config.windowSize,
            hopSize: config.hopSize,
            noiseGateDb: config.noiseGateDb,
            enableDriftCorrection: config.enableDriftCorrection
        )
        return builder
    }
    
    public func maxOffset(_ seconds: Double?) -> SyncConfigurationBuilder {
        var builder = self
        builder.config = SyncConfiguration(
            confidenceThreshold: config.confidenceThreshold,
            maxOffsetSeconds: seconds,
            windowSize: config.windowSize,
            hopSize: config.hopSize,
            noiseGateDb: config.noiseGateDb,
            enableDriftCorrection: config.enableDriftCorrection
        )
        return builder
    }
    
    public func windowSize(_ size: Int) -> SyncConfigurationBuilder {
        var builder = self
        builder.config = SyncConfiguration(
            confidenceThreshold: config.confidenceThreshold,
            maxOffsetSeconds: config.maxOffsetSeconds,
            windowSize: size,
            hopSize: config.hopSize,
            noiseGateDb: config.noiseGateDb,
            enableDriftCorrection: config.enableDriftCorrection
        )
        return builder
    }
    
    public func hopSize(_ size: Int?) -> SyncConfigurationBuilder {
        var builder = self
        builder.config = SyncConfiguration(
            confidenceThreshold: config.confidenceThreshold,
            maxOffsetSeconds: config.maxOffsetSeconds,
            windowSize: config.windowSize,
            hopSize: size,
            noiseGateDb: config.noiseGateDb,
            enableDriftCorrection: config.enableDriftCorrection
        )
        return builder
    }
    
    public func noiseGate(_ db: Double) -> SyncConfigurationBuilder {
        var builder = self
        builder.config = SyncConfiguration(
            confidenceThreshold: config.confidenceThreshold,
            maxOffsetSeconds: config.maxOffsetSeconds,
            windowSize: config.windowSize,
            hopSize: config.hopSize,
            noiseGateDb: db,
            enableDriftCorrection: config.enableDriftCorrection
        )
        return builder
    }
    
    public func driftCorrection(_ enabled: Bool) -> SyncConfigurationBuilder {
        var builder = self
        builder.config = SyncConfiguration(
            confidenceThreshold: config.confidenceThreshold,
            maxOffsetSeconds: config.maxOffsetSeconds,
            windowSize: config.windowSize,
            hopSize: config.hopSize,
            noiseGateDb: config.noiseGateDb,
            enableDriftCorrection: enabled
        )
        return builder
    }
    
    public func build() -> SyncConfiguration {
        return config
    }
}

// MARK: - Content-Aware Configuration

extension SyncConfiguration {
    /// Create configuration optimized for specific content type
    public static func optimized(for contentType: AudioContentType) -> SyncConfiguration {
        switch contentType {
        case .music:
            return .music
        case .speech:
            return .speech
        case .ambient:
            return .ambient
        case .mixed:
            return .standard
        case .unknown:
            return .standard
        }
    }
    
    /// Auto-detect optimal configuration based on audio characteristics
    public static func adaptive(
        audioDuration: TimeInterval,
        hasStrongTransients: Bool = false,
        isHarmonic: Bool = false,
        hasVoice: Bool = false
    ) -> SyncConfiguration {
        
        // Base configuration selection
        var baseConfig: SyncConfiguration
        if hasVoice {
            baseConfig = .speech
        } else if isHarmonic {
            baseConfig = .music
        } else if hasStrongTransients {
            baseConfig = .standard
        } else {
            baseConfig = .ambient
        }
        
        // Adjust for duration
        if audioDuration > 300.0 { // 5+ minutes
            return SyncConfigurationBuilder(base: baseConfig)
                .driftCorrection(true)
                .maxOffset(min(audioDuration / 10.0, 600.0))
                .build()
        } else if audioDuration < 30.0 { // Short clips
            return SyncConfigurationBuilder(base: baseConfig)
                .driftCorrection(false)
                .maxOffset(audioDuration / 2.0)
                .confidenceThreshold(baseConfig.confidenceThreshold + 0.1)
                .build()
        }
        
        return baseConfig
    }
}