//
//  sync_engine.cpp
//  HarmoniqSyncCore
//
//  High-level synchronization orchestration engine
//

#include "../include/sync_engine.hpp"
#include <chrono>
#include <cstring>

namespace HarmoniqSync {

// MARK: - Lifecycle

SyncEngine::SyncEngine() : alignmentEngine_(std::make_unique<AlignmentEngine>()) {
    // Initialize with default configuration
    config_ = {
        0.7,        // confidence_threshold
        0,          // max_offset_samples (auto-calculate)
        1024,       // window_size
        256,        // hop_size
        -40.0,      // noise_gate_db
        1           // enable_drift_correction
    };
    
    // Set default config in alignment engine
    alignmentEngine_->setConfig(convertConfig(config_));
}

SyncEngine::~SyncEngine() = default;

// MARK: - Configuration

void SyncEngine::setConfig(const harmoniq_sync_config_t& config) {
    config_ = config;
    
    // Update alignment engine configuration
    if (alignmentEngine_) {
        alignmentEngine_->setConfig(convertConfig(config_));
    }
}

harmoniq_sync_config_t SyncEngine::getConfig() const {
    return config_;
}

// MARK: - Main Processing Interface

harmoniq_sync_result_t SyncEngine::process(
    const float* referenceAudio, size_t refLength,
    const float* targetAudio, size_t targetLength,
    double sampleRate,
    harmoniq_sync_method_t method
) {
    auto startTime = std::chrono::high_resolution_clock::now();
    
    updateProgress(0.0f, "Starting synchronization");
    
    // Validate inputs
    auto validationError = validateInputs(referenceAudio, refLength, targetAudio, targetLength, sampleRate);
    if (validationError != HARMONIQ_SYNC_SUCCESS) {
        updateProcessingStats(0.0, 0.0, method, false);
        return createErrorResult(validationError, "Validation");
    }
    
    updateProgress(0.1f, "Creating audio processors");
    
    try {
        // Create audio processors
        AudioProcessor refProcessor, targetProcessor;
        
        // Load audio data
        if (!refProcessor.loadAudio(referenceAudio, refLength, sampleRate)) {
            updateProcessingStats(0.0, refLength / sampleRate, method, false);
            return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "LoadReference");
        }
        
        updateProgress(0.3f, "Loading target audio");
        
        if (!targetProcessor.loadAudio(targetAudio, targetLength, sampleRate)) {
            updateProcessingStats(0.0, refLength / sampleRate, method, false);
            return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "LoadTarget");
        }
        
        updateProgress(0.5f, "Performing alignment");
        
        // Perform alignment based on method
        harmoniq_sync_result_t result;
        
        switch (method) {
            case HARMONIQ_SYNC_SPECTRAL_FLUX:
                updateProgress(0.6f, "Extracting spectral flux features");
                result = alignmentEngine_->alignSpectralFlux(refProcessor, targetProcessor);
                break;
                
            case HARMONIQ_SYNC_CHROMA:
                updateProgress(0.6f, "Extracting chroma features");
                result = alignmentEngine_->alignChromaFeatures(refProcessor, targetProcessor);
                break;
                
            case HARMONIQ_SYNC_ENERGY:
                updateProgress(0.6f, "Analyzing energy correlation");
                result = alignmentEngine_->alignEnergyCorrelation(refProcessor, targetProcessor);
                break;
                
            case HARMONIQ_SYNC_MFCC:
                updateProgress(0.6f, "Computing MFCC features");
                result = alignmentEngine_->alignMFCC(refProcessor, targetProcessor);
                break;
                
            case HARMONIQ_SYNC_HYBRID:
                updateProgress(0.6f, "Running hybrid analysis");
                result = alignmentEngine_->alignHybrid(refProcessor, targetProcessor);
                break;
                
            default:
                updateProcessingStats(0.0, refLength / sampleRate, method, false);
                return createErrorResult(HARMONIQ_SYNC_ERROR_INVALID_INPUT, "UnknownMethod");
        }
        
        updateProgress(0.9f, "Finalizing results");
        
        auto endTime = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime);
        double processingTimeSeconds = duration.count() / 1000.0;
        double audioLengthSeconds = std::max(refLength, targetLength) / sampleRate;
        
        bool successful = (result.error == HARMONIQ_SYNC_SUCCESS);
        updateProcessingStats(processingTimeSeconds, audioLengthSeconds, method, successful);
        
        updateProgress(1.0f, successful ? "Synchronization complete" : "Synchronization failed");
        
        return result;
        
    } catch (const std::exception& e) {
        updateProcessingStats(0.0, refLength / sampleRate, method, false);
        return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "Exception");
    } catch (...) {
        updateProcessingStats(0.0, refLength / sampleRate, method, false);
        return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "UnknownError");
    }
}

