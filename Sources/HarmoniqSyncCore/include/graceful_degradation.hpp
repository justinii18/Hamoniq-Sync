//
//  graceful_degradation.hpp
//  HarmoniqSyncCore
//
//  Graceful degradation system with fallback algorithms and adaptive processing
//

#ifndef GRACEFUL_DEGRADATION_HPP
#define GRACEFUL_DEGRADATION_HPP

#include "harmoniq_sync.h"
#include "error_handler.hpp"
#include "input_validator.hpp"
#include <vector>
#include <functional>
#include <memory>

namespace HarmoniqSync {

/// Degradation strategy types
enum class DegradationStrategy {
    None,                   // No degradation
    ReduceQuality,         // Lower quality settings
    FallbackMethod,        // Use different sync method
    ReducePrecision,       // Use faster, less accurate algorithms
    AdaptiveParameters,    // Automatically adjust parameters
    Progressive,           // Try multiple strategies in sequence
    UserGuided             // Require user intervention
};

/// Degradation level indicators
enum class DegradationLevel {
    None = 0,      // Full quality processing
    Minimal = 1,   // Slight quality reduction
    Moderate = 2,  // Noticeable quality reduction
    Significant = 3, // Major quality reduction
    Emergency = 4    // Minimal functionality to avoid failure
};

/// Degradation context information
struct DegradationContext {
    harmoniq_sync_error_t originalError;
    ErrorSeverity errorSeverity;
    std::string failureReason;
    DegradationLevel currentLevel;
    std::vector<std::string> attemptedStrategies;
    
    // Resource constraints
    size_t availableMemory;
    double maxProcessingTime;
    double qualityThreshold;
    
    // Audio characteristics that led to degradation
    AudioQualityReport referenceQuality;
    AudioQualityReport targetQuality;
    harmoniq_sync_config_t originalConfig;
    
    DegradationContext() : originalError(HARMONIQ_SYNC_SUCCESS), 
                          errorSeverity(ErrorSeverity::Info),
                          currentLevel(DegradationLevel::None),
                          availableMemory(0), maxProcessingTime(0.0),
                          qualityThreshold(0.0) {}
};

/// Degradation result with modified processing parameters
struct DegradationResult {
    bool canRecover;
    DegradationLevel levelApplied;
    DegradationStrategy strategyUsed;
    std::string description;
    
    // Modified processing parameters
    harmoniq_sync_method_t recommendedMethod;
    harmoniq_sync_config_t modifiedConfig;
    std::vector<std::string> processingNotes;
    
    // Quality impact assessment
    double expectedConfidenceImpact; // Percentage reduction in confidence
    double expectedAccuracyImpact;   // Expected accuracy reduction
    double processingSpeedup;        // Expected processing time improvement
    
    DegradationResult() : canRecover(false), 
                         levelApplied(DegradationLevel::None),
                         strategyUsed(DegradationStrategy::None),
                         recommendedMethod(HARMONIQ_SYNC_SPECTRAL_FLUX),
                         expectedConfidenceImpact(0.0),
                         expectedAccuracyImpact(0.0),
                         processingSpeedup(1.0) {}
};

/// Main graceful degradation coordinator
class GracefulDegradation {
public:
    /// Attempt to recover from processing failure
    static DegradationResult attemptRecovery(
        const DegradationContext& context
    );
    
    /// Get recommended degradation for resource constraints
    static DegradationResult recommendDegradation(
        const AudioQualityReport& referenceAudio,
        const AudioQualityReport& targetAudio,
        const harmoniq_sync_config_t& config,
        size_t availableMemory,
        double maxProcessingTime
    );
    
    /// Apply specific degradation strategy
    static DegradationResult applyDegradationStrategy(
        DegradationStrategy strategy,
        DegradationLevel level,
        const DegradationContext& context
    );
    
    /// Register custom degradation strategy
    using CustomDegradationFunction = std::function<DegradationResult(const DegradationContext&)>;
    static void registerCustomStrategy(
        const std::string& name,
        CustomDegradationFunction strategy
    );

private:
    static std::map<std::string, CustomDegradationFunction> customStrategies_;
    
    // Strategy implementations
    static DegradationResult applyReduceQuality(const DegradationContext& context, DegradationLevel level);
    static DegradationResult applyFallbackMethod(const DegradationContext& context);
    static DegradationResult applyReducePrecision(const DegradationContext& context, DegradationLevel level);
    static DegradationResult applyAdaptiveParameters(const DegradationContext& context);
    static DegradationResult applyProgressive(const DegradationContext& context);
};

/// Adaptive parameter adjustment based on audio characteristics
class AdaptiveParameterAdjuster {
public:
    /// Adjust configuration based on audio quality analysis
    static harmoniq_sync_config_t adjustForAudioQuality(
        const harmoniq_sync_config_t& baseConfig,
        const AudioQualityReport& referenceAudio,
        const AudioQualityReport& targetAudio
    );
    
    /// Adjust configuration for memory constraints
    static harmoniq_sync_config_t adjustForMemoryConstraints(
        const harmoniq_sync_config_t& baseConfig,
        size_t availableMemory,
        size_t audioLength
    );
    
