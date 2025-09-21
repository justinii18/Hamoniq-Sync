//
//  LoadingStateView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct LoadingStateView: View {
    let state: LoadingState
    let configuration: LoadingStateConfiguration
    let onRetry: (() -> Void)?
    let onCancel: (() -> Void)?
    
    init(
        state: LoadingState,
        configuration: LoadingStateConfiguration = LoadingStateConfiguration(),
        onRetry: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.state = state
        self.configuration = configuration
        self.onRetry = onRetry
        self.onCancel = onCancel
    }
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                idleView
            case .loading(let message, let progress):
                loadingView(message: message, progress: progress)
            case .success(let message, let data):
                successView(message: message, data: data)
            case .failure(let error, let canRetry):
                failureView(error: error, canRetry: canRetry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(configuration.backgroundColor)
        .animation(.easeInOut(duration: 0.3), value: state.id)
    }
    
    @ViewBuilder
    private var idleView: some View {
        if configuration.showIdleState {
            VStack(spacing: 16) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                
                Text("Ready")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private func loadingView(message: String?, progress: Double?) -> some View {
        VStack(spacing: 20) {
            loadingIndicator(progress: progress)
            
            VStack(spacing: 8) {
                Text(message ?? "Loading...")
                    .font(configuration.messageFont)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if let progress = progress {
                    progressDetails(progress: progress)
                }
            }
            
            if onCancel != nil {
                Button("Cancel") {
                    onCancel?()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(configuration.contentPadding)
    }
    
    @ViewBuilder
    private func loadingIndicator(progress: Double?) -> some View {
        ZStack {
            if let progress = progress {
                CircularProgressView(
                    progress: progress,
                    configuration: CircularProgressConfiguration(
                        size: configuration.progressSize,
                        lineWidth: configuration.progressLineWidth,
                        primaryColor: configuration.progressColor,
                        backgroundColor: configuration.progressBackgroundColor
                    )
                )
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(configuration.progressSize / 40)
            }
        }
    }
    
    @ViewBuilder
    private func progressDetails(progress: Double) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundColor(.primary)
            
            if configuration.showProgressBar {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 120)
            }
        }
    }
    
    @ViewBuilder
    private func successView(message: String?, data: Any?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: configuration.iconSize))
                .foregroundColor(.green)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: state.id)
            
            Text(message ?? "Success")
                .font(configuration.messageFont)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            if configuration.autoHideSuccess {
                // Auto-hide after delay (handled by parent view)
                EmptyView()
            }
        }
        .padding(configuration.contentPadding)
    }
    
    @ViewBuilder
    private func failureView(error: Error, canRetry: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: configuration.iconSize))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Error Occurred")
                    .font(configuration.messageFont)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(error.localizedDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(spacing: 12) {
                if canRetry, let onRetry = onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if configuration.showErrorDetails {
                    Button("Details") {
                        // Show error details
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(configuration.contentPadding)
    }
}

enum LoadingState: Equatable {
    case idle
    case loading(message: String?, progress: Double?)
    case success(message: String?, data: Any?)
    case failure(error: Error, canRetry: Bool)
    
    var id: String {
        switch self {
        case .idle: return "idle"
        case .loading: return "loading"
        case .success: return "success"
        case .failure: return "failure"
        }
    }
    
    static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        lhs.id == rhs.id
    }
}

struct LoadingStateConfiguration {
    let showIdleState: Bool
    let showProgressBar: Bool
    let showErrorDetails: Bool
    let autoHideSuccess: Bool
    let progressSize: CGFloat
    let progressLineWidth: CGFloat
    let iconSize: CGFloat
    let progressColor: Color
    let progressBackgroundColor: Color
    let backgroundColor: Color
    let messageFont: Font
    let contentPadding: EdgeInsets
    
    init(
        showIdleState: Bool = false,
        showProgressBar: Bool = true,
        showErrorDetails: Bool = true,
        autoHideSuccess: Bool = true,
        progressSize: CGFloat = 40,
        progressLineWidth: CGFloat = 4,
        iconSize: CGFloat = 48,
        progressColor: Color = .blue,
        progressBackgroundColor: Color = Color(.separatorColor),
        backgroundColor: Color = .clear,
        messageFont: Font = .title3,
        contentPadding: EdgeInsets = EdgeInsets(top: 40, leading: 40, bottom: 40, trailing: 40)
    ) {
        self.showIdleState = showIdleState
        self.showProgressBar = showProgressBar
        self.showErrorDetails = showErrorDetails
        self.autoHideSuccess = autoHideSuccess
        self.progressSize = progressSize
        self.progressLineWidth = progressLineWidth
        self.iconSize = iconSize
        self.progressColor = progressColor
        self.progressBackgroundColor = progressBackgroundColor
        self.backgroundColor = backgroundColor
        self.messageFont = messageFont
        self.contentPadding = contentPadding
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let configuration: CircularProgressConfiguration
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(configuration.backgroundColor, lineWidth: configuration.lineWidth)
                .frame(width: configuration.size, height: configuration.size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    configuration.primaryColor,
                    style: StrokeStyle(
                        lineWidth: configuration.lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: configuration.size, height: configuration.size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: animatedProgress)
            
            if configuration.showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: configuration.size * 0.2, weight: .semibold, design: .monospaced))
                    .foregroundColor(configuration.textColor)
            }
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) {
            animatedProgress = progress
        }
    }
}

