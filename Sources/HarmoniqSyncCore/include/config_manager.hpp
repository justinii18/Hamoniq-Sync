//
//  config_manager.hpp
//  HarmoniqSyncCore
//
//  Advanced configuration management system with profiles and persistence
//

#ifndef CONFIG_MANAGER_HPP
#define CONFIG_MANAGER_HPP

#include "harmoniq_sync.h"
#include "error_handler.hpp"
#include <string>
#include <map>
#include <vector>
#include <memory>
#include <functional>

namespace HarmoniqSync {

/// Configuration profile types
enum class ConfigProfile {
    Fast,           // Optimize for speed
    Accurate,       // Optimize for accuracy  
    Balanced,       // Balance speed and accuracy
    HighQuality,    // Maximum quality, slower processing
    LowResource,    // Minimal CPU/memory usage
    Custom          // User-defined settings
};

/// Content type for automatic optimization
enum class ContentType {
    Unknown,
    Music,          // Musical content
    Speech,         // Voice/dialogue
    Ambient,        // Environmental sounds
    Broadcast,      // Professional broadcast content
    Podcast,        // Podcast audio
    MultiCam        // Multi-camera sync
};

/// Configuration metadata
struct ConfigMetadata {
    std::string name;
    std::string description;
    std::string version;
    std::string author;
    std::chrono::system_clock::time_point created;
    std::chrono::system_clock::time_point modified;
    std::map<std::string, std::string> tags;
    
    ConfigMetadata() : version("1.0"), author("HarmoniqSync"),
                      created(std::chrono::system_clock::now()),
                      modified(std::chrono::system_clock::now()) {}
};

/// Extended configuration with metadata and validation
struct ExtendedConfig {
    harmoniq_sync_config_t config;
    ConfigMetadata metadata;
    ConfigProfile profile;
    ContentType contentType;
    
    // Validation state
    bool isValid;
    std::vector<ErrorContext> validationErrors;
    std::vector<ErrorContext> validationWarnings;
    
    ExtendedConfig() : profile(ConfigProfile::Balanced), 
                      contentType(ContentType::Unknown), 
                      isValid(false) {}
};

/// Configuration change notification
struct ConfigChangeNotification {
    std::string parameterName;
    std::string oldValue;
    std::string newValue;
    std::string reason;
    std::chrono::system_clock::time_point timestamp;
    
    ConfigChangeNotification() : timestamp(std::chrono::system_clock::now()) {}
};

/// Main configuration management system
class ConfigManager {
public:
    /// Configuration change callback
    using ConfigChangeCallback = std::function<void(const ConfigChangeNotification&)>;
    
    // MARK: - Profile Management
    
    /// Get configuration for predefined profile
    static ExtendedConfig getProfileConfiguration(ConfigProfile profile);
    
    /// Get configuration optimized for content type
    static ExtendedConfig getContentTypeConfiguration(ContentType contentType);
    
    /// Create custom configuration from base profile
    static ExtendedConfig createCustomConfiguration(
        ConfigProfile baseProfile,
        const std::map<std::string, std::string>& overrides
    );
    
    /// Get all available profiles
    static std::vector<ConfigProfile> getAvailableProfiles();
    
    /// Get profile description
    static std::string getProfileDescription(ConfigProfile profile);
    
    // MARK: - Configuration Optimization
    
    /// Auto-optimize configuration for audio characteristics
    static ExtendedConfig optimizeForAudio(
        const ExtendedConfig& baseConfig,
        const std::map<std::string, double>& audioCharacteristics
    );
    
    /// Optimize for performance constraints
    static ExtendedConfig optimizeForConstraints(
        const ExtendedConfig& baseConfig,
        size_t memoryLimit,
        double timeLimit,
        double qualityThreshold
    );
    
    /// Get recommended configuration for use case
    static ExtendedConfig getRecommendedConfiguration(
        ContentType contentType,
        const std::string& useCase,
        const std::map<std::string, std::string>& constraints = {}
    );
    
    // MARK: - Validation and Correction
    
    /// Validate configuration comprehensively
    static ExtendedConfig validateConfiguration(const ExtendedConfig& config);
    
    /// Auto-correct configuration issues
    static ExtendedConfig autoCorrectConfiguration(const ExtendedConfig& config);
    
    /// Check configuration compatibility
    static ErrorContext checkCompatibility(
        const ExtendedConfig& config,
        const std::string& systemInfo
    );
    
    // MARK: - Persistence
    
    /// Save configuration to file
    static ErrorContext saveConfiguration(
        const ExtendedConfig& config,
        const std::string& filePath
    );
    
    /// Load configuration from file
    static std::pair<ExtendedConfig, ErrorContext> loadConfiguration(
        const std::string& filePath
    );
    
    /// Export configuration to JSON string
    static std::pair<std::string, ErrorContext> exportToJSON(
        const ExtendedConfig& config
    );
    
    /// Import configuration from JSON string
    static std::pair<ExtendedConfig, ErrorContext> importFromJSON(
        const std::string& jsonString
    );
    
    /// Get configuration file format version
    static std::string getConfigurationVersion();
    
    // MARK: - Runtime Configuration Management
    
    /// Register for configuration change notifications
    static void registerChangeCallback(ConfigChangeCallback callback);
    
    /// Unregister change callbacks
    static void clearChangeCallbacks();
    
    /// Apply configuration changes at runtime
    static ErrorContext applyRuntimeChanges(
        ExtendedConfig& currentConfig,
        const std::map<std::string, std::string>& changes,
        const std::string& reason = ""
    );
    
    /// Get configuration change history
    static std::vector<ConfigChangeNotification> getChangeHistory(
        size_t maxEntries = 100
    );
    
