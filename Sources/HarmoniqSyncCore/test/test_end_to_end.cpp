//
//  test_end_to_end.cpp
//  HarmoniqSyncCore
//
//  End-to-end integration tests for complete synchronization workflow
//

#include <gtest/gtest.h>
#include "../include/harmoniq_sync.h"
#include "../include/sync_engine.hpp"
#include <vector>
#include <cmath>
#include <memory>

using namespace HarmoniqSync;

// MARK: - Test Fixtures

class EndToEndSyncTest : public ::testing::Test {
protected:
    void SetUp() override {
        engine_ = harmoniq_sync_create_engine();
        ASSERT_NE(engine_, nullptr);
        
        config_ = harmoniq_sync_default_config();
        config_.confidence_threshold = 0.7;
        config_.window_size = 1024;
        config_.hop_size = 256;
    }
    
    void TearDown() override {
        if (engine_) {
            harmoniq_sync_destroy_engine(engine_);
        }
    }
    
    // Generate synthetic sine wave
    std::vector<float> generateSineWave(double frequency, double duration, double sampleRate) {
        size_t numSamples = static_cast<size_t>(duration * sampleRate);
        std::vector<float> samples(numSamples);
        
        for (size_t i = 0; i < numSamples; ++i) {
            double t = static_cast<double>(i) / sampleRate;
            samples[i] = static_cast<float>(0.5 * sin(2.0 * M_PI * frequency * t));
        }
        
        return samples;
    }
    
    // Generate audio with transient events (clicks) for spectral flux testing
    std::vector<float> generateClickAudio(double duration, double sampleRate, 
                                         const std::vector<double>& clickTimes) {
        size_t numSamples = static_cast<size_t>(duration * sampleRate);
        std::vector<float> samples(numSamples, 0.0f);
        
        // Add background sine wave
        for (size_t i = 0; i < numSamples; ++i) {
            double t = static_cast<double>(i) / sampleRate;
            samples[i] = static_cast<float>(0.1 * sin(2.0 * M_PI * 440.0 * t));
        }
        
        // Add transient clicks
        for (double clickTime : clickTimes) {
            size_t clickSample = static_cast<size_t>(clickTime * sampleRate);
            if (clickSample < numSamples) {
                // Create a short burst
                for (int i = -5; i <= 5; i++) {
                    size_t idx = clickSample + i;
                    if (idx < numSamples) {
                        samples[idx] += static_cast<float>(0.8 * exp(-i*i/10.0));
                    }
                }
            }
        }
        
        return samples;
    }
    
    // Create audio with known offset
    std::vector<float> createOffsetAudio(const std::vector<float>& original, 
                                        size_t offsetSamples, double sampleRate) {
        std::vector<float> offset(original.size() + offsetSamples, 0.0f);
        
        // Copy original audio with offset
        std::copy(original.begin(), original.end(), 
                 offset.begin() + offsetSamples);
        
        return offset;
    }
    
    harmoniq_sync_engine_t* engine_;
    harmoniq_sync_config_t config_;
    static constexpr double SAMPLE_RATE = 44100.0;
    static constexpr double TEST_DURATION = 5.0; // 5 seconds
};

// MARK: - Basic Engine Tests

TEST_F(EndToEndSyncTest, EngineCreationAndDestruction) {
    // Engine should be created successfully
    EXPECT_NE(engine_, nullptr);
    
    // Should be able to get default config
    auto retrievedConfig = harmoniq_sync_get_engine_config(engine_);
    EXPECT_NEAR(retrievedConfig.confidence_threshold, 0.7, 1e-6);
    EXPECT_EQ(retrievedConfig.window_size, 1024);
}

TEST_F(EndToEndSyncTest, ConfigurationManagement) {
    // Set custom configuration
    config_.confidence_threshold = 0.8;
    config_.window_size = 2048;
    config_.hop_size = 512;
    
    auto error = harmoniq_sync_set_engine_config(engine_, &config_);
    EXPECT_EQ(error, HARMONIQ_SYNC_SUCCESS);
    
    // Verify configuration was set
    auto retrievedConfig = harmoniq_sync_get_engine_config(engine_);
    EXPECT_NEAR(retrievedConfig.confidence_threshold, 0.8, 1e-6);
    EXPECT_EQ(retrievedConfig.window_size, 2048);
    EXPECT_EQ(retrievedConfig.hop_size, 512);
}

// MARK: - End-to-End Sync Tests

TEST_F(EndToEndSyncTest, IdenticalAudioSync) {
    // Generate synthetic audio
    auto audio = generateClickAudio(TEST_DURATION, SAMPLE_RATE, {1.0, 2.5, 4.0});
    
    // Test with identical audio (should result in 0 offset)
    harmoniq_sync_result_t result;
    auto error = harmoniq_sync_process(
        engine_,
        audio.data(), audio.size(),
        audio.data(), audio.size(),
        &result
    );
    
    // Should succeed
    EXPECT_EQ(error, HARMONIQ_SYNC_SUCCESS);
    EXPECT_EQ(result.error, HARMONIQ_SYNC_SUCCESS);
    
    // Should find 0 sample offset for identical audio
    EXPECT_EQ(result.offset_samples, 0);
    
    // Should have high confidence (>0.95 as specified in Sprint 2 plan)
    EXPECT_GT(result.confidence, 0.95);
    
    // Should use Spectral Flux method (default for harmoniq_sync_process)
    EXPECT_STREQ(result.method, "Spectral Flux");
    
    // Other quality metrics should be reasonable
    EXPECT_GT(result.peak_correlation, 0.8);
    EXPECT_GT(result.snr_estimate, 20.0); // Should have good SNR
}

