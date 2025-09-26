//
//  c_bridge.cpp
//  HarmoniqSyncCore
//
//  C API bridge to C++ audio processing engine
//

#include "../include/harmoniq_sync.h"
#include "../include/audio_processor.hpp"
#include "../include/alignment_engine.hpp"
#include "../include/sync_engine.hpp"
#include <memory>
#include <string>
#include <vector>
#include <map>

using namespace HarmoniqSync;

// MARK: - Internal State Management

namespace {
    // Configuration mapping
    AlignmentEngine::Config createEngineConfig(const harmoniq_sync_config_t* config) {
        AlignmentEngine::Config engineConfig;
        
        if (config) {
            engineConfig.confidenceThreshold = config->confidence_threshold;
            engineConfig.maxOffsetSamples = config->max_offset_samples;
            engineConfig.windowSize = config->window_size;
            engineConfig.hopSize = config->hop_size;
            engineConfig.noiseGateDb = config->noise_gate_db;
            engineConfig.enableDriftCorrection = config->enable_drift_correction != 0;
            
            // Algorithm-specific configurations
            engineConfig.spectralFlux.preEmphasisAlpha = 0.97f;
            engineConfig.spectralFlux.medianFilterSize = 5;
            
            engineConfig.chroma.numChromaBins = 12;
            
            engineConfig.energy.smoothingWindowSize = 3;
            
            engineConfig.mfcc.numCoeffs = 13;
            engineConfig.mfcc.includeC0 = false;
            engineConfig.mfcc.numMelFilters = 26;
        }
        
        return engineConfig;
    }
}

// MARK: - Core API Implementation

