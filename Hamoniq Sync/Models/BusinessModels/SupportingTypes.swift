//
//  SupportingTypes.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation

// MARK: - Media Group Types

enum MediaGroupType: String, CaseIterable, Codable {
    case camera = "camera"
    case audio = "audio"
    case mixed = "mixed"
    case reference = "reference"
    case bRoll = "b_roll"
    case timelapses = "timelapses"
    
    var displayName: String {
        switch self {
        case .camera: return "Camera"
        case .audio: return "Audio"
        case .mixed: return "Mixed"
        case .reference: return "Reference"
        case .bRoll: return "B-Roll"
        case .timelapses: return "Timelapses"
        }
    }
    
    var systemColor: String {
        switch self {
        case .camera: return "systemBlue"
        case .audio: return "systemGreen"
        case .mixed: return "systemOrange"
        case .reference: return "systemPurple"
        case .bRoll: return "systemIndigo"
        case .timelapses: return "systemYellow"
        }
    }
    
    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .audio: return "waveform"
        case .mixed: return "av.remote.fill"
        case .reference: return "star.fill"
        case .bRoll: return "film.fill"
        case .timelapses: return "timer"
        }
    }
}

// MARK: - Job and Processing Types

enum JobStatus: String, CaseIterable, Codable {
    case queued, running, paused, completed, failed, cancelled
    
    var displayName: String {
        switch self {
        case .queued: return "Queued"
        case .running: return "Running"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .queued: return "systemGray"
        case .running: return "systemBlue"
        case .paused: return "systemYellow"
        case .completed: return "systemGreen"
        case .failed: return "systemRed"
        case .cancelled: return "systemOrange"
        }
    }
}

enum JobPriority: String, CaseIterable, Codable {
    case low, normal, high, urgent
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .low: return 0
        case .normal: return 1
        case .high: return 2
        case .urgent: return 3
        }
    }
}

enum SyncJobType: String, CaseIterable, Codable {
    case singlePair, multiCam, batch, reSync
    
    var displayName: String {
        switch self {
        case .singlePair: return "Single Pair"
        case .multiCam: return "Multi-Camera"
        case .batch: return "Batch Processing"
        case .reSync: return "Re-sync"
        }
    }
}

enum ValidationStatus: String, CaseIterable, Codable {
    case pending, valid, warning, error
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .valid: return "Valid"
        case .warning: return "Warning"
        case .error: return "Error"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "systemGray"
        case .valid: return "systemGreen"
        case .warning: return "systemYellow"
        case .error: return "systemRed"
        }
    }
}

enum ProcessingStatus: String, CaseIterable, Codable {
    case pending, processing, completed, failed
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}

enum ImportMethod: String, CaseIterable, Codable {
    case dragDrop, fileMenu, smartStart, watchFolder
    
    var displayName: String {
        switch self {
        case .dragDrop: return "Drag & Drop"
        case .fileMenu: return "File Menu"
        case .smartStart: return "Smart Start"
        case .watchFolder: return "Watch Folder"
        }
    }
}

// MARK: - Export and NLE Types

enum NLETarget: String, CaseIterable, Codable {
    case finalCutPro, premierePro, daVinciResolve, capCut, avid, universal
    
    var displayName: String {
        switch self {
        case .finalCutPro: return "Final Cut Pro"
        case .premierePro: return "Premiere Pro"
        case .daVinciResolve: return "DaVinci Resolve"
        case .capCut: return "CapCut"
        case .avid: return "Avid Media Composer"
        case .universal: return "Universal (EDL)"
        }
    }
    
    var icon: String {
        switch self {
        case .finalCutPro: return "scissors"
        case .premierePro: return "play.rectangle.fill"
        case .daVinciResolve: return "paintbrush.fill"
        case .capCut: return "video.badge.plus"
        case .avid: return "film.strip"
        case .universal: return "doc.text.fill"
        }
    }
}

enum ExportFormat: String, CaseIterable, Codable {
    case fcpxml, premiereXML, resolveCSV, ediusPPF, edl, csv, json
    
    var displayName: String {
        switch self {
        case .fcpxml: return "FCPXML"
        case .premiereXML: return "Premiere XML"
        case .resolveCSV: return "Resolve CSV"
        case .ediusPPF: return "EDIUS PPF"
        case .edl: return "EDL"
        case .csv: return "CSV"
        case .json: return "JSON"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .fcpxml: return "fcpxml"
        case .premiereXML: return "xml"
        case .resolveCSV: return "csv"
        case .ediusPPF: return "ppf"
        case .edl: return "edl"
        case .csv: return "csv"
        case .json: return "json"
        }
    }
}

enum PostExportAction: String, CaseIterable, Codable {
    case openInNLE, revealInFinder, copyToClipboard, sendEmail
    
    var displayName: String {
        switch self {
        case .openInNLE: return "Open in NLE"
        case .revealInFinder: return "Reveal in Finder"
        case .copyToClipboard: return "Copy to Clipboard"
        case .sendEmail: return "Send Email"
        }
    }
}

// MARK: - UI and Preferences Types

enum AppTheme: String, CaseIterable, Codable {
    case system, light, dark
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum WaveformStyle: String, CaseIterable, Codable {
    case vertical, horizontal, spectrogram
    
    var displayName: String {
        switch self {
        case .vertical: return "Vertical"
        case .horizontal: return "Horizontal"
        case .spectrogram: return "Spectrogram"
        }
    }
}

enum ColorCodingScheme: String, CaseIterable, Codable {
    case confidenceLevel, mediaType, cameraAngle, none
    
    var displayName: String {
        switch self {
        case .confidenceLevel: return "Confidence Level"
        case .mediaType: return "Media Type"
        case .cameraAngle: return "Camera Angle"
        case .none: return "None"
        }
    }
}

// MARK: - Supporting Data Structures

struct GroupingCriteria: Codable {
    var byTimestamp: Bool = true
    var byLocation: Bool = false
    var byDevice: Bool = true
    var byNamingPattern: Bool = false
    var timeTolerance: TimeInterval = 300 // 5 minutes
    var namingPattern: String = ""
    
    init() {}
}