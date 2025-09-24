//
//  alignment_engine.hpp
//  HarmoniqSyncCore
//
//  Core alignment algorithms and correlation analysis
//

#ifndef ALIGNMENT_ENGINE_HPP
#define ALIGNMENT_ENGINE_HPP

#include "audio_processor.hpp"
#include "harmoniq_sync.h"
#include <vector>
#include <string>

namespace HarmoniqSync {

class AlignmentEngine {
public:
    // MARK: - Lifecycle
    
    AlignmentEngine();
    ~AlignmentEngine();
    
    // MARK: - Configuration
    
    struct Config {
        double confidenceThreshold = 0.7;
        int64_t maxOffsetSamples = 0;  // 0 = auto-calculate
        int windowSize = 1024;
        int hopSize = 0;  // 0 = auto-calculate (windowSize/4)
        double noiseGateDb = -40.0;
        bool enableDriftCorrection = true;
        
        // Algorithm-specific parameters
        struct {
            float preEmphasisAlpha = 0.97f;
            int medianFilterSize = 3;
        } spectralFlux;
        
        struct {
            int numChromaBins = 12;
            bool useHarmonicWeighting = true;
        } chroma;
        
        struct {
            int smoothingWindowSize = 5;
        } energy;
        
        struct {
            int numCoeffs = 13;
            int numMelFilters = 26;
            bool includeC0 = false;  // Include 0th coefficient
        } mfcc;
    };
    
    void setConfig(const Config& config) { config_ = config; }
    const Config& getConfig() const { return config_; }
    
    // MARK: - Alignment Methods
    
    /// Align using spectral flux (best for speech/dialogue)
    harmoniq_sync_result_t alignSpectralFlux(const AudioProcessor& reference, const AudioProcessor& target);
    
    /// Align using chroma features (best for music)
    harmoniq_sync_result_t alignChromaFeatures(const AudioProcessor& reference, const AudioProcessor& target);
    
    /// Align using energy correlation (best for ambient/simple audio)
    harmoniq_sync_result_t alignEnergyCorrelation(const AudioProcessor& reference, const AudioProcessor& target);
    
    /// Align using MFCC (best for timbral matching)
    harmoniq_sync_result_t alignMFCC(const AudioProcessor& reference, const AudioProcessor& target);
    
    /// Hybrid alignment combining multiple methods
    harmoniq_sync_result_t alignHybrid(const AudioProcessor& reference, const AudioProcessor& target);
    
    // MARK: - Batch Processing
    
    /// Align multiple targets against single reference
    std::vector<harmoniq_sync_result_t> alignBatch(
        const AudioProcessor& reference,
        const std::vector<AudioProcessor>& targets,
        harmoniq_sync_method_t method
    );
    
private:
    // MARK: - Private Members
    
    Config config_;
    
    // Working buffers for correlation analysis
    mutable std::vector<double> correlationBuffer;
    mutable std::vector<float> featureBuffer1;
    mutable std::vector<float> featureBuffer2;
    
    // MARK: - Core Correlation Functions
    
    /// Compute cross-correlation between two feature vectors
    std::vector<double> crossCorrelate(const std::vector<float>& a, const std::vector<float>& b) const;
    
    /// Find the best alignment from correlation data
    struct CorrelationPeak {
        size_t index;
        double value;
        double confidence;
        double secondaryPeakRatio;
    };
    
    CorrelationPeak findBestAlignment(const std::vector<double>& correlation) const;
    
    /// Calculate confidence score based on correlation statistics
    double calculateConfidence(const std::vector<double>& correlation, size_t peakIndex) const;
    
    /// Calculate signal-to-noise ratio estimate
    double calculateSNREstimate(const std::vector<double>& correlation, size_t peakIndex) const;
    
    /// Calculate noise floor in correlation
    double calculateNoiseFloor(const std::vector<double>& correlation) const;
    
    // MARK: - Feature Processing
    
    /// Smooth feature vector using median filter
    void smoothFeatures(std::vector<float>& features, int filterSize) const;
    
    /// Apply adaptive thresholding to features
    void applyAdaptiveThreshold(std::vector<float>& features, float percentile = 0.1f) const;
    
    /// Normalize feature vector
    void normalizeFeatures(std::vector<float>& features) const;
    
    // MARK: - Drift Correction
    
    struct DriftInfo {
        bool detected = false;
        double ppm = 0.0;  // Parts per million
        bool correctionApplied = false;
    };
    
    /// Detect and correct time drift between audio sources
    DriftInfo detectAndCorrectDrift(
        const std::vector<float>& refFeatures,
        std::vector<float>& targetFeatures,
        double sampleRate
    ) const;
    
    // MARK: - Result Creation
    
    /// Create result structure from alignment data
    harmoniq_sync_result_t createResult(
        int64_t offsetSamples,
        double confidence,
        double peakCorrelation,
        double secondaryPeakRatio,
        double snrEstimate,
        double noiseFloorDb,
        const std::string& method,
        harmoniq_sync_error_t error = HARMONIQ_SYNC_SUCCESS
    ) const;
    
    /// Create error result
    harmoniq_sync_result_t createErrorResult(harmoniq_sync_error_t error, const std::string& method) const;
    
    // MARK: - Validation
    
    /// Validate audio processors before alignment
    harmoniq_sync_error_t validateInputs(const AudioProcessor& reference, const AudioProcessor& target) const;
    
    /// Check if alignment result meets quality thresholds
    bool isResultValid(const harmoniq_sync_result_t& result) const;
    
    // MARK: - Utility Functions
    
    /// Convert sample offset to time offset
    double samplesToSeconds(int64_t samples, double sampleRate) const;
    
    /// Convert time offset to sample offset
    int64_t secondsToSamples(double seconds, double sampleRate) const;
    
    /// Calculate maximum reasonable offset based on audio lengths
    int64_t calculateMaxOffset(size_t refLength, size_t targetLength) const;
    
    /// Get method name as string
    std::string getMethodName(harmoniq_sync_method_t method) const;
};

} // namespace HarmoniqSync

#endif /* ALIGNMENT_ENGINE_HPP */