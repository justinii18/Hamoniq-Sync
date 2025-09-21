//
//  MediaGroup.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import SwiftData

@Model
final class MediaGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var groupType: MediaGroupType
    var colorCode: String
    var sortOrder: Int
    var isLocked: Bool
    var isExpanded: Bool
    
    // Group metadata
    var groupDescription: String
    var cameraAngle: Int?
    var recordingDevice: String?
    var createdAt: Date
    
    // Auto-grouping criteria
    var autoGroupingEnabled: Bool
    var groupingCriteria: GroupingCriteria
    
    // Relationships
    @Relationship var clips: [Clip]
    @Relationship(inverse: \Project.mediaGroups) var project: Project?
    
    init(name: String, type: MediaGroupType, color: String) {
        self.id = UUID()
        self.name = name
        self.groupType = type
        self.colorCode = color
        self.sortOrder = 0
        self.isLocked = false
        self.isExpanded = true
        self.groupDescription = ""
        self.createdAt = Date()
        self.autoGroupingEnabled = true
        self.groupingCriteria = GroupingCriteria()
        self.clips = []
    }
    
    // MARK: - Computed Properties
    
    var displayName: String {
        return name.isEmpty ? "Untitled Group" : name
    }
    
    var clipCount: Int {
        return clips.count
    }
    
    var totalDuration: TimeInterval {
        return clips.compactMap(\.durationSeconds).reduce(0, +)
    }
    
    var isEmpty: Bool {
        return clips.isEmpty
    }
    
    var hasVideoClips: Bool {
        return clips.contains { $0.isVideoFile }
    }
    
    var hasAudioClips: Bool {
        return clips.contains { $0.isAudioFile }
    }
    
    var audioClips: [Clip] {
        return clips.filter { $0.isAudioFile }
    }
    
    var videoClips: [Clip] {
        return clips.filter { $0.isVideoFile }
    }
    
    var referenceClip: Clip? {
        // Return the longest clip as reference, or first clip if durations are unknown
        return clips.max { (clip1, clip2) in
            let duration1 = clip1.durationSeconds ?? 0
            let duration2 = clip2.durationSeconds ?? 0
            return duration1 < duration2
        }
    }
    
    var canBeReference: Bool {
        return !isEmpty && (hasAudioClips || hasVideoClips)
    }
    
    var averageFileSize: Int64 {
        guard !clips.isEmpty else { return 0 }
        let totalSize = clips.reduce(0) { $0 + $1.fileSize }
        return totalSize / Int64(clips.count)
    }
    
    // MARK: - Methods
    
    func addClip(_ clip: Clip) {
        clips.append(clip)
        clip.mediaGroup = self
        
        // Update sort order based on creation time or filename
        sortClips()
    }
    
    func removeClip(_ clip: Clip) {
        clips.removeAll { $0.id == clip.id }
        clip.mediaGroup = nil
    }
    
    func sortClips() {
        clips.sort { clip1, clip2 in
            // Sort by recording date if available, otherwise by filename
            if let date1 = clip1.recordingDate,
               let date2 = clip2.recordingDate {
                return date1 < date2
            }
            return clip1.filename.localizedCompare(clip2.filename) == .orderedAscending
        }
    }
    
    func updateSortOrder(_ newOrder: Int) {
        sortOrder = newOrder
    }
    
    func lock() {
        isLocked = true
    }
    
    func unlock() {
        isLocked = false
    }
    
    func expand() {
        isExpanded = true
    }
    
    func collapse() {
        isExpanded = false
    }
    
    func toggleExpansion() {
        isExpanded.toggle()
    }
    
    func setColor(_ colorCode: String) {
        self.colorCode = colorCode
    }
    
    func updateGroupingCriteria(_ criteria: GroupingCriteria) {
        self.groupingCriteria = criteria
    }
    
    func validateClips() -> [Clip] {
        // Return clips that don't match the grouping criteria
        // This is a placeholder for more sophisticated validation logic
        return clips.filter { clip in
            // Example validation: check if clip matches the group's media type
            switch groupType {
            case .camera:
                return !clip.isVideoFile
            case .audio:
                return !clip.isAudioFile
            case .mixed, .reference, .bRoll, .timelapses:
                return false // These groups can contain any type
            }
        }
    }
}