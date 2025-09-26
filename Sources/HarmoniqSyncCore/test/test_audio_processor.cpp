//
//  test_audio_processor.cpp
//  HarmoniqSyncCore
//
//  Comprehensive unit tests for AudioProcessor class
//

#include <gtest/gtest.h>
#include "../include/audio_processor.hpp"
#include <vector>
#include <cmath>
#include <random>
#include <limits>

using namespace HarmoniqSync;

class AudioProcessorTest : public ::testing::Test {
protected:
    void SetUp() override {
        processor = std::make_unique<AudioProcessor>();
    }
    
    void TearDown() override {
        processor.reset();
    }
    
    // Generate test sine wave
    std::vector<float> generateSineWave(double frequency, double duration, 
                                       double sampleRate, double amplitude = 1.0) {
        size_t numSamples = static_cast<size_t>(duration * sampleRate);
        std::vector<float> samples(numSamples);
        
        double phaseIncrement = 2.0 * M_PI * frequency / sampleRate;
        for (size_t i = 0; i < numSamples; ++i) {
            samples[i] = static_cast<float>(amplitude * sin(i * phaseIncrement));
        }
        return samples;
    }
    
    // Generate white noise
    std::vector<float> generateWhiteNoise(size_t numSamples, double amplitude = 1.0) {
        std::vector<float> samples(numSamples);
        std::random_device rd;
        std::mt19937 gen(rd());
        std::normal_distribution<float> dis(0.0f, static_cast<float>(amplitude));
        
        for (size_t i = 0; i < numSamples; ++i) {
            samples[i] = dis(gen);
        }
        return samples;
    }
    
    // Generate impulse signal
    std::vector<float> generateImpulse(size_t numSamples, size_t impulsePosition = 0) {
        std::vector<float> samples(numSamples, 0.0f);
        if (impulsePosition < numSamples) {
            samples[impulsePosition] = 1.0f;
        }
        return samples;
    }
    
    std::unique_ptr<AudioProcessor> processor;
};

// MARK: - Constructor/Destructor Tests

TEST_F(AudioProcessorTest, ConstructorInitializesCorrectly) {
    EXPECT_FALSE(processor->isValid());
    EXPECT_EQ(processor->getLength(), 0);
    EXPECT_EQ(processor->getSampleRate(), 0.0);
    EXPECT_EQ(processor->getDurationSeconds(), 0.0);
    EXPECT_TRUE(processor->getAudioData().empty());
}

TEST_F(AudioProcessorTest, DestructorCleansUpProperly) {
    // Load some audio data
    auto samples = generateSineWave(440.0, 1.0, 44100.0);
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    EXPECT_TRUE(processor->isValid());
    
    // Destructor should clean up automatically when going out of scope
    // No crashes should occur
}

// MARK: - Audio Loading Tests

TEST_F(AudioProcessorTest, LoadValidAudio) {
    auto samples = generateSineWave(440.0, 1.0, 44100.0);
    
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    EXPECT_TRUE(processor->isValid());
    EXPECT_EQ(processor->getLength(), samples.size());
    EXPECT_EQ(processor->getSampleRate(), 44100.0);
    EXPECT_NEAR(processor->getDurationSeconds(), 1.0, 0.001);
}

TEST_F(AudioProcessorTest, LoadAudioWithDifferentSampleRates) {
    auto samples = generateSineWave(440.0, 0.5, 48000.0);
    
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 48000.0));
    EXPECT_EQ(processor->getSampleRate(), 48000.0);
    
    // Test with 22kHz
    auto samples22k = generateSineWave(440.0, 0.5, 22050.0);
    EXPECT_TRUE(processor->loadAudio(samples22k.data(), samples22k.size(), 22050.0));
    EXPECT_EQ(processor->getSampleRate(), 22050.0);
}

TEST_F(AudioProcessorTest, RejectNullPointer) {
    EXPECT_FALSE(processor->loadAudio(nullptr, 1000, 44100.0));
    EXPECT_FALSE(processor->isValid());
}

