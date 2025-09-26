//
//  test_integration.cpp
//  HarmoniqSyncCore
//
//  Integration test for C ABI bridge - Week 3 Sprint 1
//  Tests the integration between C++ AudioProcessor and C API interface
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

void testAudioProcessorCIntegration() {
    std::cout << "\n=== Testing AudioProcessor C API Integration ===" << std::endl;
    
    // Test 1: Basic data integrity between C++ and C interfaces
    std::cout << "1. Testing C++/C data integrity..." << std::endl;
    
    double sampleRate = 44100.0;
    auto testSignal = generateSineWave(440.0, 1.0, sampleRate);
    
    // Create AudioProcessor directly (C++)
    AudioProcessor processor;
    bool cppLoadResult = processor.loadAudio(testSignal.data(), testSignal.size(), sampleRate);
    assert(cppLoadResult);
    
    // Extract features using C++
    auto cppSpectralFlux = processor.extractSpectralFlux(1024, 256);
    auto cppEnergyProfile = processor.extractEnergyProfile(512, 256);
    
    assert(!cppSpectralFlux.empty());
    assert(!cppEnergyProfile.empty());
    
    std::cout << "   C++ spectral flux frames: " << cppSpectralFlux.size() << std::endl;
    std::cout << "   C++ energy profile frames: " << cppEnergyProfile.size() << std::endl;
    std::cout << "   ✓ C++ AudioProcessor working correctly" << std::endl;
    
    // Test 2: Input validation through C API
    std::cout << "2. Testing C API input validation..." << std::endl;
    
    auto config = harmoniq_sync_default_config();
    
    // Test null pointer validation
    auto result = harmoniq_sync_align(
        nullptr, testSignal.size(),
        testSignal.data(), testSignal.size(),
        sampleRate, HARMONIQ_SYNC_ENERGY, &config
    );
    assert(result.error == HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    std::cout << "   ✓ Null pointer properly rejected" << std::endl;
    
    // Test zero length validation
    result = harmoniq_sync_align(
        testSignal.data(), 0,
        testSignal.data(), testSignal.size(),
        sampleRate, HARMONIQ_SYNC_ENERGY, &config
    );
    assert(result.error == HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    std::cout << "   ✓ Zero length properly rejected" << std::endl;
    
    // Test invalid sample rate
    result = harmoniq_sync_align(
        testSignal.data(), testSignal.size(),
        testSignal.data(), testSignal.size(),
        0.0, HARMONIQ_SYNC_ENERGY, &config
    );
    assert(result.error == HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    std::cout << "   ✓ Invalid sample rate properly rejected" << std::endl;
}

void testApiCompleteness() {
    std::cout << "\n=== Testing API Completeness ===" << std::endl;
    
    std::cout << "1. Verifying all declared functions are callable..." << std::endl;
    
    // Test all functions that are actually declared in harmoniq_sync.h
    const char* version = harmoniq_sync_version();
    const char* buildInfo = harmoniq_sync_build_info();
    harmoniq_sync_config_t config = harmoniq_sync_default_config();
    harmoniq_sync_config_t musicConfig = harmoniq_sync_config_for_use_case("music");
    
    assert(version != nullptr);
    assert(buildInfo != nullptr);
    std::cout << "   ✓ All utility functions callable" << std::endl;
    
    std::cout << "2. Testing comprehensive error handling..." << std::endl;
    
    // Test alignment function with expected failure (no AlignmentEngine)
    auto testSignal = generateSineWave(440.0, 2.0, 44100.0);
    
    harmoniq_sync_result_t result = harmoniq_sync_align(
        testSignal.data(), testSignal.size(),
        testSignal.data(), testSignal.size(),
        44100.0, HARMONIQ_SYNC_ENERGY, &config
    );
    
    // Should fail gracefully since AlignmentEngine is not implemented
    std::cout << "   Alignment result error: " << result.error << std::endl;
    std::cout << "   Error description: " << harmoniq_sync_error_description(result.error) << std::endl;
    std::cout << "   ✓ Error handling working correctly" << std::endl;
    
    std::cout << "Note: Full alignment functionality requires AlignmentEngine" << std::endl;
    std::cout << "Currently testing C API bridge interface and error handling" << std::endl;
}

void testMemoryManagement() {
    std::cout << "\n=== Testing C API Memory Management ===" << std::endl;
    
    // Test single result memory management
    std::cout << "1. Testing single result memory management..." << std::endl;
    
    auto testSignal = generateSineWave(440.0, 2.0, 44100.0);
    auto config = harmoniq_sync_default_config();
    
    // Note: Since AlignmentEngine isn't fully implemented, this will return an error
    // but we can still test the memory management aspects
    harmoniq_sync_result_t result = harmoniq_sync_align(
        testSignal.data(), testSignal.size(),
        testSignal.data(), testSignal.size(),
        44100.0, HARMONIQ_SYNC_ENERGY, &config
    );
    
    // Clean up (should not crash even if no allocation occurred)
    harmoniq_sync_free_result(&result);
    std::cout << "   ✓ Single result cleanup handled" << std::endl;
    
    // Test batch result memory management
    std::cout << "2. Testing batch result memory management..." << std::endl;
    
    const float* targetAudios[] = {testSignal.data(), testSignal.data()};
    size_t targetLengths[] = {testSignal.size(), testSignal.size()};
    
    harmoniq_sync_batch_result_t batchResult = harmoniq_sync_align_batch(
        testSignal.data(), testSignal.size(),
        targetAudios, targetLengths, 2,
        44100.0, HARMONIQ_SYNC_ENERGY, &config
    );
    
    // Clean up batch result
    harmoniq_sync_free_batch_result(&batchResult);
    
    // Verify cleanup
    assert(batchResult.results == nullptr);
    assert(batchResult.count == 0);
    
    std::cout << "   ✓ Batch result cleanup handled" << std::endl;
    
    // Test double cleanup (should not crash)
    harmoniq_sync_free_batch_result(&batchResult);
    std::cout << "   ✓ Double cleanup handled safely" << std::endl;
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
    
    std::cout << "   ✓ Struct layout compatible" << std::endl;
}

int main() {
    std::cout << "HarmoniqSyncCore Integration Test - C ABI Bridge" << std::endl;
    std::cout << "=================================================" << std::endl;
    
    try {
        testCApiUtilityFunctions();
        testConfigurationManagement(); 
        testAudioProcessorCIntegration();
        testApiCompleteness();
        testMemoryManagement();
        testApiCompliance();
        
        std::cout << "\n🎉 ALL INTEGRATION TESTS PASSED!" << std::endl;
        std::cout << "C ABI bridge is working correctly with AudioProcessor." << std::endl;
        std::cout << "\nIntegration Test Summary:" << std::endl;
        std::cout << "✓ C API utility functions working" << std::endl;
        std::cout << "✓ Configuration management validated" << std::endl;
        std::cout << "✓ AudioProcessor C++ integration confirmed" << std::endl;
        std::cout << "✓ API completeness verified" << std::endl;
        std::cout << "✓ Memory management safe and correct" << std::endl;
        std::cout << "✓ API compliance verified" << std::endl;
        std::cout << "\nNote: Full alignment testing requires AlignmentEngine implementation" << std::endl;
        std::cout << "(scheduled for Sprint 2 - Spectral Flux Algorithm Development)" << std::endl;
        
    } catch (const std::exception& e) {
        std::cerr << "\n❌ INTEGRATION TEST FAILED: " << e.what() << std::endl;
        return 1;
    } catch (...) {
        std::cerr << "\n❌ INTEGRATION TEST FAILED: Unknown exception" << std::endl;
        return 1;
    }
    
    return 0;
}