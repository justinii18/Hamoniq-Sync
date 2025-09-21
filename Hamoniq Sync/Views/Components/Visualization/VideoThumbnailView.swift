//
//  VideoThumbnailView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI
import AVFoundation

struct VideoThumbnailView: View {
    let videoURL: URL?
    let configuration: ThumbnailConfiguration
    let onThumbnailTapped: (() -> Void)?
    
    @State private var thumbnailImage: NSImage?
    @State private var isLoading = false
    @State private var loadingError: Error?
    
    init(
        videoURL: URL?,
        configuration: ThumbnailConfiguration = ThumbnailConfiguration(),
        onThumbnailTapped: (() -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.configuration = configuration
        self.onThumbnailTapped = onThumbnailTapped
    }
    
    var body: some View {
        ZStack {
            thumbnailContent
            
            if configuration.showPlayButton {
                playButtonOverlay
            }
            
            if configuration.showDuration || configuration.showResolution {
                infoOverlay
            }
        }
        .frame(width: configuration.size.width, height: configuration.size.height)
        .background(configuration.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .overlay {
            if configuration.showBorder {
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .stroke(configuration.borderColor, lineWidth: configuration.borderWidth)
            }
        }
        .shadow(
            color: configuration.shadowColor,
            radius: configuration.shadowRadius,
            x: configuration.shadowOffset.width,
            y: configuration.shadowOffset.height
        )
        .onTapGesture {
            onThumbnailTapped?()
        }
        .task {
            if let videoURL = videoURL {
                await loadThumbnail(from: videoURL)
            }
        }
    }
    
    @ViewBuilder
    private var thumbnailContent: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let image = thumbnailImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: configuration.contentMode)
                .clipped()
        } else if loadingError != nil {
            errorPlaceholder
        } else {
            defaultPlaceholder
        }
    }
    
    @ViewBuilder
    private var defaultPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "video")
                .font(.system(size: configuration.size.width * 0.3))
                .foregroundColor(configuration.placeholderColor)
            
            if configuration.showPlaceholderText {
                Text("No Preview")
                    .font(.caption)
                    .foregroundColor(configuration.placeholderColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var errorPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.video")
                .font(.system(size: configuration.size.width * 0.25))
                .foregroundColor(.red)
            
            if configuration.showPlaceholderText {
                Text("Failed to Load")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var playButtonOverlay: some View {
        Button {
            onThumbnailTapped?()
        } label: {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "play.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .offset(x: 2) // Slight offset to center the play icon
            }
        }
        .buttonStyle(.plain)
        .opacity(thumbnailImage != nil ? 1 : 0)
    }
    
    @ViewBuilder
    private var infoOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                if configuration.showDuration {
                    Text(formatDuration(configuration.duration))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                }
                
                Spacer()
                
                if configuration.showResolution, let resolution = configuration.resolution {
                    Text(resolution)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(8)
        }
        .opacity(thumbnailImage != nil ? 1 : 0)
    }
    
    private func loadThumbnail(from url: URL) async {
        isLoading = true
        loadingError = nil
        
        do {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(
                width: configuration.size.width * 2,
                height: configuration.size.height * 2
            )
            
            let time = CMTime(seconds: configuration.thumbnailTime, preferredTimescale: 600)
            let cgImage = try await imageGenerator.image(at: time).image
            
            await MainActor.run {
                thumbnailImage = NSImage(cgImage: cgImage, size: NSSize(
                    width: cgImage.width,
                    height: cgImage.height
                ))
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadingError = error
                isLoading = false
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct ThumbnailConfiguration {
    let size: CGSize
    let cornerRadius: CGFloat
    let backgroundColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let showBorder: Bool
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let contentMode: ContentMode
    let thumbnailTime: TimeInterval
    let duration: TimeInterval
    let resolution: String?
    let showPlayButton: Bool
    let showDuration: Bool
    let showResolution: Bool
    let showPlaceholderText: Bool
    let placeholderColor: Color
    
    init(
        size: CGSize = CGSize(width: 160, height: 90),
        cornerRadius: CGFloat = 8,
        backgroundColor: Color = Color(.controlBackgroundColor),
        borderColor: Color = Color(.separatorColor),
        borderWidth: CGFloat = 1,
        showBorder: Bool = true,
        shadowColor: Color = .black.opacity(0.1),
        shadowRadius: CGFloat = 4,
        shadowOffset: CGSize = CGSize(width: 0, height: 2),
        contentMode: ContentMode = .fill,
        thumbnailTime: TimeInterval = 1.0,
        duration: TimeInterval = 0,
        resolution: String? = nil,
        showPlayButton: Bool = true,
        showDuration: Bool = true,
        showResolution: Bool = false,
        showPlaceholderText: Bool = true,
        placeholderColor: Color = .secondary
    ) {
        self.size = size
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.showBorder = showBorder
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.contentMode = contentMode
        self.thumbnailTime = thumbnailTime
        self.duration = duration
        self.resolution = resolution
        self.showPlayButton = showPlayButton
        self.showDuration = showDuration
        self.showResolution = showResolution
        self.showPlaceholderText = showPlaceholderText
        self.placeholderColor = placeholderColor
    }
}

// MARK: - Thumbnail Grid

struct ThumbnailGridView: View {
    let videoURLs: [URL]
    let configuration: ThumbnailConfiguration
    let columns: Int
    let spacing: CGFloat
    let onThumbnailTapped: ((URL) -> Void)?
    
    init(
        videoURLs: [URL],
        configuration: ThumbnailConfiguration = ThumbnailConfiguration(),
        columns: Int = 3,
        spacing: CGFloat = 12,
        onThumbnailTapped: ((URL) -> Void)? = nil
    ) {
        self.videoURLs = videoURLs
        self.configuration = configuration
        self.columns = columns
        self.spacing = spacing
        self.onThumbnailTapped = onThumbnailTapped
    }
    
    var body: some View {
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
        
        LazyVGrid(columns: gridItems, spacing: spacing) {
            ForEach(videoURLs.indices, id: \.self) { index in
                VideoThumbnailView(
                    videoURL: videoURLs[index],
                    configuration: configuration
                ) {
                    onThumbnailTapped?(videoURLs[index])
                }
            }
        }
    }
}

// MARK: - Timeline Thumbnail Strip

struct TimelineThumbnailStrip: View {
    let videoURL: URL
    let duration: TimeInterval
    let thumbnailCount: Int
    let configuration: ThumbnailConfiguration
    let onTimeSelected: ((TimeInterval) -> Void)?
    
    @State private var thumbnails: [TimelineThumbnail] = []
    @State private var isLoading = false
    
    init(
        videoURL: URL,
        duration: TimeInterval,
        thumbnailCount: Int = 10,
        configuration: ThumbnailConfiguration = ThumbnailConfiguration(),
        onTimeSelected: ((TimeInterval) -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.duration = duration
        self.thumbnailCount = thumbnailCount
        self.configuration = configuration
        self.onTimeSelected = onTimeSelected
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(thumbnails, id: \.time) { thumbnail in
                    VStack(spacing: 4) {
                        Group {
                            if let image = thumbnail.image {
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle()
                                    .fill(configuration.backgroundColor)
                                    .overlay {
                                        if isLoading {
                                            ProgressView()
                                                .scaleEffect(0.5)
                                        } else {
                                            Image(systemName: "video")
                                                .foregroundColor(configuration.placeholderColor)
                                        }
                                    }
                            }
                        }
                        .frame(width: 80, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .onTapGesture {
                            onTimeSelected?(thumbnail.time)
                        }
                        
                        Text(formatTime(thumbnail.time))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal)
        }
        .task {
            await loadTimelineThumbnails()
        }
    }
    
    private func loadTimelineThumbnails() async {
        isLoading = true
        
        let timeInterval = duration / Double(thumbnailCount)
        var newThumbnails: [TimelineThumbnail] = []
        
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 160, height: 90)
        
        for i in 0..<thumbnailCount {
            let time = Double(i) * timeInterval
            newThumbnails.append(TimelineThumbnail(time: time, image: nil))
        }
        
        await MainActor.run {
            thumbnails = newThumbnails
        }
        
        // Load thumbnails asynchronously
        await withTaskGroup(of: (Int, NSImage?).self) { group in
            for (index, thumbnail) in newThumbnails.enumerated() {
                group.addTask {
                    let cmTime = CMTime(seconds: thumbnail.time, preferredTimescale: 600)
                    do {
                        let cgImage = try await imageGenerator.image(at: cmTime).image
                        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                        return (index, nsImage)
                    } catch {
                        return (index, nil)
                    }
                }
            }
            
            for await (index, image) in group {
                await MainActor.run {
                    if index < thumbnails.count {
                        thumbnails[index].image = image
                    }
                }
            }
        }
        
        isLoading = false
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TimelineThumbnail {
    let time: TimeInterval
    var image: NSImage?
}

// MARK: - Scrubbing Thumbnail View

struct ScrubbingThumbnailView: View {
    let videoURL: URL
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    let configuration: ThumbnailConfiguration
    
    @State private var thumbnailImage: NSImage?
    @State private var isLoading = false
    @State private var lastLoadedTime: TimeInterval = -1
    
    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: configuration.contentMode)
            } else {
                Rectangle()
                    .fill(configuration.backgroundColor)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "video")
                                .font(.system(size: 24))
                                .foregroundColor(configuration.placeholderColor)
                        }
                    }
            }
            
            VStack {
                Spacer()
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    
                    Spacer()
                }
                .padding(8)
            }
        }
        .frame(width: configuration.size.width, height: configuration.size.height)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(configuration.borderColor, lineWidth: configuration.borderWidth)
        }
        .onChange(of: currentTime) { newTime in
            Task {
                await loadThumbnailForTime(newTime)
            }
        }
    }
    
    private func loadThumbnailForTime(_ time: TimeInterval) async {
        // Throttle thumbnail loading to avoid excessive requests
        let roundedTime = round(time * 10) / 10 // Round to nearest 0.1 second
        guard roundedTime != lastLoadedTime else { return }
        
        lastLoadedTime = roundedTime
        isLoading = true
        
        do {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 320, height: 180)
            
            let cmTime = CMTime(seconds: roundedTime, preferredTimescale: 600)
            let cgImage = try await imageGenerator.image(at: cmTime).image
            
            await MainActor.run {
                if roundedTime == lastLoadedTime { // Ensure this is still the current time
                    thumbnailImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            VideoThumbnailView(
                videoURL: nil,
                configuration: ThumbnailConfiguration(
                    duration: 125.5,
                    showPlayButton: true,
                    showDuration: true
                )
            )
            
            VideoThumbnailView(
                videoURL: nil,
                configuration: ThumbnailConfiguration(
                    size: CGSize(width: 120, height: 68),
                    duration: 62.3,
                    resolution: "1920x1080",
                    showResolution: true
                )
            )
        }
        
        ThumbnailGridView(
            videoURLs: Array(repeating: URL(fileURLWithPath: "/tmp/sample.mov"), count: 6),
            configuration: ThumbnailConfiguration(
                size: CGSize(width: 100, height: 56),
                showPlayButton: false,
                showDuration: false
            ),
            columns: 3
        )
        
        ScrubbingThumbnailView(
            videoURL: URL(fileURLWithPath: "/tmp/sample.mov"),
            currentTime: .constant(45.7),
            duration: 120,
            configuration: ThumbnailConfiguration(size: CGSize(width: 200, height: 112))
        )
    }
    .padding()
}