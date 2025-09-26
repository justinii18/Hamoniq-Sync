//
//  alignment_engine.cpp
//  HarmoniqSyncCore
//
//  Core audio alignment algorithms and correlation analysis
//

#include "../include/alignment_engine.hpp"
#include <algorithm>
#include <cmath>
#include <numeric>
#include <limits>

namespace HarmoniqSync {

// MARK: - Lifecycle

AlignmentEngine::AlignmentEngine() = default;

AlignmentEngine::~AlignmentEngine() = default;

// MARK: - Alignment Methods

harmoniq_sync_result_t AlignmentEngine::alignSpectralFlux(const AudioProcessor& reference, const AudioProcessor& target) {
    if (auto error = validateInputs(reference, target); error != HARMONIQ_SYNC_SUCCESS) {
        return createErrorResult(error, "Spectral Flux");
    }
    
    // Note: We work directly with the inputs since AudioProcessor is non-copyable
    // In production, consider cloning the data for thread safety
    // TODO: Add clone() method to AudioProcessor for thread safety
    
    auto refFeatures = reference.extractSpectralFlux(config_.windowSize, config_.hopSize);
    auto targetFeatures = target.extractSpectralFlux(config_.windowSize, config_.hopSize);
    
    if (refFeatures.empty() || targetFeatures.empty()) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA, "Spectral Flux");
    }
    
    // Apply adaptive thresholding to emphasize onsets
    applyAdaptiveThreshold(refFeatures, 0.1f);
    applyAdaptiveThreshold(targetFeatures, 0.1f);
    
    // Apply median filtering
    smoothFeatures(refFeatures, config_.spectralFlux.medianFilterSize);
    smoothFeatures(targetFeatures, config_.spectralFlux.medianFilterSize);
    
    // Normalize features
    normalizeFeatures(refFeatures);
    normalizeFeatures(targetFeatures);
    
    // Perform cross-correlation
    auto correlation = crossCorrelate(refFeatures, targetFeatures);
    auto peak = findBestAlignment(correlation);
    
    if (peak.confidence < config_.confidenceThreshold) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "Spectral Flux");
    }
    
    // Convert feature index to sample offset
    int64_t sampleOffset = static_cast<int64_t>(peak.index) * config_.hopSize - static_cast<int64_t>(refFeatures.size() * config_.hopSize / 2);
    
    // Calculate quality metrics
    double snrEstimate = calculateSNREstimate(correlation, peak.index);
    double noiseFloor = calculateNoiseFloor(correlation);
    
    return createResult(
        sampleOffset,
        peak.confidence,
        peak.value,
        peak.secondaryPeakRatio,
        snrEstimate,
        noiseFloor,
        "Spectral Flux"
    );
}

