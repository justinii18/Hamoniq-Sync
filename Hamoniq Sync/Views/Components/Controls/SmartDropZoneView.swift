//
//  SmartDropZoneView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct SmartDropZoneView: View {
    let configuration: DropZoneConfiguration
    let onDrop: ([URL]) -> Bool
    let onValidationChange: ((DropValidationState) -> Void)?
    
    @State private var isDropTargeted = false
    @State private var draggedFiles: [URL] = []
    @State private var validationState: DropValidationState = .none
    
    init(
        configuration: DropZoneConfiguration = DropZoneConfiguration(),
        onDrop: @escaping ([URL]) -> Bool,
        onValidationChange: ((DropValidationState) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.onDrop = onDrop
        self.onValidationChange = onValidationChange
    }
    
    var body: some View {
        VStack(spacing: 16) {
            dropIcon
            
            VStack(spacing: 8) {
                Text(configuration.title)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(textColor)
                
                Text(configuration.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if !configuration.supportedFormats.isEmpty {
                    Text("Supported formats: \(formattedSupportedTypes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if configuration.showBrowseButton {
                Button("Browse Files") {
                    browseForFiles()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            
            if !draggedFiles.isEmpty && validationState != .none {
                validationFeedback
            }
        }
        .padding(configuration.padding)
        .frame(
            minWidth: configuration.minSize.width,
            minHeight: configuration.minSize.height
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(borderColor, style: StrokeStyle(
                    lineWidth: configuration.borderWidth,
                    dash: configuration.useDashedBorder ? [8, 4] : []
                ))
                .background {
                    RoundedRectangle(cornerRadius: configuration.cornerRadius)
                        .fill(backgroundColor)
                }
        }
        .scaleEffect(isDropTargeted ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
        .animation(.easeInOut(duration: 0.2), value: validationState)
        .onDrop(of: configuration.acceptedTypes, isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onChange(of: validationState) { state in
            onValidationChange?(state)
        }
    }
    
    @ViewBuilder
    private var dropIcon: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 60, height: 60)
            
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(iconColor)
        }
    }
    
    @ViewBuilder
    private var validationFeedback: some View {
        HStack(spacing: 8) {
            Image(systemName: validationState.iconName)
                .font(.caption)
                .foregroundColor(validationState.color)
            
            Text(validationState.message(for: draggedFiles.count))
                .font(.caption)
                .foregroundColor(validationState.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(validationState.color.opacity(0.1))
        }
    }
    
    private var iconName: String {
        if isDropTargeted {
            return "plus.circle.fill"
        }
        
        switch validationState {
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        case .mixed: return "exclamationmark.triangle.fill"
        case .none: return configuration.iconName
        }
    }
    
    private var iconColor: Color {
        switch validationState {
        case .valid: return .green
        case .invalid: return .red
        case .mixed: return .orange
        case .none: return isDropTargeted ? .blue : .secondary
        }
    }
    
    private var iconBackgroundColor: Color {
        switch validationState {
        case .valid: return .green.opacity(0.1)
        case .invalid: return .red.opacity(0.1)
        case .mixed: return .orange.opacity(0.1)
        case .none: return isDropTargeted ? .blue.opacity(0.1) : .secondary.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        switch validationState {
        case .valid: return .green
        case .invalid: return .red
        case .mixed: return .orange
        case .none: return isDropTargeted ? .blue : .primary
        }
    }
    
    private var backgroundColor: Color {
        if isDropTargeted {
            return .blue.opacity(0.05)
        }
        
        switch validationState {
        case .valid: return .green.opacity(0.03)
        case .invalid: return .red.opacity(0.03)
        case .mixed: return .orange.opacity(0.03)
        case .none: return configuration.backgroundColor
        }
    }
    
    private var borderColor: Color {
        if isDropTargeted {
            return .blue
        }
        
        switch validationState {
        case .valid: return .green
        case .invalid: return .red
        case .mixed: return .orange
        case .none: return configuration.borderColor
        }
    }
    
    private var formattedSupportedTypes: String {
        configuration.supportedFormats.joined(separator: ", ")
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                defer { group.leave() }
                
                if let url = url, error == nil {
                    urls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            self.draggedFiles = urls
            self.validationState = validateFiles(urls)
            
            if validationState == .valid || (validationState == .mixed && configuration.allowMixedTypes) {
                let validFiles = filterValidFiles(urls)
                _ = onDrop(validFiles)
            }
            
            // Clear validation state after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.validationState = .none
                self.draggedFiles = []
            }
        }
        
        return true
    }
    
    private func validateFiles(_ urls: [URL]) -> DropValidationState {
        let validFiles = filterValidFiles(urls)
        
        if validFiles.count == urls.count && !urls.isEmpty {
            return .valid
        } else if validFiles.isEmpty {
            return .invalid
        } else {
            return .mixed
        }
    }
    
    private func filterValidFiles(_ urls: [URL]) -> [URL] {
        urls.filter { url in
            let fileExtension = url.pathExtension.lowercased()
            return configuration.supportedFormats.contains(fileExtension) ||
                   configuration.acceptedTypes.contains { type in
                       if let utType = UTType(filenameExtension: fileExtension) {
                           return utType.conforms(to: type)
                       }
                       return false
                   }
        }
    }
    
    private func browseForFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = configuration.allowsMultipleFiles
        panel.canChooseDirectories = configuration.allowsDirectories
        panel.canChooseFiles = true
        panel.allowedContentTypes = configuration.acceptedTypes
        
        if panel.runModal() == .OK {
            _ = onDrop(panel.urls)
        }
    }
}

struct DropZoneConfiguration {
    let title: String
    let subtitle: String
    let iconName: String
    let minSize: CGSize
    let padding: EdgeInsets
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let useDashedBorder: Bool
    let backgroundColor: Color
    let borderColor: Color
    let acceptedTypes: [UTType]
    let supportedFormats: [String]
    let allowsMultipleFiles: Bool
    let allowsDirectories: Bool
    let allowMixedTypes: Bool
    let showBrowseButton: Bool
    
    init(
        title: String = "Drop files here",
        subtitle: String = "Or click to browse",
        iconName: String = "square.and.arrow.down",
        minSize: CGSize = CGSize(width: 300, height: 200),
        padding: EdgeInsets = EdgeInsets(top: 40, leading: 40, bottom: 40, trailing: 40),
        cornerRadius: CGFloat = 12,
        borderWidth: CGFloat = 2,
        useDashedBorder: Bool = true,
        backgroundColor: Color = Color(.windowBackgroundColor),
        borderColor: Color = Color(.separatorColor),
        acceptedTypes: [UTType] = [.audio, .movie],
        supportedFormats: [String] = ["wav", "aiff", "mp3", "m4a", "mov", "mp4", "avi"],
        allowsMultipleFiles: Bool = true,
        allowsDirectories: Bool = false,
        allowMixedTypes: Bool = true,
        showBrowseButton: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.minSize = minSize
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.useDashedBorder = useDashedBorder
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.acceptedTypes = acceptedTypes
        self.supportedFormats = supportedFormats
        self.allowsMultipleFiles = allowsMultipleFiles
        self.allowsDirectories = allowsDirectories
        self.allowMixedTypes = allowMixedTypes
        self.showBrowseButton = showBrowseButton
    }
}

enum DropValidationState {
    case none
    case valid
    case invalid
    case mixed
    
    var iconName: String {
        switch self {
        case .none: return ""
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "xmark.circle.fill"
        case .mixed: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .none: return .secondary
        case .valid: return .green
        case .invalid: return .red
        case .mixed: return .orange
        }
    }
    
    func message(for fileCount: Int) -> String {
        switch self {
        case .none: return ""
        case .valid: return "\(fileCount) valid file\(fileCount == 1 ? "" : "s")"
        case .invalid: return "No supported files found"
        case .mixed: return "Some files are not supported"
        }
    }
}

// MARK: - Specialized Drop Zones

struct AudioDropZoneView: View {
    let onDrop: ([URL]) -> Bool
    
    var body: some View {
        SmartDropZoneView(
            configuration: DropZoneConfiguration(
                title: "Drop Audio Files",
                subtitle: "Supports WAV, AIFF, MP3, and M4A formats",
                iconName: "waveform",
                acceptedTypes: [.audio],
                supportedFormats: ["wav", "aiff", "mp3", "m4a", "flac"],
                allowsDirectories: false
            ),
            onDrop: onDrop
        )
    }
}

struct VideoDropZoneView: View {
    let onDrop: ([URL]) -> Bool
    
    var body: some View {
        SmartDropZoneView(
            configuration: DropZoneConfiguration(
                title: "Drop Video Files",
                subtitle: "Supports MOV, MP4, and AVI formats",
                iconName: "video",
                acceptedTypes: [.movie],
                supportedFormats: ["mov", "mp4", "avi", "mkv"],
                allowsDirectories: false
            ),
            onDrop: onDrop
        )
    }
}

struct ProjectDropZoneView: View {
    let onDrop: ([URL]) -> Bool
    
    var body: some View {
        SmartDropZoneView(
            configuration: DropZoneConfiguration(
                title: "Import Project",
                subtitle: "Drop project files or media folders",
                iconName: "folder.badge.plus",
                acceptedTypes: [.audio, .movie, .folder],
                supportedFormats: ["wav", "aiff", "mp3", "m4a", "mov", "mp4", "avi"],
                allowsDirectories: true,
                allowMixedTypes: true
            ),
            onDrop: onDrop
        )
    }
}

#Preview {
    VStack(spacing: 30) {
        SmartDropZoneView(
            configuration: DropZoneConfiguration(
                title: "Drop Media Files",
                subtitle: "Audio and video files for synchronization"
            )
        ) { urls in
            print("Dropped files: \(urls)")
            return true
        }
        .frame(height: 200)
        
        HStack(spacing: 20) {
            AudioDropZoneView { urls in
                print("Audio files: \(urls)")
                return true
            }
            .frame(width: 250, height: 150)
            
            VideoDropZoneView { urls in
                print("Video files: \(urls)")
                return true
            }
            .frame(width: 250, height: 150)
        }
    }
    .padding()
}