//
//  error_handler.cpp
//  HarmoniqSyncCore
//
//  Centralized error handling system for production-grade error management
//

#include "../include/error_handler.hpp"
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <atomic>

namespace HarmoniqSync {

// Static member definitions
std::mutex ErrorHandler::errorMutex_;
std::vector<ErrorContext> ErrorHandler::errorLog_;
std::vector<ErrorHandler::ErrorCallback> ErrorHandler::callbacks_;
ErrorSeverity ErrorHandler::minimumSeverity_ = ErrorSeverity::Info;
std::atomic<uint64_t> ErrorHandler::operationCounter_{0};

// MARK: - ErrorHandler Implementation

ErrorContext ErrorHandler::createError(
    harmoniq_sync_error_t code,
    ErrorSeverity severity,
    const std::string& message,
    const std::string& component,
    const std::string& location,
    const std::string& suggestion
) {
    ErrorContext context;
    context.code = code;
    context.severity = severity;
    context.message = message;
    context.component = component;
    context.location = location;
    context.suggestion = suggestion;
    context.timestamp = std::chrono::system_clock::now();
    context.operationId = createOperationId();
    
    return context;
}

ErrorContext ErrorHandler::createError(
    harmoniq_sync_error_t code,
    const std::string& message,
    const std::string& component,
    const std::string& location,
    const std::string& suggestion
) {
    ErrorSeverity severity = getErrorSeverity(code);
    return createError(code, severity, message, component, location, suggestion);
}

void ErrorHandler::logError(const ErrorContext& context) {
    // Check if severity meets minimum threshold
    if (context.severity < minimumSeverity_) {
        return;
    }
    
    {
        std::lock_guard<std::mutex> lock(errorMutex_);
        
        // Add to error log with size limit
        errorLog_.push_back(context);
        if (errorLog_.size() > 1000) { // Keep last 1000 errors
            errorLog_.erase(errorLog_.begin());
        }
    }
    
    // Call all registered callbacks
    std::vector<ErrorCallback> callbacks;
    {
        std::lock_guard<std::mutex> lock(errorMutex_);
        callbacks = callbacks_;
    }
    
    for (const auto& callback : callbacks) {
        try {
            callback(context);
        } catch (...) {
            // Callbacks should not throw, but protect against bad implementations
        }
    }
}

std::vector<ErrorContext> ErrorHandler::getRecentErrors(size_t maxCount) {
    std::lock_guard<std::mutex> lock(errorMutex_);
    
    std::vector<ErrorContext> result;
    size_t startIndex = errorLog_.size() > maxCount ? errorLog_.size() - maxCount : 0;
    
    result.reserve(errorLog_.size() - startIndex);
    for (size_t i = startIndex; i < errorLog_.size(); ++i) {
        result.push_back(errorLog_[i]);
    }
    
    return result;
}

void ErrorHandler::clearErrorLog() {
    std::lock_guard<std::mutex> lock(errorMutex_);
    errorLog_.clear();
}

void ErrorHandler::registerErrorCallback(ErrorCallback callback) {
    std::lock_guard<std::mutex> lock(errorMutex_);
    callbacks_.push_back(callback);
}

void ErrorHandler::clearErrorCallbacks() {
    std::lock_guard<std::mutex> lock(errorMutex_);
    callbacks_.clear();
}

void ErrorHandler::setMinimumSeverity(ErrorSeverity minSeverity) {
    minimumSeverity_ = minSeverity;
}

ErrorSeverity ErrorHandler::getErrorSeverity(harmoniq_sync_error_t code) {
    switch (code) {
        case HARMONIQ_SYNC_SUCCESS:
            return ErrorSeverity::Info;
        case HARMONIQ_SYNC_ERROR_INVALID_INPUT:
            return ErrorSeverity::Warning;
        case HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA:
            return ErrorSeverity::Warning;
        case HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT:
            return ErrorSeverity::Warning;
        case HARMONIQ_SYNC_ERROR_PROCESSING_FAILED:
            return ErrorSeverity::Error;
        case HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY:
            return ErrorSeverity::Critical;
        default:
            return ErrorSeverity::Error;
    }
}

std::string ErrorHandler::getSeverityName(ErrorSeverity severity) {
    switch (severity) {
        case ErrorSeverity::Trace: return "TRACE";
        case ErrorSeverity::Debug: return "DEBUG";
        case ErrorSeverity::Info: return "INFO";
        case ErrorSeverity::Warning: return "WARNING";
        case ErrorSeverity::Error: return "ERROR";
        case ErrorSeverity::Critical: return "CRITICAL";
        default: return "UNKNOWN";
    }
}

std::string ErrorHandler::getErrorCodeName(harmoniq_sync_error_t code) {
    switch (code) {
        case HARMONIQ_SYNC_SUCCESS: return "SUCCESS";
        case HARMONIQ_SYNC_ERROR_INVALID_INPUT: return "INVALID_INPUT";
        case HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA: return "INSUFFICIENT_DATA";
        case HARMONIQ_SYNC_ERROR_PROCESSING_FAILED: return "PROCESSING_FAILED";
        case HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY: return "OUT_OF_MEMORY";
        case HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT: return "UNSUPPORTED_FORMAT";
        default: return "UNKNOWN_ERROR";
    }
}

std::string ErrorHandler::formatError(const ErrorContext& context) {
    std::ostringstream oss;
    
    // Timestamp formatting
    auto timeT = std::chrono::system_clock::to_time_t(context.timestamp);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        context.timestamp.time_since_epoch()) % 1000;
    