harmoniq_sync_result_t AlignmentEngine::alignChromaFeatures(const AudioProcessor& reference, const AudioProcessor& target) {
    if (auto error = validateInputs(reference, target); error != HARMONIQ_SYNC_SUCCESS) {
        return createErrorResult(error, "Chroma Features");
    }
    
    // Extract chroma features (12-dimensional vectors)
    auto refFeatures = reference.extractChromaFeatures(config_.windowSize, config_.hopSize);
    auto targetFeatures = target.extractChromaFeatures(config_.windowSize, config_.hopSize);
    
    if (refFeatures.empty() || targetFeatures.empty()) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA, "Chroma Features");
    }
    
    // Chroma features are already normalized in extraction
    
    // For chroma features, we compute correlation on each chroma dimension and combine
    std::vector<double> combinedCorrelation;
    
    // Process each chroma dimension (C, C#, D, D#, E, F, F#, G, G#, A, A#, B)
    for (int chromaDim = 0; chromaDim < config_.chroma.numChromaBins; ++chromaDim) {
        // Extract single dimension
        std::vector<float> refChroma, targetChroma;
        
        for (size_t i = chromaDim; i < refFeatures.size(); i += 12) {
            refChroma.push_back(refFeatures[i]);
        }
        for (size_t i = chromaDim; i < targetFeatures.size(); i += 12) {
            targetChroma.push_back(targetFeatures[i]);
        }
        
        if (refChroma.empty() || targetChroma.empty()) continue;
        
        auto chromaCorrelation = crossCorrelate(refChroma, targetChroma);
        
        // Combine correlations (weighted average)
        if (combinedCorrelation.empty()) {
            combinedCorrelation = chromaCorrelation;
        } else {
            for (size_t i = 0; i < std::min(combinedCorrelation.size(), chromaCorrelation.size()); ++i) {
                combinedCorrelation[i] = (combinedCorrelation[i] + chromaCorrelation[i]) / 2.0;
            }
        }
    }
    
    if (combinedCorrelation.empty()) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "Chroma Features");
    }
    
    auto peak = findBestAlignment(combinedCorrelation);
    
    if (peak.confidence < config_.confidenceThreshold) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "Chroma Features");
    }
    
    // Convert to sample offset
    int64_t sampleOffset = static_cast<int64_t>(peak.index) * config_.hopSize - static_cast<int64_t>(refFeatures.size() / 12 * config_.hopSize / 2);
    
    double snrEstimate = calculateSNREstimate(combinedCorrelation, peak.index);
    double noiseFloor = calculateNoiseFloor(combinedCorrelation);
    
    return createResult(
        sampleOffset,
        peak.confidence,
        peak.value,
        peak.secondaryPeakRatio,
        snrEstimate,
        noiseFloor,
        "Chroma Features"
    );
}

harmoniq_sync_result_t AlignmentEngine::alignEnergyCorrelation(const AudioProcessor& reference, const AudioProcessor& target) {
    if (auto error = validateInputs(reference, target); error != HARMONIQ_SYNC_SUCCESS) {
        return createErrorResult(error, "Energy Correlation");
    }
    
    // Extract energy profiles
    auto refFeatures = reference.extractEnergyProfile(config_.windowSize, config_.hopSize);
    auto targetFeatures = target.extractEnergyProfile(config_.windowSize, config_.hopSize);
    
    if (refFeatures.empty() || targetFeatures.empty()) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA, "Energy Correlation");
    }
    
    // Apply smoothing
    smoothFeatures(refFeatures, config_.energy.smoothingWindowSize);
    smoothFeatures(targetFeatures, config_.energy.smoothingWindowSize);
    
    // Normalize features
    normalizeFeatures(refFeatures);
    normalizeFeatures(targetFeatures);
    
    // Perform cross-correlation
    auto correlation = crossCorrelate(refFeatures, targetFeatures);
    auto peak = findBestAlignment(correlation);
    
    if (peak.confidence < config_.confidenceThreshold) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "Energy Correlation");
    }
    
    // Convert to sample offset
    int64_t sampleOffset = static_cast<int64_t>(peak.index) * config_.hopSize - static_cast<int64_t>(refFeatures.size() * config_.hopSize / 2);
    
    double snrEstimate = calculateSNREstimate(correlation, peak.index);
    double noiseFloor = calculateNoiseFloor(correlation);
    
    return createResult(
        sampleOffset,
        peak.confidence,
        peak.value,
        peak.secondaryPeakRatio,
        snrEstimate,
        noiseFloor,
        "Energy Correlation"
    );
}

