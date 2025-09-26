//
//  config_manager.cpp
//  HarmoniqSyncCore
//
//  Advanced configuration management system with profiles and persistence
//

#include "../include/config_manager.hpp"
#include <sstream>
#include <fstream>
#include <algorithm>
#include <iomanip>

namespace HarmoniqSync {

// Static member definitions
std::vector<ConfigManager::ConfigChangeCallback> ConfigManager::changeCallbacks_;
std::vector<ConfigChangeNotification> ConfigManager::changeHistory_;
std::map<std::string, ExtendedConfig> ConfigManager::configTemplates_;
std::mutex ConfigManager::configMutex_;

// MARK: - ConfigManager Implementation

ExtendedConfig ConfigManager::getProfileConfiguration(ConfigProfile profile) {
    ExtendedConfig config;
    config.config = createBaseConfig(profile);
    config.profile = profile;
    config.metadata.name = getProfileDescription(profile);
    config.metadata.description = "Predefined " + getProfileDescription(profile) + " configuration";
    config.isValid = true;
    
    return config;
}

ExtendedConfig ConfigManager::getContentTypeConfiguration(ContentType contentType) {
    // Start with balanced profile as base
    ExtendedConfig config = getProfileConfiguration(ConfigProfile::Balanced);
    config.contentType = contentType;
    config.config = optimizeForContentType(config.config, contentType);
    
    switch (contentType) {
        case ContentType::Music:
            config.metadata.name = "Music Optimized";
            config.metadata.description = "Optimized for musical content with harmonic structure";
            break;
        case ContentType::Speech:
            config.metadata.name = "Speech Optimized";
            config.metadata.description = "Optimized for voice and dialogue content";
            break;
        case ContentType::Ambient:
            config.metadata.name = "Ambient Optimized";
            config.metadata.description = "Optimized for environmental and ambient audio";
            break;
        case ContentType::Broadcast:
            config.metadata.name = "Broadcast Quality";
            config.metadata.description = "High-quality settings for professional broadcast content";
            break;
        case ContentType::Podcast:
            config.metadata.name = "Podcast Optimized";
            config.metadata.description = "Optimized for podcast and interview audio";
            break;
        case ContentType::MultiCam:
            config.metadata.name = "MultiCam Sync";
            config.metadata.description = "Optimized for multi-camera synchronization";
            break;
        default:
            config.metadata.name = "General Purpose";
            config.metadata.description = "General purpose configuration";
            break;
    }
    
    return config;
}

harmoniq_sync_config_t ConfigManager::createBaseConfig(ConfigProfile profile) {
    harmoniq_sync_config_t config = {};
    
    switch (profile) {
        case ConfigProfile::Fast:
            config.confidence_threshold = 0.6;
            config.max_offset_samples = 0; // Auto-calculate
            config.window_size = 512;
            config.hop_size = 256;
            config.noise_gate_db = -35.0;
            config.enable_drift_correction = 0;
            break;
            
        case ConfigProfile::Accurate:
            config.confidence_threshold = 0.8;
            config.max_offset_samples = 0;
            config.window_size = 4096;
            config.hop_size = 1024;
            config.noise_gate_db = -50.0;
            config.enable_drift_correction = 1;
            break;
            
        case ConfigProfile::Balanced:
            config.confidence_threshold = 0.7;
            config.max_offset_samples = 0;
            config.window_size = 1024;
            config.hop_size = 256;
            config.noise_gate_db = -40.0;
            config.enable_drift_correction = 1;
            break;
            
        case ConfigProfile::HighQuality:
            config.confidence_threshold = 0.85;
            config.max_offset_samples = 0;
            config.window_size = 8192;
            config.hop_size = 2048;
            config.noise_gate_db = -55.0;
            config.enable_drift_correction = 1;
            break;
            
        case ConfigProfile::LowResource:
            config.confidence_threshold = 0.5;
            config.max_offset_samples = static_cast<int64_t>(44100 * 5); // 5 second max
            config.window_size = 256;
            config.hop_size = 128;
            config.noise_gate_db = -30.0;
            config.enable_drift_correction = 0;
            break;
            
        default: // Custom - use balanced as starting point
            config = createBaseConfig(ConfigProfile::Balanced);
            break;
    }
    
    return config;
}

harmoniq_sync_config_t ConfigManager::optimizeForContentType(
    const harmoniq_sync_config_t& baseConfig,
    ContentType contentType
) {
    harmoniq_sync_config_t optimized = baseConfig;
    
    switch (contentType) {
        case ContentType::Music:
            // Optimize for harmonic content
            optimized.window_size = std::max(2048, optimized.window_size);
            optimized.hop_size = optimized.window_size / 4;
            optimized.noise_gate_db = std::min(-45.0, optimized.noise_gate_db);
            optimized.confidence_threshold = std::max(0.75, optimized.confidence_threshold);
            break;
            
        case ContentType::Speech:
            // Optimize for transients and voice
            optimized.window_size = 1024;
            optimized.hop_size = 256;
            optimized.noise_gate_db = -35.0;
            optimized.confidence_threshold = 0.7;
            break;
            
        case ContentType::Ambient:
            // Optimize for low-energy content
            optimized.window_size = std::max(2048, optimized.window_size);
            optimized.hop_size = optimized.window_size / 8;
            optimized.noise_gate_db = -50.0;
            optimized.confidence_threshold = 0.6;
            break;
            
        case ContentType::Broadcast:
            // High quality for professional content
            optimized.window_size = 4096;
            optimized.hop_size = 1024;
            optimized.noise_gate_db = -55.0;
            optimized.confidence_threshold = 0.8;
            optimized.enable_drift_correction = 1;
            break;
            
        case ContentType::Podcast:
            // Optimize for voice with background music
            optimized.window_size = 1024;
            optimized.hop_size = 256;
            optimized.noise_gate_db = -40.0;
            optimized.confidence_threshold = 0.7;
            break;
            
        case ContentType::MultiCam:
            // Optimize for camera sync
            optimized.window_size = 2048;
            optimized.hop_size = 512;
            optimized.noise_gate_db = -40.0;
            optimized.confidence_threshold = 0.75;
            optimized.enable_drift_correction = 1;
            break;
            
        default:
            // No specific optimizations
            break;
    }
    
    return optimized;
}

std::vector<ConfigProfile> ConfigManager::getAvailableProfiles() {
    return {
        ConfigProfile::Fast,
        ConfigProfile::Accurate,
        ConfigProfile::Balanced,
        ConfigProfile::HighQuality,
        ConfigProfile::LowResource
    };
}

std::string ConfigManager::getProfileDescription(ConfigProfile profile) {
    switch (profile) {
        case ConfigProfile::Fast: return "Fast Processing";
        case ConfigProfile::Accurate: return "High Accuracy";
        case ConfigProfile::Balanced: return "Balanced Performance";
        case ConfigProfile::HighQuality: return "Maximum Quality";
        case ConfigProfile::LowResource: return "Low Resource Usage";
        case ConfigProfile::Custom: return "Custom Configuration";
        default: return "Unknown Profile";
    }
}

ExtendedConfig ConfigManager::validateConfiguration(const ExtendedConfig& config) {
    ExtendedConfig validated = config;
    validated.validationErrors.clear();
    validated.validationWarnings.clear();
    validated.isValid = true;
    
    // Validate confidence threshold
    if (config.config.confidence_threshold < 0.0 || config.config.confidence_threshold > 1.0) {
        validated.validationErrors.push_back(ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            "Confidence threshold must be between 0.0 and 1.0",
            "ConfigManager", __FUNCTION__
        ));
        validated.isValid = false;
    }
    
