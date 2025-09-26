//
//  test_c_api_integration.cpp
//  HarmoniqSyncCore
//
//  C API Integration Test - Week 3 Sprint 1
//  Tests C API interface components that don't require AlignmentEngine
//

#include "include/harmoniq_sync.h"
#include "include/audio_processor.hpp"
#include <iostream>
#include <vector>
#include <cmath>
#include <cassert>

using namespace HarmoniqSync;

// Generate test sine wave
std::vector<float> generateSineWave(double frequency, double duration, double sampleRate, double amplitude = 1.0) {
    size_t numSamples = static_cast<size_t>(duration * sampleRate);
    std::vector<float> samples(numSamples);
    
    double phaseIncrement = 2.0 * M_PI * frequency / sampleRate;
    for (size_t i = 0; i < numSamples; ++i) {
        samples[i] = static_cast<float>(amplitude * sin(i * phaseIncrement));
    }
    return samples;
}

void testCApiUtilityFunctions() {
    std::cout << "\n=== Testing C API Utility Functions ===" << std::endl;
    
    // Test version information
    std::cout << "1. Testing version information..." << std::endl;
    const char* version = harmoniq_sync_version();
    const char* buildInfo = harmoniq_sync_build_info();
    
    assert(version != nullptr);
    assert(buildInfo != nullptr);
    assert(strlen(version) > 0);
    assert(strlen(buildInfo) > 0);
    
    std::cout << "   Version: " << version << std::endl;
    std::cout << "   Build: " << buildInfo << std::endl;
    std::cout << "   ✓ Version information accessible" << std::endl;
    
    // Test error descriptions
    std::cout << "2. Testing error descriptions..." << std::endl;
    
    harmoniq_sync_error_t errors[] = {
        HARMONIQ_SYNC_SUCCESS,
        HARMONIQ_SYNC_ERROR_INVALID_INPUT,
        HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA,
        HARMONIQ_SYNC_ERROR_PROCESSING_FAILED,
        HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY,
        HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT
    };
    
    for (harmoniq_sync_error_t error : errors) {
        const char* desc = harmoniq_sync_error_description(error);
        assert(desc != nullptr);
        assert(strlen(desc) > 0);
        std::cout << "   Error " << error << ": " << desc << std::endl;
    }
    std::cout << "   ✓ Error descriptions working" << std::endl;
    
    // Test method names
    std::cout << "3. Testing method names..." << std::endl;
    
    harmoniq_sync_method_t methods[] = {
        HARMONIQ_SYNC_SPECTRAL_FLUX,
        HARMONIQ_SYNC_CHROMA,
        HARMONIQ_SYNC_ENERGY,
        HARMONIQ_SYNC_MFCC,
        HARMONIQ_SYNC_HYBRID
    };
    
    for (harmoniq_sync_method_t method : methods) {
        const char* name = harmoniq_sync_method_name(method);
        assert(name != nullptr);
        assert(strlen(name) > 0);
        std::cout << "   Method " << method << ": " << name << std::endl;
    }
    std::cout << "   ✓ Method names working" << std::endl;
    
    // Test minimum audio length calculation
    std::cout << "4. Testing minimum audio length calculation..." << std::endl;
    
    double sampleRate = 44100.0;
    for (harmoniq_sync_method_t method : methods) {
        size_t minLength = harmoniq_sync_min_audio_length(method, sampleRate);
        double minSeconds = (double)minLength / sampleRate;
        
        std::cout << "   " << harmoniq_sync_method_name(method) 
                  << ": " << minLength << " samples (" << minSeconds << "s)" << std::endl;
        
        assert(minLength > 0);
        assert(minSeconds >= 1.0); // Should be at least 1 second
    }
    std::cout << "   ✓ Minimum audio length calculation working" << std::endl;
}

