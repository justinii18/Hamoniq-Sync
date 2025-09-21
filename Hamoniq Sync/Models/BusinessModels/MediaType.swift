//
//  MediaType.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation

enum MediaType: String, CaseIterable, Codable {
    case video = "video"
    case audio = "audio"
    case mixed = "mixed"
    
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .audio: return "Audio"
        case .mixed: return "Mixed"
        }
    }
    
    var supportedExtensions: [String] {
        switch self {
        case .video:
            return ["mp4", "mov", "avi", "mkv", "mts", "m2ts", "mxf", "r3d", "braw"]
        case .audio:
            return ["wav", "aiff", "aif", "mp3", "aac", "m4a", "flac", "ogg"]
        case .mixed:
            return ["mp4", "mov", "avi", "mkv", "mts", "m2ts", "mxf"]
        }
    }
    
    var icon: String {
        switch self {
        case .video: return "video.fill"
        case .audio: return "waveform"
        case .mixed: return "av.remote.fill"
        }
    }
    
    static func detectType(from url: URL) -> MediaType {
        let pathExtension = url.pathExtension.lowercased()
        
        if MediaType.video.supportedExtensions.contains(pathExtension) {
            return .video
        } else if MediaType.audio.supportedExtensions.contains(pathExtension) {
            return .audio
        } else if MediaType.mixed.supportedExtensions.contains(pathExtension) {
            return .mixed
        }
        
        return .mixed // Default fallback
    }
}