TEST_F(AudioProcessorTest, RejectZeroLength) {
    float dummySample = 1.0f;
    EXPECT_FALSE(processor->loadAudio(&dummySample, 0, 44100.0));
    EXPECT_FALSE(processor->isValid());
}

TEST_F(AudioProcessorTest, RejectInvalidSampleRates) {
    auto samples = generateSineWave(440.0, 1.0, 44100.0);
    
    // Too low
    EXPECT_FALSE(processor->loadAudio(samples.data(), samples.size(), 7999.0));
    
    // Too high  
    EXPECT_FALSE(processor->loadAudio(samples.data(), samples.size(), 200000.0));
    
    // Zero
    EXPECT_FALSE(processor->loadAudio(samples.data(), samples.size(), 0.0));
    
    // Negative
    EXPECT_FALSE(processor->loadAudio(samples.data(), samples.size(), -44100.0));
    
    EXPECT_FALSE(processor->isValid());
}

TEST_F(AudioProcessorTest, RejectTooLongAudio) {
    // Try to load audio longer than MAX_AUDIO_LENGTH
    std::vector<float> longSamples(10000001, 1.0f); // Slightly over the limit
    
    EXPECT_FALSE(processor->loadAudio(longSamples.data(), longSamples.size(), 44100.0));
    EXPECT_FALSE(processor->isValid());
}

TEST_F(AudioProcessorTest, RejectInvalidAudioData) {
    std::vector<float> invalidSamples = {1.0f, 2.0f, std::numeric_limits<float>::infinity(), 4.0f};
    
    EXPECT_FALSE(processor->loadAudio(invalidSamples.data(), invalidSamples.size(), 44100.0));
    EXPECT_FALSE(processor->isValid());
    
    // Test with NaN
    std::vector<float> nanSamples = {1.0f, std::numeric_limits<float>::quiet_NaN(), 3.0f};
    EXPECT_FALSE(processor->loadAudio(nanSamples.data(), nanSamples.size(), 44100.0));
    EXPECT_FALSE(processor->isValid());
}

// MARK: - Clear and Getter Tests

TEST_F(AudioProcessorTest, ClearResetsState) {
    auto samples = generateSineWave(440.0, 1.0, 44100.0);
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    EXPECT_TRUE(processor->isValid());
    
    processor->clear();
    
    EXPECT_FALSE(processor->isValid());
    EXPECT_EQ(processor->getLength(), 0);
    EXPECT_EQ(processor->getSampleRate(), 0.0);
    EXPECT_EQ(processor->getDurationSeconds(), 0.0);
    EXPECT_TRUE(processor->getAudioData().empty());
}

TEST_F(AudioProcessorTest, GettersReturnCorrectValues) {
    auto samples = generateSineWave(440.0, 2.5, 22050.0);
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 22050.0));
    
    EXPECT_EQ(processor->getLength(), samples.size());
    EXPECT_EQ(processor->getSampleRate(), 22050.0);
    EXPECT_NEAR(processor->getDurationSeconds(), 2.5, 0.001);
    EXPECT_EQ(processor->getAudioData().size(), samples.size());
    
    // Verify audio data integrity
    const auto& audioData = processor->getAudioData();
    for (size_t i = 0; i < samples.size(); ++i) {
        EXPECT_NEAR(audioData[i], samples[i], 1e-6f);
    }
}

// MARK: - FFT Tests

TEST_F(AudioProcessorTest, FFTWithSineWave) {
    double frequency = 1000.0; // 1kHz sine wave
    double sampleRate = 44100.0;
    auto samples = generateSineWave(frequency, 0.1, sampleRate); // 100ms
    
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), sampleRate));
    
    // Extract spectral flux (which uses FFT internally)
    auto spectralFlux = processor->extractSpectralFlux(1024, 256);
    
    // Should have some spectral flux values
    EXPECT_FALSE(spectralFlux.empty());
    
    // Values should be finite
    for (float value : spectralFlux) {
        EXPECT_TRUE(std::isfinite(value));
        EXPECT_GE(value, 0.0f); // Spectral flux should be non-negative
    }
}