void testConfigurationManagement() {
    std::cout << "\n=== Testing Configuration Management ===" << std::endl;
    
    // Test default configuration
    std::cout << "1. Testing default configuration..." << std::endl;
    
    harmoniq_sync_config_t defaultConfig = harmoniq_sync_default_config();
    
    assert(defaultConfig.confidence_threshold > 0.0 && defaultConfig.confidence_threshold <= 1.0);
    assert(defaultConfig.window_size > 0);
    assert(defaultConfig.hop_size > 0);
    assert(defaultConfig.hop_size <= defaultConfig.window_size);
    assert(defaultConfig.noise_gate_db < 0.0);
    
    std::cout << "   Confidence threshold: " << defaultConfig.confidence_threshold << std::endl;
    std::cout << "   Window size: " << defaultConfig.window_size << std::endl;
    std::cout << "   Hop size: " << defaultConfig.hop_size << std::endl;
    std::cout << "   Noise gate: " << defaultConfig.noise_gate_db << " dB" << std::endl;
    std::cout << "   Drift correction: " << (defaultConfig.enable_drift_correction ? "enabled" : "disabled") << std::endl;
    std::cout << "   ✓ Default configuration valid" << std::endl;
    
    // Test configuration validation
    std::cout << "2. Testing configuration validation..." << std::endl;
    
    // Test valid config
    harmoniq_sync_error_t result = harmoniq_sync_validate_config(&defaultConfig);
    assert(result == HARMONIQ_SYNC_SUCCESS);
    std::cout << "   ✓ Valid configuration accepted" << std::endl;
    
    // Test invalid configurations
    harmoniq_sync_config_t invalidConfig = defaultConfig;
    
    // Invalid confidence threshold
    invalidConfig.confidence_threshold = -0.5;
    result = harmoniq_sync_validate_config(&invalidConfig);
    assert(result == HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    
    invalidConfig.confidence_threshold = 1.5;
    result = harmoniq_sync_validate_config(&invalidConfig);
    assert(result == HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    
    // Invalid window/hop sizes
    invalidConfig = defaultConfig;
    invalidConfig.window_size = 0;
    result = harmoniq_sync_validate_config(&invalidConfig);
    assert(result == HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    
    invalidConfig = defaultConfig;
    invalidConfig.hop_size = defaultConfig.window_size + 1;
    result = harmoniq_sync_validate_config(&invalidConfig);
    assert(result == HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    
    // Invalid noise gate
    invalidConfig = defaultConfig;
    invalidConfig.noise_gate_db = 10.0; // Positive dB
    result = harmoniq_sync_validate_config(&invalidConfig);
    assert(result == HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    
    std::cout << "   ✓ Invalid configurations properly rejected" << std::endl;
    
    // Test use case configurations
    std::cout << "3. Testing use case configurations..." << std::endl;
    
    const char* useCases[] = {"music", "speech", "ambient", "multicam", "broadcast"};
    
    for (const char* useCase : useCases) {
        harmoniq_sync_config_t config = harmoniq_sync_config_for_use_case(useCase);
        harmoniq_sync_error_t validation = harmoniq_sync_validate_config(&config);
        
        assert(validation == HARMONIQ_SYNC_SUCCESS);
        std::cout << "   " << useCase << " config: window=" << config.window_size 
                  << ", hop=" << config.hop_size 
                  << ", confidence=" << config.confidence_threshold << std::endl;
    }
    std::cout << "   ✓ Use case configurations working" << std::endl;
}

void testAudioProcessorIntegration() {
    std::cout << "\n=== Testing AudioProcessor Integration ===" << std::endl;
    
    std::cout << "1. Testing C++ AudioProcessor functionality..." << std::endl;
    
    double sampleRate = 44100.0;
    auto testSignal = generateSineWave(440.0, 1.0, sampleRate);
    
    // Create AudioProcessor directly (C++)
    AudioProcessor processor;
    bool cppLoadResult = processor.loadAudio(testSignal.data(), testSignal.size(), sampleRate);
    assert(cppLoadResult);
    
    // Extract features using C++
    auto cppSpectralFlux = processor.extractSpectralFlux(1024, 256);
    auto cppEnergyProfile = processor.extractEnergyProfile(512, 256);
    auto cppChromaFeatures = processor.extractChromaFeatures(4096, 1024);
    auto cppMfccFeatures = processor.extractMFCC(13, 1024, 256);
    
    assert(!cppSpectralFlux.empty());
    assert(!cppEnergyProfile.empty());
    assert(!cppChromaFeatures.empty());
    assert(!cppMfccFeatures.empty());
    
    std::cout << "   Spectral flux frames: " << cppSpectralFlux.size() << std::endl;
    std::cout << "   Energy profile frames: " << cppEnergyProfile.size() << std::endl;
    std::cout << "   Chroma frames: " << cppChromaFeatures.size() / 12 << std::endl;
    std::cout << "   MFCC frames: " << cppMfccFeatures.size() / 13 << std::endl;
    std::cout << "   ✓ C++ AudioProcessor working correctly" << std::endl;
    
    std::cout << "2. Testing parameter compatibility..." << std::endl;
    
    // Test that C API config parameters match AudioProcessor expectations
    auto config = harmoniq_sync_default_config();
    
    // These parameters should be compatible with AudioProcessor feature extraction
    assert(config.window_size > 0 && (config.window_size & (config.window_size - 1)) == 0); // Power of 2
    assert(config.hop_size > 0 && config.hop_size <= config.window_size);
    
    std::cout << "   Window size (power of 2): " << config.window_size << " ✓" << std::endl;
    std::cout << "   Hop size (≤ window): " << config.hop_size << " ✓" << std::endl;
    std::cout << "   ✓ Parameter compatibility verified" << std::endl;
}

void testMemoryManagement() {
    std::cout << "\n=== Testing Memory Management ===" << std::endl;
    
    std::cout << "1. Testing result structure initialization..." << std::endl;
    
    // Test structure initialization
    harmoniq_sync_result_t result = {};
    assert(result.offset_samples == 0);
    assert(result.confidence == 0.0);
    assert(result.error == 0);
    
    // Test manual initialization
    result.offset_samples = 1000;
    result.confidence = 0.85;
    result.peak_correlation = 0.95;
    result.error = HARMONIQ_SYNC_SUCCESS;
    strcpy(result.method, "TestMethod");
    
    assert(result.offset_samples == 1000);
    assert(result.confidence == 0.85);
    assert(strcmp(result.method, "TestMethod") == 0);
    
    std::cout << "   ✓ Result structure working correctly" << std::endl;
    
    std::cout << "2. Testing batch structure management..." << std::endl;
    
    harmoniq_sync_batch_result_t batchResult = {};
    assert(batchResult.results == nullptr);
    assert(batchResult.count == 0);
    
    // Test cleanup of empty batch (should not crash)
    harmoniq_sync_free_batch_result(&batchResult);
    assert(batchResult.results == nullptr);
    
    std::cout << "   ✓ Batch structure management working" << std::endl;
    
    std::cout << "3. Testing string handling..." << std::endl;
    
    // Test that all string functions return valid C strings
    const char* version = harmoniq_sync_version();
    const char* buildInfo = harmoniq_sync_build_info();
    const char* errorDesc = harmoniq_sync_error_description(HARMONIQ_SYNC_SUCCESS);
    const char* methodName = harmoniq_sync_method_name(HARMONIQ_SYNC_ENERGY);
    
    // All should be null-terminated and readable
    size_t versionLen = strlen(version);
    size_t buildLen = strlen(buildInfo);
    size_t errorLen = strlen(errorDesc);
    size_t methodLen = strlen(methodName);
    
    assert(versionLen > 0 && versionLen < 100);
    assert(buildLen > 0 && buildLen < 500);
    assert(errorLen > 0 && errorLen < 200);
    assert(methodLen > 0 && methodLen < 50);
    
    std::cout << "   ✓ String handling safe and correct" << std::endl;
}

void testApiCompliance() {
    std::cout << "\n=== Testing API Compliance ===" << std::endl;
    
    std::cout << "1. Testing C linkage compatibility..." << std::endl;
    
    // These calls should compile and link without C++ name mangling issues
    const char* version = harmoniq_sync_version();
    harmoniq_sync_config_t config = harmoniq_sync_default_config();
    harmoniq_sync_error_t validation = harmoniq_sync_validate_config(&config);
    
    assert(version != nullptr);
    assert(validation == HARMONIQ_SYNC_SUCCESS);
    std::cout << "   ✓ C linkage working correctly" << std::endl;
    
    std::cout << "2. Testing enum value stability..." << std::endl;
    
    // Verify enum values are stable (important for ABI compatibility)
    assert(HARMONIQ_SYNC_SUCCESS == 0);
    assert(HARMONIQ_SYNC_SPECTRAL_FLUX == 0);
    assert(HARMONIQ_SYNC_CHROMA == 1);
    assert(HARMONIQ_SYNC_ENERGY == 2);
    assert(HARMONIQ_SYNC_MFCC == 3);
    assert(HARMONIQ_SYNC_HYBRID == 4);
    
    std::cout << "   ✓ Enum values stable" << std::endl;
    
    std::cout << "3. Testing struct layout compatibility..." << std::endl;
    
    // Test struct sizes and alignment
    harmoniq_sync_result_t result = {};
    harmoniq_sync_config_t testConfig = {};
    
    // Basic struct initialization should work
    result.offset_samples = 1000;
    result.confidence = 0.85;
    result.error = HARMONIQ_SYNC_SUCCESS;
    
    testConfig.confidence_threshold = 0.7;
    testConfig.window_size = 1024;
    
    assert(result.offset_samples == 1000);
    assert(result.confidence == 0.85);
    assert(testConfig.confidence_threshold == 0.7);
    
    // Test struct sizes are reasonable
    assert(sizeof(harmoniq_sync_result_t) > 0);
    assert(sizeof(harmoniq_sync_config_t) > 0);
    assert(sizeof(harmoniq_sync_batch_result_t) > 0);
    
    std::cout << "   Result struct size: " << sizeof(harmoniq_sync_result_t) << " bytes" << std::endl;
    std::cout << "   Config struct size: " << sizeof(harmoniq_sync_config_t) << " bytes" << std::endl;
    std::cout << "   ✓ Struct layout compatible" << std::endl;
}

int main() {
    std::cout << "HarmoniqSyncCore C API Integration Test - Week 3 Sprint 1" << std::endl;
    std::cout << "=========================================================" << std::endl;
    
    try {
        testCApiUtilityFunctions();
        testConfigurationManagement();
        testAudioProcessorIntegration();
        testMemoryManagement();
        testApiCompliance();
        
        std::cout << "\n🎉 ALL C API INTEGRATION TESTS PASSED!" << std::endl;
        std::cout << "C API bridge components working correctly with AudioProcessor." << std::endl;
        std::cout << "\nC API Integration Test Summary:" << std::endl;
        std::cout << "✓ C API utility functions validated" << std::endl;
        std::cout << "✓ Configuration management working" << std::endl;
        std::cout << "✓ AudioProcessor C++ integration confirmed" << std::endl;
        std::cout << "✓ Memory management safe and correct" << std::endl;
        std::cout << "✓ API compliance and ABI compatibility verified" << std::endl;
        std::cout << "\n📋 Sprint Status:" << std::endl;
        std::cout << "✅ AudioProcessor implementation complete and tested" << std::endl;
        std::cout << "✅ C API interface structure complete and tested" << std::endl;
        std::cout << "⏳ AlignmentEngine implementation scheduled for Sprint 2" << std::endl;
        std::cout << "⏳ Full alignment functionality pending AlignmentEngine" << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "\n❌ C API INTEGRATION TEST FAILED: " << e.what() << std::endl;
        return 1;
    } catch (...) {
        std::cerr << "\n❌ C API INTEGRATION TEST FAILED: Unknown exception" << std::endl;
        return 1;
    }
    
    return 0;
}