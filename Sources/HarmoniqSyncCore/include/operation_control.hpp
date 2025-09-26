//
//  operation_control.hpp
//  HarmoniqSyncCore
//
//  Operation control system with cancellation, timeouts, and progress reporting
//

#ifndef OPERATION_CONTROL_HPP
#define OPERATION_CONTROL_HPP

#include <chrono>
#include <atomic>
#include <memory>
#include <functional>
#include <string>
#include <mutex>
#include <condition_variable>
#include <thread>

namespace HarmoniqSync {

/// Cancellation token for cooperative cancellation
class CancellationToken {
public:
    CancellationToken();
    ~CancellationToken();
    
    /// Check if cancellation was requested
    bool isCancelled() const;
    
    /// Request cancellation
    void cancel();
    
    /// Reset cancellation state
    void reset();
    
    /// Wait for cancellation with timeout
    bool waitForCancellation(std::chrono::milliseconds timeout) const;

private:
    mutable std::atomic<bool> cancelled_;
    mutable std::mutex mutex_;
    mutable std::condition_variable condition_;
};

/// Progress information with detailed metrics
struct ProgressInfo {
    float percentage;                    // 0.0 to 100.0
    std::string currentStage;           // Human-readable current operation
    std::string detailedStatus;         // Detailed status description
    
    // Timing information
    std::chrono::milliseconds elapsedTime;
    std::chrono::milliseconds estimatedTimeRemaining;
    std::chrono::milliseconds totalEstimatedTime;
    
    // Processing metrics
    size_t itemsProcessed;
    size_t totalItems;
    double processingRate;              // Items per second
    
    // Resource usage
    size_t memoryUsed;                  // Bytes
    double cpuUtilization;              // Percentage
    
    ProgressInfo() 
        : percentage(0.0f)
        , elapsedTime(0)
        , estimatedTimeRemaining(0)
        , totalEstimatedTime(0)
        , itemsProcessed(0)
        , totalItems(0)
        , processingRate(0.0)
        , memoryUsed(0)
        , cpuUtilization(0.0) {}
};

/// Operation control for managing long-running operations
class OperationControl {
public:
    /// Progress callback function type
    using ProgressCallback = std::function<void(const ProgressInfo&)>;
    
    /// Operation completion callback
    using CompletionCallback = std::function<void(bool success, const std::string& result)>;
    
    OperationControl();
    ~OperationControl();
    
    // MARK: - Cancellation Control
    
    /// Set cancellation token
    void setCancellationToken(std::shared_ptr<CancellationToken> token);
    
    /// Get current cancellation token
    std::shared_ptr<CancellationToken> getCancellationToken() const;
    
    /// Check if operation was cancelled
    bool isCancelled() const;
    
    /// Request cancellation of current operation
    void requestCancellation();
    
    // MARK: - Timeout Management
    
    /// Set operation timeout
    void setTimeout(std::chrono::milliseconds timeout);
    
    /// Get remaining time before timeout
    std::chrono::milliseconds getTimeRemaining() const;
    
    /// Check if timeout has occurred
    bool hasTimedOut() const;
    
    /// Extend timeout by additional time
    void extendTimeout(std::chrono::milliseconds additionalTime);
    
    // MARK: - Progress Reporting
    
    /// Set progress callback
    void setProgressCallback(ProgressCallback callback);
    
    /// Clear progress callback
    void clearProgressCallback();
    
    /// Update progress information
    void updateProgress(const ProgressInfo& progress);
    
    /// Update progress with simple percentage
    void updateProgress(float percentage, const std::string& stage);
    
    /// Get current progress information
    ProgressInfo getCurrentProgress() const;
    
    // MARK: - Operation Lifecycle
    
    /// Start operation timing
    void startOperation(const std::string& operationName, size_t totalItems = 0);
    
    /// Complete operation
    void completeOperation(bool success, const std::string& result = "");
    
    /// Check if operation is currently running
    bool isRunning() const;
    
    /// Get operation start time
    std::chrono::steady_clock::time_point getStartTime() const;
    
    /// Get operation duration so far
    std::chrono::milliseconds getElapsedTime() const;
    
    // MARK: - Resource Monitoring
    
    /// Update resource usage information
    void updateResourceUsage(size_t memoryUsed, double cpuUtilization);
    
    /// Get current resource usage
    std::pair<size_t, double> getCurrentResourceUsage() const;
    
    // MARK: - Checkpoint System
    
    /// Create checkpoint for potential rollback
    void createCheckpoint(const std::string& checkpointName);
    
    /// Check if should continue processing (checks cancellation, timeout)
    bool shouldContinue() const;
    
    /// Pause operation (can be resumed)
    void pause();
    
    /// Resume paused operation
    void resume();
    
    /// Check if operation is paused
    bool isPaused() const;

private:
    mutable std::mutex mutex_;
    
    // Cancellation
    std::shared_ptr<CancellationToken> cancellationToken_;
    
    // Timeout
    std::chrono::milliseconds timeout_;
    std::chrono::steady_clock::time_point startTime_;
    
    // Progress
    ProgressCallback progressCallback_;
    ProgressInfo currentProgress_;
    