harmoniq_sync_result_t AlignmentEngine::alignMFCC(const AudioProcessor& reference, const AudioProcessor& target) {
    if (auto error = validateInputs(reference, target); error != HARMONIQ_SYNC_SUCCESS) {
        return createErrorResult(error, "MFCC");
    }
    
    // Extract MFCC features
    auto refFeatures = reference.extractMFCC(config_.mfcc.numCoeffs, config_.windowSize, config_.hopSize);
    auto targetFeatures = target.extractMFCC(config_.mfcc.numCoeffs, config_.windowSize, config_.hopSize);
    
    if (refFeatures.empty() || targetFeatures.empty()) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA, "MFCC");
    }
    
    // For MFCC, we can either correlate the full feature vectors or individual coefficients
    // We'll use the approach of correlating coefficient-wise and combining
    
    std::vector<double> combinedCorrelation;
    
    // Process each MFCC coefficient
    for (int coeff = 0; coeff < config_.mfcc.numCoeffs; ++coeff) {
        // Extract single coefficient across time
        std::vector<float> refCoeff, targetCoeff;
        
        for (size_t i = coeff; i < refFeatures.size(); i += config_.mfcc.numCoeffs) {
            refCoeff.push_back(refFeatures[i]);
        }
        for (size_t i = coeff; i < targetFeatures.size(); i += config_.mfcc.numCoeffs) {
            targetCoeff.push_back(targetFeatures[i]);
        }
        
        if (refCoeff.empty() || targetCoeff.empty()) continue;
        
        // Skip C0 if configured (energy-related coefficient)
        if (!config_.mfcc.includeC0 && coeff == 0) continue;
        
        auto coeffCorrelation = crossCorrelate(refCoeff, targetCoeff);
        
        // Weight lower coefficients more (they contain more perceptually relevant information)
        double weight = 1.0 / (1.0 + coeff * 0.1);
        
        if (combinedCorrelation.empty()) {
            combinedCorrelation = coeffCorrelation;
            for (double& val : combinedCorrelation) val *= weight;
        } else {
            for (size_t i = 0; i < std::min(combinedCorrelation.size(), coeffCorrelation.size()); ++i) {
                combinedCorrelation[i] = (combinedCorrelation[i] + coeffCorrelation[i] * weight) / 2.0;
            }
        }
    }
    
    if (combinedCorrelation.empty()) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "MFCC");
    }
    
    auto peak = findBestAlignment(combinedCorrelation);
    
    if (peak.confidence < config_.confidenceThreshold) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "MFCC");
    }
    
    // Convert to sample offset
    int64_t sampleOffset = static_cast<int64_t>(peak.index) * config_.hopSize - static_cast<int64_t>(refFeatures.size() / config_.mfcc.numCoeffs * config_.hopSize / 2);
    
    double snrEstimate = calculateSNREstimate(combinedCorrelation, peak.index);
    double noiseFloor = calculateNoiseFloor(combinedCorrelation);
    
    return createResult(
        sampleOffset,
        peak.confidence,
        peak.value,
        peak.secondaryPeakRatio,
        snrEstimate,
        noiseFloor,
        "MFCC"
    );
}

harmoniq_sync_result_t AlignmentEngine::alignHybrid(const AudioProcessor& reference, const AudioProcessor& target) {
    if (auto error = validateInputs(reference, target); error != HARMONIQ_SYNC_SUCCESS) {
        return createErrorResult(error, "Hybrid");
    }
    
    // Run multiple algorithms
    auto spectralResult = alignSpectralFlux(reference, target);
    auto chromaResult = alignChromaFeatures(reference, target);
    auto energyResult = alignEnergyCorrelation(reference, target);
    auto mfccResult = alignMFCC(reference, target);
    
    // Collect valid results
    std::vector<harmoniq_sync_result_t> results;
    if (spectralResult.error == HARMONIQ_SYNC_SUCCESS) results.push_back(spectralResult);
    if (chromaResult.error == HARMONIQ_SYNC_SUCCESS) results.push_back(chromaResult);
    if (energyResult.error == HARMONIQ_SYNC_SUCCESS) results.push_back(energyResult);
    if (mfccResult.error == HARMONIQ_SYNC_SUCCESS) results.push_back(mfccResult);
    
    if (results.empty()) {
        return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "Hybrid");
    }
    
    // Find consensus among results
    // For now, we'll use a simple weighted average based on confidence
    double totalWeight = 0.0;
    double weightedOffset = 0.0;
    double weightedConfidence = 0.0;
    double weightedCorrelation = 0.0;
    double weightedSNR = 0.0;
    double weightedNoiseFloor = 0.0;
    
    for (const auto& result : results) {
        double weight = result.confidence;
        totalWeight += weight;
        weightedOffset += result.offset_samples * weight;
        weightedConfidence += result.confidence * weight;
        weightedCorrelation += result.peak_correlation * weight;
        weightedSNR += result.snr_estimate * weight;
        weightedNoiseFloor += result.noise_floor_db * weight;
    }
    
    if (totalWeight > 0.0) {
        int64_t finalOffset = static_cast<int64_t>(weightedOffset / totalWeight);
        double finalConfidence = weightedConfidence / totalWeight;
        double finalCorrelation = weightedCorrelation / totalWeight;
        double finalSNR = weightedSNR / totalWeight;
        double finalNoiseFloor = weightedNoiseFloor / totalWeight;
        
        // Calculate secondary peak ratio as average
        double avgSecondaryRatio = 0.0;
        for (const auto& result : results) {
            avgSecondaryRatio += result.secondary_peak_ratio;
        }
        avgSecondaryRatio /= results.size();
        
        return createResult(
            finalOffset,
            finalConfidence,
            finalCorrelation,
            avgSecondaryRatio,
            finalSNR,
            finalNoiseFloor,
            "Hybrid"
        );
    }
    
    return createErrorResult(HARMONIQ_SYNC_ERROR_PROCESSING_FAILED, "Hybrid");
}