TEST_F(EndToEndSyncTest, KnownOffsetSync) {
    // Generate original audio
    auto originalAudio = generateClickAudio(TEST_DURATION, SAMPLE_RATE, {1.0, 2.5, 4.0});
    
    // Create offset version (100ms = 0.1s)
    double offsetSeconds = 0.1;
    size_t offsetSamples = static_cast<size_t>(offsetSeconds * SAMPLE_RATE);
    auto offsetAudio = createOffsetAudio(originalAudio, offsetSamples, SAMPLE_RATE);
    
    // Test synchronization
    harmoniq_sync_result_t result;
    auto error = harmoniq_sync_process(
        engine_,
        originalAudio.data(), originalAudio.size(),
        offsetAudio.data(), offsetAudio.size(),
        &result
    );
    
    // Should succeed
    EXPECT_EQ(error, HARMONIQ_SYNC_SUCCESS);
    EXPECT_EQ(result.error, HARMONIQ_SYNC_SUCCESS);
    
    // Should find correct offset within 1ms tolerance (as specified in Sprint 2 plan)
    int64_t expectedOffset = static_cast<int64_t>(offsetSamples);
    int64_t tolerance = static_cast<int64_t>(0.001 * SAMPLE_RATE); // 1ms tolerance
    
    EXPECT_NEAR(result.offset_samples, expectedOffset, tolerance);
    
    // Should have reasonable confidence
    EXPECT_GT(result.confidence, 0.7);
    
    // Should have detected the correlation peak
    EXPECT_GT(result.peak_correlation, 0.5);
}

TEST_F(EndToEndSyncTest, MultipleKnownOffsetsAccuracy) {
    // Test multiple different offsets to verify algorithm robustness
    auto originalAudio = generateClickAudio(TEST_DURATION, SAMPLE_RATE, {0.5, 1.5, 3.0});
    
    std::vector<double> testOffsets = {0.05, 0.1, 0.25, 0.5}; // 50ms, 100ms, 250ms, 500ms
    
    for (double offsetSeconds : testOffsets) {
        size_t offsetSamples = static_cast<size_t>(offsetSeconds * SAMPLE_RATE);
        auto offsetAudio = createOffsetAudio(originalAudio, offsetSamples, SAMPLE_RATE);
        
        harmoniq_sync_result_t result;
        auto error = harmoniq_sync_process(
            engine_,
            originalAudio.data(), originalAudio.size(),
            offsetAudio.data(), offsetAudio.size(),
            &result
        );
        
        // Should succeed
        EXPECT_EQ(error, HARMONIQ_SYNC_SUCCESS);
        EXPECT_EQ(result.error, HARMONIQ_SYNC_SUCCESS);
        
        // Check accuracy within 1ms tolerance
        int64_t expectedOffset = static_cast<int64_t>(offsetSamples);
        int64_t tolerance = static_cast<int64_t>(0.001 * SAMPLE_RATE);
        
        EXPECT_NEAR(result.offset_samples, expectedOffset, tolerance)
            << "Failed for offset: " << offsetSeconds << "s";
        
        // Should maintain reasonable confidence
        EXPECT_GT(result.confidence, 0.6)
            << "Low confidence for offset: " << offsetSeconds << "s";
    }
}

// MARK: - Edge Case Tests

TEST_F(EndToEndSyncTest, UncorrelatedAudioLowConfidence) {
    // Generate two completely different audio signals
    auto audio1 = generateSineWave(440.0, TEST_DURATION, SAMPLE_RATE); // A note
    auto audio2 = generateSineWave(880.0, TEST_DURATION, SAMPLE_RATE); // A octave higher
    
    harmoniq_sync_result_t result;
    auto error = harmoniq_sync_process(
        engine_,
        audio1.data(), audio1.size(),
        audio2.data(), audio2.size(),
        &result
    );
    
    // Should complete but with low confidence
    EXPECT_EQ(error, HARMONIQ_SYNC_SUCCESS);
    EXPECT_EQ(result.error, HARMONIQ_SYNC_SUCCESS);
    
    // Should have low confidence (<0.2 as specified in Sprint 2 plan)
    EXPECT_LT(result.confidence, 0.2);
    
    // Correlation should be low
    EXPECT_LT(result.peak_correlation, 0.3);
}