std::vector<harmoniq_sync_result_t> SyncEngine::processBatch(
    const float* referenceAudio, size_t refLength,
    const float** targetAudios, const size_t* targetLengths, size_t targetCount,
    double sampleRate,
    harmoniq_sync_method_t method
) {
    auto startTime = std::chrono::high_resolution_clock::now();
    
    std::vector<harmoniq_sync_result_t> results;
    results.reserve(targetCount);
    
    updateProgress(0.0f, "Starting batch synchronization");
    
    // Validate inputs
    if (!referenceAudio || !targetAudios || !targetLengths || targetCount == 0) {
        harmoniq_sync_result_t errorResult = createErrorResult(HARMONIQ_SYNC_ERROR_INVALID_INPUT, "BatchValidation");
        results.resize(targetCount, errorResult);
        return results;
    }
    
    try {
        // Create reference processor once
        AudioProcessor refProcessor;
        if (!refProcessor.loadAudio(referenceAudio, refLength, sampleRate)) {
            harmoniq_sync_result_t errorResult = createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "BatchLoadReference");
            results.resize(targetCount, errorResult);
            return results;
        }
        
        updateProgress(0.1f, "Processing batch targets");
        
        // Create target processors
        std::vector<AudioProcessor> targetProcessors(targetCount);
        for (size_t i = 0; i < targetCount; i++) {
            if (!targetProcessors[i].loadAudio(targetAudios[i], targetLengths[i], sampleRate)) {
                // Continue processing - individual failures will be handled by batch alignment
            }
            
            float progress = 0.1f + (0.2f * (i + 1) / targetCount);
            updateProgress(progress, "Loading target " + std::to_string(i + 1) + "/" + std::to_string(targetCount));
        }
        
        updateProgress(0.3f, "Running batch alignment");
        
        // Use batch processing for efficiency
        results = alignmentEngine_->alignBatch(refProcessor, targetProcessors, method);
        
        auto endTime = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime);
        double processingTimeSeconds = duration.count() / 1000.0;
        
        // Calculate average audio length for stats
        double totalAudioLength = refLength / sampleRate;
        for (size_t i = 0; i < targetCount; i++) {
            totalAudioLength += targetLengths[i] / sampleRate;
        }
        double avgAudioLength = totalAudioLength / (targetCount + 1);
        
        // Count successful results
        size_t successCount = 0;
        for (const auto& result : results) {
            if (result.error == HARMONIQ_SYNC_SUCCESS) {
                successCount++;
            }
        }
        
        bool overallSuccess = (successCount > 0);
        updateProcessingStats(processingTimeSeconds, avgAudioLength, method, overallSuccess);
        
        updateProgress(1.0f, "Batch synchronization complete: " + std::to_string(successCount) + 
                      "/" + std::to_string(targetCount) + " successful");
        
        return results;
        
    } catch (const std::exception& e) {
        harmoniq_sync_result_t errorResult = createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "BatchException");
        results.resize(targetCount, errorResult);
        return results;
    } catch (...) {
        harmoniq_sync_result_t errorResult = createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "BatchUnknownError");
        results.resize(targetCount, errorResult);
        return results;
    }
}

// MARK: - Progress Monitoring

void SyncEngine::setProgressCallback(ProgressCallback callback) {
    progressCallback_ = callback;
}

void SyncEngine::clearProgressCallback() {
    progressCallback_ = nullptr;
}

// MARK: - Validation

harmoniq_sync_error_t SyncEngine::validateInputs(
    const float* referenceAudio, size_t refLength,
    const float* targetAudio, size_t targetLength,
    double sampleRate
) const {
    // Validate pointers
    if (!referenceAudio || !targetAudio) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    // Validate lengths
    if (refLength == 0 || targetLength == 0) {
        return HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA;
    }
    
    // Validate sample rate
    if (sampleRate <= 0 || sampleRate > 192000) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    // Check minimum audio length requirements
    size_t minRequiredSamples = static_cast<size_t>(1.0 * sampleRate); // 1 second minimum
    if (refLength < minRequiredSamples || targetLength < minRequiredSamples) {
        return HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA;
    }
    
    return HARMONIQ_SYNC_SUCCESS;
}

