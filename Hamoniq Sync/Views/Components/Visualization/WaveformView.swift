//
//  WaveformView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct WaveformView: View {
    let waveformData: WaveformData
    let configuration: WaveformConfiguration
    let onSeek: ((TimeInterval) -> Void)?
    let onSelectionChanged: ((TimeInterval, TimeInterval) -> Void)?
    
    @State private var playheadPosition: TimeInterval = 0
    @State private var selectionStart: TimeInterval?
    @State private var selectionEnd: TimeInterval?
    @State private var isDragging = false
    @State private var isSelecting = false
    @GestureState private var dragLocation: CGPoint = .zero
    
    init(
        waveformData: WaveformData,
        configuration: WaveformConfiguration = WaveformConfiguration(),
        onSeek: ((TimeInterval) -> Void)? = nil,
        onSelectionChanged: ((TimeInterval, TimeInterval) -> Void)? = nil
    ) {
        self.waveformData = waveformData
        self.configuration = configuration
        self.onSeek = onSeek
        self.onSelectionChanged = onSelectionChanged
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                waveformPath(in: geometry)
                
                if configuration.showSelection {
                    selectionOverlay(in: geometry)
                }
                
                if configuration.showPlayhead {
                    playheadView(in: geometry)
                }
                
                if configuration.showTimeMarkers {
                    timeMarkersView(in: geometry)
                }
            }
            .background(configuration.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
            .overlay {
                if configuration.showBorder {
                    RoundedRectangle(cornerRadius: configuration.cornerRadius)
                        .stroke(configuration.borderColor, lineWidth: configuration.borderWidth)
                }
            }
            .gesture(waveformGesture(in: geometry))
        }
        .frame(height: configuration.height)
    }
    
    @ViewBuilder
    private func waveformPath(in geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            drawWaveform(context: context, size: size)
        }
    }
    
    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let sampleCount = waveformData.samples.count
        guard sampleCount > 0 else { return }
        
        let sampleWidth = size.width / CGFloat(sampleCount)
        let centerY = size.height / 2
        let maxAmplitude = size.height / 2 * CGFloat(configuration.amplitudeScale)
        
        var path = Path()
        var negativePath = Path()
        
        for (index, sample) in waveformData.samples.enumerated() {
            let x = CGFloat(index) * sampleWidth
            let normalizedSample = CGFloat(sample * configuration.amplitudeScale)
            let positiveY = centerY - normalizedSample * maxAmplitude
            let negativeY = centerY + normalizedSample * maxAmplitude
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: positiveY))
                negativePath.move(to: CGPoint(x: x, y: negativeY))
            } else {
                path.addLine(to: CGPoint(x: x, y: positiveY))
                negativePath.addLine(to: CGPoint(x: x, y: negativeY))
            }
            
            // Draw sample bar if configured
            if configuration.style == .bars {
                let barPath = Path { path in
                    path.move(to: CGPoint(x: x, y: centerY))
                    path.addLine(to: CGPoint(x: x, y: positiveY))
                    path.move(to: CGPoint(x: x, y: centerY))
                    path.addLine(to: CGPoint(x: x, y: negativeY))
                }
                
                context.stroke(
                    barPath,
                    with: .color(configuration.waveformColor),
                    style: StrokeStyle(lineWidth: max(1, sampleWidth * 0.8), lineCap: .round)
                )
            }
        }
        
        if configuration.style == .filled {
            // Create filled waveform
            var combinedPath = path
            
            // Close the path by connecting to the negative path in reverse
            for (index, sample) in waveformData.samples.enumerated().reversed() {
                let x = CGFloat(index) * sampleWidth
                let normalizedSample = CGFloat(sample * configuration.amplitudeScale)
                let negativeY = centerY + normalizedSample * maxAmplitude
                combinedPath.addLine(to: CGPoint(x: x, y: negativeY))
            }
            combinedPath.closeSubpath()
            
            context.fill(combinedPath, with: .color(configuration.waveformColor.opacity(0.7)))
            context.stroke(path, with: .color(configuration.waveformColor), lineWidth: 1)
            context.stroke(negativePath, with: .color(configuration.waveformColor), lineWidth: 1)
            
        } else if configuration.style == .outline {
            context.stroke(path, with: .color(configuration.waveformColor), lineWidth: configuration.lineWidth)
            context.stroke(negativePath, with: .color(configuration.waveformColor), lineWidth: configuration.lineWidth)
        }
    }
    
    @ViewBuilder
    private func selectionOverlay(in geometry: GeometryProxy) -> some View {
        if let start = selectionStart, let end = selectionEnd {
            let startX = timeToX(start, in: geometry)
            let endX = timeToX(end, in: geometry)
            let width = abs(endX - startX)
            
            Rectangle()
                .fill(configuration.selectionColor.opacity(0.3))
                .frame(width: width)
                .position(x: min(startX, endX) + width / 2, y: geometry.size.height / 2)
                .overlay {
                    Rectangle()
                        .stroke(configuration.selectionColor, lineWidth: 1)
                        .frame(width: width)
                        .position(x: min(startX, endX) + width / 2, y: geometry.size.height / 2)
                }
        }
    }
    
    @ViewBuilder
    private func playheadView(in geometry: GeometryProxy) -> some View {
        let x = timeToX(playheadPosition, in: geometry)
        
        Rectangle()
            .fill(configuration.playheadColor)
            .frame(width: configuration.playheadWidth)
            .position(x: x, y: geometry.size.height / 2)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 0)
    }
    
    @ViewBuilder
    private func timeMarkersView(in geometry: GeometryProxy) -> some View {
        let duration = waveformData.duration
        let markerInterval = calculateMarkerInterval(for: duration)
        
        ForEach(0..<Int(duration / markerInterval) + 1, id: \.self) { index in
            let time = Double(index) * markerInterval
            let x = timeToX(time, in: geometry)
            
            VStack(spacing: 0) {
                Rectangle()
                    .fill(configuration.timeMarkerColor)
                    .frame(width: 1, height: geometry.size.height * 0.1)
                
                Spacer()
                
                Text(formatTime(time))
                    .font(.caption2)
                    .foregroundColor(configuration.timeMarkerColor)
                    .background(configuration.backgroundColor)
            }
            .position(x: x, y: geometry.size.height / 2)
        }
    }
    
    private func waveformGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragLocation) { value, state, _ in
                state = value.location
            }
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    
                    if configuration.allowsSelection && isSelecting {
                        selectionStart = xToTime(value.startLocation.x, in: geometry)
                    }
                }
                
                let currentTime = xToTime(value.location.x, in: geometry)
                
                if configuration.allowsSelection && isSelecting {
                    selectionEnd = currentTime
                } else if configuration.allowsSeeking {
                    playheadPosition = currentTime
                    onSeek?(currentTime)
                }
            }
            .onEnded { value in
                isDragging = false
                
                if configuration.allowsSelection && isSelecting {
                    isSelecting = false
                    if let start = selectionStart, let end = selectionEnd {
                        onSelectionChanged?(min(start, end), max(start, end))
                    }
                }
            }
            .exclusively(before: TapGesture().onEnded { _ in
                if configuration.allowsSelection {
                    isSelecting = true
                }
            })
    }
    
    private func timeToX(_ time: TimeInterval, in geometry: GeometryProxy) -> CGFloat {
        let progress = time / waveformData.duration
        return CGFloat(progress) * geometry.size.width
    }
    
    private func xToTime(_ x: CGFloat, in geometry: GeometryProxy) -> TimeInterval {
        let progress = Double(x / geometry.size.width)
        return progress * waveformData.duration
    }
    
    private func calculateMarkerInterval(for duration: TimeInterval) -> TimeInterval {
        if duration <= 30 { return 5 }
        else if duration <= 60 { return 10 }
        else if duration <= 300 { return 30 }
        else if duration <= 600 { return 60 }
        else { return 120 }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func updatePlayhead(to time: TimeInterval) {
        playheadPosition = time
    }
    
    func clearSelection() {
        selectionStart = nil
        selectionEnd = nil
    }
}

