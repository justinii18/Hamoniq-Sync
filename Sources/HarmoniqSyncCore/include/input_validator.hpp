//
//  input_validator.hpp
//  HarmoniqSyncCore
//
//  Comprehensive input validation system for production-grade audio processing
//

#ifndef INPUT_VALIDATOR_HPP
#define INPUT_VALIDATOR_HPP

#include "harmoniq_sync.h"
#include "error_handler.hpp"
#include <vector>
#include <string>
#include <map>
#include <limits>

namespace HarmoniqSync {

/// Audio quality assessment results
struct AudioQualityReport {
    // Basic properties
    double sampleRate;
    size_t sampleCount;
    double durationSeconds;
    
    // Content analysis
    double rmsLevel;            // Root mean square level
    double peakLevel;           // Maximum absolute amplitude
    double dynamicRange;        // Difference between peak and RMS (dB)
    double silenceRatio;        // Fraction of samples below silence threshold
    double clippingRatio;       // Fraction of samples at or near full scale
    
    // Spectral characteristics
    double spectralCentroid;    // Brightness measure
    double spectralRolloff;     // High frequency content
    double zeroCrossingRate;    // Rate of sign changes
    
    // Quality indicators
    bool hasSufficientContent;  // Enough non-silent content for sync
    bool hasExcessiveClipping;  // Too much distortion
    bool hasGoodDynamicRange;   // Sufficient amplitude variation
    bool isMonotonic;          // Constant or nearly constant signal
    
    // Recommendations
    std::vector<std::string> warnings;
    std::vector<std::string> recommendations;
};

/// Configuration validation results
struct ConfigValidationResult {
    bool isValid;
    std::vector<ErrorContext> errors;
    std::vector<ErrorContext> warnings;
    std::map<std::string, std::string> corrections; // Suggested corrections
    harmoniq_sync_config_t correctedConfig;         // Auto-corrected version
    
    ConfigValidationResult() : isValid(false) {}
};

/// Input validation comprehensive results
struct ValidationResult {
    bool isValid;
    AudioQualityReport referenceAudio;
    AudioQualityReport targetAudio;
    ConfigValidationResult configValidation;
    std::vector<ErrorContext> errors;
    std::vector<ErrorContext> warnings;
    
    // Performance estimates
    double estimatedProcessingTime;
    size_t estimatedMemoryUsage;
    
    ValidationResult() : isValid(false), estimatedProcessingTime(0.0), estimatedMemoryUsage(0) {}
};

/// Comprehensive input validator for audio and configuration
class InputValidator {
public:
    // MARK: - Audio Validation
    
    /// Validate basic audio parameters
    static ErrorContext validateAudioFormat(
        const float* audioData,
        size_t sampleCount,
        double sampleRate,
        const std::string& audioName = "audio"
    );
    
    /// Perform comprehensive audio quality analysis
    static AudioQualityReport analyzeAudioQuality(
        const float* audioData,
        size_t sampleCount,
        double sampleRate,
        const std::string& audioName = "audio"
    );
    
    /// Check if audio has sufficient content for synchronization
    static bool hasSufficientContent(
        const AudioQualityReport& report,
        harmoniq_sync_method_t method
    );
    
    /// Validate audio length requirements for specific method
    static ErrorContext validateAudioLength(
        size_t sampleCount,
        double sampleRate,
        harmoniq_sync_method_t method
    );
    
    /// Check audio compatibility (sample rates, etc.)
    static ErrorContext validateAudioCompatibility(
        const AudioQualityReport& reference,
        const AudioQualityReport& target
    );
    
    // MARK: - Configuration Validation
    
    /// Validate complete configuration
    static ConfigValidationResult validateConfiguration(
        const harmoniq_sync_config_t& config
    );
    
    /// Validate specific configuration parameter
    static ErrorContext validateParameter(
        const std::string& paramName,
        double value,
        double minValue,
        double maxValue,
        const std::string& suggestion = ""
    );
    
    /// Auto-correct configuration parameters
    static harmoniq_sync_config_t autoCorrectConfiguration(
        const harmoniq_sync_config_t& config
    );
    
    /// Optimize configuration for specific audio characteristics
    static harmoniq_sync_config_t optimizeConfiguration(
        const harmoniq_sync_config_t& baseConfig,
        const AudioQualityReport& referenceAudio,
        const AudioQualityReport& targetAudio
    );
    
    // MARK: - Comprehensive Validation
    