TEST_F(AudioProcessorTest, FFTWithImpulse) {
    // Impulse should give flat spectrum
    auto samples = generateImpulse(2048, 100);
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    
    auto spectralFlux = processor->extractSpectralFlux(1024, 512);
    
    // Should have spectral flux values
    EXPECT_FALSE(spectralFlux.empty());
    
    // All values should be finite
    for (float value : spectralFlux) {
        EXPECT_TRUE(std::isfinite(value));
    }
}

TEST_F(AudioProcessorTest, FFTWithSilence) {
    std::vector<float> silence(4096, 0.0f);
    EXPECT_TRUE(processor->loadAudio(silence.data(), silence.size(), 44100.0));
    
    auto spectralFlux = processor->extractSpectralFlux(1024, 256);
    
    // Should have some values (even if small for silence)
    EXPECT_FALSE(spectralFlux.empty());
    
    // Values should be very small for silence
    for (float value : spectralFlux) {
        EXPECT_TRUE(std::isfinite(value));
        EXPECT_GE(value, 0.0f);
        EXPECT_LT(value, 0.1f); // Should be small for silence
    }
}

// MARK: - Feature Extraction Tests

TEST_F(AudioProcessorTest, ExtractSpectralFlux) {
    auto samples = generateSineWave(440.0, 1.0, 44100.0);
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    
    auto flux = processor->extractSpectralFlux(1024, 256);
    
    EXPECT_FALSE(flux.empty());
    for (float value : flux) {
        EXPECT_TRUE(std::isfinite(value));
        EXPECT_GE(value, 0.0f);
    }
}

TEST_F(AudioProcessorTest, ExtractChromaFeatures) {
    auto samples = generateSineWave(440.0, 1.0, 44100.0); // A4
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    
    auto chroma = processor->extractChromaFeatures(4096, 1024);
    
    EXPECT_FALSE(chroma.empty());
    EXPECT_EQ(chroma.size() % 12, 0); // Should be multiple of 12 (12-dimensional chroma)
    
    for (float value : chroma) {
        EXPECT_TRUE(std::isfinite(value));
        EXPECT_GE(value, 0.0f);
        EXPECT_LE(value, 1.0f); // Normalized chroma values
    }
}

TEST_F(AudioProcessorTest, ExtractEnergyProfile) {
    auto samples = generateSineWave(440.0, 1.0, 44100.0);
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    
    auto energy = processor->extractEnergyProfile(512, 256);
    
    EXPECT_FALSE(energy.empty());
    for (float value : energy) {
        EXPECT_TRUE(std::isfinite(value));
        EXPECT_GE(value, 0.0f);
    }
}

TEST_F(AudioProcessorTest, ExtractMFCC) {
    auto samples = generateSineWave(440.0, 1.0, 44100.0);
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    
    int numCoeffs = 13;
    auto mfcc = processor->extractMFCC(numCoeffs, 1024, 256);
    
    EXPECT_FALSE(mfcc.empty());
    EXPECT_EQ(mfcc.size() % numCoeffs, 0); // Should be multiple of numCoeffs
    
    for (float value : mfcc) {
        EXPECT_TRUE(std::isfinite(value));
    }
}

// MARK: - Preprocessing Tests

TEST_F(AudioProcessorTest, ApplyPreEmphasis) {
    auto samples = generateSineWave(440.0, 0.1, 44100.0);
    auto originalSamples = samples; // Keep copy
    
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    
    processor->applyPreEmphasis(0.97f);
    
    // Audio should still be valid
    EXPECT_TRUE(processor->isValid());
    
    // First sample should be unchanged, others should be different
    const auto& audioData = processor->getAudioData();
    EXPECT_NEAR(audioData[0], originalSamples[0], 1e-6f);
    
    // Other samples should be different (pre-emphasized)
    bool foundDifference = false;
    for (size_t i = 1; i < audioData.size() && i < 100; ++i) {
        if (std::abs(audioData[i] - originalSamples[i]) > 1e-6f) {
            foundDifference = true;
            break;
        }
    }
    EXPECT_TRUE(foundDifference);
}

