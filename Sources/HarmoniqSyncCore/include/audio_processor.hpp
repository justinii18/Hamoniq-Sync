//
//  audio_processor.hpp
//  HarmoniqSyncCore
//
//  Audio processing and feature extraction
//

#ifndef AUDIO_PROCESSOR_HPP
#define AUDIO_PROCESSOR_HPP

#include <vector>
#include <memory>
#include <complex>

namespace HarmoniqSync {

class AudioProcessor {
public:
    // MARK: - Lifecycle
    
    AudioProcessor();
    ~AudioProcessor();
    
    // Non-copyable but movable
    AudioProcessor(const AudioProcessor&) = delete;
    AudioProcessor& operator=(const AudioProcessor&) = delete;
    AudioProcessor(AudioProcessor&&) = default;
    AudioProcessor& operator=(AudioProcessor&&) = default;
    
    // MARK: - Audio Loading
    
    /// Load audio data with optional resampling
    /// @param samples Audio samples (mono)
    /// @param length Number of samples
    /// @param sampleRate Sample rate of the audio
    /// @param targetSampleRate Target sample rate (0 = no resampling)
    /// @return True if successful
    bool loadAudio(const float* samples, size_t length, double sampleRate, double targetSampleRate = 0.0);
    
    /// Clear loaded audio data
    void clear();
    
    // MARK: - Getters
    
    const std::vector<float>& getAudioData() const { return audioData; }
    double getSampleRate() const { return sampleRate; }
    size_t getLength() const { return audioData.size(); }
    double getDurationSeconds() const { return getLength() / sampleRate; }
    bool isValid() const { return !audioData.empty() && sampleRate > 0; }
    
    // MARK: - Feature Extraction
    
    /// Extract spectral flux (onset detection)
    /// @param windowSize FFT window size (default: 1024)
    /// @param hopSize Hop size (default: windowSize/4)
    /// @return Spectral flux values over time
    std::vector<float> extractSpectralFlux(int windowSize = 1024, int hopSize = 0) const;
    
    /// Extract chroma features (harmonic content)
    /// @param windowSize FFT window size (default: 4096)
    /// @param hopSize Hop size (default: windowSize/4)
    /// @return 12-dimensional chroma vectors concatenated
    std::vector<float> extractChromaFeatures(int windowSize = 4096, int hopSize = 0) const;
    
    /// Extract energy profile
    /// @param windowSize Analysis window size (default: 512)
    /// @param hopSize Hop size (default: windowSize/2)
    /// @return RMS energy values over time
    std::vector<float> extractEnergyProfile(int windowSize = 512, int hopSize = 0) const;
    
    /// Extract MFCC coefficients
    /// @param numCoeffs Number of MFCC coefficients (default: 13)
    /// @param windowSize FFT window size (default: 1024)
    /// @param hopSize Hop size (default: windowSize/4)
    /// @return MFCC coefficients concatenated
    std::vector<float> extractMFCC(int numCoeffs = 13, int windowSize = 1024, int hopSize = 0) const;
    
    // MARK: - Preprocessing
    
    /// Apply pre-emphasis filter
    /// @param alpha Pre-emphasis coefficient (default: 0.97)
    void applyPreEmphasis(float alpha = 0.97f);
    
    /// Apply noise gate
    /// @param thresholdDb Threshold in dB (default: -40.0)
    void applyNoiseGate(float thresholdDb = -40.0f);
    
    /// Normalize audio to peak amplitude
    /// @param targetPeak Target peak amplitude (default: 0.95)
    void normalize(float targetPeak = 0.95f);
    
private:
    // MARK: - Private Members
    
    std::vector<float> audioData;
    double sampleRate;
    
    // Working buffers for DSP operations
    mutable std::vector<float> workingBuffer;
    mutable std::vector<std::complex<float>> fftBuffer;
    mutable std::vector<float> windowFunction;
    
    // MARK: - Private Methods
    
    /// Resample audio data
    bool resampleAudio(double targetSampleRate);
    
    /// Apply Hann window
    void applyHannWindow(float* data, size_t length) const;
    
    /// Compute FFT magnitude spectrum
    void computeFFT(const float* input, size_t inputLength, std::vector<float>& magnitude) const;
    
    /// Convert frequency to mel scale
    static float frequencyToMel(float frequency);
    
    /// Convert mel scale to frequency
    static float melToFrequency(float mel);
    
    /// Create mel filter bank
    std::vector<std::vector<float>> createMelFilterBank(int numFilters, int fftSize, double sampleRate) const;
    
    /// Compute DCT for MFCC
    void computeDCT(const std::vector<float>& input, std::vector<float>& output, int numCoeffs) const;
    
    /// Compute chroma vector from magnitude spectrum
    void computeChromaVector(const std::vector<float>& magnitude, std::vector<float>& chroma) const;
    
    /// Calculate RMS energy
    float calculateRMSEnergy(const float* data, size_t length) const;
    
    /// Find peak value in array
    float findPeak(const float* data, size_t length) const;
    
    /// Apply median filtering for smoothing
    void smoothFeatures(std::vector<float>& features, int filterSize) const;
};

} // namespace HarmoniqSync

#endif /* AUDIO_PROCESSOR_HPP */