//
//  SyncStrategy.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation

enum SyncStrategy: String, CaseIterable, Codable {
    case auto = "auto"
    case manual = "manual"
    case hybrid = "hybrid"
    case timecodeOnly = "timecode_only"
    
    var description: String {
        switch self {
        case .auto: return "Automatic sync using audio analysis"
        case .manual: return "Manual sync with user guidance"
        case .hybrid: return "Automatic with manual refinement"
        case .timecodeOnly: return "Sync using embedded timecode"
        }
    }
    
    var displayName: String {
        switch self {
        case .auto: return "Automatic"
        case .manual: return "Manual"
        case .hybrid: return "Hybrid"
        case .timecodeOnly: return "Timecode Only"
        }
    }
    
    var requiresAudioAnalysis: Bool {
        switch self {
        case .auto, .hybrid: return true
        case .manual, .timecodeOnly: return false
        }
    }
}