    /// Validate complete synchronization request
    static ValidationResult validateSyncRequest(
        const float* referenceAudio, size_t refSampleCount,
        const float* targetAudio, size_t targetSampleCount,
        double sampleRate,
        harmoniq_sync_method_t method,
        const harmoniq_sync_config_t& config
    );
    
    /// Quick validation for basic requirements (faster)
    static ErrorContext quickValidate(
        const float* referenceAudio, size_t refSampleCount,
        const float* targetAudio, size_t targetSampleCount,
        double sampleRate
    );
    
    // MARK: - Performance Estimation
    
    /// Estimate processing time for given parameters
    static double estimateProcessingTime(
        size_t audioLengthSamples,
        double sampleRate,
        harmoniq_sync_method_t method,
        const harmoniq_sync_config_t& config
    );
    
    /// Estimate memory usage for processing
    static size_t estimateMemoryUsage(
        size_t refSampleCount,
        size_t targetSampleCount,
        const harmoniq_sync_config_t& config
    );
    
    // MARK: - Validation Rules Configuration
    
    struct ValidationLimits {
        // Audio format limits
        double minSampleRate = 8000.0;
        double maxSampleRate = 192000.0;
        size_t minSampleCount = 8000;      // ~1 second at 8kHz
        size_t maxSampleCount = 1073741824; // 1GB at 4 bytes per sample
        
        // Quality thresholds
        double silenceThreshold = -60.0;    // dB
        double maxSilenceRatio = 0.9;       // 90% silence max
        double minDynamicRange = 12.0;      // 12dB minimum
        double maxClippingRatio = 0.05;     // 5% clipping max
        
        // Configuration limits
        double minConfidenceThreshold = 0.0;
        double maxConfidenceThreshold = 1.0;
        int minWindowSize = 64;
        int maxWindowSize = 8192;
        int minHopSize = 16;
        double minNoiseGate = -120.0;
        double maxNoiseGate = 0.0;
        
        // Performance limits
        size_t maxMemoryUsage = 2147483648; // 2GB max
        double maxProcessingTime = 3600.0;  // 1 hour max
    };
    
    /// Set validation limits
    static void setValidationLimits(const ValidationLimits& limits);
    
    /// Get current validation limits
    static const ValidationLimits& getValidationLimits();
    
private:
    static ValidationLimits validationLimits_;
    
    // MARK: - Internal Analysis Functions
    
    /// Calculate RMS level
    static double calculateRMSLevel(const float* audioData, size_t sampleCount);
    
    /// Calculate peak level
    static double calculatePeakLevel(const float* audioData, size_t sampleCount);
    
    /// Calculate silence ratio
    static double calculateSilenceRatio(
        const float* audioData, 
        size_t sampleCount,
        double silenceThreshold
    );
    
    /// Calculate clipping ratio
    static double calculateClippingRatio(
        const float* audioData,
        size_t sampleCount,
        double clippingThreshold = 0.95
    );
    
    /// Calculate spectral centroid
    static double calculateSpectralCentroid(const float* audioData, size_t sampleCount);
    
    /// Calculate zero crossing rate
    static double calculateZeroCrossingRate(const float* audioData, size_t sampleCount);
    
    /// Check if signal is monotonic (constant)
    static bool isMonotonic(const float* audioData, size_t sampleCount, double threshold = 0.001);
    
    /// Generate quality recommendations
    static std::vector<std::string> generateRecommendations(const AudioQualityReport& report);
    
    /// Generate quality warnings
    static std::vector<std::string> generateWarnings(const AudioQualityReport& report);
};

/// Real-time input validator for streaming processing
class StreamingValidator {
public:
    StreamingValidator(double sampleRate, size_t blockSize);
    ~StreamingValidator();
    
    /// Process audio block and update validation state
    ErrorContext processBlock(const float* audioData, size_t blockSize);
    
    /// Get current validation state
    AudioQualityReport getCurrentState() const;
    
    /// Check if current state is valid for synchronization
    bool isCurrentStateValid() const;
    
    /// Reset validation state
    void reset();

private:
    double sampleRate_;
    size_t blockSize_;
    size_t totalSamples_;
    double runningRMS_;
    double runningPeak_;
    size_t silentSamples_;
    size_t clippedSamples_;
    double runningZCR_;
    
    // Internal state for streaming calculations
    std::vector<float> analysisBuffer_;
    size_t bufferPos_;
};

} // namespace HarmoniqSync

#endif /* INPUT_VALIDATOR_HPP */