// MARK: - Batch Processing

std::vector<harmoniq_sync_result_t> AlignmentEngine::alignBatch(
    const AudioProcessor& reference,
    const std::vector<AudioProcessor>& targets,
    harmoniq_sync_method_t method
) {
    std::vector<harmoniq_sync_result_t> results;
    results.reserve(targets.size());
    
    for (const auto& target : targets) {
        harmoniq_sync_result_t result;
        
        switch (method) {
            case HARMONIQ_SYNC_SPECTRAL_FLUX:
                result = alignSpectralFlux(reference, target);
                break;
            case HARMONIQ_SYNC_CHROMA:
                result = alignChromaFeatures(reference, target);
                break;
            case HARMONIQ_SYNC_ENERGY:
                result = alignEnergyCorrelation(reference, target);
                break;
            case HARMONIQ_SYNC_MFCC:
                result = alignMFCC(reference, target);
                break;
            case HARMONIQ_SYNC_HYBRID:
                result = alignHybrid(reference, target);
                break;
            default:
                result = createErrorResult(HARMONIQ_SYNC_ERROR_INVALID_INPUT, "Unknown");
                break;
        }
        
        results.push_back(result);
    }
    
    return results;
}

// MARK: - Core Correlation Functions

std::vector<double> AlignmentEngine::crossCorrelate(const std::vector<float>& a, const std::vector<float>& b) const {
    if (a.empty() || b.empty()) return {};
    
    size_t maxLag = std::min(a.size(), b.size());
    size_t correlationSize = 2 * maxLag - 1;
    std::vector<double> correlation(correlationSize, 0.0);
    
    // Calculate cross-correlation for different lags
    for (size_t lag = 0; lag < correlationSize; ++lag) {
        int actualLag = static_cast<int>(lag) - static_cast<int>(maxLag) + 1;
        double sum = 0.0;
        size_t count = 0;
        
        for (size_t i = 0; i < a.size(); ++i) {
            int j = static_cast<int>(i) + actualLag;
            if (j >= 0 && j < static_cast<int>(b.size())) {
                sum += a[i] * b[j];
                count++;
            }
        }
        
        if (count > 0) {
            correlation[lag] = sum / count;
        }
    }
    
    return correlation;
}

