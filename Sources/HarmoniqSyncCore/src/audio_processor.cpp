//
//  audio_processor.cpp
//  HarmoniqSyncCore
//
//  High-performance audio feature extraction for sync algorithms
//

#include "../include/audio_processor.hpp"
#include <algorithm>
#include <cmath>
#include <numeric>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

namespace HarmoniqSync {

// MARK: - Lifecycle

AudioProcessor::AudioProcessor() : sampleRate(0.0) {
    // Reserve initial capacity for working buffers
    workingBuffer.reserve(8192);
    fftBuffer.reserve(4096);
    windowFunction.reserve(4096);
}

AudioProcessor::~AudioProcessor() = default;

// MARK: - Audio Loading

bool AudioProcessor::loadAudio(const float* samples, size_t length, double inputSampleRate, double targetSampleRate) {
    if (!samples || length == 0 || inputSampleRate <= 0) {
        return false;
    }
    
    // Clear previous data
    clear();
    
    // Copy audio data
    audioData.assign(samples, samples + length);
    sampleRate = inputSampleRate;
    
    // Resample if needed
    if (targetSampleRate > 0 && std::abs(targetSampleRate - inputSampleRate) > 1.0) {
        if (!resampleAudio(targetSampleRate)) {
            return false;
        }
    }
    
    return true;
}

void AudioProcessor::clear() {
    audioData.clear();
    sampleRate = 0.0;
    workingBuffer.clear();
    fftBuffer.clear();
    windowFunction.clear();
}

// MARK: - Feature Extraction

std::vector<float> AudioProcessor::extractSpectralFlux(int windowSize, int hopSize) const {
    if (!isValid()) return {};
    
    if (hopSize <= 0) hopSize = windowSize / 4;
    
    std::vector<float> spectralFlux;
    std::vector<float> prevMagnitude;
    
    // Process overlapping windows
    for (size_t pos = 0; pos + windowSize <= audioData.size(); pos += hopSize) {
        // Compute magnitude spectrum
        std::vector<float> magnitude;
        computeFFT(&audioData[pos], windowSize, magnitude);
        
        if (!prevMagnitude.empty()) {
            // Calculate spectral flux (sum of positive differences)
            float flux = 0.0f;
            size_t minSize = std::min(magnitude.size(), prevMagnitude.size());
            
            for (size_t i = 1; i < minSize; ++i) { // Skip DC component
                float diff = magnitude[i] - prevMagnitude[i];
                if (diff > 0) {
                    flux += diff;
                }
            }
            
            spectralFlux.push_back(flux);
        }
        
        prevMagnitude = std::move(magnitude);
    }
    
    // Apply median filtering for smoothing
    smoothFeatures(spectralFlux, 3);
    
    return spectralFlux;
}

std::vector<float> AudioProcessor::extractChromaFeatures(int windowSize, int hopSize) const {
    if (!isValid()) return {};
    
    if (hopSize <= 0) hopSize = windowSize / 4;
    
    std::vector<float> chromaFeatures;
    
    // Process overlapping windows
    for (size_t pos = 0; pos + windowSize <= audioData.size(); pos += hopSize) {
        // Compute magnitude spectrum
        std::vector<float> magnitude;
        computeFFT(&audioData[pos], windowSize, magnitude);
        
        // Extract 12-dimensional chroma vector
        std::vector<float> chroma(12, 0.0f);
        computeChromaVector(magnitude, chroma);
        
        // Append to feature vector
        chromaFeatures.insert(chromaFeatures.end(), chroma.begin(), chroma.end());
    }
    
    return chromaFeatures;
}

std::vector<float> AudioProcessor::extractEnergyProfile(int windowSize, int hopSize) const {
    if (!isValid()) return {};
    
    if (hopSize <= 0) hopSize = windowSize / 2;
    
    std::vector<float> energyProfile;
    
    // Process overlapping windows
    for (size_t pos = 0; pos + windowSize <= audioData.size(); pos += hopSize) {
        float energy = calculateRMSEnergy(&audioData[pos], windowSize);
        energyProfile.push_back(energy);
    }
    
    // Apply smoothing
    smoothFeatures(energyProfile, 5);
    
    return energyProfile;
}

std::vector<float> AudioProcessor::extractMFCC(int numCoeffs, int windowSize, int hopSize) const {
    if (!isValid()) return {};
    
    if (hopSize <= 0) hopSize = windowSize / 4;
    
    std::vector<float> mfccFeatures;
    
    // Create mel filter bank
    int numMelFilters = 26;
    auto melFilters = createMelFilterBank(numMelFilters, windowSize / 2, sampleRate);
    
    // Process overlapping windows
    for (size_t pos = 0; pos + windowSize <= audioData.size(); pos += hopSize) {
        // Compute magnitude spectrum
        std::vector<float> magnitude;
        computeFFT(&audioData[pos], windowSize, magnitude);
        
        // Apply mel filter bank
        std::vector<float> melEnergy(numMelFilters, 0.0f);
        for (int i = 0; i < numMelFilters; ++i) {
            for (size_t j = 0; j < magnitude.size() && j < melFilters[i].size(); ++j) {
                melEnergy[i] += magnitude[j] * melFilters[i][j];
            }
            // Log energy (with small epsilon to avoid log(0))
            melEnergy[i] = std::log(melEnergy[i] + 1e-10f);
        }
        
        // Compute DCT to get MFCC coefficients
        std::vector<float> mfcc(numCoeffs);
        computeDCT(melEnergy, mfcc, numCoeffs);
        
        // Append to feature vector
        mfccFeatures.insert(mfccFeatures.end(), mfcc.begin(), mfcc.end());
    }
    
    return mfccFeatures;
}

// MARK: - Preprocessing

void AudioProcessor::applyPreEmphasis(float alpha) {
    if (!isValid() || audioData.size() < 2) return;
    
    for (size_t i = audioData.size() - 1; i > 0; --i) {
        audioData[i] = audioData[i] - alpha * audioData[i - 1];
    }
}

void AudioProcessor::applyNoiseGate(float thresholdDb) {
    if (!isValid()) return;
    
    float threshold = std::pow(10.0f, thresholdDb / 20.0f);
    
    for (float& sample : audioData) {
        if (std::abs(sample) < threshold) {
            sample = 0.0f;
        }
    }
}

void AudioProcessor::normalize(float targetPeak) {
    if (!isValid()) return;
    
    float peak = findPeak(audioData.data(), audioData.size());
    if (peak > 0.0f) {
        float scale = targetPeak / peak;
        for (float& sample : audioData) {
            sample *= scale;
        }
    }
}

// MARK: - Private Methods

bool AudioProcessor::resampleAudio(double targetSampleRate) {
    if (sampleRate == targetSampleRate) return true;
    
    // Simple linear interpolation resampling
    // For production use, consider using a proper resampling library
    double ratio = targetSampleRate / sampleRate;
    size_t newLength = static_cast<size_t>(audioData.size() * ratio);
    
    std::vector<float> resampled;
    resampled.reserve(newLength);
    
    for (size_t i = 0; i < newLength; ++i) {
        double srcIndex = i / ratio;
        size_t index0 = static_cast<size_t>(srcIndex);
        size_t index1 = std::min(index0 + 1, audioData.size() - 1);
        double frac = srcIndex - index0;
        
        if (index0 < audioData.size()) {
            float value = audioData[index0] * (1.0 - frac) + audioData[index1] * frac;
            resampled.push_back(value);
        }
    }
    
    audioData = std::move(resampled);
    sampleRate = targetSampleRate;
    
    return true;
}

void AudioProcessor::applyHannWindow(float* data, size_t length) const {
    // Ensure window function is computed
    if (windowFunction.size() != length) {
        windowFunction.resize(length);
        for (size_t i = 0; i < length; ++i) {
            windowFunction[i] = 0.5f * (1.0f - std::cos(2.0f * M_PI * i / (length - 1)));
        }
    }
    
    // Apply window
    for (size_t i = 0; i < length; ++i) {
        data[i] *= windowFunction[i];
    }
}

void AudioProcessor::computeFFT(const float* input, size_t inputLength, std::vector<float>& magnitude) const {
    // Simple DFT implementation for educational purposes
    // For production use, consider using FFTW or Apple's Accelerate framework
    
    size_t fftSize = inputLength / 2 + 1;
    magnitude.resize(fftSize);
    
    // Copy and window the input
    workingBuffer.assign(input, input + inputLength);
    applyHannWindow(workingBuffer.data(), inputLength);
    
    // Compute DFT
    for (size_t k = 0; k < fftSize; ++k) {
        double real = 0.0, imag = 0.0;
        double phaseStep = -2.0 * M_PI * k / inputLength;
        
        for (size_t n = 0; n < inputLength; ++n) {
            double phase = phaseStep * n;
            real += workingBuffer[n] * std::cos(phase);
            imag += workingBuffer[n] * std::sin(phase);
        }
        
        magnitude[k] = std::sqrt(real * real + imag * imag);
    }
}

float AudioProcessor::frequencyToMel(float frequency) {
    return 2595.0f * std::log10(1.0f + frequency / 700.0f);
}

float AudioProcessor::melToFrequency(float mel) {
    return 700.0f * (std::pow(10.0f, mel / 2595.0f) - 1.0f);
}

std::vector<std::vector<float>> AudioProcessor::createMelFilterBank(int numFilters, int fftSize, double sampleRate) const {
    std::vector<std::vector<float>> filterBank(numFilters, std::vector<float>(fftSize, 0.0f));
    
    // Frequency range
    float lowFreq = 0.0f;
    float highFreq = sampleRate / 2.0f;
    
    // Convert to mel scale
    float lowMel = frequencyToMel(lowFreq);
    float highMel = frequencyToMel(highFreq);
    
    // Create equally spaced mel points
    std::vector<float> melPoints(numFilters + 2);
    for (int i = 0; i < numFilters + 2; ++i) {
        melPoints[i] = lowMel + (highMel - lowMel) * i / (numFilters + 1);
    }
    
    // Convert back to Hz and then to FFT bin indices
    std::vector<int> binIndices(numFilters + 2);
    for (int i = 0; i < numFilters + 2; ++i) {
        float freq = melToFrequency(melPoints[i]);
        binIndices[i] = static_cast<int>(freq * fftSize * 2 / sampleRate);
        binIndices[i] = std::min(binIndices[i], fftSize - 1);
    }
    
    // Create triangular filters
    for (int i = 0; i < numFilters; ++i) {
        int left = binIndices[i];
        int center = binIndices[i + 1];
        int right = binIndices[i + 2];
        
        // Left slope
        for (int j = left; j < center; ++j) {
            if (center > left) {
                filterBank[i][j] = static_cast<float>(j - left) / (center - left);
            }
        }
        
        // Right slope
        for (int j = center; j < right; ++j) {
            if (right > center) {
                filterBank[i][j] = static_cast<float>(right - j) / (right - center);
            }
        }
    }
    
    return filterBank;
}

void AudioProcessor::computeDCT(const std::vector<float>& input, std::vector<float>& output, int numCoeffs) const {
    output.resize(numCoeffs);
    
    for (int k = 0; k < numCoeffs; ++k) {
        double sum = 0.0;
        for (size_t n = 0; n < input.size(); ++n) {
            sum += input[n] * std::cos(M_PI * k * (n + 0.5) / input.size());
        }
        output[k] = static_cast<float>(sum);
    }
}

void AudioProcessor::computeChromaVector(const std::vector<float>& magnitude, std::vector<float>& chroma) const {
    chroma.assign(12, 0.0f);
    
    // Map frequency bins to chroma classes
    for (size_t i = 1; i < magnitude.size(); ++i) { // Skip DC
        // Convert bin to frequency
        double freq = i * sampleRate / (2.0 * (magnitude.size() - 1));
        
        if (freq > 80.0 && freq < 2000.0) { // Focus on musical range
            // Convert to MIDI note number
            double midiNote = 12.0 * std::log2(freq / 440.0) + 69.0; // A4 = 440Hz = MIDI 69
            
            if (midiNote >= 0) {
                int chromaClass = static_cast<int>(midiNote) % 12;
                chroma[chromaClass] += magnitude[i];
            }
        }
    }
    
    // Normalize chroma vector
    float sum = std::accumulate(chroma.begin(), chroma.end(), 0.0f);
    if (sum > 0.0f) {
        for (float& value : chroma) {
            value /= sum;
        }
    }
}

float AudioProcessor::calculateRMSEnergy(const float* data, size_t length) const {
    if (length == 0) return 0.0f;
    
    double sum = 0.0;
    for (size_t i = 0; i < length; ++i) {
        sum += data[i] * data[i];
    }
    
    return std::sqrt(sum / length);
}

float AudioProcessor::findPeak(const float* data, size_t length) const {
    if (length == 0) return 0.0f;
    
    float peak = 0.0f;
    for (size_t i = 0; i < length; ++i) {
        peak = std::max(peak, std::abs(data[i]));
    }
    
    return peak;
}

void AudioProcessor::smoothFeatures(std::vector<float>& features, int filterSize) const {
    if (features.size() < 3 || filterSize < 3) return;
    
    std::vector<float> smoothed = features;
    int halfSize = filterSize / 2;
    
    for (size_t i = halfSize; i < features.size() - halfSize; ++i) {
        std::vector<float> window;
        for (int j = -halfSize; j <= halfSize; ++j) {
            window.push_back(features[i + j]);
        }
        
        // Median filter
        std::sort(window.begin(), window.end());
        smoothed[i] = window[window.size() / 2];
    }
    
    features = std::move(smoothed);
}

} // namespace HarmoniqSync