struct WaveformData {
    let samples: [Float]
    let duration: TimeInterval
    let sampleRate: Double
    
    init(samples: [Float], duration: TimeInterval, sampleRate: Double = 44100) {
        self.samples = samples
        self.duration = duration
        self.sampleRate = sampleRate
    }
    
    static func mock(duration: TimeInterval = 60, sampleCount: Int = 200) -> WaveformData {
        let samples = (0..<sampleCount).map { index in
            let frequency = 0.1 + Float(index) / Float(sampleCount) * 0.3
            let amplitude = sin(Float(index) * frequency) * (0.3 + 0.7 * Float.random(in: 0...1))
            return amplitude
        }
        return WaveformData(samples: samples, duration: duration)
    }
}

struct WaveformConfiguration {
    let height: CGFloat
    let waveformColor: Color
    let backgroundColor: Color
    let playheadColor: Color
    let selectionColor: Color
    let timeMarkerColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let playheadWidth: CGFloat
    let lineWidth: CGFloat
    let amplitudeScale: Float
    let style: WaveformDisplayStyle
    let showPlayhead: Bool
    let showSelection: Bool
    let showTimeMarkers: Bool
    let showBorder: Bool
    let allowsSeeking: Bool
    let allowsSelection: Bool
    
    init(
        height: CGFloat = 80,
        waveformColor: Color = .blue,
        backgroundColor: Color = Color(.controlBackgroundColor),
        playheadColor: Color = .red,
        selectionColor: Color = .yellow,
        timeMarkerColor: Color = .secondary,
        borderColor: Color = Color(.separatorColor),
        borderWidth: CGFloat = 1,
        cornerRadius: CGFloat = 4,
        playheadWidth: CGFloat = 2,
        lineWidth: CGFloat = 1.5,
        amplitudeScale: Float = 0.8,
        style: WaveformDisplayStyle = .filled,
        showPlayhead: Bool = true,
        showSelection: Bool = true,
        showTimeMarkers: Bool = true,
        showBorder: Bool = true,
        allowsSeeking: Bool = true,
        allowsSelection: Bool = true
    ) {
        self.height = height
        self.waveformColor = waveformColor
        self.backgroundColor = backgroundColor
        self.playheadColor = playheadColor
        self.selectionColor = selectionColor
        self.timeMarkerColor = timeMarkerColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.playheadWidth = playheadWidth
        self.lineWidth = lineWidth
        self.amplitudeScale = amplitudeScale
        self.style = style
        self.showPlayhead = showPlayhead
        self.showSelection = showSelection
        self.showTimeMarkers = showTimeMarkers
        self.showBorder = showBorder
        self.allowsSeeking = allowsSeeking
        self.allowsSelection = allowsSelection
    }
}

