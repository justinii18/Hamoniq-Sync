//
//  input_validator.cpp
//  HarmoniqSyncCore
//
//  Comprehensive input validation system for production-grade audio processing
//

#include "../include/input_validator.hpp"
#include <cmath>
#include <algorithm>
#include <numeric>
#include <sstream>

namespace HarmoniqSync {

// Static member definitions
InputValidator::ValidationLimits InputValidator::validationLimits_;

// MARK: - Audio Validation

ErrorContext InputValidator::validateAudioFormat(
    const float* audioData,
    size_t sampleCount,
    double sampleRate,
    const std::string& audioName
) {
    ErrorScope scope("validateAudioFormat");
    scope.addMetadata("audio_name", audioName);
    scope.addMetadata("sample_count", std::to_string(sampleCount));
    scope.addMetadata("sample_rate", std::to_string(sampleRate));
    
    // Check null pointer
    if (!audioData) {
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            "Audio data pointer is null",
            "InputValidator",
            __FUNCTION__,
            "Provide valid audio data pointer"
        );
    }
    
    // Check sample count
    if (sampleCount < validationLimits_.minSampleCount) {
        std::ostringstream oss;
        oss << audioName << " has insufficient samples (" << sampleCount 
            << " < " << validationLimits_.minSampleCount << ")";
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA,
            oss.str(),
            "InputValidator",
            __FUNCTION__,
            "Provide audio with at least " + std::to_string(validationLimits_.minSampleCount) + " samples"
        );
    }
    
    if (sampleCount > validationLimits_.maxSampleCount) {
        std::ostringstream oss;
        oss << audioName << " has too many samples (" << sampleCount 
            << " > " << validationLimits_.maxSampleCount << ")";
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            oss.str(),
            "InputValidator",
            __FUNCTION__,
            "Reduce audio length or increase processing limits"
        );
    }
    
    // Check sample rate
    if (sampleRate < validationLimits_.minSampleRate || sampleRate > validationLimits_.maxSampleRate) {
        std::ostringstream oss;
        oss << audioName << " sample rate (" << sampleRate 
            << " Hz) is outside supported range [" << validationLimits_.minSampleRate 
            << ", " << validationLimits_.maxSampleRate << "]";
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT,
            oss.str(),
            "InputValidator",
            __FUNCTION__,
            "Resample audio to supported sample rate (44.1kHz or 48kHz recommended)"
        );
    }
    
    // Check for NaN or infinite values
    for (size_t i = 0; i < sampleCount; ++i) {
        if (!std::isfinite(audioData[i])) {
            std::ostringstream oss;
            oss << audioName << " contains invalid values (NaN/Inf) at sample " << i;
            return ErrorHandler::createError(
                HARMONIQ_SYNC_ERROR_INVALID_INPUT,
                oss.str(),
                "InputValidator",
                __FUNCTION__,
                "Clean audio data to remove NaN/Inf values"
            );
        }
    }
    
    return ErrorHandler::createError(HARMONIQ_SYNC_SUCCESS, "Audio format validation passed");
}

AudioQualityReport InputValidator::analyzeAudioQuality(
    const float* audioData,
    size_t sampleCount,
    double sampleRate,
    const std::string& audioName
) {
    ErrorScope scope("analyzeAudioQuality");
    scope.addMetadata("audio_name", audioName);
    
    AudioQualityReport report;
    report.sampleRate = sampleRate;
    report.sampleCount = sampleCount;
    report.durationSeconds = static_cast<double>(sampleCount) / sampleRate;
    
    // Calculate basic audio metrics
    report.rmsLevel = calculateRMSLevel(audioData, sampleCount);
    report.peakLevel = calculatePeakLevel(audioData, sampleCount);
    report.dynamicRange = 20.0 * std::log10(report.peakLevel / (report.rmsLevel + 1e-10));
    report.silenceRatio = calculateSilenceRatio(audioData, sampleCount, validationLimits_.silenceThreshold);
    report.clippingRatio = calculateClippingRatio(audioData, sampleCount);
    
    // Calculate spectral characteristics
    report.spectralCentroid = calculateSpectralCentroid(audioData, sampleCount);
    report.spectralRolloff = report.spectralCentroid * 1.5; // Approximation
    report.zeroCrossingRate = calculateZeroCrossingRate(audioData, sampleCount);
    
    // Determine quality indicators
    report.hasSufficientContent = (report.silenceRatio < validationLimits_.maxSilenceRatio);
    report.hasExcessiveClipping = (report.clippingRatio > validationLimits_.maxClippingRatio);
    report.hasGoodDynamicRange = (report.dynamicRange >= validationLimits_.minDynamicRange);
    report.isMonotonic = isMonotonic(audioData, sampleCount);
    
    // Generate warnings and recommendations
    report.warnings = generateWarnings(report);
    report.recommendations = generateRecommendations(report);
    
    return report;
}

