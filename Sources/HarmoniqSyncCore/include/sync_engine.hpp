//
//  sync_engine.hpp
//  HarmoniqSyncCore
//
//  High-level synchronization orchestration engine
//

#ifndef SYNC_ENGINE_HPP
#define SYNC_ENGINE_HPP

#include "audio_processor.hpp"
#include "alignment_engine.hpp"
#include "harmoniq_sync.h"
#include <memory>
#include <vector>
#include <functional>

namespace HarmoniqSync {

/// High-level synchronization engine that orchestrates the full sync process
/// This class provides the main interface for end-to-end audio synchronization
class SyncEngine {
public:
    // MARK: - Lifecycle
    
    SyncEngine();
    ~SyncEngine();
    
    // MARK: - Configuration
    
    /// Set configuration for the sync engine
    void setConfig(const harmoniq_sync_config_t& config);
    
    /// Get current configuration
    harmoniq_sync_config_t getConfig() const;
    
    // MARK: - Main Processing Interface
    
    /// Process two audio buffers and return sync result
    /// This is the main entry point for synchronization
    /// @param referenceAudio Reference audio samples (mono, float)
    /// @param refLength Number of samples in reference audio
    /// @param targetAudio Target audio samples (mono, float) 
    /// @param targetLength Number of samples in target audio
    /// @param sampleRate Sample rate for both audio clips
    /// @param method Alignment method to use
    /// @return Sync result with offset and confidence metrics
    harmoniq_sync_result_t process(
        const float* referenceAudio, size_t refLength,
        const float* targetAudio, size_t targetLength,
        double sampleRate,
        harmoniq_sync_method_t method
    );
    
    /// Process multiple targets against single reference
    /// @param referenceAudio Reference audio samples
    /// @param refLength Number of samples in reference
    /// @param targetAudios Array of pointers to target audio data
    /// @param targetLengths Array of target audio lengths
    /// @param targetCount Number of target clips
    /// @param sampleRate Sample rate for all audio
    /// @param method Alignment method to use
    /// @return Vector of sync results
    std::vector<harmoniq_sync_result_t> processBatch(
        const float* referenceAudio, size_t refLength,
        const float** targetAudios, const size_t* targetLengths, size_t targetCount,
        double sampleRate,
        harmoniq_sync_method_t method
    );
    
    // MARK: - Progress Monitoring
    
    /// Progress callback function type
    using ProgressCallback = std::function<void(float progress, const std::string& status)>;
    
    /// Set progress callback for monitoring long operations
    void setProgressCallback(ProgressCallback callback);
    
    /// Clear progress callback
    void clearProgressCallback();
    
    // MARK: - Validation
    
    /// Validate input parameters before processing
    harmoniq_sync_error_t validateInputs(
        const float* referenceAudio, size_t refLength,
        const float* targetAudio, size_t targetLength,
        double sampleRate
    ) const;
    
    /// Check if configuration is valid
    harmoniq_sync_error_t validateConfig() const;
    
    // MARK: - Performance Metrics
    
    /// Get estimated processing time for given parameters
    double estimateProcessingTime(
        size_t audioLengthSamples,
        double sampleRate,
        harmoniq_sync_method_t method
    ) const;
    
    /// Get last processing statistics
    struct ProcessingStats {
        double processingTimeSeconds = 0.0;
        double audioLengthSeconds = 0.0;
        double realtimeRatio = 0.0;  // processing_time / audio_length
        size_t memoryUsedBytes = 0;
        harmoniq_sync_method_t methodUsed = HARMONIQ_SYNC_SPECTRAL_FLUX;
        bool successful = false;
    };
    
    ProcessingStats getLastProcessingStats() const;

private:
    // MARK: - Private Members
    
    harmoniq_sync_config_t config_;
    std::unique_ptr<AlignmentEngine> alignmentEngine_;
    ProgressCallback progressCallback_;
    ProcessingStats lastStats_;
    
    // MARK: - Internal Processing
    
    /// Update progress and call callback if set
    void updateProgress(float progress, const std::string& status);
    
    /// Convert C config to C++ config
    AlignmentEngine::Config convertConfig(const harmoniq_sync_config_t& cConfig) const;
    
    /// Create error result
    harmoniq_sync_result_t createErrorResult(
        harmoniq_sync_error_t error,
        const std::string& method
    ) const;
    
    /// Update processing statistics
    void updateProcessingStats(
        double processingTime,
        double audioLength,
        harmoniq_sync_method_t method,
        bool successful,
        size_t memoryUsed = 0
    );
};

} // namespace HarmoniqSync

#endif /* SYNC_ENGINE_HPP */