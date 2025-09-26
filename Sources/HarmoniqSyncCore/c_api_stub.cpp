//
//  c_api_stub.cpp
//  HarmoniqSyncCore
//
//  Minimal C API implementation for Week 3 testing
//  Contains only utility functions that don't require AlignmentEngine
//

#include "include/harmoniq_sync.h"
#include <string>
#include <cstring>
#include <cstdlib>

extern "C" {

// MARK: - Utility Functions

const char* harmoniq_sync_version(void) {
    return "1.0.0";
}

const char* harmoniq_sync_build_info(void) {
    return "HarmoniqSync 1.0.0 (C++ Engine) - Built " __DATE__ " " __TIME__ 
           " [Week 3 Sprint 1 - AudioProcessor Testing Phase]";
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

// MARK: - Configuration Functions

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

// MARK: - Memory Management Stubs

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

// MARK: - Alignment Function Stubs (Not Implemented - Require AlignmentEngine)

harmoniq_sync_result_t harmoniq_sync_align(
    const float* reference_audio, size_t ref_length,
    const float* target_audio, size_t target_length,
    double sample_rate,
    harmoniq_sync_method_t method,
    const harmoniq_sync_config_t* config
) {
    harmoniq_sync_result_t result = {};
    
    // Basic input validation
    if (!reference_audio || !target_audio || ref_length == 0 || target_length == 0 || sample_rate <= 0) {
        result.error = HARMONIQ_SYNC_ERROR_INVALID_INPUT;
        std::strcpy(result.method, "Invalid");
        return result;
    }
    
    // Return error indicating AlignmentEngine not implemented
    result.error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
    std::strcpy(result.method, "NotImplemented");
    result.offset_samples = 0;
    result.confidence = 0.0;
    result.peak_correlation = 0.0;
    result.secondary_peak_ratio = 0.0;
    result.snr_estimate = -60.0;
    result.noise_floor_db = -60.0;
    
    return result;
}

harmoniq_sync_batch_result_t harmoniq_sync_align_batch(
    const float* reference_audio, size_t ref_length,
    const float** target_audios, const size_t* target_lengths, size_t target_count,
    double sample_rate,
    harmoniq_sync_method_t method,
    const harmoniq_sync_config_t* config
) {
    harmoniq_sync_batch_result_t batch_result = {};
    
    // Basic input validation
    if (!reference_audio || !target_audios || !target_lengths || target_count == 0) {
        batch_result.error = HARMONIQ_SYNC_ERROR_INVALID_INPUT;
        return batch_result;
    }
    
    // Return error indicating AlignmentEngine not implemented
    batch_result.error = HARMONIQ_SYNC_ERROR_PROCESSING_FAILED;
    batch_result.results = nullptr;
    batch_result.count = 0;
    
    return batch_result;
}

} // extern "C"