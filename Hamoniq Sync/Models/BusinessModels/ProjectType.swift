//
//  ProjectType.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation

enum ProjectType: String, CaseIterable, Codable {
    case singleCam = "single_cam"
    case multiCam = "multi_cam"
    case musicVideo = "music_video"
    case documentary = "documentary"
    case podcast = "podcast"
    case wedding = "wedding"
    case commercial = "commercial"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .singleCam: return "Single Camera"
        case .multiCam: return "Multi-Camera"
        case .musicVideo: return "Music Video"
        case .documentary: return "Documentary"
        case .podcast: return "Podcast"
        case .wedding: return "Wedding"
        case .commercial: return "Commercial"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .singleCam: return "video.fill"
        case .multiCam: return "rectangle.split.3x1.fill"
        case .musicVideo: return "music.note"
        case .documentary: return "doc.fill"
        case .podcast: return "mic.fill"
        case .wedding: return "heart.fill"
        case .commercial: return "megaphone.fill"
        case .custom: return "gear"
        }
    }
    
    var defaultSyncStrategy: SyncStrategy {
        switch self {
        case .musicVideo: return .hybrid
        case .podcast: return .auto
        case .multiCam: return .auto
        default: return .auto
        }
    }
}