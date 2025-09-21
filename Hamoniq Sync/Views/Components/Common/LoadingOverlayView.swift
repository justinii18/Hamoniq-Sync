//
//  LoadingOverlayView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct LoadingOverlayView: View {
    let message: String
    let progress: Float?
    let showProgress: Bool
    let style: LoadingStyle
    
    init(
        message: String = "Loading...",
        progress: Float? = nil,
        showProgress: Bool = false,
        style: LoadingStyle = .overlay
    ) {
        self.message = message
        self.progress = progress
        self.showProgress = showProgress
        self.style = style
    }
    
    var body: some View {
        ZStack {
            if style == .overlay {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 16) {
                loadingIndicator
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if showProgress, let progress = progress {
                    VStack(spacing: 8) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 200)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(style == .overlay ? 1.0 : 0.8)
        }
    }
    
    @ViewBuilder
    private var loadingIndicator: some View {
        switch style {
        case .overlay, .inline:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
        case .minimal:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
        case .waveform:
            WaveformLoadingView()
        }
    }
}

struct WaveformLoadingView: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(.blue)
                    .frame(width: 4)
                    .frame(height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.1),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = 1
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 24
        let animationPhase = (animationOffset + Double(index) * 0.2).truncatingRemainder(dividingBy: 1.0)
        let height = baseHeight + (maxHeight - baseHeight) * sin(animationPhase * .pi)
        return height
    }
}

enum LoadingStyle {
    case overlay    // Full screen overlay with background
    case inline     // Inline loading without background
    case minimal    // Small, minimal loading indicator
    case waveform   // Audio-themed waveform animation
}

// MARK: - View Modifier

struct LoadingModifier: ViewModifier {
    let isLoading: Bool
    let message: String
    let progress: Float?
    let showProgress: Bool
    let style: LoadingStyle
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading && style == .overlay)
                .blur(radius: isLoading && style == .overlay ? 1 : 0)
            
            if isLoading {
                LoadingOverlayView(
                    message: message,
                    progress: progress,
                    showProgress: showProgress,
                    style: style
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(.easeInOut(duration: 0.3), value: isLoading)
            }
        }
    }
}

extension View {
    func loading(
        _ isLoading: Bool,
        message: String = "Loading...",
        progress: Float? = nil,
        showProgress: Bool = false,
        style: LoadingStyle = .overlay
    ) -> some View {
        modifier(LoadingModifier(
            isLoading: isLoading,
            message: message,
            progress: progress,
            showProgress: showProgress,
            style: style
        ))
    }
}

#Preview {
    VStack(spacing: 30) {
        Text("Content behind loading overlay")
            .font(.title)
        
        Button("Start Loading") {}
        
        HStack(spacing: 20) {
            LoadingOverlayView(style: .inline)
            LoadingOverlayView(style: .minimal)
            LoadingOverlayView(style: .waveform)
        }
        
        LoadingOverlayView(
            message: "Processing audio files...",
            progress: 0.65,
            showProgress: true,
            style: .inline
        )
    }
    .padding()
    .loading(true, message: "Loading application...", style: .overlay)
}