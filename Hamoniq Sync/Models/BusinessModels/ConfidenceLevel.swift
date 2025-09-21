//
//  ConfidenceLevel.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation

enum ConfidenceLevel: String, CaseIterable, Codable {
    case veryLow = "very_low"
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .veryLow: return "Very Low"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
    
    var color: String {
        switch self {
        case .veryLow: return "systemRed"
        case .low: return "systemOrange"
        case .medium: return "systemYellow"
        case .high: return "systemGreen"
        }
    }
    
    var threshold: Double {
        switch self {
        case .veryLow: return 0.0
        case .low: return 0.4
        case .medium: return 0.6
        case .high: return 0.8
        }
    }
    
    var icon: String {
        switch self {
        case .veryLow: return "exclamationmark.triangle.fill"
        case .low: return "exclamationmark.circle.fill"
        case .medium: return "checkmark.circle"
        case .high: return "checkmark.circle.fill"
        }
    }
    
    static func from(confidence: Double) -> ConfidenceLevel {
        switch confidence {
        case 0.8...: return .high
        case 0.6..<0.8: return .medium
        case 0.4..<0.6: return .low
        default: return .veryLow
        }
    }
}