struct CircularProgressConfiguration {
    let size: CGFloat
    let lineWidth: CGFloat
    let primaryColor: Color
    let backgroundColor: Color
    let textColor: Color
    let showPercentage: Bool
    
    init(
        size: CGFloat = 60,
        lineWidth: CGFloat = 6,
        primaryColor: Color = .blue,
        backgroundColor: Color = Color(.separatorColor),
        textColor: Color = .primary,
        showPercentage: Bool = true
    ) {
        self.size = size
        self.lineWidth = lineWidth
        self.primaryColor = primaryColor
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.showPercentage = showPercentage
    }
}

// MARK: - State Machine View

struct StateMachineView<Content: View>: View {
    @State private var currentState: LoadingState = .idle
    let content: (LoadingState, @escaping (LoadingState) -> Void) -> Content
    
    init(@ViewBuilder content: @escaping (LoadingState, @escaping (LoadingState) -> Void) -> Content) {
        self.content = content
    }
    
    var body: some View {
        content(currentState) { newState in
            currentState = newState
        }
    }
}

// MARK: - Specialized Loading States

struct SyncLoadingStateView: View {
    let state: LoadingState
    let onCancel: (() -> Void)?
    
    var body: some View {
        LoadingStateView(
            state: state,
            configuration: LoadingStateConfiguration(
                progressColor: .purple,
                messageFont: .title2
            ),
            onCancel: onCancel
        )
    }
}

struct ImportLoadingStateView: View {
    let state: LoadingState
    let onCancel: (() -> Void)?
    
    var body: some View {
        LoadingStateView(
            state: state,
            configuration: LoadingStateConfiguration(
                showProgressBar: true,
                progressColor: .green
            ),
            onCancel: onCancel
        )
    }
}

struct ExportLoadingStateView: View {
    let state: LoadingState
    let onCancel: (() -> Void)?
    
    var body: some View {
        LoadingStateView(
            state: state,
            configuration: LoadingStateConfiguration(
                showProgressBar: true,
                autoHideSuccess: false,
                progressColor: .orange
            ),
            onCancel: onCancel
        )
    }
}

// MARK: - Loading State Container

struct LoadingStateContainer<Content: View>: View {
    @Binding var loadingState: LoadingState
    let content: Content
    let onRetry: (() -> Void)?
    let onCancel: (() -> Void)?
    
    init(
        loadingState: Binding<LoadingState>,
        onRetry: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._loadingState = loadingState
        self.onRetry = onRetry
        self.onCancel = onCancel
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .disabled(loadingState.id == "loading")
            
            if loadingState.id != "idle" {
                LoadingStateView(
                    state: loadingState,
                    onRetry: onRetry,
                    onCancel: onCancel
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: loadingState.id)
    }
}

#Preview {
    TabView {
        LoadingStateView(
            state: .loading(message: "Synchronizing audio files...", progress: 0.67),
            onCancel: { print("Cancelled") }
        )
        .tabItem {
            Label("Loading", systemImage: "arrow.clockwise")
        }
        
        LoadingStateView(
            state: .success(message: "Sync completed successfully!", data: nil)
        )
        .tabItem {
            Label("Success", systemImage: "checkmark")
        }
        
        LoadingStateView(
            state: .failure(
                error: NSError(domain: "SyncError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Audio analysis failed"]),
                canRetry: true
            ),
            onRetry: { print("Retry") }
        )
        .tabItem {
            Label("Error", systemImage: "exclamationmark.triangle")
        }
        
        CircularProgressView(
            progress: 0.75,
            configuration: CircularProgressConfiguration(size: 80)
        )
        .tabItem {
            Label("Progress", systemImage: "circle.dotted")
        }
    }
    .frame(height: 400)
}