AlignmentEngine::CorrelationPeak AlignmentEngine::findBestAlignment(const std::vector<double>& correlation) const {
    if (correlation.empty()) {
        return {0, 0.0, 0.0, 1.0};
    }
    
    // Find maximum correlation
    auto maxIt = std::max_element(correlation.begin(), correlation.end());
    size_t maxIndex = std::distance(correlation.begin(), maxIt);
    double maxValue = *maxIt;
    
    // Find second highest peak (for secondary peak ratio)
    double secondMax = -1e10; // Use large negative number instead of infinity
    for (size_t i = 0; i < correlation.size(); ++i) {
        if (i != maxIndex && correlation[i] > secondMax) {
            secondMax = correlation[i];
        }
    }
    
    double secondaryPeakRatio = (secondMax > 0) ? (maxValue / secondMax) : 1e10;
    
    // Calculate confidence based on peak prominence
    double confidence = calculateConfidence(correlation, maxIndex);
    
    return {maxIndex, maxValue, confidence, secondaryPeakRatio};
}

AlignmentEngine::ConfidenceFactors AlignmentEngine::calculateConfidenceFactors(const std::vector<double>& correlation, size_t peakIndex) const {
    ConfidenceFactors factors;
    
    if (correlation.empty() || peakIndex >= correlation.size()) {
        return factors; // Return zeros
    }
    
    double peakValue = correlation[peakIndex];
    
    // Factor 1: Correlation Strength (Peak Height)
    // Normalize the raw peak value by the energy of the correlation function
    double correlationEnergy = 0.0;
    for (double val : correlation) {
        correlationEnergy += val * val;
    }
    correlationEnergy = std::sqrt(correlationEnergy / correlation.size());
    
    if (correlationEnergy > 1e-10) {
        factors.correlationStrength = std::abs(peakValue) / correlationEnergy;
        factors.correlationStrength = std::max(0.0, std::min(1.0, factors.correlationStrength));
    }
    
    // Factor 2: Peak Sharpness (Clarity)
    // Ratio of primary peak to average correlation value
    double mean = std::accumulate(correlation.begin(), correlation.end(), 0.0) / correlation.size();
    double avgAbsCorrelation = 0.0;
    for (double val : correlation) {
        avgAbsCorrelation += std::abs(val);
    }
    avgAbsCorrelation /= correlation.size();
    
    if (avgAbsCorrelation > 1e-10) {
        factors.peakSharpness = std::abs(peakValue) / avgAbsCorrelation;
        // Normalize to [0,1] using tanh to handle extreme values
        factors.peakSharpness = std::tanh(factors.peakSharpness / 10.0);
    }
    
    // Factor 3: Signal-to-Noise Ratio (Secondary Peak Ratio)
    // Find second highest peak
    double secondMaxValue = -1e10;
    for (size_t i = 0; i < correlation.size(); ++i) {
        if (i != peakIndex && correlation[i] > secondMaxValue) {
            secondMaxValue = correlation[i];
        }
    }
    
    if (secondMaxValue > 1e-10 && std::abs(peakValue) > 1e-10) {
        factors.snr = std::abs(peakValue) / std::abs(secondMaxValue);
        // Convert to [0,1] range using logarithmic scaling
        factors.snr = std::tanh(std::log(factors.snr + 1.0) / 3.0);
    } else if (std::abs(peakValue) > 1e-10) {
        factors.snr = 1.0; // Perfect SNR if no secondary peak
    }
    
    return factors;
}

double AlignmentEngine::calculateConfidence(const std::vector<double>& correlation, size_t peakIndex) const {
    if (correlation.empty()) return 0.0;
    
    ConfidenceFactors factors = calculateConfidenceFactors(correlation, peakIndex);
    
    // Combine factors into a single score [0.0, 1.0]
    // Weighted average as specified in Sprint 2 plan
    double confidence = (factors.correlationStrength * 0.5) + 
                       (factors.peakSharpness * 0.3) + 
                       (factors.snr * 0.2);
    
    return std::max(0.0, std::min(1.0, confidence));
}