    // Validate window size
    if (config.config.window_size < 64 || config.config.window_size > 8192) {
        validated.validationErrors.push_back(ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            "Window size must be between 64 and 8192",
            "ConfigManager", __FUNCTION__
        ));
        validated.isValid = false;
    }
    
    // Check if window size is power of 2
    int windowSize = config.config.window_size;
    if ((windowSize & (windowSize - 1)) != 0) {
        validated.validationWarnings.push_back(ErrorHandler::createError(
            HARMONIQ_SYNC_SUCCESS, ErrorSeverity::Warning,
            "Window size is not a power of 2 - may reduce FFT efficiency",
            "ConfigManager", __FUNCTION__
        ));
    }
    
    // Validate hop size relative to window size
    if (config.config.hop_size <= 0 || config.config.hop_size > config.config.window_size) {
        validated.validationErrors.push_back(ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            "Hop size must be positive and not greater than window size",
            "ConfigManager", __FUNCTION__
        ));
        validated.isValid = false;
    }
    
    // Validate noise gate
    if (config.config.noise_gate_db > 0.0 || config.config.noise_gate_db < -120.0) {
        validated.validationErrors.push_back(ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_INVALID_INPUT,
            "Noise gate must be between -120.0 and 0.0 dB",
            "ConfigManager", __FUNCTION__
        ));
        validated.isValid = false;
    }
    
    return validated;
}

