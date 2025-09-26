//
//  error_handler.hpp
//  HarmoniqSyncCore
//
//  Centralized error handling system for production-grade error management
//

#ifndef ERROR_HANDLER_HPP
#define ERROR_HANDLER_HPP

#include "harmoniq_sync.h"
#include <string>
#include <vector>
#include <chrono>
#include <mutex>
#include <memory>
#include <functional>

namespace HarmoniqSync {

/// Error severity levels for hierarchical error management
enum class ErrorSeverity {
    Trace = 0,
    Debug = 1,
    Info = 2,
    Warning = 3,
    Error = 4,
    Critical = 5
};

/// Comprehensive error context with detailed information
struct ErrorContext {
    harmoniq_sync_error_t code;
    ErrorSeverity severity;
    std::string message;
    std::string component;
    std::string location;
    std::string suggestion;
    std::chrono::system_clock::time_point timestamp;
    
    // Additional context
    std::string operationId;
    std::map<std::string, std::string> metadata;
    
    // Default constructor
    ErrorContext() 
        : code(HARMONIQ_SYNC_SUCCESS)
        , severity(ErrorSeverity::Info)
        , timestamp(std::chrono::system_clock::now()) {}
};

/// Error handler interface for custom error processing
class ErrorHandler {
public:
    /// Error callback function type
    using ErrorCallback = std::function<void(const ErrorContext&)>;
    
    /// Create error context with automatic timestamp
    static ErrorContext createError(
        harmoniq_sync_error_t code,
        ErrorSeverity severity,
        const std::string& message,
        const std::string& component = "",
        const std::string& location = "",
        const std::string& suggestion = ""
    );
    
    /// Create error with automatic severity mapping from error code
    static ErrorContext createError(
        harmoniq_sync_error_t code,
        const std::string& message,
        const std::string& component = "",
        const std::string& location = "",
        const std::string& suggestion = ""
    );
    
    /// Log error to all registered handlers
    static void logError(const ErrorContext& context);
    
    /// Get recent errors (thread-safe)
    static std::vector<ErrorContext> getRecentErrors(size_t maxCount = 100);
    
    /// Clear error log
    static void clearErrorLog();
    
    /// Register error callback
    static void registerErrorCallback(ErrorCallback callback);
    
    /// Unregister all callbacks
    static void clearErrorCallbacks();
    
    /// Set minimum severity level for logging
    static void setMinimumSeverity(ErrorSeverity minSeverity);
    
    /// Get error severity from error code
    static ErrorSeverity getErrorSeverity(harmoniq_sync_error_t code);
    
    /// Get human-readable severity name
    static std::string getSeverityName(ErrorSeverity severity);
    
    /// Get error code name
    static std::string getErrorCodeName(harmoniq_sync_error_t code);
    
    /// Format error context as string
    static std::string formatError(const ErrorContext& context);
    
    /// Create operation ID for tracking related errors
    static std::string createOperationId();

private:
    static std::mutex errorMutex_;
    static std::vector<ErrorContext> errorLog_;
    static std::vector<ErrorCallback> callbacks_;
    static ErrorSeverity minimumSeverity_;
    static std::atomic<uint64_t> operationCounter_;
};

/// RAII error scope for tracking operation context
class ErrorScope {
public:
    explicit ErrorScope(const std::string& operationName);
    ~ErrorScope();
    
    /// Add metadata to current operation
    void addMetadata(const std::string& key, const std::string& value);
    
    /// Log error within this scope
    void logError(const ErrorContext& context);
    
    /// Get current operation ID
    std::string getOperationId() const;

private:
    std::string operationId_;
    std::string operationName_;
    std::chrono::system_clock::time_point startTime_;
    std::map<std::string, std::string> metadata_;
};

/// Macro helpers for convenient error logging
#define HARMONIQ_ERROR(code, message) \
    HarmoniqSync::ErrorHandler::logError( \
        HarmoniqSync::ErrorHandler::createError( \
            (code), (message), __FILE__, __FUNCTION__, ""))

#define HARMONIQ_ERROR_WITH_SUGGESTION(code, message, suggestion) \
    HarmoniqSync::ErrorHandler::logError( \
        HarmoniqSync::ErrorHandler::createError( \
            (code), (message), __FILE__, __FUNCTION__, (suggestion)))

#define HARMONIQ_WARNING(message) \
    HarmoniqSync::ErrorHandler::logError( \
        HarmoniqSync::ErrorHandler::createError( \
            HARMONIQ_SYNC_SUCCESS, HarmoniqSync::ErrorSeverity::Warning, \
            (message), __FILE__, __FUNCTION__, ""))

#define HARMONIQ_INFO(message) \
    HarmoniqSync::ErrorHandler::logError( \
        HarmoniqSync::ErrorHandler::createError( \
            HARMONIQ_SYNC_SUCCESS, HarmoniqSync::ErrorSeverity::Info, \
            (message), __FILE__, __FUNCTION__, ""))

/// Enhanced error results with context
struct EnhancedResult {
    harmoniq_sync_result_t syncResult;
    std::vector<ErrorContext> errors;
    std::vector<ErrorContext> warnings;
    
    /// Check if operation was successful
    bool isSuccess() const {
        return syncResult.error == HARMONIQ_SYNC_SUCCESS;
    }
    
    /// Get all issues (errors + warnings)
    std::vector<ErrorContext> getAllIssues() const {
        std::vector<ErrorContext> all = errors;
        all.insert(all.end(), warnings.begin(), warnings.end());
        return all;
    }
};

/// Error recovery strategies
enum class RecoveryStrategy {
    None,           // No recovery possible
    Retry,          // Operation can be retried
    Fallback,       // Use fallback algorithm/parameters
    Degrade,        // Reduce quality/accuracy for success
    UserInput       // Requires user intervention
};

/// Error recovery recommendation
struct RecoveryRecommendation {
    RecoveryStrategy strategy;
    std::string description;
    std::map<std::string, std::string> parameters;
    double successProbability;
    
    RecoveryRecommendation() 
        : strategy(RecoveryStrategy::None)
        , successProbability(0.0) {}
};

/// Error recovery advisor
class ErrorRecoveryAdvisor {
public:
    /// Get recovery recommendation for error
    static RecoveryRecommendation getRecoveryRecommendation(
        const ErrorContext& error,
        const std::map<std::string, std::string>& context = {}
    );
    
    /// Register custom recovery strategy
    static void registerRecoveryStrategy(
        harmoniq_sync_error_t errorCode,
        std::function<RecoveryRecommendation(const ErrorContext&)> strategy
    );

private:
    static std::map<harmoniq_sync_error_t, 
                   std::function<RecoveryRecommendation(const ErrorContext&)>> strategies_;
};

} // namespace HarmoniqSync

#endif /* ERROR_HANDLER_HPP */