//
//  ErrorTypes.swift
//  HarmoniqSyncKit
//
//  Enhanced error handling for audio synchronization
//

import Foundation
import HarmoniqSyncCore

// MARK: - Sync Engine Error

public enum SyncEngineError: LocalizedError, CustomDebugStringConvertible, Sendable {
    case invalidInput(String)
    case insufficientData(minimumDuration: TimeInterval)
    case processingFailed(String)
    case outOfMemory(requestedBytes: Int)
    case unsupportedFormat(formatDescription: String)
    case cancelled
    case configurationError(String)
    case fileAccessError(String)
    
    internal init?(from cError: harmoniq_sync_error_t, context: String = "") {
        switch cError {
        case HARMONIQ_SYNC_SUCCESS:
            return nil
        case HARMONIQ_SYNC_ERROR_INVALID_INPUT:
            self = .invalidInput(context.isEmpty ? "Invalid input data provided" : context)
        case HARMONIQ_SYNC_ERROR_INSUFFICIENT_DATA:
            self = .insufficientData(minimumDuration: 1.0) // Default minimum
        case HARMONIQ_SYNC_ERROR_PROCESSING_FAILED:
            self = .processingFailed(context.isEmpty ? "Processing operation failed" : context)
        case HARMONIQ_SYNC_ERROR_OUT_OF_MEMORY:
            self = .outOfMemory(requestedBytes: 0) // Unknown size
        case HARMONIQ_SYNC_ERROR_UNSUPPORTED_FORMAT:
            self = .unsupportedFormat(formatDescription: context.isEmpty ? "Unknown format" : context)
        default:
            self = .processingFailed("Unknown error code: \(cError)")
        }
    }
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let details):
            return "Invalid input: \(details)"
        case .insufficientData(let minimumDuration):
            return "Insufficient audio data. Minimum duration required: \(String(format: "%.1f", minimumDuration)) seconds"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .outOfMemory(let requestedBytes):
            return requestedBytes > 0 
                ? "Out of memory (requested: \(ByteCountFormatter().string(fromByteCount: Int64(requestedBytes))))"
                : "Out of memory during processing"
        case .unsupportedFormat(let formatDescription):
            return "Unsupported audio format: \(formatDescription)"
        case .cancelled:
            return "Operation was cancelled"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        case .fileAccessError(let details):
            return "File access error: \(details)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .invalidInput:
            return "The provided audio data is invalid or corrupted"
        case .insufficientData:
            return "The audio clips are too short for reliable alignment"
        case .processingFailed:
            return "An error occurred during audio processing"
        case .outOfMemory:
            return "The system ran out of available memory"
        case .unsupportedFormat:
            return "The audio format is not supported"
        case .cancelled:
            return "The user or system cancelled the operation"
        case .configurationError:
            return "The synchronization configuration is invalid"
        case .fileAccessError:
            return "Unable to access the specified audio file"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidInput:
            return "Check that the audio files are valid and not corrupted"
        case .insufficientData(let minimumDuration):
            return "Use audio clips that are at least \(String(format: "%.1f", minimumDuration)) seconds long"
        case .processingFailed:
            return "Try using different alignment settings or check system resources"
        case .outOfMemory:
            return "Close other applications to free up memory, or use smaller audio files"
        case .unsupportedFormat:
            return "Convert the audio to a supported format (WAV, AIFF, MP3, or M4A)"
        case .cancelled:
            return "Restart the operation if needed"
        case .configurationError:
            return "Review and correct the synchronization configuration"
        case .fileAccessError:
            return "Check file permissions and ensure the file exists"
        }
    }
    
    // MARK: - CustomDebugStringConvertible
    
    public var debugDescription: String {
        let baseDescription = errorDescription ?? "Unknown error"
        let reason = failureReason ?? ""
        let suggestion = recoverySuggestion ?? ""
        
        var debug = "SyncEngineError: \(baseDescription)"
        if !reason.isEmpty {
            debug += "\nReason: \(reason)"
        }
        if !suggestion.isEmpty {
            debug += "\nSuggestion: \(suggestion)"
        }
        
        return debug
    }
}

// MARK: - Audio Decoder Error