TEST_F(EndToEndSyncTest, InvalidInputHandling) {
    auto audio = generateSineWave(440.0, TEST_DURATION, SAMPLE_RATE);
    harmoniq_sync_result_t result;
    
    // Test null engine
    auto error = harmoniq_sync_process(
        nullptr,
        audio.data(), audio.size(),
        audio.data(), audio.size(),
        &result
    );
    EXPECT_EQ(error, HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    
    // Test null reference audio
    error = harmoniq_sync_process(
        engine_,
        nullptr, audio.size(),
        audio.data(), audio.size(),
        &result
    );
    EXPECT_EQ(error, HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    
    // Test null target audio
    error = harmoniq_sync_process(
        engine_,
        audio.data(), audio.size(),
        nullptr, audio.size(),
        &result
    );
    EXPECT_EQ(error, HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    
    // Test null result
    error = harmoniq_sync_process(
        engine_,
        audio.data(), audio.size(),
        audio.data(), audio.size(),
        nullptr
    );
    EXPECT_EQ(error, HARMONIQ_SYNC_ERROR_INVALID_INPUT);
    
    // Test zero length audio
    error = harmoniq_sync_process(
        engine_,
        audio.data(), 0,
        audio.data(), audio.size(),
        &result
    );
    EXPECT_EQ(error, HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA);
}

TEST_F(EndToEndSyncTest, ShortAudioHandling) {
    // Generate very short audio (less than minimum required)
    double shortDuration = 0.1; // 100ms - too short for reliable sync
    auto shortAudio = generateSineWave(440.0, shortDuration, SAMPLE_RATE);
    
    harmoniq_sync_result_t result;
    auto error = harmoniq_sync_process(
        engine_,
        shortAudio.data(), shortAudio.size(),
        shortAudio.data(), shortAudio.size(),
        &result
    );
    
    // Should fail with insufficient data error
    EXPECT_EQ(error, HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA);
}

// MARK: - Performance Tests

TEST_F(EndToEndSyncTest, ProcessingPerformanceTarget) {
    // Generate 1-minute audio clip
    double longDuration = 60.0; // 1 minute
    auto longAudio = generateClickAudio(longDuration, SAMPLE_RATE, 
                                       {5.0, 15.0, 25.0, 35.0, 45.0, 55.0});
    
    // Measure processing time
    auto startTime = std::chrono::high_resolution_clock::now();
    
    harmoniq_sync_result_t result;
    auto error = harmoniq_sync_process(
        engine_,
        longAudio.data(), longAudio.size(),
        longAudio.data(), longAudio.size(),
        &result
    );
    
    auto endTime = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime);
    double processingTimeSeconds = duration.count() / 1000.0;
    
    // Should succeed
    EXPECT_EQ(error, HARMONIQ_SYNC_SUCCESS);
    
    // Should achieve target performance (under 20 seconds for 1-minute audio = 3x real-time)
    EXPECT_LT(processingTimeSeconds, 20.0) 
        << "Processing took " << processingTimeSeconds << " seconds for " 
        << longDuration << " seconds of audio";
    
    // Calculate real-time ratio
    double realtimeRatio = processingTimeSeconds / longDuration;
    EXPECT_LT(realtimeRatio, 0.33) // Should be faster than 1/3 real-time
        << "Real-time ratio: " << realtimeRatio;
}

// MARK: - Integration with C++ SyncEngine

TEST_F(EndToEndSyncTest, CppSyncEngineIntegration) {
    // Test direct C++ SyncEngine usage
    SyncEngine cppEngine;
    
    auto audio = generateClickAudio(TEST_DURATION, SAMPLE_RATE, {1.0, 2.5});
    
    // Test identical audio
    auto result = cppEngine.process(
        audio.data(), audio.size(),
        audio.data(), audio.size(),
        SAMPLE_RATE,
        HARMONIQ_SYNC_SPECTRAL_FLUX
    );
    
    EXPECT_EQ(result.error, HARMONIQ_SYNC_SUCCESS);
    EXPECT_EQ(result.offset_samples, 0);
    EXPECT_GT(result.confidence, 0.95);
    
    // Test progress callback
    bool callbackCalled = false;
    float lastProgress = 0.0f;
    std::string lastStatus;
    
    cppEngine.setProgressCallback([&](float progress, const std::string& status) {
        callbackCalled = true;
        lastProgress = progress;
        lastStatus = status;
    });
    
    // Process again with callback
    result = cppEngine.process(
        audio.data(), audio.size(),
        audio.data(), audio.size(),
        SAMPLE_RATE,
        HARMONIQ_SYNC_SPECTRAL_FLUX
    );
    
    EXPECT_TRUE(callbackCalled);
    EXPECT_NEAR(lastProgress, 1.0f, 0.1f); // Should reach close to 100%
    EXPECT_FALSE(lastStatus.empty());
    
    // Test processing stats
    auto stats = cppEngine.getLastProcessingStats();
    EXPECT_GT(stats.processingTimeSeconds, 0.0);
    EXPECT_NEAR(stats.audioLengthSeconds, TEST_DURATION, 0.1);
    EXPECT_TRUE(stats.successful);
    EXPECT_EQ(stats.methodUsed, HARMONIQ_SYNC_SPECTRAL_FLUX);
}

// MARK: - Test Main

// Note: Google Test main is handled by the test framework
// Individual test files don't need their own main() function