double AlignmentEngine::calculateSNREstimate(const std::vector<double>& correlation, size_t peakIndex) const {
    if (correlation.empty()) return 0.0;
    
    double signal = correlation[peakIndex];
    
    // Estimate noise as the median of correlation values (excluding peak region)
    std::vector<double> noiseValues;
    int exclusionWindow = 10;
    
    for (size_t i = 0; i < correlation.size(); ++i) {
        if (abs(static_cast<int>(i) - static_cast<int>(peakIndex)) > exclusionWindow) {
            noiseValues.push_back(std::abs(correlation[i]));
        }
    }
    
    if (noiseValues.empty()) return 40.0; // Default high SNR
    
    std::sort(noiseValues.begin(), noiseValues.end());
    double noise = noiseValues[noiseValues.size() / 2]; // Median
    
    if (noise > 0) {
        return 20.0 * std::log10(std::abs(signal) / noise);
    }
    
    return 40.0; // High SNR if noise is effectively zero
}

double AlignmentEngine::calculateNoiseFloor(const std::vector<double>& correlation) const {
    if (correlation.empty()) return -60.0;
    
    // Find the 10th percentile as noise floor estimate
    std::vector<double> sortedValues = correlation;
    for (double& val : sortedValues) {
        val = std::abs(val);
    }
    std::sort(sortedValues.begin(), sortedValues.end());
    
    double noiseFloor = sortedValues[sortedValues.size() / 10];
    return 20.0 * std::log10(noiseFloor + 1e-10);
}

// MARK: - Feature Processing