ExtendedConfig ConfigManager::autoCorrectConfiguration(const ExtendedConfig& config) {
    ExtendedConfig corrected = config;
    
    // Auto-correct confidence threshold
    corrected.config.confidence_threshold = std::max(0.0, 
        std::min(1.0, config.config.confidence_threshold));
    
    // Auto-correct window size
    corrected.config.window_size = std::max(64, 
        std::min(8192, config.config.window_size));
    
    // Round to nearest power of 2 for efficiency
    int windowSize = corrected.config.window_size;
    int powerOf2 = 1;
    while (powerOf2 < windowSize) powerOf2 *= 2;
    if (powerOf2 - windowSize < windowSize - powerOf2/2) {
        corrected.config.window_size = powerOf2;
    } else {
        corrected.config.window_size = powerOf2 / 2;
    }
    
    // Auto-correct hop size
    if (corrected.config.hop_size <= 0) {
        corrected.config.hop_size = corrected.config.window_size / 4;
    } else {
        corrected.config.hop_size = std::min(corrected.config.hop_size, 
                                           corrected.config.window_size);
    }
    
    // Auto-correct noise gate
    corrected.config.noise_gate_db = std::max(-120.0, 
        std::min(0.0, config.config.noise_gate_db));
    
    return validateConfiguration(corrected);
}

// MARK: - Persistence Implementation

ErrorContext ConfigManager::saveConfiguration(
    const ExtendedConfig& config,
    const std::string& filePath
) {
    ErrorScope scope("saveConfiguration");
    scope.addMetadata("file_path", filePath);
    
    auto [jsonString, exportError] = exportToJSON(config);
    if (exportError.code != HARMONIQ_SYNC_SUCCESS) {
        return exportError;
    }
    
    std::ofstream file(filePath);
    if (!file.is_open()) {
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_PROCESSING_FAILED,
            "Failed to open file for writing: " + filePath,
            "ConfigManager", __FUNCTION__
        );
    }
    
    file << jsonString;
    file.close();
    
    if (file.fail()) {
        return ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_PROCESSING_FAILED,
            "Failed to write configuration to file: " + filePath,
            "ConfigManager", __FUNCTION__
        );
    }
    
    return ErrorHandler::createError(HARMONIQ_SYNC_SUCCESS, "Configuration saved successfully");
}

std::pair<ExtendedConfig, ErrorContext> ConfigManager::loadConfiguration(
    const std::string& filePath
) {
    ErrorScope scope("loadConfiguration");
    scope.addMetadata("file_path", filePath);
    
    std::ifstream file(filePath);
    if (!file.is_open()) {
        return {ExtendedConfig{}, ErrorHandler::createError(
            HARMONIQ_SYNC_ERROR_PROCESSING_FAILED,
            "Failed to open file for reading: " + filePath,
            "ConfigManager", __FUNCTION__
        )};
    }
    
    std::ostringstream buffer;
    buffer << file.rdbuf();
    file.close();
    
    return importFromJSON(buffer.str());
}

std::pair<std::string, ErrorContext> ConfigManager::exportToJSON(
    const ExtendedConfig& config
) {
    ErrorScope scope("exportToJSON");
    
    std::ostringstream json;
    json << "{\n";
    json << "  \"version\": \"" << getConfigurationVersion() << "\",\n";
    json << "  \"metadata\": {\n";
    json << "    \"name\": \"" << config.metadata.name << "\",\n";
    json << "    \"description\": \"" << config.metadata.description << "\",\n";
    json << "    \"author\": \"" << config.metadata.author << "\",\n";
    json << "    \"version\": \"" << config.metadata.version << "\"\n";
    json << "  },\n";
    json << "  \"profile\": " << static_cast<int>(config.profile) << ",\n";
    json << "  \"contentType\": " << static_cast<int>(config.contentType) << ",\n";
    json << "  \"config\": {\n";
    json << "    \"confidence_threshold\": " << config.config.confidence_threshold << ",\n";
    json << "    \"max_offset_samples\": " << config.config.max_offset_samples << ",\n";
    json << "    \"window_size\": " << config.config.window_size << ",\n";
    json << "    \"hop_size\": " << config.config.hop_size << ",\n";
    json << "    \"noise_gate_db\": " << config.config.noise_gate_db << ",\n";
    json << "    \"enable_drift_correction\": " << (config.config.enable_drift_correction ? "true" : "false") << "\n";
    json << "  }\n";
    json << "}";
    
    return {json.str(), ErrorHandler::createError(HARMONIQ_SYNC_SUCCESS, "JSON export successful")};
}