harmoniq_sync_error_t SyncEngine::validateConfig() const {
    // Validate confidence threshold
    if (config_.confidence_threshold < 0.0 || config_.confidence_threshold > 1.0) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    // Validate window and hop sizes
    if (config_.window_size <= 0 || config_.hop_size <= 0) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    // Validate hop size relative to window size
    if (config_.hop_size > config_.window_size) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    // Validate noise gate
    if (config_.noise_gate_db > 0.0 || config_.noise_gate_db < -120.0) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    return HARMONIQ_SYNC_SUCCESS;
}

// MARK: - Performance Metrics

double SyncEngine::estimateProcessingTime(
    size_t audioLengthSamples,
    double sampleRate,
    harmoniq_sync_method_t method
) const {
    if (sampleRate <= 0) return 0.0;
    
    double durationSeconds = audioLengthSamples / sampleRate;
    
    // Estimate processing time based on method complexity
    // These are estimates based on Apple Silicon M1 performance
    switch (method) {
        case HARMONIQ_SYNC_SPECTRAL_FLUX:
            return durationSeconds * 0.08; // ~8% of audio duration
        case HARMONIQ_SYNC_CHROMA:
            return durationSeconds * 0.12; // ~12% of audio duration  
        case HARMONIQ_SYNC_ENERGY:
            return durationSeconds * 0.04; // ~4% of audio duration
        case HARMONIQ_SYNC_MFCC:
            return durationSeconds * 0.18; // ~18% of audio duration
        case HARMONIQ_SYNC_HYBRID:
            return durationSeconds * 0.35; // ~35% of audio duration (runs all methods)
        default:
            return durationSeconds * 0.08;
    }
}

SyncEngine::ProcessingStats SyncEngine::getLastProcessingStats() const {
    return lastStats_;
}

// MARK: - Internal Processing

void SyncEngine::updateProgress(float progress, const std::string& status) {
    if (progressCallback_) {
        progressCallback_(progress, status);
    }
}

AlignmentEngine::Config SyncEngine::convertConfig(const harmoniq_sync_config_t& cConfig) const {
    AlignmentEngine::Config engineConfig;
    
    engineConfig.confidenceThreshold = cConfig.confidence_threshold;
    engineConfig.maxOffsetSamples = cConfig.max_offset_samples;
    engineConfig.windowSize = cConfig.window_size;
    engineConfig.hopSize = cConfig.hop_size;
    engineConfig.noiseGateDb = cConfig.noise_gate_db;
    engineConfig.enableDriftCorrection = (cConfig.enable_drift_correction != 0);
    
    // Algorithm-specific configurations with defaults
    engineConfig.spectralFlux.preEmphasisAlpha = 0.97f;
    engineConfig.spectralFlux.medianFilterSize = 5;
    
    engineConfig.chroma.numChromaBins = 12;
    engineConfig.chroma.useHarmonicWeighting = true;
    
    engineConfig.energy.smoothingWindowSize = 3;
    
    engineConfig.mfcc.numCoeffs = 13;
    engineConfig.mfcc.includeC0 = false;
    engineConfig.mfcc.numMelFilters = 26;
    
    return engineConfig;
}

harmoniq_sync_result_t SyncEngine::createErrorResult(
    harmoniq_sync_error_t error,
    const std::string& method
) const {
    harmoniq_sync_result_t result = {};
    
    result.offset_samples = 0;
    result.confidence = 0.0;
    result.peak_correlation = 0.0;
    result.secondary_peak_ratio = 1.0;
    result.snr_estimate = 0.0;
    result.noise_floor_db = -60.0;
    result.error = error;
    
    // Copy method name (ensure null termination)
    size_t copyLen = std::min(method.length(), sizeof(result.method) - 1);
    std::memcpy(result.method, method.c_str(), copyLen);
    result.method[copyLen] = '\0';
    
    return result;
}

void SyncEngine::updateProcessingStats(
    double processingTime,
    double audioLength,
    harmoniq_sync_method_t method,
    bool successful,
    size_t memoryUsed
) {
    lastStats_.processingTimeSeconds = processingTime;
    lastStats_.audioLengthSeconds = audioLength;
    lastStats_.realtimeRatio = (audioLength > 0) ? (processingTime / audioLength) : 0.0;
    lastStats_.memoryUsedBytes = memoryUsed;
    lastStats_.methodUsed = method;
    lastStats_.successful = successful;
}

} // namespace HarmoniqSync