void AlignmentEngine::smoothFeatures(std::vector<float>& features, int filterSize) const {
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

void AlignmentEngine::applyAdaptiveThreshold(std::vector<float>& features, float percentile) const {
    if (features.empty()) return;
    
    // Calculate threshold as percentile
    std::vector<float> sorted = features;
    std::sort(sorted.begin(), sorted.end());
    float threshold = sorted[static_cast<size_t>(sorted.size() * percentile)];
    
    // Apply threshold
    for (float& feature : features) {
        feature = std::max(0.0f, feature - threshold);
    }
}

void AlignmentEngine::normalizeFeatures(std::vector<float>& features) const {
    if (features.empty()) return;
    
    // Find min and max
    auto minMax = std::minmax_element(features.begin(), features.end());
    float minVal = *minMax.first;
    float maxVal = *minMax.second;
    
    if (maxVal > minVal) {
        float range = maxVal - minVal;
        for (float& feature : features) {
            feature = (feature - minVal) / range;
        }
    }
}

// MARK: - Result Creation

harmoniq_sync_result_t AlignmentEngine::createResult(
    int64_t offsetSamples,
    double confidence,
    double peakCorrelation,
    double secondaryPeakRatio,
    double snrEstimate,
    double noiseFloorDb,
    const std::string& method,
    harmoniq_sync_error_t error
) const {
    harmoniq_sync_result_t result = {};
    
    result.offset_samples = offsetSamples;
    result.confidence = confidence;
    result.peak_correlation = peakCorrelation;
    result.secondary_peak_ratio = secondaryPeakRatio;
    result.snr_estimate = snrEstimate;
    result.noise_floor_db = noiseFloorDb;
    result.error = error;
    
    // Copy method name (ensure null termination)
    size_t copyLen = std::min(method.length(), sizeof(result.method) - 1);
    std::memcpy(result.method, method.c_str(), copyLen);
    result.method[copyLen] = '\0';
    
    return result;
}

harmoniq_sync_result_t AlignmentEngine::createErrorResult(harmoniq_sync_error_t error, const std::string& method) const {
    return createResult(0, 0.0, 0.0, 1.0, 0.0, -60.0, method, error);
}

// MARK: - Validation

harmoniq_sync_error_t AlignmentEngine::validateInputs(const AudioProcessor& reference, const AudioProcessor& target) const {
    if (!reference.isValid() || !target.isValid()) {
        return HARMONIQ_SYNC_ERROR_INVALID_INPUT;
    }
    
    if (reference.getLength() == 0 || target.getLength() == 0) {
        return HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA;
    }
    
    if (std::abs(reference.getSampleRate() - target.getSampleRate()) > 1.0) {
        return HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT;
    }
    
    return HARMONIQ_SYNC_SUCCESS;
}

bool AlignmentEngine::isResultValid(const harmoniq_sync_result_t& result) const {
    return result.error == HARMONIQ_SYNC_SUCCESS && 
           result.confidence >= config_.confidenceThreshold &&
           result.confidence <= 1.0;
}

// MARK: - Utility Functions

double AlignmentEngine::samplesToSeconds(int64_t samples, double sampleRate) const {
    return static_cast<double>(samples) / sampleRate;
}

int64_t AlignmentEngine::secondsToSamples(double seconds, double sampleRate) const {
    return static_cast<int64_t>(seconds * sampleRate);
}

void AlignmentEngine::detectOnsets(const std::vector<float>& spectralFlux,
                                  std::vector<size_t>& onsets,
                                  float threshold,
                                  int windowSize) const {
    onsets.clear();
    
    if (spectralFlux.empty() || windowSize <= 0) {
        return;
    }
    
    int halfWindow = windowSize / 2;
    
    // Check if we have enough samples for windowing
    if (spectralFlux.size() <= static_cast<size_t>(2 * halfWindow)) {
        return; // Not enough samples for proper onset detection
    }
    
    // Process each potential onset point
    for (size_t i = halfWindow; i < spectralFlux.size() - halfWindow; ++i) {
        float currentValue = spectralFlux[i];
        
        // Check if current value exceeds threshold
        if (currentValue < threshold) {
            continue;
        }
        
        // Calculate local mean for adaptive threshold
        double localSum = 0.0;
        int validSamples = 0;
        
        for (int j = -halfWindow; j <= halfWindow; ++j) {
            if (static_cast<int>(i) + j >= 0 && i + j < spectralFlux.size()) {
                localSum += spectralFlux[i + j];
                validSamples++;
            }
        }
        
        double localMean = validSamples > 0 ? localSum / validSamples : 0.0;
        double adaptiveThreshold = localMean + threshold;
        
        // Check if current point is a local maximum and exceeds adaptive threshold
        bool isLocalMax = true;
        if (currentValue < adaptiveThreshold) {
            isLocalMax = false;
        } else {
            // Verify it's a local maximum in the window
            for (int j = -halfWindow; j <= halfWindow; ++j) {
                if (j == 0) continue; // Skip the center point
                
                size_t checkIndex = i + j;
                if (checkIndex < spectralFlux.size()) {
                    if (spectralFlux[checkIndex] > currentValue) {
                        isLocalMax = false;
                        break;
                    }
                }
            }
        }
        
        if (isLocalMax) {
            // Avoid duplicate detections by checking minimum distance to previous onset
            bool validOnset = true;
            if (!onsets.empty()) {
                size_t lastOnset = onsets.back();
                if (i - lastOnset < static_cast<size_t>(windowSize / 2)) {
                    // Too close to previous onset - only keep if current is stronger
                    if (currentValue > spectralFlux[lastOnset]) {
                        onsets.pop_back(); // Remove previous weaker onset
                    } else {
                        validOnset = false; // Skip current weaker onset
                    }
                }
            }
            
            if (validOnset) {
                onsets.push_back(i);
            }
        }
    }
}

int64_t AlignmentEngine::calculateMaxOffset(size_t refLength, size_t targetLength) const {
    if (config_.maxOffsetSamples > 0) {
        return config_.maxOffsetSamples;
    }
    
    // Default to 25% of the shorter clip length
    size_t minLength = std::min(refLength, targetLength);
    return static_cast<int64_t>(minLength / 4);
}

std::string AlignmentEngine::getMethodName(harmoniq_sync_method_t method) const {
    switch (method) {
        case HARMONIQ_SYNC_SPECTRAL_FLUX: return "Spectral Flux";
        case HARMONIQ_SYNC_CHROMA: return "Chroma Features";
        case HARMONIQ_SYNC_ENERGY: return "Energy Correlation";
        case HARMONIQ_SYNC_MFCC: return "MFCC";
        case HARMONIQ_SYNC_HYBRID: return "Hybrid";
        default: return "Unknown";
    }
}

} // namespace HarmoniqSync