extern "C" {

harmoniq_sync_result_t harmoniq_sync_align(
    const float* reference_audio, size_t ref_length,
    const float* target_audio, size_t target_length,
    double sample_rate,
    harmoniq_sync_method_t method,
    const harmoniq_sync_config_t* config
) {
    harmoniq_sync_result_t result = {};
    
    try {
        // Validate inputs
        if (!reference_audio || !target_audio || ref_length == 0 || target_length == 0 || sample_rate <= 0) {
            result.error = HARMONIQ_SYNC_ERROR_INVALID_INPUT;
            std::strcpy(result.method, "Invalid");
            return result;
        }
        
        // Create audio processors
        AudioProcessor refProcessor, targetProcessor;
        
        // Load audio data
        if (!refProcessor.loadAudio(reference_audio, ref_length, sample_rate)) {
            result.error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
            std::strcpy(result.method, "LoadFailed");
            return result;
        }
        
        if (!targetProcessor.loadAudio(target_audio, target_length, sample_rate)) {
            result.error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
            std::strcpy(result.method, "LoadFailed");
            return result;
        }
        
        // Create alignment engine with configuration
        AlignmentEngine engine;
        auto engineConfig = createEngineConfig(config);
        engine.setConfig(engineConfig);
        
        // Perform alignment based on method
        switch (method) {
            case HARMONIQ_SYNC_SPECTRAL_FLUX:
                return engine.alignSpectralFlux(refProcessor, targetProcessor);
            case HARMONIQ_SYNC_CHROMA:
                return engine.alignChromaFeatures(refProcessor, targetProcessor);
            case HARMONIQ_SYNC_ENERGY:
                return engine.alignEnergyCorrelation(refProcessor, targetProcessor);
            case HARMONIQ_SYNC_MFCC:
                return engine.alignMFCC(refProcessor, targetProcessor);
            case HARMONIQ_SYNC_HYBRID:
                return engine.alignHybrid(refProcessor, targetProcessor);
            default:
                result.error = HARMONIQ_SYNC_ERROR_INVALID_INPUT;
                std::strcpy(result.method, "Unknown");
                return result;
        }
        
    } catch (const std::exception& e) {
        result.error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
        std::strcpy(result.method, "Exception");
        return result;
    } catch (...) {
        result.error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
        std::strcpy(result.method, "Unknown");
        return result;
    }
}

harmoniq_sync_batch_result_t harmoniq_sync_align_batch(
    const float* reference_audio, size_t ref_length,
    const float** target_audios, const size_t* target_lengths, size_t target_count,
    double sample_rate,
    harmoniq_sync_method_t method,
    const harmoniq_sync_config_t* config
) {
    harmoniq_sync_batch_result_t batch_result = {};
    
    try {
        // Validate inputs
        if (!reference_audio || !target_audios || !target_lengths || target_count == 0) {
            batch_result.error = HARMONIQ_SYNC_ERROR_INVALID_INPUT;
            return batch_result;
        }
        
        // Create reference processor once
        AudioProcessor refProcessor;
        if (!refProcessor.loadAudio(reference_audio, ref_length, sample_rate)) {
            batch_result.error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
            return batch_result;
        }
        
        // Create alignment engine with configuration
        AlignmentEngine engine;
        auto engineConfig = createEngineConfig(config);
        engine.setConfig(engineConfig);
        
        // Create target processors
        std::vector<AudioProcessor> targetProcessors(target_count);
        for (size_t i = 0; i < target_count; i++) {
            if (!targetProcessors[i].loadAudio(target_audios[i], target_lengths[i], sample_rate)) {
                // We will continue and let the batch alignment handle the error
            }
        }
        
        // Use batch processing for efficiency
        auto results = engine.alignBatch(refProcessor, targetProcessors, method);
        
        // Allocate results array and copy results
        batch_result.results = (harmoniq_sync_result_t*)std::malloc(sizeof(harmoniq_sync_result_t) * results.size());
        if (!batch_result.results) {
            batch_result.error = HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY;
            return batch_result;
        }
        
        std::copy(results.begin(), results.end(), batch_result.results);
        batch_result.count = results.size();
        batch_result.error = HARMONIQ_SYNC_SUCCESS;
        
        return batch_result;
        
    } catch (const std::exception& e) {
        batch_result.error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
        return batch_result;
    } catch (...) {
        batch_result.error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
        return batch_result;
    }
}

harmoniq_sync_config_t harmoniq_sync_default_config(void) {
    harmoniq_sync_config_t config = {};
    
    config.confidence_threshold = 0.7;
    config.max_offset_samples = 0; // Auto-calculate
    config.window_size = 1024;
    config.hop_size = 256;
    config.noise_gate_db = -40.0;
    config.enable_drift_correction = 1;
    
    return config;
}

harmoniq_sync_config_t harmoniq_sync_config_for_use_case(const char* use_case) {
    harmoniq_sync_config_t config = harmoniq_sync_default_config();
    
    if (!use_case) return config;
    
    std::string useCase(use_case);
    
    if (useCase == "music") {
        // Optimized for musical content
        config.window_size = 4096;
        config.hop_size = 1024;
        config.noise_gate_db = -50.0;
        config.confidence_threshold = 0.75;
    } else if (useCase == "speech") {
        // Optimized for speech content
        config.window_size = 1024;
        config.hop_size = 256;
        config.noise_gate_db = -35.0;
        config.confidence_threshold = 0.65;
    } else if (useCase == "ambient") {
        // Optimized for ambient/environmental audio
        config.window_size = 2048;
        config.hop_size = 512;
        config.confidence_threshold = 0.6;
        config.noise_gate_db = -45.0;
    } else if (useCase == "multicam") {
        // Optimized for multicamera sync
        config.window_size = 2048;
        config.hop_size = 512;
        config.confidence_threshold = 0.7;
        config.enable_drift_correction = 1;
    } else if (useCase == "broadcast") {
        // Optimized for broadcast/professional content
        config.window_size = 4096;
        config.hop_size = 1024;
        config.confidence_threshold = 0.8;
        config.noise_gate_db = -55.0;
    }
    
    return config;
}

void harmoniq_sync_free_result(harmoniq_sync_result_t* result) {
    // Single results don't currently allocate dynamic memory
    // This is for future compatibility
    (void)result;
}

void harmoniq_sync_free_batch_result(harmoniq_sync_batch_result_t* batch_result) {
    if (batch_result && batch_result->results) {
        std::free(batch_result->results);
        batch_result->results = nullptr;
        batch_result->count = 0;
    }
}

const char* harmoniq_sync_error_description(harmoniq_sync_error_t error) {
    switch (error) {
        case HARMONIQ_SYNC_SUCCESS:
            return "Operation completed successfully";
        case HARMONIQ_SYNC_ERROR_INVALID_INPUT:
            return "Invalid input parameters provided";
        case HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA:
            return "Insufficient audio data for reliable synchronization";
        case HARMONIQ_SYNC_ERROR_PROCESSING_FAILED:
            return "Audio processing failed during synchronization";
        case HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY:
            return "Insufficient memory to complete operation";
        case HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT:
            return "Unsupported audio format or configuration";
        default:
            return "Unknown error occurred";
    }
}

const char* harmoniq_sync_method_name(harmoniq_sync_method_t method) {
    switch (method) {
        case HARMONIQ_SYNC_SPECTRAL_FLUX:
            return "Spectral Flux";
        case HARMONIQ_SYNC_CHROMA:
            return "Chroma Features";
        case HARMONIQ_SYNC_ENERGY:
            return "Energy Correlation";
        case HARMONIQ_SYNC_MFCC:
            return "MFCC";
        case HARMONIQ_SYNC_HYBRID:
            return "Hybrid";
        default:
            return "Unknown Method";
    }
}

harmoniq_sync_error_t harmoniq_sync_validate_config(const harmoniq_sync_config_t* config) {
    if (!config) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    // Validate confidence threshold
    if (config->confidence_threshold < 0.0 || config->confidence_threshold > 1.0) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    // Validate window and hop sizes
    if (config->window_size <= 0 || config->hop_size <= 0) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    // Validate hop size is reasonable relative to window size
    if (config->hop_size > config->window_size) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    // Validate noise gate threshold
    if (config->noise_gate_db > 0.0 || config->noise_gate_db < -120.0) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    return HARMONIQ_SYNC_SUCCESS;
}

size_t harmoniq_sync_min_audio_length(harmoniq_sync_method_t method, double sample_rate) {
    if (sample_rate <= 0) return 0;
    
    // Return minimum samples needed for reliable sync based on method
    switch (method) {
        case HARMONIQ_SYNC_SPECTRAL_FLUX:
            return (size_t)(2.0 * sample_rate); // 2 seconds for onset detection
        case HARMONIQ_SYNC_CHROMA:
            return (size_t)(4.0 * sample_rate); // 4 seconds for harmonic analysis
        case HARMONIQ_SYNC_ENERGY:
            return (size_t)(1.0 * sample_rate); // 1 second for energy profiles
        case HARMONIQ_SYNC_MFCC:
            return (size_t)(3.0 * sample_rate); // 3 seconds for cepstral analysis
        case HARMONIQ_SYNC_HYBRID:
            return (size_t)(4.0 * sample_rate); // 4 seconds to run all methods
        default:
            return (size_t)(2.0 * sample_rate); // Safe default
    }
}

const char* harmoniq_sync_version(void) {
    return "1.0.0";
}

const char* harmoniq_sync_build_info(void) {
    return "HarmoniqSync 1.0.0 (C++ Engine) - Built " __DATE__ " " __TIME__ 
           " [Spectral Flux, Chroma, Energy, MFCC, Hybrid algorithms]";
}

// MARK: - Extended API for Advanced Features

harmoniq_sync_error_t harmoniq_sync_set_progress_callback(
    void (*callback)(float progress, const char* status, void* user_data),
    void* user_data
) {
    // TODO: Implement progress callback support in AlignmentEngine
    // For now, return success but don't use the callback
    (void)callback;
    (void)user_data;
    return HARMONIQ_SYNC_SUCCESS;
}

harmoniq_sync_error_t harmoniq_sync_cancel_operation(void) {
    // TODO: Implement cancellation support
    // For now, return success but operations can't be cancelled mid-flight
    return HARMONIQ_SYNC_SUCCESS;
}

double harmoniq_sync_estimate_processing_time(
    size_t audio_length_samples,
    double sample_rate,
    harmoniq_sync_method_t method
) {
    if (sample_rate <= 0) return 0.0;
    
    double duration_seconds = audio_length_samples / sample_rate;
    
    // Estimate processing time based on method complexity
    // These are rough estimates and will vary by hardware
    switch (method) {
        case HARMONIQ_SYNC_SPECTRAL_FLUX:
            return duration_seconds * 0.1; // ~10% of audio duration
        case HARMONIQ_SYNC_CHROMA:
            return duration_seconds * 0.15; // ~15% of audio duration  
        case HARMONIQ_SYNC_ENERGY:
            return duration_seconds * 0.05; // ~5% of audio duration
        case HARMONIQ_SYNC_MFCC:
            return duration_seconds * 0.2; // ~20% of audio duration
        case HARMONIQ_SYNC_HYBRID:
            return duration_seconds * 0.4; // ~40% of audio duration (runs all methods)
        default:
            return duration_seconds * 0.1;
    }
}

// MARK: - Engine Management API (Sprint 2 Week 3)

harmoniq_sync_engine_t* harmoniq_sync_create_engine(void) {
    try {
        auto engine = new SyncEngine();
        return reinterpret_cast<harmoniq_sync_engine_t*>(engine);
    } catch (...) {
        return nullptr;
    }
}

void harmoniq_sync_destroy_engine(harmoniq_sync_engine_t* engine) {
    if (engine) {
        auto syncEngine = reinterpret_cast<SyncEngine*>(engine);
        delete syncEngine;
    }
}

harmoniq_sync_error_t harmoniq_sync_process(
    harmoniq_sync_engine_t* engine,
    const float* reference_samples, size_t ref_count,
    const float* target_samples, size_t target_count,
    harmoniq_sync_result_t* result
) {
    // Validate inputs
    if (!engine || !reference_samples || !target_samples || !result) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    if (ref_count == 0 || target_count == 0) {
        return HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA;
    }
    
    try {
        auto syncEngine = reinterpret_cast<SyncEngine*>(engine);
        
        // Use default sample rate of 44.1kHz for this simplified interface
        // In production, sample rate should be passed as parameter
        double sampleRate = 44100.0;
        
        // Use spectral flux as default method for this interface
        // In production, method should be configurable
        harmoniq_sync_method_t method = HARMONIQ_SYNC_SPECTRAL_FLUX;
        
        // Process using the SyncEngine
        *result = syncEngine->process(
            reference_samples, ref_count,
            target_samples, target_count,
            sampleRate,
            method
        );
        
        return result->error;
        
    } catch (const std::exception& e) {
        // Create error result
        *result = {};
        result->error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
        std::strcpy(result->method, "Exception");
        return HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
    } catch (...) {
        // Create error result
        *result = {};
        result->error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
        std::strcpy(result->method, "Unknown");
        return HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
    }
}

harmoniq_sync_error_t harmoniq_sync_set_engine_config(
    harmoniq_sync_engine_t* engine,
    const harmoniq_sync_config_t* config
) {
    if (!engine || !config) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    try {
        auto syncEngine = reinterpret_cast<SyncEngine*>(engine);
        
        // Validate config first
        auto validationError = syncEngine->validateConfig();
        if (validationError != HARMONIQ_SYNC_SUCCESS) {
            return validationError;
        }
        
        syncEngine->setConfig(*config);
        return HARMONIQ_SYNC_SUCCESS;
        
    } catch (...) {
        return HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
    }
}

harmoniq_sync_config_t harmoniq_sync_get_engine_config(harmoniq_sync_engine_t* engine) {
    harmoniq_sync_config_t defaultConfig = harmoniq_sync_default_config();
    
    if (!engine) {
        return defaultConfig;
    }
    
    try {
        auto syncEngine = reinterpret_cast<SyncEngine*>(engine);
        return syncEngine->getConfig();
    } catch (...) {
        return defaultConfig;
    }
}

} // extern "C"