    /// Clear change history
    static void clearChangeHistory();
    
    // MARK: - Configuration Templates
    
    /// Save configuration as template
    static ErrorContext saveAsTemplate(
        const ExtendedConfig& config,
        const std::string& templateName,
        const std::string& description
    );
    
    /// Load configuration template
    static std::pair<ExtendedConfig, ErrorContext> loadTemplate(
        const std::string& templateName
    );
    
    /// Get available templates
    static std::vector<std::string> getAvailableTemplates();
    
    /// Delete configuration template
    static ErrorContext deleteTemplate(const std::string& templateName);

private:
    static std::vector<ConfigChangeCallback> changeCallbacks_;
    static std::vector<ConfigChangeNotification> changeHistory_;
    static std::map<std::string, ExtendedConfig> configTemplates_;
    static std::mutex configMutex_;
    
    // MARK: - Internal Implementation
    
    /// Create base configuration for profile
    static harmoniq_sync_config_t createBaseConfig(ConfigProfile profile);
    
    /// Apply content-specific optimizations
    static harmoniq_sync_config_t optimizeForContentType(
        const harmoniq_sync_config_t& baseConfig,
        ContentType contentType
    );
    
    /// Validate individual parameter
    static ErrorContext validateParameter(
        const std::string& name,
        const std::string& value,
        const std::map<std::string, std::string>& context = {}
    );
    
    /// Convert config to string map for serialization
    static std::map<std::string, std::string> configToStringMap(
        const harmoniq_sync_config_t& config
    );
    
    /// Convert string map to config
    static harmoniq_sync_config_t stringMapToConfig(
        const std::map<std::string, std::string>& stringMap
    );
    
    /// Notify change callbacks
    static void notifyConfigChange(const ConfigChangeNotification& notification);
    
    /// Generate configuration hash for change detection
    static std::string generateConfigHash(const harmoniq_sync_config_t& config);
    
    /// Initialize default profiles and templates
    static void initializeDefaults();
};

/// Configuration builder for fluent API
class ConfigBuilder {
public:
    ConfigBuilder() = default;
    explicit ConfigBuilder(ConfigProfile baseProfile);
    explicit ConfigBuilder(const ExtendedConfig& baseConfig);
    
    /// Set basic parameters
    ConfigBuilder& withConfidenceThreshold(double threshold);
    ConfigBuilder& withWindowSize(int size);
    ConfigBuilder& withHopSize(int size);
    ConfigBuilder& withNoiseGate(double db);
    ConfigBuilder& withMaxOffset(int64_t samples);
    ConfigBuilder& withDriftCorrection(bool enabled);
    
    /// Set metadata
    ConfigBuilder& withName(const std::string& name);
    ConfigBuilder& withDescription(const std::string& description);
    ConfigBuilder& withAuthor(const std::string& author);
    ConfigBuilder& withTag(const std::string& key, const std::string& value);
    
    /// Set content type
    ConfigBuilder& forContentType(ContentType type);
    
    /// Apply profile
    ConfigBuilder& withProfile(ConfigProfile profile);
    
    /// Build final configuration
    ExtendedConfig build();

private:
    ExtendedConfig config_;
};

/// Configuration comparison utilities
class ConfigComparator {
public:
    /// Compare two configurations
    struct ComparisonResult {
        bool areEqual;
        std::vector<std::string> differences;
        std::map<std::string, std::pair<std::string, std::string>> changedParameters;
        double similarityScore; // 0.0 to 1.0
        
        ComparisonResult() : areEqual(false), similarityScore(0.0) {}
    };
    
    /// Compare configurations in detail
    static ComparisonResult compareConfigurations(
        const ExtendedConfig& config1,
        const ExtendedConfig& config2
    );
    
    /// Calculate configuration similarity
    static double calculateSimilarity(
        const harmoniq_sync_config_t& config1,
        const harmoniq_sync_config_t& config2
    );
    
    /// Find closest matching template
    static std::pair<std::string, double> findClosestTemplate(
        const ExtendedConfig& config
    );

private:
    static double calculateParameterSimilarity(
        const std::string& param,
        const std::string& value1,
        const std::string& value2
    );
};

/// Configuration performance analyzer
class ConfigPerformanceAnalyzer {
public:
    /// Performance prediction
    struct PerformancePrediction {
        double expectedProcessingTime;
        size_t expectedMemoryUsage;
        double expectedAccuracy;
        double expectedConfidence;
        std::vector<std::string> performanceNotes;
        
        PerformancePrediction() : expectedProcessingTime(0.0), 
                                 expectedMemoryUsage(0),
                                 expectedAccuracy(0.0),
                                 expectedConfidence(0.0) {}
    };
    
    /// Predict performance for configuration
    static PerformancePrediction predictPerformance(
        const ExtendedConfig& config,
        size_t audioLengthSamples,
        double sampleRate
    );
    
    /// Compare performance of multiple configurations
    static std::vector<std::pair<ExtendedConfig, PerformancePrediction>> comparePerformance(
        const std::vector<ExtendedConfig>& configurations,
        size_t audioLengthSamples,
        double sampleRate
    );
    
    /// Get optimization suggestions
    static std::vector<std::string> getOptimizationSuggestions(
        const ExtendedConfig& config,
        const PerformancePrediction& prediction
    );

private:
    static double calculateComplexityFactor(const harmoniq_sync_config_t& config);
    static size_t estimateMemoryFootprint(const harmoniq_sync_config_t& config, size_t audioLength);
};

} // namespace HarmoniqSync

#endif /* CONFIG_MANAGER_HPP */