    /// Adjust configuration for time constraints  
    static harmoniq_sync_config_t adjustForTimeConstraints(
        const harmoniq_sync_config_t& baseConfig,
        double maxProcessingTime,
        double estimatedTime
    );
    
    /// Get processing quality estimate for configuration
    static double estimateQualityImpact(
        const harmoniq_sync_config_t& original,
        const harmoniq_sync_config_t& adjusted
    );

private:
    static double calculateParameterImpact(const std::string& param, double original, double adjusted);
};

/// Fallback method selector based on failure analysis
class FallbackMethodSelector {
public:
    /// Select best fallback method based on failure reason
    static harmoniq_sync_method_t selectFallbackMethod(
        harmoniq_sync_method_t originalMethod,
        const harmoniq_sync_error_t& failureReason,
        const AudioQualityReport& referenceAudio,
        const AudioQualityReport& targetAudio
    );
    
    /// Get method compatibility matrix
    static std::vector<harmoniq_sync_method_t> getCompatibleMethods(
        const AudioQualityReport& referenceAudio,
        const AudioQualityReport& targetAudio
    );
    
    /// Rank methods by expected success probability
    static std::vector<std::pair<harmoniq_sync_method_t, double>> rankMethods(
        const AudioQualityReport& referenceAudio,
        const AudioQualityReport& targetAudio,
        const harmoniq_sync_config_t& config
    );

private:
    static double calculateMethodSuitability(
        harmoniq_sync_method_t method,
        const AudioQualityReport& audio
    );
};

/// Progressive quality reduction system
class ProgressiveQualityReduction {
public:
    /// Define quality reduction levels
    struct QualityLevel {
        std::string name;
        double confidenceThreshold;
        int windowSize;
        int hopSize;
        double noiseGate;
        double expectedSpeedup;
        double expectedAccuracyLoss;
        
        QualityLevel() : confidenceThreshold(0.7), windowSize(1024), hopSize(256),
                        noiseGate(-40.0), expectedSpeedup(1.0), expectedAccuracyLoss(0.0) {}
    };
    
    /// Get predefined quality levels
    static std::vector<QualityLevel> getPredefinedLevels();
    
    /// Apply quality level to configuration
    static harmoniq_sync_config_t applyQualityLevel(
        const harmoniq_sync_config_t& baseConfig,
        const QualityLevel& level
    );
    
    /// Create custom quality reduction progression
    static std::vector<QualityLevel> createProgressionForConstraints(
        size_t availableMemory,
        double maxProcessingTime,
        double minAcceptableConfidence
    );

private:
    static std::vector<QualityLevel> predefinedLevels_;
    static void initializePredefinedLevels();
};

/// Resource-aware processing controller
class ResourceAwareProcessor {
public:
    /// Monitor resource usage during processing
    struct ResourceMonitor {
        size_t peakMemoryUsage;
        double processingTime;
        double cpuUtilization;
        bool memoryPressureDetected;
        bool timeoutApproaching;
        
        ResourceMonitor() : peakMemoryUsage(0), processingTime(0.0),
                           cpuUtilization(0.0), memoryPressureDetected(false),
                           timeoutApproaching(false) {}
    };
    
    /// Check if resource constraints are being violated
    static bool checkResourceConstraints(
        const ResourceMonitor& monitor,
        size_t memoryLimit,
        double timeLimit
    );
    
    /// Get recommended actions for resource pressure
    static std::vector<std::string> getResourcePressureActions(
        const ResourceMonitor& monitor,
        const DegradationContext& context
    );
    
    /// Estimate resource requirements for configuration
    static ResourceMonitor estimateResourceRequirements(
        const harmoniq_sync_config_t& config,
        size_t audioLength,
        harmoniq_sync_method_t method
    );
};

/// Degradation impact assessor
class DegradationImpactAssessor {
public:
    /// Assess quality impact of degradation
    struct QualityImpact {
        double confidenceReduction;    // Expected confidence score reduction
        double accuracyReduction;      // Expected timing accuracy reduction (ms)
        double reliabilityReduction;   // Probability of sync failure increase
        std::vector<std::string> qualityNotes; // Human-readable impact description
        
        QualityImpact() : confidenceReduction(0.0), accuracyReduction(0.0),
                         reliabilityReduction(0.0) {}
    };
    
    /// Assess impact of configuration changes
    static QualityImpact assessConfigurationImpact(
        const harmoniq_sync_config_t& original,
        const harmoniq_sync_config_t& degraded,
        const AudioQualityReport& referenceAudio,
        const AudioQualityReport& targetAudio
    );
    
    /// Assess impact of method change
    static QualityImpact assessMethodChangeImpact(
        harmoniq_sync_method_t originalMethod,
        harmoniq_sync_method_t fallbackMethod,
        const AudioQualityReport& referenceAudio,
        const AudioQualityReport& targetAudio
    );
    
    /// Get user-friendly description of quality impact
    static std::string formatQualityImpactDescription(const QualityImpact& impact);

private:
    static double calculateParameterSensitivity(
        const std::string& parameter,
        const AudioQualityReport& audio
    );
};

} // namespace HarmoniqSync

#endif /* GRACEFUL_DEGRADATION_HPP */