bool InputValidator::hasSufficientContent(
    const AudioQualityReport& report,
    harmoniq_sync_method_t method
) {
    // Method-specific content requirements
    switch (method) {
        case HARMONIQ_SYNC_SPECTRAL_FLUX:
            return report.hasSufficientContent && !report.isMonotonic && report.zeroCrossingRate > 0.01;
            
        case HARMONIQ_SYNC_CHROMA:
            return report.hasSufficientContent && report.hasGoodDynamicRange && report.spectralCentroid > 200.0;
            
        case HARMONIQ_SYNC_ENERGY:
            return report.hasSufficientContent && report.dynamicRange > 6.0;
            
        case HARMONIQ_SYNC_MFCC:
            return report.hasSufficientContent && !report.hasExcessiveClipping;
            
        case HARMONIQ_SYNC_HYBRID:
            return report.hasSufficientContent;
            
        default:
            return report.hasSufficientContent;
    }
}

ErrorContext InputValidator::validateAudioLength(
    size_t sampleCount,
    double sampleRate,
    harmoniq_sync_method_t method
) {
    // Method-specific minimum length requirements
    size_t minRequired = 0;
    std::string methodName = "Unknown";
    
    switch (method) {
        case HARMONIQ_SYNC_SPECTRAL_FLUX:
            minRequired = static_cast<size_t>(2.0 * sampleRate); // 2 seconds
            methodName = "Spectral Flux";
            break;
        case HARMONIQ_SYNC_CHROMA:
            minRequired = static_cast<size_t>(4.0 * sampleRate); // 4 seconds
            methodName = "Chroma Features";
            break;
        case HARMONIQ_SYNC_ENERGY:
            minRequired = static_cast<size_t>(1.0 * sampleRate); // 1 second
            methodName = "Energy Correlation";
            break;
        case HARMONIQ_SYNC_MFCC:
            minRequired = static_cast<size_t>(3.0 * sampleRate); // 3 seconds
            methodName = "MFCC";
            break;
        case HARMONIQ_SYNC_HYBRID:
            minRequired = static_cast<size_t>(4.0 * sampleRate); // 4 seconds (maximum of all)
            methodName = "Hybrid";
            break;
    }
    
    if (sampleCount < minRequired) {
        std::ostringstream oss;
        oss << "Audio length insufficient for " << methodName << " method ("
            << (static_cast<double>(sampleCount) / sampleRate) << "s < "
            << (static_cast<double>(minRequired) / sampleRate) << "s)";
        
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA,
            oss.str(),
            "InputValidator",
            __FUNCTION__,
            "Provide longer audio or use a different sync method"
        );
    }
    
    return ErrorHandler::createError(HARMONIQ_SYNC_SUCCESS, "Audio length validation passed");
}

