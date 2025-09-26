//
//  harmoniq_sync.h
//  HarmoniqSyncCore
//
//  C API interface for HarmoniqSync audio alignment engine
//

#ifndef HARMONIQ_SYNC_H
#define HARMONIQ_SYNC_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Types and Enums

typedef enum {
    HARMONIQ_SYNC_SUCCESS = 0,
    HARMONIQ_SYNC_ERROR_INVALID_INPUT = -1,
    HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA = -2,
    HARMONIQ_SYNC_ERROR_PROCESSING_FAILED = -3,
    HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY = -4,
    HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT = -5
} harmoniq_sync_error_t;

typedef enum {
    HARMONIQ_SYNC_SPECTRAL_FLUX = 0,
    HARMONIQ_SYNC_CHROMA = 1,
    HARMONIQ_SYNC_ENERGY = 2,
    HARMONIQ_SYNC_MFCC = 3,
    HARMONIQ_SYNC_HYBRID = 4
} harmoniq_sync_method_t;

typedef struct {
    int64_t offset_samples;          // Alignment offset in samples
    double confidence;               // Confidence score [0.0, 1.0]
    double peak_correlation;         // Maximum correlation value
    double secondary_peak_ratio;     // Ratio of second-best to best peak
    double snr_estimate;            // Signal-to-noise ratio estimate (dB)
    double noise_floor_db;          // Noise floor level (dB)
    char method[32];                // Algorithm used
    harmoniq_sync_error_t error;    // Error code (0 = success)
} harmoniq_sync_result_t;

typedef struct {
    harmoniq_sync_result_t* results;
    size_t count;
    harmoniq_sync_error_t error;
} harmoniq_sync_batch_result_t;

typedef struct {
    double confidence_threshold;     // Minimum confidence to accept result
    int64_t max_offset_samples;     // Maximum search offset
    int window_size;                // Analysis window size
    int hop_size;                   // Hop size for analysis
    double noise_gate_db;           // Noise gate threshold
    int enable_drift_correction;   // Enable drift correction (0/1)
} harmoniq_sync_config_t;

// MARK: - Core Alignment Functions

/// Align two audio clips using specified method
/// @param reference_audio Reference audio samples (mono, float)
/// @param ref_length Number of samples in reference audio
/// @param target_audio Target audio samples (mono, float)
/// @param target_length Number of samples in target audio
/// @param sample_rate Sample rate for both audio clips
/// @param method Alignment method to use
/// @param config Configuration parameters
/// @return Alignment result with offset and confidence metrics
harmoniq_sync_result_t harmoniq_sync_align(
    const float* reference_audio, size_t ref_length,
    const float* target_audio, size_t target_length,
    double sample_rate,
    harmoniq_sync_method_t method,
    const harmoniq_sync_config_t* config
);

/// Align multiple target clips against a single reference
/// @param reference_audio Reference audio samples
/// @param ref_length Number of samples in reference
/// @param target_audios Array of pointers to target audio data
/// @param target_lengths Array of target audio lengths
/// @param target_count Number of target clips
/// @param sample_rate Sample rate for all audio
/// @param method Alignment method to use
/// @param config Configuration parameters
/// @return Batch result with all alignment results
harmoniq_sync_batch_result_t harmoniq_sync_align_batch(
    const float* reference_audio, size_t ref_length,
    const float** target_audios, const size_t* target_lengths, size_t target_count,
    double sample_rate,
    harmoniq_sync_method_t method,
    const harmoniq_sync_config_t* config
);

// MARK: - Configuration Management

/// Create default configuration
/// @return Default configuration with recommended settings
harmoniq_sync_config_t harmoniq_sync_default_config(void);

/// Create configuration optimized for specific use case
/// @param use_case "music", "speech", "ambient", or "mixed"
/// @return Optimized configuration
harmoniq_sync_config_t harmoniq_sync_config_for_use_case(const char* use_case);

// MARK: - Memory Management

/// Free single alignment result (if needed for dynamic allocations)
/// @param result Result to free
void harmoniq_sync_free_result(harmoniq_sync_result_t* result);

/// Free batch alignment results
/// @param batch_result Batch result to free
void harmoniq_sync_free_batch_result(harmoniq_sync_batch_result_t* batch_result);

// MARK: - Utility Functions

/// Get human-readable description of error code
/// @param error Error code
/// @return Error description string
const char* harmoniq_sync_error_description(harmoniq_sync_error_t error);

/// Get human-readable name of alignment method
/// @param method Alignment method
/// @return Method name string
const char* harmoniq_sync_method_name(harmoniq_sync_method_t method);

/// Validate configuration parameters
/// @param config Configuration to validate
/// @return Error code (HARMONIQ_SYNC_SUCCESS if valid)
harmoniq_sync_error_t harmoniq_sync_validate_config(const harmoniq_sync_config_t* config);

/// Get recommended minimum audio length for reliable alignment
/// @param method Alignment method
/// @param sample_rate Sample rate
/// @return Minimum recommended length in samples
size_t harmoniq_sync_min_audio_length(harmoniq_sync_method_t method, double sample_rate);

// MARK: - Engine Management

/// Opaque handle to sync engine instance
typedef struct harmoniq_sync_engine harmoniq_sync_engine_t;

/// Create new sync engine instance
/// @return Pointer to sync engine or NULL on failure
harmoniq_sync_engine_t* harmoniq_sync_create_engine(void);

/// Destroy sync engine instance
/// @param engine Engine instance to destroy
void harmoniq_sync_destroy_engine(harmoniq_sync_engine_t* engine);

/// Main processing function for end-to-end synchronization
/// This is the primary function specified in Sprint 2 Week 3
/// @param engine Sync engine instance
/// @param reference_samples Reference audio samples (mono, float)
/// @param ref_count Number of samples in reference audio
/// @param target_samples Target audio samples (mono, float)
/// @param target_count Number of samples in target audio
/// @param result Output sync result
/// @return Error code (HARMONIQ_SYNC_SUCCESS on success)
harmoniq_sync_error_t harmoniq_sync_process(
    harmoniq_sync_engine_t* engine,
    const float* reference_samples, size_t ref_count,
    const float* target_samples, size_t target_count,
    harmoniq_sync_result_t* result
);

/// Set configuration for sync engine
/// @param engine Sync engine instance
/// @param config Configuration parameters
/// @return Error code
harmoniq_sync_error_t harmoniq_sync_set_engine_config(
    harmoniq_sync_engine_t* engine,
    const harmoniq_sync_config_t* config
);

/// Get configuration from sync engine
/// @param engine Sync engine instance
/// @return Current configuration
harmoniq_sync_config_t harmoniq_sync_get_engine_config(harmoniq_sync_engine_t* engine);

// MARK: - Version Information

/// Get library version string
/// @return Version string (e.g., "1.0.0")
const char* harmoniq_sync_version(void);

/// Get build information
/// @return Build info string with date and features
const char* harmoniq_sync_build_info(void);

#ifdef __cplusplus
}
#endif

#endif /* HARMONIQ_SYNC_H */