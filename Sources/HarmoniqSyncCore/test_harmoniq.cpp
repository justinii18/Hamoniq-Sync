//
//  test_harmoniq.cpp
//  Simple test for HarmoniqSyncCore C++ engine
//

#include "include/harmoniq_sync.h"
#include <iostream>
#include <vector>
#include <cmath>
#include <chrono>

// Generate test audio signal (sine wave)
std::vector<float> generateTestSignal(double frequency, double duration, double sampleRate, double offset = 0.0) {
    size_t numSamples = static_cast<size_t>(duration * sampleRate);
    std::vector<float> signal(numSamples);
    
    for (size_t i = 0; i < numSamples; ++i) {
        double time = (static_cast<double>(i) / sampleRate) + offset;
        signal[i] = 0.5f * std::sin(2.0 * M_PI * frequency * time);
    }
    
    return signal;
}

int main() {
    std::cout << "HarmoniqSync C++ Engine Test\n";
    std::cout << "=============================\n";
    
    // Print version info
    std::cout << "Version: " << harmoniq_sync_version() << "\n";
    std::cout << "Build Info: " << harmoniq_sync_build_info() << "\n\n";
    
    // Test parameters
    const double sampleRate = 44100.0;
    const double duration = 2.0; // 2 seconds
    const double frequency = 440.0; // A4 note
    
    // Generate reference signal
    auto referenceSignal = generateTestSignal(frequency, duration, sampleRate);
    
    // Generate target signal with a small offset (50ms delay)
    const double offsetSeconds = 0.05; // 50ms
    auto targetSignal = generateTestSignal(frequency, duration, sampleRate, offsetSeconds);
    
    std::cout << "Generated test signals:\n";
    std::cout << "  Reference: " << referenceSignal.size() << " samples\n";
    std::cout << "  Target: " << targetSignal.size() << " samples\n";
    std::cout << "  Expected offset: " << offsetSeconds << " seconds (" 
              << static_cast<int64_t>(offsetSeconds * sampleRate) << " samples)\n\n";
    
    // Test different alignment methods
    harmoniq_sync_method_t methods[] = {
        HARMONIQ_SYNC_SPECTRAL_FLUX,
        HARMONIQ_SYNC_CHROMA,
        HARMONIQ_SYNC_ENERGY,
        HARMONIQ_SYNC_MFCC,
        HARMONIQ_SYNC_HYBRID
    };
    
    const char* methodNames[] = {
        "Spectral Flux",
        "Chroma Features", 
        "Energy Correlation",
        "MFCC",
        "Hybrid"
    };
    
    // Get default configuration
    auto config = harmoniq_sync_default_config();
    
    // Validate configuration
    auto configResult = harmoniq_sync_validate_config(&config);
    if (configResult != HARMONIQ_SYNC_SUCCESS) {
        std::cout << "Error: Invalid configuration - " 
                  << harmoniq_sync_error_description(configResult) << "\n";
        return 1;
    }
    
    std::cout << "Testing alignment methods:\n";
    std::cout << "--------------------------\n";
    
    for (size_t i = 0; i < sizeof(methods) / sizeof(methods[0]); ++i) {
        std::cout << "\nTesting " << methodNames[i] << "...\n";
        
        // Check minimum audio length requirement
        size_t minLength = harmoniq_sync_min_audio_length(methods[i], sampleRate);
        if (referenceSignal.size() < minLength) {
            std::cout << "  Skipped: insufficient audio length (need " 
                      << minLength << " samples)\n";
            continue;
        }
        
        // Measure processing time
        auto start = std::chrono::high_resolution_clock::now();
        
        // Perform alignment
        harmoniq_sync_result_t result = harmoniq_sync_align(
            referenceSignal.data(), referenceSignal.size(),
            targetSignal.data(), targetSignal.size(),
            sampleRate,
            methods[i],
            &config
        );
        
        auto end = std::chrono::high_resolution_clock::now();
        auto duration_ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();
        
        // Check result
        if (result.error != HARMONIQ_SYNC_SUCCESS) {
            std::cout << "  Error: " << harmoniq_sync_error_description(result.error) << "\n";
            continue;
        }
        
        // Calculate offset in seconds
        double offsetSec = static_cast<double>(result.offset_samples) / sampleRate;
        double expectedOffsetSamples = offsetSeconds * sampleRate;
        double error = std::abs(result.offset_samples - expectedOffsetSamples);
        double errorPercent = (error / expectedOffsetSamples) * 100.0;
        
        std::cout << "  Results:\n";
        std::cout << "    Offset: " << result.offset_samples << " samples (" 
                  << offsetSec << " seconds)\n";
        std::cout << "    Confidence: " << result.confidence << "\n";
        std::cout << "    Peak correlation: " << result.peak_correlation << "\n";
        std::cout << "    Secondary peak ratio: " << result.secondary_peak_ratio << "\n";
        std::cout << "    SNR estimate: " << result.snr_estimate << " dB\n";
        std::cout << "    Noise floor: " << result.noise_floor_db << " dB\n";
        std::cout << "    Processing time: " << duration_ms << " ms\n";
        std::cout << "    Accuracy: " << (100.0 - errorPercent) << "% (error: " 
                  << error << " samples)\n";
        
        // Free result (if needed)
        harmoniq_sync_free_result(&result);
    }
    
    // Test batch processing
    std::cout << "\n\nTesting batch processing:\n";
    std::cout << "-------------------------\n";
    
    // Create multiple target signals with different offsets
    std::vector<std::vector<float>> targets;
    std::vector<const float*> targetPointers;
    std::vector<size_t> targetLengths;
    
    double offsets[] = {0.01, 0.05, 0.1}; // 10ms, 50ms, 100ms
    
    for (double offset : offsets) {
        targets.push_back(generateTestSignal(frequency, duration, sampleRate, offset));
        targetPointers.push_back(targets.back().data());
        targetLengths.push_back(targets.back().size());
    }
    
    auto batchResult = harmoniq_sync_align_batch(
        referenceSignal.data(), referenceSignal.size(),
        targetPointers.data(), targetLengths.data(), targets.size(),
        sampleRate,
        HARMONIQ_SYNC_ENERGY, // Use energy method for speed
        &config
    );
    
    if (batchResult.error != HARMONIQ_SYNC_SUCCESS) {
        std::cout << "Batch processing failed: " 
                  << harmoniq_sync_error_description(batchResult.error) << "\n";
    } else {
        std::cout << "Batch processing successful (" << batchResult.count << " targets):\n";
        
        for (size_t i = 0; i < batchResult.count; ++i) {
            double offsetSec = static_cast<double>(batchResult.results[i].offset_samples) / sampleRate;
            std::cout << "  Target " << (i + 1) << ": " 
                      << batchResult.results[i].offset_samples << " samples (" 
                      << offsetSec << " seconds), confidence: " 
                      << batchResult.results[i].confidence << "\n";
        }
        
        harmoniq_sync_free_batch_result(&batchResult);
    }
    
    std::cout << "\nTest completed successfully!\n";
    return 0;
}