ErrorContext InputValidator::validateAudioCompatibility(
    const AudioQualityReport& reference,
    const AudioQualityReport& target
) {
    // Check sample rate compatibility
    double sampleRateDiff = std::abs(reference.sampleRate - target.sampleRate);
    if (sampleRateDiff > 1.0) {
        std::ostringstream oss;
        oss << "Sample rate mismatch: reference=" << reference.sampleRate 
            << "Hz, target=" << target.sampleRate << "Hz";
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT,
            oss.str(),
            "InputValidator",
            __FUNCTION__,
            "Resample both audio files to the same sample rate"
        );
    }
    
    // Check duration compatibility
    double durationRatio = reference.durationSeconds / target.durationSeconds;
    if (durationRatio > 10.0 || durationRatio < 0.1) {
        std::ostringstream oss;
        oss << "Audio duration mismatch too large: reference=" << reference.durationSeconds 
            << "s, target=" << target.durationSeconds << "s (ratio=" << durationRatio << ")";
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            oss.str(),
            "InputValidator",
            __FUNCTION__,
            "Use audio clips with similar duration ranges"
        );
    }
    
    return ErrorHandler::createError(HARMONIQ_SYNC_SUCCESS, "Audio compatibility validation passed");
}

// MARK: - Configuration Validation

ConfigValidationResult InputValidator::validateConfiguration(
    const harmoniq_sync_config_t& config
) {
    ConfigValidationResult result;
    result.correctedConfig = config;
    
    // Validate confidence threshold
    auto confidenceError = validateParameter(
        "confidence_threshold", 
        config.confidence_threshold,
        validationLimits_.minConfidenceThreshold,
        validationLimits_.maxConfidenceThreshold,
        "Use value between 0.0 and 1.0"
    );
    if (confidenceError.code != HARMONIQ_SYNC_SUCCESS) {
        result.errors.push_back(confidenceError);
        result.correctedConfig.confidence_threshold = std::max(
            validationLimits_.minConfidenceThreshold,
            std::min(validationLimits_.maxConfidenceThreshold, config.confidence_threshold)
        );
        result.corrections["confidence_threshold"] = std::to_string(result.correctedConfig.confidence_threshold);
    }
    
    // Validate window size
    auto windowError = validateParameter(
        "window_size",
        static_cast<double>(config.window_size),
        static_cast<double>(validationLimits_.minWindowSize),
        static_cast<double>(validationLimits_.maxWindowSize),
        "Use power-of-two window size (512, 1024, 2048, 4096)"
    );
    if (windowError.code != HARMONIQ_SYNC_SUCCESS) {
        result.errors.push_back(windowError);
        result.correctedConfig.window_size = std::max(
            validationLimits_.minWindowSize,
            std::min(validationLimits_.maxWindowSize, config.window_size)
        );
        result.corrections["window_size"] = std::to_string(result.correctedConfig.window_size);
    }
    
    // Validate hop size relative to window size
    if (config.hop_size <= 0) {
        result.correctedConfig.hop_size = config.window_size / 4; // Default to 25% overlap
        result.corrections["hop_size"] = std::to_string(result.correctedConfig.hop_size);
    } else if (config.hop_size > config.window_size) {
        ErrorContext error = ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            "hop_size (" + std::to_string(config.hop_size) + 
            ") cannot be larger than window_size (" + std::to_string(config.window_size) + ")",
            "InputValidator",
            __FUNCTION__,
            "Set hop_size to window_size/4 or smaller"
        );
        result.errors.push_back(error);
        result.correctedConfig.hop_size = config.window_size / 4;
        result.corrections["hop_size"] = std::to_string(result.correctedConfig.hop_size);
    }
    
    // Validate noise gate
    auto noiseError = validateParameter(
        "noise_gate_db",
        config.noise_gate_db,
        validationLimits_.minNoiseGate,
        validationLimits_.maxNoiseGate,
        "Use negative dB value (-60.0 to 0.0)"
    );
    if (noiseError.code != HARMONIQ_SYNC_SUCCESS) {
        result.errors.push_back(noiseError);
        result.correctedConfig.noise_gate_db = std::max(
            validationLimits_.minNoiseGate,
            std::min(validationLimits_.maxNoiseGate, config.noise_gate_db)
        );
        result.corrections["noise_gate_db"] = std::to_string(result.correctedConfig.noise_gate_db);
    }
    
    result.isValid = result.errors.empty();
    return result;
}

