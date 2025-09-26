//
//  graceful_degradation.cpp  
//  HarmoniqSyncCore
//
//  Graceful degradation system with fallback algorithms and adaptive processing
//

#include "../include/graceful_degradation.hpp"
#include <algorithm>
#include <cmath>

namespace HarmoniqSync {

// Static member definitions
std::map<std::string, GracefulDegradation::CustomDegradationFunction> GracefulDegradation::customStrategies_;
std::vector<ProgressiveQualityReduction::QualityLevel> ProgressiveQualityReduction::predefinedLevels_;

// MARK: - GracefulDegradation Implementation

DegradationResult GracefulDegradation::attemptRecovery(const DegradationContext& context) {
    ErrorScope scope("attemptRecovery");
    scope.addMetadata("original_error", std::to_string(static_cast<int>(context.originalError)));
    scope.addMetadata("current_level", std::to_string(static_cast<int>(context.currentLevel)));
    
    // Try different strategies based on error type and context
    std::vector<DegradationStrategy> strategySequence;
    
    switch (context.originalError) {
        case HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY:
            strategySequence = {DegradationStrategy::ReduceQuality, 
                               DegradationStrategy::ReducePrecision,
                               DegradationStrategy::FallbackMethod};
            break;
            
        case HARMONIQ_SYNC_ERROR_PROCESSING_FAILED:
            strategySequence = {DegradationStrategy::FallbackMethod,
                               DegradationStrategy::AdaptiveParameters,
                               DegradationStrategy::ReduceQuality};
            break;
            
        case HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA:
            strategySequence = {DegradationStrategy::AdaptiveParameters,
                               DegradationStrategy::ReduceQuality,
                               DegradationStrategy::FallbackMethod};
            break;
            
        default:
            strategySequence = {DegradationStrategy::Progressive};
            break;
    }
    
    // Try each strategy in sequence
    for (auto strategy : strategySequence) {
        // Skip strategies already attempted
        std::string strategyName = "strategy_" + std::to_string(static_cast<int>(strategy));
        if (std::find(context.attemptedStrategies.begin(), 
                     context.attemptedStrategies.end(), 
                     strategyName) != context.attemptedStrategies.end()) {
            continue;
        }
        
        DegradationLevel nextLevel = static_cast<DegradationLevel>(
            std::min(static_cast<int>(context.currentLevel) + 1, 
                    static_cast<int>(DegradationLevel::Emergency))
        );
        
        auto result = applyDegradationStrategy(strategy, nextLevel, context);
        if (result.canRecover) {
            scope.addMetadata("recovery_strategy", strategyName);
            scope.addMetadata("recovery_level", std::to_string(static_cast<int>(result.levelApplied)));
            return result;
        }
    }
    
    // All strategies failed - return emergency fallback
    DegradationResult emergencyResult;
    emergencyResult.canRecover = false;
    emergencyResult.levelApplied = DegradationLevel::Emergency;
    emergencyResult.strategyUsed = DegradationStrategy::UserGuided;
    emergencyResult.description = "All automatic recovery attempts failed - user intervention required";
    
    return emergencyResult;
}

DegradationResult GracefulDegradation::recommendDegradation(
    const AudioQualityReport& referenceAudio,
    const AudioQualityReport& targetAudio,
    const harmoniq_sync_config_t& config,
    size_t availableMemory,
    double maxProcessingTime
) {
    DegradationResult result;
    result.canRecover = true;
    result.levelApplied = DegradationLevel::None;
    result.modifiedConfig = config;
    
    // Estimate resource requirements
    size_t estimatedMemory = InputValidator::estimateMemoryUsage(
        static_cast<size_t>(referenceAudio.sampleCount),
        static_cast<size_t>(targetAudio.sampleCount),
        config
    );
    
    double estimatedTime = InputValidator::estimateProcessingTime(
        std::max(referenceAudio.sampleCount, targetAudio.sampleCount),
        referenceAudio.sampleRate,
        HARMONIQ_SYNC_SPECTRAL_FLUX, // Default method for estimation
        config
    );
    
    // Check if degradation is needed
    bool memoryPressure = (estimatedMemory > availableMemory * 0.8);
    bool timePressure = (estimatedTime > maxProcessingTime * 0.8);
    
    if (!memoryPressure && !timePressure) {
        result.description = "No degradation needed - resources sufficient for full quality processing";
        return result;
    }
    
    // Apply appropriate degradation strategy
    if (memoryPressure && timePressure) {
        result.strategyUsed = DegradationStrategy::Progressive;
        result.levelApplied = DegradationLevel::Moderate;
        result.modifiedConfig = AdaptiveParameterAdjuster::adjustForMemoryConstraints(
            config, availableMemory, static_cast<size_t>(referenceAudio.sampleCount)
        );
        result.modifiedConfig = AdaptiveParameterAdjuster::adjustForTimeConstraints(
            result.modifiedConfig, maxProcessingTime, estimatedTime
        );
        result.description = "Applied memory and time optimizations";
        result.processingSpeedup = 2.0;
        result.expectedConfidenceImpact = 15.0;
        result.expectedAccuracyImpact = 10.0;
    } else if (memoryPressure) {
        result.strategyUsed = DegradationStrategy::ReducePrecision;
        result.levelApplied = DegradationLevel::Minimal;
        result.modifiedConfig = AdaptiveParameterAdjuster::adjustForMemoryConstraints(
            config, availableMemory, static_cast<size_t>(referenceAudio.sampleCount)
        );
        result.description = "Applied memory optimizations";
        result.processingSpeedup = 1.3;
        result.expectedConfidenceImpact = 8.0;
        result.expectedAccuracyImpact = 5.0;
    } else if (timePressure) {
        result.strategyUsed = DegradationStrategy::ReduceQuality;
        result.levelApplied = DegradationLevel::Minimal;
        result.modifiedConfig = AdaptiveParameterAdjuster::adjustForTimeConstraints(
            config, maxProcessingTime, estimatedTime
        );
        result.description = "Applied time optimizations";
        result.processingSpeedup = 1.5;
        result.expectedConfidenceImpact = 10.0;
        result.expectedAccuracyImpact = 8.0;
    }
    
    return result;
}

DegradationResult GracefulDegradation::applyDegradationStrategy(
    DegradationStrategy strategy,
    DegradationLevel level,
    const DegradationContext& context
) {
    switch (strategy) {
        case DegradationStrategy::ReduceQuality:
            return applyReduceQuality(context, level);
        case DegradationStrategy::FallbackMethod:
            return applyFallbackMethod(context);
        case DegradationStrategy::ReducePrecision:
            return applyReducePrecision(context, level);
        case DegradationStrategy::AdaptiveParameters:
            return applyAdaptiveParameters(context);
        case DegradationStrategy::Progressive:
            return applyProgressive(context);
        default:
            DegradationResult result;
            result.canRecover = false;
            result.description = "Unknown degradation strategy";
            return result;
    }
}

// MARK: - Strategy Implementations

DegradationResult GracefulDegradation::applyReduceQuality(
    const DegradationContext& context, 
    DegradationLevel level
) {
    DegradationResult result;
    result.canRecover = true;
    result.levelApplied = level;
    result.strategyUsed = DegradationStrategy::ReduceQuality;
    result.modifiedConfig = context.originalConfig;
    
    // Apply quality reduction based on level
    switch (level) {
        case DegradationLevel::Minimal:
            result.modifiedConfig.window_size = std::max(512, result.modifiedConfig.window_size / 2);
            result.modifiedConfig.hop_size = result.modifiedConfig.window_size / 4;
            result.expectedConfidenceImpact = 5.0;
            result.expectedAccuracyImpact = 3.0;
            result.processingSpeedup = 1.5;
            break;
            
        case DegradationLevel::Moderate:
            result.modifiedConfig.window_size = 512;
            result.modifiedConfig.hop_size = 128;
            result.modifiedConfig.confidence_threshold = std::max(0.5, result.modifiedConfig.confidence_threshold - 0.1);
            result.expectedConfidenceImpact = 15.0;
            result.expectedAccuracyImpact = 10.0;
            result.processingSpeedup = 2.0;
            break;
            
        case DegradationLevel::Significant:
            result.modifiedConfig.window_size = 256;
            result.modifiedConfig.hop_size = 64;
            result.modifiedConfig.confidence_threshold = std::max(0.4, result.modifiedConfig.confidence_threshold - 0.2);
            result.expectedConfidenceImpact = 25.0;
            result.expectedAccuracyImpact = 20.0;
            result.processingSpeedup = 3.0;
            break;
            
        case DegradationLevel::Emergency:
            result.modifiedConfig.window_size = 256;
            result.modifiedConfig.hop_size = 128;
            result.modifiedConfig.confidence_threshold = 0.3;
            result.expectedConfidenceImpact = 40.0;
            result.expectedAccuracyImpact = 35.0;
            result.processingSpeedup = 4.0;
            break;
            
        default:
            break;
    }
    
    result.description = "Reduced processing quality for better performance";
    return result;
}

DegradationResult GracefulDegradation::applyFallbackMethod(const DegradationContext& context) {
    DegradationResult result;
    result.levelApplied = DegradationLevel::Minimal;
    result.strategyUsed = DegradationStrategy::FallbackMethod;
    result.modifiedConfig = context.originalConfig;
    
    // Select fallback method based on audio characteristics
    auto compatibleMethods = FallbackMethodSelector::getCompatibleMethods(
        context.referenceQuality, context.targetQuality
    );
    
    if (!compatibleMethods.empty()) {
        result.canRecover = true;
        result.recommendedMethod = compatibleMethods[0]; // Use most compatible method
        result.description = "Using fallback synchronization method: " + 
                            std::string("alternative algorithm");
        result.expectedConfidenceImpact = 10.0;
        result.expectedAccuracyImpact = 8.0;
        result.processingSpeedup = 1.2;
    } else {
        result.canRecover = false;
        result.description = "No compatible fallback methods available";
    }
    
    return result;
}

DegradationResult GracefulDegradation::applyReducePrecision(
    const DegradationContext& context,
    DegradationLevel level
) {
    DegradationResult result;
    result.canRecover = true;
    result.levelApplied = level;
    result.strategyUsed = DegradationStrategy::ReducePrecision;
    result.modifiedConfig = context.originalConfig;
    
    // Reduce precision by simplifying algorithms
    switch (level) {
        case DegradationLevel::Minimal:
            result.modifiedConfig.hop_size = std::max(result.modifiedConfig.hop_size, 
                                                     result.modifiedConfig.window_size / 2);
            result.processingSpeedup = 1.8;
            result.expectedAccuracyImpact = 5.0;
            break;
            
        case DegradationLevel::Moderate:
            result.modifiedConfig.hop_size = result.modifiedConfig.window_size / 2;
            result.modifiedConfig.confidence_threshold = std::max(0.5, result.modifiedConfig.confidence_threshold - 0.05);
            result.processingSpeedup = 2.5;
            result.expectedAccuracyImpact = 12.0;
            break;
            
        case DegradationLevel::Significant:
            result.modifiedConfig.hop_size = result.modifiedConfig.window_size;
            result.modifiedConfig.confidence_threshold = 0.4;
            result.processingSpeedup = 4.0;
            result.expectedAccuracyImpact = 25.0;
            break;
            
        default:
            break;
    }
    
    result.description = "Reduced algorithm precision for faster processing";
    result.expectedConfidenceImpact = result.expectedAccuracyImpact * 0.8;
    
    return result;
}

DegradationResult GracefulDegradation::applyAdaptiveParameters(const DegradationContext& context) {
    DegradationResult result;
    result.canRecover = true;
    result.levelApplied = DegradationLevel::Minimal;
    result.strategyUsed = DegradationStrategy::AdaptiveParameters;
    
    // Adapt parameters based on audio quality
    result.modifiedConfig = AdaptiveParameterAdjuster::adjustForAudioQuality(
        context.originalConfig, context.referenceQuality, context.targetQuality
    );
    
    double qualityImpact = AdaptiveParameterAdjuster::estimateQualityImpact(
        context.originalConfig, result.modifiedConfig
    );
    
    result.expectedConfidenceImpact = qualityImpact * 100.0;
    result.expectedAccuracyImpact = qualityImpact * 80.0;
    result.processingSpeedup = 1.0 + qualityImpact;
    result.description = "Automatically adjusted parameters based on audio characteristics";
    
    return result;
}

DegradationResult GracefulDegradation::applyProgressive(const DegradationContext& context) {
    DegradationResult result;
    
    // Try multiple strategies in order of least impact
    std::vector<DegradationStrategy> strategies = {
        DegradationStrategy::AdaptiveParameters,
        DegradationStrategy::ReducePrecision,
        DegradationStrategy::ReduceQuality,
        DegradationStrategy::FallbackMethod
    };
    
    for (auto strategy : strategies) {
        auto attemptResult = applyDegradationStrategy(strategy, 
                                                     DegradationLevel::Minimal, 
                                                     context);
        if (attemptResult.canRecover) {
            result = attemptResult;
            result.strategyUsed = DegradationStrategy::Progressive;
            result.description = "Applied progressive degradation: " + attemptResult.description;
            break;
        }
    }
    
    if (!result.canRecover) {
        result.description = "Progressive degradation failed - no viable recovery path";
    }
    
    return result;
}

// MARK: - AdaptiveParameterAdjuster Implementation

harmoniq_sync_config_t AdaptiveParameterAdjuster::adjustForAudioQuality(
    const harmoniq_sync_config_t& baseConfig,
    const AudioQualityReport& referenceAudio,
    const AudioQualityReport& targetAudio
) {
    harmoniq_sync_config_t adjusted = baseConfig;
    
    // Adjust based on dynamic range
    double avgDynamicRange = (referenceAudio.dynamicRange + targetAudio.dynamicRange) / 2.0;
    if (avgDynamicRange < 12.0) {
        adjusted.confidence_threshold = std::max(0.5, adjusted.confidence_threshold - 0.1);
        adjusted.noise_gate_db = std::max(-50.0, adjusted.noise_gate_db - 5.0);
    }
    
    // Adjust based on silence ratio
    double avgSilenceRatio = (referenceAudio.silenceRatio + targetAudio.silenceRatio) / 2.0;
    if (avgSilenceRatio > 0.3) {
        adjusted.noise_gate_db = std::max(-55.0, adjusted.noise_gate_db - 10.0);
    }
    
    // Adjust based on duration
    double avgDuration = (referenceAudio.durationSeconds + targetAudio.durationSeconds) / 2.0;
    if (avgDuration < 10.0) {
        adjusted.window_size = std::max(512, adjusted.window_size / 2);
        adjusted.hop_size = adjusted.window_size / 4;
    }
    
    return adjusted;
}

harmoniq_sync_config_t AdaptiveParameterAdjuster::adjustForMemoryConstraints(
    const harmoniq_sync_config_t& baseConfig,
    size_t availableMemory,
    size_t audioLength
) {
    harmoniq_sync_config_t adjusted = baseConfig;
    
    // Calculate memory pressure ratio
    size_t estimatedUsage = InputValidator::estimateMemoryUsage(audioLength, audioLength, baseConfig);
    double memoryPressure = static_cast<double>(estimatedUsage) / availableMemory;
    
    if (memoryPressure > 0.8) {
        // Aggressive reduction
        adjusted.window_size = std::max(256, adjusted.window_size / 4);
        adjusted.hop_size = adjusted.window_size / 2;
    } else if (memoryPressure > 0.6) {
        // Moderate reduction
        adjusted.window_size = std::max(512, adjusted.window_size / 2);
        adjusted.hop_size = adjusted.window_size / 4;
    }
    
    return adjusted;
}

harmoniq_sync_config_t AdaptiveParameterAdjuster::adjustForTimeConstraints(
    const harmoniq_sync_config_t& baseConfig,
    double maxProcessingTime,
    double estimatedTime
) {
    harmoniq_sync_config_t adjusted = baseConfig;
    
    double timeRatio = estimatedTime / maxProcessingTime;
    
    if (timeRatio > 1.5) {
        // Aggressive speedup needed
        adjusted.window_size = std::max(512, adjusted.window_size / 2);
        adjusted.hop_size = std::max(adjusted.hop_size * 2, adjusted.window_size / 2);
    } else if (timeRatio > 1.1) {
        // Moderate speedup needed  
        adjusted.hop_size = std::max(adjusted.hop_size, adjusted.window_size / 6);
    }
    
    return adjusted;
}

double AdaptiveParameterAdjuster::estimateQualityImpact(
    const harmoniq_sync_config_t& original,
    const harmoniq_sync_config_t& adjusted
) {
    double totalImpact = 0.0;
    
    // Window size impact
    if (adjusted.window_size != original.window_size) {
        double windowRatio = static_cast<double>(original.window_size) / adjusted.window_size;
        totalImpact += std::max(0.0, (windowRatio - 1.0) * 0.1);
    }
    
    // Hop size impact
    if (adjusted.hop_size != original.hop_size) {
        double hopRatio = static_cast<double>(adjusted.hop_size) / original.hop_size;
        totalImpact += std::max(0.0, (hopRatio - 1.0) * 0.05);
    }
    
    // Confidence threshold impact
    double confidenceDiff = original.confidence_threshold - adjusted.confidence_threshold;
    if (confidenceDiff > 0) {
        totalImpact += confidenceDiff * 0.2;
    }
    
    return std::min(1.0, totalImpact); // Cap at 100% impact
}

// MARK: - FallbackMethodSelector Implementation

harmoniq_sync_method_t FallbackMethodSelector::selectFallbackMethod(
    harmoniq_sync_method_t originalMethod,
    const harmoniq_sync_error_t& failureReason,
    const AudioQualityReport& referenceAudio,
    const AudioQualityReport& targetAudio
) {
    auto compatibleMethods = getCompatibleMethods(referenceAudio, targetAudio);
    
    // Remove original method from candidates
    compatibleMethods.erase(
        std::remove(compatibleMethods.begin(), compatibleMethods.end(), originalMethod),
        compatibleMethods.end()
    );
    
    if (compatibleMethods.empty()) {
        return HARMONIQ_SYNC_ENERGY; // Default fallback
    }
    
    // Select based on failure reason
    switch (failureReason) {
        case HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA:
            // Prefer simpler methods for insufficient data
            for (auto method : {HARMONIQ_SYNC_ENERGY, HARMONIQ_SYNC_SPECTRAL_FLUX}) {
                if (std::find(compatibleMethods.begin(), compatibleMethods.end(), method) 
                    != compatibleMethods.end()) {
                    return method;
                }
            }
            break;
            
        case HARMONIQ_SYNC_ERROR_PROCESSING_FAILED:
            // Try alternative complex methods
            for (auto method : {HARMONIQ_SYNC_CHROMA, HARMONIQ_SYNC_MFCC, HARMONIQ_SYNC_ENERGY}) {
                if (std::find(compatibleMethods.begin(), compatibleMethods.end(), method) 
                    != compatibleMethods.end()) {
                    return method;
                }
            }
            break;
            
        default:
            break;
    }
    
    return compatibleMethods[0]; // Return first compatible method
}

std::vector<harmoniq_sync_method_t> FallbackMethodSelector::getCompatibleMethods(
    const AudioQualityReport& referenceAudio,
    const AudioQualityReport& targetAudio
) {
    std::vector<harmoniq_sync_method_t> compatible;
    
    // Energy correlation - most compatible, least demanding
    compatible.push_back(HARMONIQ_SYNC_ENERGY);
    
    // Spectral flux - good for most content with transients
    if (referenceAudio.zeroCrossingRate > 0.01 && targetAudio.zeroCrossingRate > 0.01) {
        compatible.push_back(HARMONIQ_SYNC_SPECTRAL_FLUX);
    }
    
    // Chroma - good for musical content
    if (referenceAudio.spectralCentroid > 200.0 && targetAudio.spectralCentroid > 200.0) {
        compatible.push_back(HARMONIQ_SYNC_CHROMA);
    }
    
    // MFCC - good for clean audio without excessive clipping
    if (!referenceAudio.hasExcessiveClipping && !targetAudio.hasExcessiveClipping) {
        compatible.push_back(HARMONIQ_SYNC_MFCC);
    }
    
    // Hybrid - only if both audio have sufficient content
    if (referenceAudio.hasSufficientContent && targetAudio.hasSufficientContent &&
        referenceAudio.durationSeconds > 4.0 && targetAudio.durationSeconds > 4.0) {
        compatible.push_back(HARMONIQ_SYNC_HYBRID);
    }
    
    return compatible;
}

} // namespace HarmoniqSync