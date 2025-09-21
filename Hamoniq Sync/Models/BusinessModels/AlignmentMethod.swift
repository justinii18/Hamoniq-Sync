//
//  AlignmentMethod.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation

enum AlignmentMethod: String, CaseIterable, Codable {
    case spectralFlux = "spectral_flux"
    case chroma = "chroma"
    case energy = "energy"
    case mfcc = "mfcc"
    case zeroCrossing = "zero_crossing"
    case timecode = "timecode"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .spectralFlux: return "Spectral Flux"
        case .chroma: return "Chroma Features"
        case .energy: return "Energy Correlation"
        case .mfcc: return "MFCC"
        case .zeroCrossing: return "Zero Crossing"
        case .timecode: return "Timecode"
        case .manual: return "Manual"
        }
    }
    
    var description: String {
        switch self {
        case .spectralFlux: return "Best for speech and dialogue with clear onsets"
        case .chroma: return "Best for music with harmonic content"
        case .energy: return "Best for ambient sounds and simple audio"
        case .mfcc: return "Best for timbral matching between similar sources"
        case .zeroCrossing: return "Voice activity-based alignment"
        case .timecode: return "Use embedded timecode for sync"
        case .manual: return "User-guided manual alignment"
        }
    }
    
    var icon: String {
        switch self {
        case .spectralFlux: return "waveform.path"
        case .chroma: return "music.note"
        case .energy: return "bolt.fill"
        case .mfcc: return "chart.line.uptrend.xyaxis"
        case .zeroCrossing: return "waveform.path.badge.plus"
        case .timecode: return "clock.fill"
        case .manual: return "hand.point.up.left.fill"
        }
    }
    
    var isAutomatic: Bool {
        return self != .manual
    }
}