ErrorContext InputValidator::validateParameter(
    const std::string& paramName,
    double value,
    double minValue,
    double maxValue,
    const std::string& suggestion
) {
    if (value < minValue || value > maxValue) {
        std::ostringstream oss;
        oss << "Parameter '" << paramName << "' value (" << value 
            << ") is outside valid range [" << minValue << ", " << maxValue << "]";
        
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            oss.str(),
            "InputValidator",
            __FUNCTION__,
            suggestion.empty() ? ("Use value between " + std::to_string(minValue) + 
                                 " and " + std::to_string(maxValue)) : suggestion
        );
    }
    
    return ErrorHandler::createError(HARMONIQ_SYNC_SUCCESS, "Parameter validation passed");
}

harmoniq_sync_config_t InputValidator::autoCorrectConfiguration(
    const harmoniq_sync_config_t& config
) {
    auto result = validateConfiguration(config);
    return result.correctedConfig;
}

harmoniq_sync_config_t InputValidator::optimizeConfiguration(
    const harmoniq_sync_config_t& baseConfig,
    const AudioQualityReport& referenceAudio,
    const AudioQualityReport& targetAudio
) {
    harmoniq_sync_config_t optimized = baseConfig;
    
    // Adjust window size based on audio characteristics
    double avgDuration = (referenceAudio.durationSeconds + targetAudio.durationSeconds) / 2.0;
    if (avgDuration < 10.0) {
        optimized.window_size = 512;  // Smaller window for short audio
    } else if (avgDuration > 60.0) {
        optimized.window_size = 2048; // Larger window for long audio
    }
    
    // Adjust confidence threshold based on audio quality
    double avgDynamicRange = (referenceAudio.dynamicRange + targetAudio.dynamicRange) / 2.0;
    if (avgDynamicRange < 12.0) {
        optimized.confidence_threshold = 0.6; // Lower threshold for poor quality audio
    } else if (avgDynamicRange > 30.0) {
        optimized.confidence_threshold = 0.8; // Higher threshold for good quality audio
    }
    
    // Adjust noise gate based on silence characteristics
    double avgSilenceRatio = (referenceAudio.silenceRatio + targetAudio.silenceRatio) / 2.0;
    if (avgSilenceRatio > 0.3) {
        optimized.noise_gate_db = -45.0; // More aggressive noise gate for noisy audio
    }
    
    return optimized;
}

// MARK: - Internal Analysis Functions

double InputValidator::calculateRMSLevel(const float* audioData, size_t sampleCount) {
    if (sampleCount == 0) return 0.0;
    
    double sum = 0.0;
    for (size_t i = 0; i < sampleCount; ++i) {
        sum += audioData[i] * audioData[i];
    }
    return std::sqrt(sum / sampleCount);
}

double InputValidator::calculatePeakLevel(const float* audioData, size_t sampleCount) {
    if (sampleCount == 0) return 0.0;
    
    double peak = 0.0;
    for (size_t i = 0; i < sampleCount; ++i) {
        peak = std::max(peak, std::abs(static_cast<double>(audioData[i])));
    }
    return peak;
}

double InputValidator::calculateSilenceRatio(
    const float* audioData,
    size_t sampleCount,
    double silenceThreshold
) {
    if (sampleCount == 0) return 1.0;
    
    double linearThreshold = std::pow(10.0, silenceThreshold / 20.0);
    size_t silentSamples = 0;
    
    for (size_t i = 0; i < sampleCount; ++i) {
        if (std::abs(audioData[i]) < linearThreshold) {
            silentSamples++;
        }
    }
    
    return static_cast<double>(silentSamples) / sampleCount;
}

double InputValidator::calculateClippingRatio(
    const float* audioData,
    size_t sampleCount,
    double clippingThreshold
) {
    if (sampleCount == 0) return 0.0;
    
    size_t clippedSamples = 0;
    
    for (size_t i = 0; i < sampleCount; ++i) {
        if (std::abs(audioData[i]) >= clippingThreshold) {
            clippedSamples++;
        }
    }
    
    return static_cast<double>(clippedSamples) / sampleCount;
}

double InputValidator::calculateZeroCrossingRate(const float* audioData, size_t sampleCount) {
    if (sampleCount < 2) return 0.0;
    
    size_t crossings = 0;
    for (size_t i = 1; i < sampleCount; ++i) {
        if ((audioData[i] >= 0.0) != (audioData[i-1] >= 0.0)) {
            crossings++;
        }
    }
    
    return static_cast<double>(crossings) / (sampleCount - 1);
}