public enum AudioDecoderError: LocalizedError, CustomDebugStringConvertible, Sendable {
    case invalidURL(String)
    case unsupportedFormat(String)
    case decodingFailed(String)
    case insufficientData(minimumSamples: Int)
    case memoryAllocationFailed(requestedSize: Int)
    case fileNotFound(String)
    case permissionDenied(String)
    case corruptedFile(String)
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid audio file URL: \(url)"
        case .unsupportedFormat(let format):
            return "Unsupported audio format: \(format)"
        case .decodingFailed(let reason):
            return "Audio decoding failed: \(reason)"
        case .insufficientData(let minimumSamples):
            return "Insufficient audio data (minimum: \(minimumSamples) samples)"
        case .memoryAllocationFailed(let requestedSize):
            return "Failed to allocate memory (\(ByteCountFormatter().string(fromByteCount: Int64(requestedSize))))"
        case .fileNotFound(let path):
            return "Audio file not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied accessing: \(path)"
        case .corruptedFile(let path):
            return "Corrupted audio file: \(path)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .invalidURL:
            return "The provided URL is not valid or accessible"
        case .unsupportedFormat:
            return "The audio format is not supported by the decoder"
        case .decodingFailed:
            return "An error occurred while decoding the audio file"
        case .insufficientData:
            return "The audio file contains insufficient data for processing"
        case .memoryAllocationFailed:
            return "Unable to allocate required memory for audio processing"
        case .fileNotFound:
            return "The specified audio file does not exist"
        case .permissionDenied:
            return "Insufficient permissions to access the audio file"
        case .corruptedFile:
            return "The audio file appears to be corrupted or incomplete"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidURL:
            return "Check that the file path is correct and the file exists"
        case .unsupportedFormat:
            return "Convert the audio to WAV, AIFF, MP3, or M4A format"
        case .decodingFailed:
            return "Try converting the file to a different format or check if it's corrupted"
        case .insufficientData:
            return "Use a longer audio file or check if the file is complete"
        case .memoryAllocationFailed:
            return "Close other applications to free up memory"
        case .fileNotFound:
            return "Verify the file path and ensure the file exists"
        case .permissionDenied:
            return "Check file permissions or run with appropriate privileges"
        case .corruptedFile:
            return "Try re-encoding the audio file or obtain a new copy"
        }
    }
    
    // MARK: - CustomDebugStringConvertible
    
    public var debugDescription: String {
        let baseDescription = errorDescription ?? "Unknown audio decoder error"
        let reason = failureReason ?? ""
        let suggestion = recoverySuggestion ?? ""
        
        var debug = "AudioDecoderError: \(baseDescription)"
        if !reason.isEmpty {
            debug += "\nReason: \(reason)"
        }
        if !suggestion.isEmpty {
            debug += "\nSuggestion: \(suggestion)"
        }
        
        return debug
    }
}

// MARK: - Error Utilities

extension SyncEngineError {
    /// Create error with additional context
    public static func invalidInput(details: String) -> SyncEngineError {
        return .invalidInput(details)
    }
    
    public static func insufficientData(duration: TimeInterval, required: TimeInterval) -> SyncEngineError {
        return .insufficientData(minimumDuration: required)
    }
    
    public static func processingFailed(operation: String, underlying: Error? = nil) -> SyncEngineError {
        let details = underlying?.localizedDescription ?? operation
        return .processingFailed(details)
    }
    
    /// Check if error is recoverable
    public var isRecoverable: Bool {
        switch self {
        case .invalidInput, .unsupportedFormat, .configurationError:
            return true
        case .insufficientData, .fileAccessError:
            return true
        case .outOfMemory, .processingFailed, .cancelled:
            return false
        }
    }
}

extension AudioDecoderError {
    /// Create error from NSError
    public static func from(_ nsError: NSError, context: String = "") -> AudioDecoderError {
        let description = nsError.localizedDescription
        let contextDescription = context.isEmpty ? description : "\(context): \(description)"
        
        switch nsError.code {
        case NSFileReadNoSuchFileError:
            return .fileNotFound(contextDescription)
        case NSFileReadNoPermissionError:
            return .permissionDenied(contextDescription)
        default:
            return .decodingFailed(contextDescription)
        }
    }
}