    // Operation state
    std::atomic<bool> isRunning_;
    std::atomic<bool> isPaused_;
    std::string operationName_;
    
    // Resource monitoring
    std::atomic<size_t> memoryUsed_;
    std::atomic<double> cpuUtilization_;
    
    // Internal helpers
    void notifyProgress();
    std::chrono::milliseconds calculateEstimatedTimeRemaining() const;
};

/// Automatic operation scope manager (RAII)
class OperationScope {
public:
    OperationScope(OperationControl& control, const std::string& operationName, size_t totalItems = 0);
    ~OperationScope();
    
    /// Update progress within this scope
    void updateProgress(float percentage, const std::string& stage = "");
    
    /// Check if should continue (throws if cancelled/timeout)
    void checkContinuation() const;
    
    /// Mark operation as successful
    void markSuccess(const std::string& result = "");
    
    /// Mark operation as failed
    void markFailure(const std::string& error = "");

private:
    OperationControl& control_;
    bool completed_;
    bool success_;
    std::string result_;
};

/// Operation timeout exception
class OperationTimeoutException : public std::exception {
public:
    explicit OperationTimeoutException(const std::string& message) : message_(message) {}
    const char* what() const noexcept override { return message_.c_str(); }

private:
    std::string message_;
};

/// Operation cancelled exception
class OperationCancelledException : public std::exception {
public:
    explicit OperationCancelledException(const std::string& message) : message_(message) {}
    const char* what() const noexcept override { return message_.c_str(); }

private:
    std::string message_;
};

/// Global operation manager for coordinating multiple operations
class GlobalOperationManager {
public:
    /// Register operation for global tracking
    static void registerOperation(const std::string& operationId, 
                                 std::shared_ptr<OperationControl> control);
    
    /// Unregister operation
    static void unregisterOperation(const std::string& operationId);
    
    /// Cancel all registered operations
    static void cancelAllOperations();
    
    /// Get operation by ID
    static std::shared_ptr<OperationControl> getOperation(const std::string& operationId);
    
    /// Get all active operations
    static std::vector<std::pair<std::string, std::shared_ptr<OperationControl>>> getAllOperations();
    
    /// Set global operation timeout
    static void setGlobalTimeout(std::chrono::milliseconds timeout);
    
    /// Get global operation statistics
    struct GlobalStats {
        size_t activeOperations;
        size_t totalOperationsStarted;
        size_t totalOperationsCompleted;
        size_t totalOperationsCancelled;
        size_t totalOperationsTimedOut;
        std::chrono::milliseconds averageOperationTime;
        
        GlobalStats() : activeOperations(0), totalOperationsStarted(0),
                       totalOperationsCompleted(0), totalOperationsCancelled(0),
                       totalOperationsTimedOut(0), averageOperationTime(0) {}
    };
    
    static GlobalStats getGlobalStats();
    
    /// Clear global statistics
    static void clearStats();

private:
    static std::mutex globalMutex_;
    static std::map<std::string, std::shared_ptr<OperationControl>> operations_;
    static GlobalStats stats_;
    static std::chrono::milliseconds globalTimeout_;
};

/// Utility class for operation performance monitoring
class OperationProfiler {
public:
    /// Performance metrics for an operation
    struct PerformanceMetrics {
        std::chrono::milliseconds totalTime;
        std::chrono::milliseconds setupTime;
        std::chrono::milliseconds processingTime;
        std::chrono::milliseconds cleanupTime;
        
        size_t peakMemoryUsage;
        double averageCpuUtilization;
        double maxCpuUtilization;
        
        size_t itemsProcessed;
        double itemsPerSecond;
        
        PerformanceMetrics() : totalTime(0), setupTime(0), processingTime(0),
                             cleanupTime(0), peakMemoryUsage(0),
                             averageCpuUtilization(0.0), maxCpuUtilization(0.0),
                             itemsProcessed(0), itemsPerSecond(0.0) {}
    };
    
    /// Start profiling an operation
    static void startProfiling(const std::string& operationId);
    
    /// Mark setup phase complete
    static void markSetupComplete(const std::string& operationId);
    
    /// Mark processing phase complete
    static void markProcessingComplete(const std::string& operationId);
    
    /// End profiling and get metrics
    static PerformanceMetrics endProfiling(const std::string& operationId);
    
    /// Get profiling results for operation
    static PerformanceMetrics getMetrics(const std::string& operationId);
    
    /// Clear profiling data
    static void clearProfiling(const std::string& operationId);

private:
    struct ProfilingData {
        std::chrono::steady_clock::time_point startTime;
        std::chrono::steady_clock::time_point setupCompleteTime;
        std::chrono::steady_clock::time_point processingCompleteTime;
        std::chrono::steady_clock::time_point endTime;
        
        size_t peakMemoryUsage;
        std::vector<double> cpuSamples;
        size_t itemsProcessed;
    };
    
    static std::mutex profilingMutex_;
    static std::map<std::string, ProfilingData> profilingData_;
};

} // namespace HarmoniqSync

#endif /* OPERATION_CONTROL_HPP */