bool InputValidator::isMonotonic(const float* audioData, size_t sampleCount, double threshold) {
    if (sampleCount < 2) return true;
    
    double variance = 0.0;
    double mean = 0.0;
    
    // Calculate mean
    for (size_t i = 0; i < sampleCount; ++i) {
        mean += audioData[i];
    }
    mean /= sampleCount;
    
    // Calculate variance
    for (size_t i = 0; i < sampleCount; ++i) {
        double diff = audioData[i] - mean;
        variance += diff * diff;
    }
    variance /= sampleCount;
    
    return variance < (threshold * threshold);
}

std::vector<std::string> InputValidator::generateWarnings(const AudioQualityReport& report) {
    std::vector<std::string> warnings;
    
    if (report.silenceRatio > 0.5) {
        warnings.push_back("High silence ratio (" + 
                          std::to_string(static_cast<int>(report.silenceRatio * 100)) + 
                          "%) may reduce sync accuracy");
    }
    
    if (report.hasExcessiveClipping) {
        warnings.push_back("Excessive clipping detected (" + 
                          std::to_string(static_cast<int>(report.clippingRatio * 100)) + 
                          "%) - audio may be distorted");
    }
    
    if (!report.hasGoodDynamicRange) {
        warnings.push_back("Poor dynamic range (" + 
                          std::to_string(static_cast<int>(report.dynamicRange)) + 
                          "dB) may reduce sync quality");
    }
    
    if (report.isMonotonic) {
        warnings.push_back("Audio appears to be constant or nearly constant - sync may fail");
    }
    
    return warnings;
}

std::vector<std::string> InputValidator::generateRecommendations(const AudioQualityReport& report) {
    std::vector<std::string> recommendations;
    
    if (report.silenceRatio > 0.3) {
        recommendations.push_back("Consider trimming silent portions or using noise gate");
    }
    
    if (report.hasExcessiveClipping) {
        recommendations.push_back("Reduce input gain or use audio with less distortion");
    }
    
    if (!report.hasGoodDynamicRange) {
        recommendations.push_back("Use audio compression or normalization to improve dynamic range");
    }
    
    if (report.zeroCrossingRate < 0.01) {
        recommendations.push_back("Audio may be too tonal - consider using chroma-based sync method");
    }
    
    return recommendations;
}

// MARK: - Public Interface Methods

ValidationResult InputValidator::validateSyncRequest(
    const float* referenceAudio, size_t refSampleCount,
    const float* targetAudio, size_t targetSampleCount,
    double sampleRate,
    harmoniq_sync_method_t method,
    const harmoniq_sync_config_t& config
) {
    ValidationResult result;
    
    // Validate basic audio format
    auto refFormatError = validateAudioFormat(referenceAudio, refSampleCount, sampleRate, "reference");
    if (refFormatError.code != HARMONIQ_SYNC_SUCCESS) {
        result.errors.push_back(refFormatError);
    }
    
    auto targetFormatError = validateAudioFormat(targetAudio, targetSampleCount, sampleRate, "target");
    if (targetFormatError.code != HARMONIQ_SYNC_SUCCESS) {
        result.errors.push_back(targetFormatError);
    }
    
    if (!result.errors.empty()) {
        result.isValid = false;
        return result;
    }
    
    // Analyze audio quality
    result.referenceAudio = analyzeAudioQuality(referenceAudio, refSampleCount, sampleRate, "reference");
    result.targetAudio = analyzeAudioQuality(targetAudio, targetSampleCount, sampleRate, "target");
    
    // Check audio compatibility
    auto compatError = validateAudioCompatibility(result.referenceAudio, result.targetAudio);
    if (compatError.code != HARMONIQ_SYNC_SUCCESS) {
        result.errors.push_back(compatError);
    }
    
    // Validate configuration
    result.configValidation = validateConfiguration(config);
    if (!result.configValidation.isValid) {
        result.errors.insert(result.errors.end(), 
                           result.configValidation.errors.begin(), 
                           result.configValidation.errors.end());
    }
    
    // Check method-specific requirements
    if (!hasSufficientContent(result.referenceAudio, method)) {
        result.warnings.push_back(ErrorHandler::createError(
            HARMONIQ_SYNC_SUCCESS, ErrorSeverity::Warning,
            "Reference audio may not have sufficient content for " + std::string("selected method"),
            "InputValidator", __FUNCTION__
        ));
    }
    
    if (!hasSufficientContent(result.targetAudio, method)) {
        result.warnings.push_back(ErrorHandler::createError(
            HARMONIQ_SYNC_SUCCESS, ErrorSeverity::Warning,
            "Target audio may not have sufficient content for selected method",
            "InputValidator", __FUNCTION__
        ));
    }
    
    // Performance estimates
    result.estimatedProcessingTime = estimateProcessingTime(
        std::max(refSampleCount, targetSampleCount), sampleRate, method, config
    );
    result.estimatedMemoryUsage = estimateMemoryUsage(refSampleCount, targetSampleCount, config);
    
    result.isValid = result.errors.empty();
    return result;
}