    oss << std::put_time(std::localtime(&timeT), "%Y-%m-%d %H:%M:%S");
    oss << "." << std::setfill('0') << std::setw(3) << ms.count();
    
    // Error information
    oss << " [" << getSeverityName(context.severity) << "]";
    oss << " [" << getErrorCodeName(context.code) << "]";
    
    if (!context.component.empty()) {
        oss << " [" << context.component << "]";
    }
    
    if (!context.operationId.empty()) {
        oss << " [Op:" << context.operationId << "]";
    }
    
    oss << " " << context.message;
    
    if (!context.location.empty()) {
        oss << " (at " << context.location << ")";
    }
    
    if (!context.suggestion.empty()) {
        oss << " | Suggestion: " << context.suggestion;
    }
    
    // Metadata
    if (!context.metadata.empty()) {
        oss << " | Metadata: ";
        bool first = true;
        for (const auto& pair : context.metadata) {
            if (!first) oss << ", ";
            oss << pair.first << "=" << pair.second;
            first = false;
        }
    }
    
    return oss.str();
}

std::string ErrorHandler::createOperationId() {
    uint64_t counter = operationCounter_.fetch_add(1);
    std::ostringstream oss;
    oss << "OP" << std::setfill('0') << std::setw(8) << std::hex << counter;
    return oss.str();
}

// MARK: - ErrorScope Implementation

ErrorScope::ErrorScope(const std::string& operationName)
    : operationId_(ErrorHandler::createOperationId())
    , operationName_(operationName)
    , startTime_(std::chrono::system_clock::now())
{
    // Log operation start
    ErrorContext context = ErrorHandler::createError(
        HARMONIQ_SYNC_SUCCESS,
        ErrorSeverity::Debug,
        "Operation started: " + operationName_,
        "ErrorScope",
        __FUNCTION__
    );
    context.operationId = operationId_;
    ErrorHandler::logError(context);
}

ErrorScope::~ErrorScope() {
    auto endTime = std::chrono::system_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime_);
    
    // Log operation end
    ErrorContext context = ErrorHandler::createError(
        HARMONIQ_SYNC_SUCCESS,
        ErrorSeverity::Debug,
        "Operation completed: " + operationName_ + " (took " + std::to_string(duration.count()) + "ms)",
        "ErrorScope",
        __FUNCTION__
    );
    context.operationId = operationId_;
    context.metadata = metadata_;
    context.metadata["duration_ms"] = std::to_string(duration.count());
    
    ErrorHandler::logError(context);
}

void ErrorScope::addMetadata(const std::string& key, const std::string& value) {
    metadata_[key] = value;
}

void ErrorScope::logError(const ErrorContext& context) {
    ErrorContext modifiedContext = context;
    modifiedContext.operationId = operationId_;
    
    // Merge metadata
    for (const auto& pair : metadata_) {
        modifiedContext.metadata[pair.first] = pair.second;
    }
    
    ErrorHandler::logError(modifiedContext);
}

std::string ErrorScope::getOperationId() const {
    return operationId_;
}

// MARK: - ErrorRecoveryAdvisor Implementation

std::map<harmoniq_sync_error_t, 
         std::function<RecoveryRecommendation(const ErrorContext&)>> ErrorRecoveryAdvisor::strategies_;

RecoveryRecommendation ErrorRecoveryAdvisor::getRecoveryRecommendation(
    const ErrorContext& error,
    const std::map<std::string, std::string>& context
) {
    RecoveryRecommendation recommendation;
    
    // Check for custom recovery strategy
    auto strategyIt = strategies_.find(error.code);
    if (strategyIt != strategies_.end()) {
        return strategyIt->second(error);
    }
    
    // Default recovery strategies based on error code
    switch (error.code) {
        case HARMONIQ_SYNC_ERROR_INVALID_INPUT:
            recommendation.strategy = RecoveryStrategy::UserInput;
            recommendation.description = "Validate and correct input parameters";
            recommendation.successProbability = 0.9;
            break;
            
        case HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA:
            recommendation.strategy = RecoveryStrategy::Degrade;
            recommendation.description = "Use lower quality settings or provide more audio data";
            recommendation.parameters["min_audio_duration"] = "2.0";
            recommendation.successProbability = 0.7;
            break;
            
        case HARMONIQ_SYNC_ERROR_PROCESSING_FAILED:
            recommendation.strategy = RecoveryStrategy::Fallback;
            recommendation.description = "Try alternative synchronization algorithm";
            recommendation.parameters["fallback_method"] = "energy_correlation";
            recommendation.successProbability = 0.6;
            break;
            
        case HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY:
            recommendation.strategy = RecoveryStrategy::Degrade;
            recommendation.description = "Reduce processing quality or free system memory";
            recommendation.parameters["max_window_size"] = "512";
            recommendation.parameters["reduce_precision"] = "true";
            recommendation.successProbability = 0.8;
            break;
            
        case HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT:
            recommendation.strategy = RecoveryStrategy::UserInput;
            recommendation.description = "Convert audio to supported format";
            recommendation.parameters["supported_sample_rates"] = "44100,48000";
            recommendation.successProbability = 0.95;
            break;
            
        default:
            recommendation.strategy = RecoveryStrategy::None;
            recommendation.description = "No automatic recovery available";
            recommendation.successProbability = 0.0;
            break;
    }
    
    return recommendation;
}

void ErrorRecoveryAdvisor::registerRecoveryStrategy(
    harmoniq_sync_error_t errorCode,
    std::function<RecoveryRecommendation(const ErrorContext&)> strategy
) {
    strategies_[errorCode] = strategy;
}

} // namespace HarmoniqSync