TEST_F(AudioProcessorTest, ApplyNoiseGate) {
    // Create signal with some small values that should be gated
    std::vector<float> samples;
    for (int i = 0; i < 1000; ++i) {
        if (i % 10 == 0) {
            samples.push_back(0.1f); // Loud sample
        } else {
            samples.push_back(0.001f); // Quiet sample that should be gated
        }
    }
    
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    
    processor->applyNoiseGate(-40.0f); // Gate at -40dB
    
    const auto& audioData = processor->getAudioData();
    
    // Check that quiet samples were gated to zero
    int gatedSamples = 0;
    for (float sample : audioData) {
        if (sample == 0.0f) {
            gatedSamples++;
        }
    }
    
    EXPECT_GT(gatedSamples, 0); // Some samples should have been gated
}

TEST_F(AudioProcessorTest, Normalize) {
    // Create signal with known peak
    std::vector<float> samples = {0.5f, -0.8f, 0.3f, -0.2f, 0.8f}; // Peak = 0.8
    
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    
    processor->normalize(0.95f);
    
    const auto& audioData = processor->getAudioData();
    
    // Find new peak
    float newPeak = 0.0f;
    for (float sample : audioData) {
        newPeak = std::max(newPeak, std::abs(sample));
    }
    
    // New peak should be close to 0.95
    EXPECT_NEAR(newPeak, 0.95f, 0.01f);
}

// MARK: - Move Semantics Tests

TEST_F(AudioProcessorTest, MoveConstructor) {
    auto samples = generateSineWave(440.0, 1.0, 44100.0);
    EXPECT_TRUE(processor->loadAudio(samples.data(), samples.size(), 44100.0));
    
    // Move construct
    AudioProcessor movedProcessor = std::move(*processor);
    
    // Moved processor should be valid
    EXPECT_TRUE(movedProcessor.isValid());
    EXPECT_EQ(movedProcessor.getLength(), samples.size());
    EXPECT_EQ(movedProcessor.getSampleRate(), 44100.0);
    
    // Original processor should be in valid but empty state
    EXPECT_FALSE(processor->isValid());
    EXPECT_EQ(processor->getLength(), 0);
}

TEST_F(AudioProcessorTest, MoveAssignment) {
    auto samples1 = generateSineWave(440.0, 1.0, 44100.0);
    auto samples2 = generateSineWave(880.0, 0.5, 48000.0);
    
    EXPECT_TRUE(processor->loadAudio(samples1.data(), samples1.size(), 44100.0));
    
    AudioProcessor processor2;
    EXPECT_TRUE(processor2.loadAudio(samples2.data(), samples2.size(), 48000.0));
    
    // Move assign
    processor2 = std::move(*processor);
    
    // processor2 should have processor's data
    EXPECT_TRUE(processor2.isValid());
    EXPECT_EQ(processor2.getLength(), samples1.size());
    EXPECT_EQ(processor2.getSampleRate(), 44100.0);
    
    // Original processor should be in valid but empty state
    EXPECT_FALSE(processor->isValid());
}

// MARK: - Edge Case Tests

TEST_F(AudioProcessorTest, VeryShortAudio) {
    std::vector<float> shortSamples = {1.0f, -1.0f, 0.5f};
    
    EXPECT_TRUE(processor->loadAudio(shortSamples.data(), shortSamples.size(), 44100.0));
    EXPECT_TRUE(processor->isValid());
    
    // Should handle short audio gracefully in feature extraction
    auto energy = processor->extractEnergyProfile(2, 1);
    // May be empty or have limited data, but shouldn't crash
}

TEST_F(AudioProcessorTest, LoadAfterLoad) {
    auto samples1 = generateSineWave(440.0, 1.0, 44100.0);
    auto samples2 = generateSineWave(880.0, 0.5, 48000.0);
    
    // Load first audio
    EXPECT_TRUE(processor->loadAudio(samples1.data(), samples1.size(), 44100.0));
    EXPECT_EQ(processor->getLength(), samples1.size());
    
    // Load second audio (should replace first)
    EXPECT_TRUE(processor->loadAudio(samples2.data(), samples2.size(), 48000.0));
    EXPECT_EQ(processor->getLength(), samples2.size());
    EXPECT_EQ(processor->getSampleRate(), 48000.0);
}

// Helper main function for running tests
int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}