ErrorContext InputValidator::quickValidate(
    const float* referenceAudio, size_t refSampleCount,
    const float* targetAudio, size_t targetSampleCount,
    double sampleRate
) {
    // Quick null checks
    if (!referenceAudio || !targetAudio) {
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            "Null audio data pointer",
            "InputValidator", __FUNCTION__
        );
    }
    
    // Quick size checks
    if (refSampleCount < validationLimits_.minSampleCount || 
        targetSampleCount < validationLimits_.minSampleCount) {
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA,
            "Audio too short for synchronization",
            "InputValidator", __FUNCTION__
        );
    }
    
    // Quick sample rate check
    if (sampleRate < validationLimits_.minSampleRate || sampleRate > validationLimits_.maxSampleRate) {
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT,
            "Unsupported sample rate",
            "InputValidator", __FUNCTION__
        );
    }
    
    return ErrorHandler::createError(HARMONIQ_SYNC_SUCCESS, "Quick validation passed");
}

double InputValidator::estimateProcessingTime(
    size_t audioLengthSamples,
    double sampleRate,
    harmoniq_sync_method_t method,
    const harmoniq_sync_config_t& config
) {
    double durationSeconds = audioLengthSamples / sampleRate;
    double baseMultiplier = 0.1; // Base 10% of audio duration
    
    // Method-specific multipliers
    switch (method) {
        case HARMONIQ_SYNC_SPECTRAL_FLUX: baseMultiplier = 0.08; break;
        case HARMONIQ_SYNC_CHROMA: baseMultiplier = 0.12; break;
        case HARMONIQ_SYNC_ENERGY: baseMultiplier = 0.04; break;
        case HARMONIQ_SYNC_MFCC: baseMultiplier = 0.18; break;
        case HARMONIQ_SYNC_HYBRID: baseMultiplier = 0.35; break;
    }
    
    // Configuration adjustments
    double configMultiplier = 1.0;
    if (config.window_size > 2048) configMultiplier *= 1.5;
    if (config.hop_size < config.window_size / 8) configMultiplier *= 1.2;
    
    return durationSeconds * baseMultiplier * configMultiplier;
}

size_t InputValidator::estimateMemoryUsage(
    size_t refSampleCount,
    size_t targetSampleCount,
    const harmoniq_sync_config_t& config
) {
    size_t totalSamples = refSampleCount + targetSampleCount;
    size_t workingMemory = totalSamples * sizeof(float) * 2; // Input + working buffers
    size_t fftMemory = config.window_size * sizeof(float) * 4; // FFT buffers
    size_t correlationMemory = (refSampleCount + targetSampleCount) * sizeof(double); // Correlation buffer
    
    return workingMemory + fftMemory + correlationMemory;
}

void InputValidator::setValidationLimits(const ValidationLimits& limits) {
    validationLimits_ = limits;
}

const InputValidator::ValidationLimits& InputValidator::getValidationLimits() {
    return validationLimits_;
}

} // namespace HarmoniqSync