enum WaveformDisplayStyle {
    case outline
    case filled
    case bars
}

// MARK: - Multi-Channel Waveform

struct MultiChannelWaveformView: View {
    let channels: [WaveformData]
    let configuration: WaveformConfiguration
    let channelColors: [Color]
    let onSeek: ((TimeInterval) -> Void)?
    
    init(
        channels: [WaveformData],
        configuration: WaveformConfiguration = WaveformConfiguration(),
        channelColors: [Color] = [.blue, .green, .red, .orange],
        onSeek: ((TimeInterval) -> Void)? = nil
    ) {
        self.channels = channels
        self.configuration = configuration
        self.channelColors = channelColors
        self.onSeek = onSeek
    }
    
    var body: some View {
        VStack(spacing: 1) {
            ForEach(channels.indices, id: \.self) { index in
                WaveformView(
                    waveformData: channels[index],
                    configuration: WaveformConfiguration(
                        height: configuration.height / CGFloat(channels.count),
                        waveformColor: channelColors[index % channelColors.count],
                        backgroundColor: configuration.backgroundColor,
                        showTimeMarkers: index == channels.count - 1, // Only show on last channel
                        showBorder: false
                    ),
                    onSeek: onSeek
                )
            }
        }
        .background(configuration.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .stroke(configuration.borderColor, lineWidth: configuration.borderWidth)
        }
    }
}

// MARK: - Waveform Analysis View

struct WaveformAnalysisView: View {
    let primaryWaveform: WaveformData
    let secondaryWaveform: WaveformData
    let syncOffset: TimeInterval
    let confidence: Double
    
    @State private var showOffset = true
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Reference Track")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(showOffset ? "Hide Offset" : "Show Offset") {
                    showOffset.toggle()
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
            
            WaveformView(
                waveformData: primaryWaveform,
                configuration: WaveformConfiguration(
                    height: 60,
                    waveformColor: .blue,
                    showPlayhead: false,
                    showSelection: false
                )
            )
            
            HStack {
                Text("Target Track")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if showOffset {
                    Text("Offset: \(formatOffset(syncOffset))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Confidence: \(Int(confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(confidenceColor)
                }
            }
            
            WaveformView(
                waveformData: secondaryWaveform,
                configuration: WaveformConfiguration(
                    height: 60,
                    waveformColor: .green,
                    showPlayhead: false,
                    showSelection: false
                )
            )
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    private func formatOffset(_ offset: TimeInterval) -> String {
        let sign = offset >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.3f", offset))s"
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView(
            waveformData: WaveformData.mock(duration: 30),
            configuration: WaveformConfiguration(
                height: 100,
                style: .filled,
                showTimeMarkers: true
            )
        ) { time in
            print("Seek to: \(time)")
        }
        
        MultiChannelWaveformView(
            channels: [
                WaveformData.mock(duration: 30),
                WaveformData.mock(duration: 30)
            ],
            configuration: WaveformConfiguration(height: 120),
            channelColors: [.blue, .green]
        )
        
        WaveformAnalysisView(
            primaryWaveform: WaveformData.mock(duration: 30),
            secondaryWaveform: WaveformData.mock(duration: 30),
            syncOffset: -0.125,
            confidence: 0.87
        )
    }
    .padding()
}