std::pair<ExtendedConfig, ErrorContext> ConfigManager::importFromJSON(
    const std::string& jsonString
) {
    ErrorScope scope("importFromJSON");
    
    ExtendedConfig config;
    
    // Simple JSON parsing for basic structure
    // In production, use a proper JSON library like nlohmann/json
    std::istringstream iss(jsonString);
    std::string line;
    
    while (std::getline(iss, line)) {
        // Remove whitespace
        line.erase(0, line.find_first_not_of(" \t"));
        line.erase(line.find_last_not_of(" \t,") + 1);
        
        if (line.find("\"confidence_threshold\":") != std::string::npos) {
            size_t pos = line.find(':');
            if (pos != std::string::npos) {
                config.config.confidence_threshold = std::stod(line.substr(pos + 1));
            }
        } else if (line.find("\"window_size\":") != std::string::npos) {
            size_t pos = line.find(':');
            if (pos != std::string::npos) {
                config.config.window_size = std::stoi(line.substr(pos + 1));
            }
        } else if (line.find("\"hop_size\":") != std::string::npos) {
            size_t pos = line.find(':');
            if (pos != std::string::npos) {
                config.config.hop_size = std::stoi(line.substr(pos + 1));
            }
        } else if (line.find("\"noise_gate_db\":") != std::string::npos) {
            size_t pos = line.find(':');
            if (pos != std::string::npos) {
                config.config.noise_gate_db = std::stod(line.substr(pos + 1));
            }
        } else if (line.find("\"name\":") != std::string::npos) {
            size_t start = line.find('"', line.find(':')) + 1;
            size_t end = line.find('"', start);
            if (start != std::string::npos && end != std::string::npos) {
                config.metadata.name = line.substr(start, end - start);
            }
        }
    }
    
    // Validate loaded configuration
    config = validateConfiguration(config);
    
    return {config, ErrorHandler::createError(HARMONIQ_SYNC_SUCCESS, "JSON import successful")};
}

std::string ConfigManager::getConfigurationVersion() {
    return "1.0";
}

// MARK: - ConfigBuilder Implementation

ConfigBuilder::ConfigBuilder(ConfigProfile baseProfile) {
    config_ = ConfigManager::getProfileConfiguration(baseProfile);
}

ConfigBuilder::ConfigBuilder(const ExtendedConfig& baseConfig) : config_(baseConfig) {}

ConfigBuilder& ConfigBuilder::withConfidenceThreshold(double threshold) {
    config_.config.confidence_threshold = threshold;
    return *this;
}

ConfigBuilder& ConfigBuilder::withWindowSize(int size) {
    config_.config.window_size = size;
    return *this;
}

ConfigBuilder& ConfigBuilder::withHopSize(int size) {
    config_.config.hop_size = size;
    return *this;
}

ConfigBuilder& ConfigBuilder::withNoiseGate(double db) {
    config_.config.noise_gate_db = db;
    return *this;
}

ConfigBuilder& ConfigBuilder::withName(const std::string& name) {
    config_.metadata.name = name;
    return *this;
}

ConfigBuilder& ConfigBuilder::withDescription(const std::string& description) {
    config_.metadata.description = description;
    return *this;
}

ConfigBuilder& ConfigBuilder::forContentType(ContentType type) {
    config_.contentType = type;
    config_.config = ConfigManager::optimizeForContentType(config_.config, type);
    return *this;
}

ConfigBuilder& ConfigBuilder::withProfile(ConfigProfile profile) {
    config_.profile = profile;
    config_.config = ConfigManager::createBaseConfig(profile);
    return *this;
}

ExtendedConfig ConfigBuilder::build() {
    return ConfigManager::validateConfiguration(config_);
}

} // namespace HarmoniqSync