//
//  AsyncSyncTestView.swift
//  HarmoniqSyncKit
//
//  SwiftUI test views for async sync functionality
//

import SwiftUI
import AVFoundation
import AppKit

// MARK: - Async Sync Demo View

public struct AsyncSyncDemoView: View {
    @StateObject private var viewModel = AsyncSyncDemoViewModel()
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Progress Section
                if viewModel.isProcessing {
                    progressSection
                }
                
                // Controls Section
                controlsSection
                
                // Results Section  
                if !viewModel.results.isEmpty {
                    resultsSection
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Async Sync Demo")
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("HarmoniqSyncKit Demo")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Test async audio synchronization with progress reporting")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.progress.percentage))%")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: viewModel.progress.percentage, total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(y: 2.0)
            }
            
            // Stage Information
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    stageBadge(viewModel.progress.stage)
                    
                    Spacer()
                    
                    if let timeRemaining = viewModel.progress.estimatedTimeRemaining {
                        Text("\(Int(timeRemaining))s remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(viewModel.progress.currentOperation)
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            // Single Alignment
            HStack {
                Button("Quick Align") {
                    Task {
                        await viewModel.performQuickAlign()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
                
                Button("Precise Align") {
                    Task {
                        await viewModel.performPreciseAlign()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isProcessing)
            }
            
            // Batch Alignment
            Button("Batch Align (3 files)") {
                Task {
                    await viewModel.performBatchAlign()
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isProcessing)
            
            // Cancellation
            if viewModel.isProcessing {
                Button("Cancel Operation") {
                    viewModel.cancelOperation()
                }
                .buttonStyle(.borderedProminent)
                .foregroundColor(.red)
            }
            
            // Clear Results
            if !viewModel.results.isEmpty && !viewModel.isProcessing {
                Button("Clear Results") {
                    viewModel.clearResults()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.headline)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.offset) { index, result in
                        resultCard(result, index: index)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }
    
    private func resultCard(_ result: AlignmentResult, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Result \(index + 1)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                qualityBadge(result.quality)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offset: \(result.offsetTimecode)")
                        .font(.caption)
                        .monospaced()
                    
                    Text("Confidence: \(result.confidencePercentage)")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Method: \(result.method)")
                        .font(.caption)
                    
                    Text("SNR: \(String(format: "%.1f dB", result.snrEstimate))")
                        .font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func stageBadge(_ stage: SyncProgress.Stage) -> some View {
        Text(stage.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stageColor(stage))
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private func qualityBadge(_ quality: AlignmentQuality) -> some View {
        Text(quality.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(qualityColor(quality)))
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private func stageColor(_ stage: SyncProgress.Stage) -> Color {
        switch stage {
        case .loading: return .blue
        case .preprocessing: return .orange
        case .analyzing: return .purple
        case .correlating: return .green
        case .finalizing: return .indigo
        }
    }
    
    private func qualityColor(_ quality: AlignmentQuality) -> String {
        switch quality {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"  
        case .poor: return "red"
        }
    }
}

// MARK: - Demo View Model

@MainActor
class AsyncSyncDemoViewModel: ObservableObject {
    @Published var progress = SyncProgress(
        stage: .loading,
        percentage: 0.0,
        currentOperation: "Ready"
    )
    
    @Published var isProcessing = false
    @Published var results: [AlignmentResult] = []
    
    private let syncEngine = AsyncSyncEngine()
    private var currentTask: Task<Void, Error>?
    
    // MARK: - Operations
    
    func performQuickAlign() async {
        await performOperation(type: .quickAlign)
    }
    
    func performPreciseAlign() async {
        await performOperation(type: .preciseAlign)
    }
    
    func performBatchAlign() async {
        await performOperation(type: .batchAlign)
    }
    
    func cancelOperation() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        
        Task {
            await syncEngine.cancel()
        }
        
        progress = SyncProgress(
            stage: .loading,
            percentage: 0.0,
            currentOperation: "Operation cancelled"
        )
    }
    
    func clearResults() {
        results.removeAll()
    }
    
    // MARK: - Private Implementation
    
    private enum OperationType {
        case quickAlign
        case preciseAlign
        case batchAlign
    }
    
    private func performOperation(type: OperationType) async {
        guard !isProcessing else { return }
        
        isProcessing = true
        progress = SyncProgress(stage: .loading, percentage: 0.0, currentOperation: "Starting...")
        
        currentTask = Task {
            do {
                let mockReference = createMockAudioData(duration: 10.0, label: "reference")
                
                switch type {
                case .quickAlign:
                    let mockTarget = createMockAudioData(duration: 10.0, label: "target")
                    let result = try await syncEngine.quickAlign(
                        reference: mockReference,
                        target: mockTarget,
                        progressHandler: { [weak self] progress in
                            Task { @MainActor [weak self] in
                                self?.progress = progress
                            }
                        }
                    )
                    results.append(result)
                    
                case .preciseAlign:
                    let mockTarget = createMockAudioData(duration: 10.0, label: "target")
                    let result = try await syncEngine.preciseAlign(
                        reference: mockReference,
                        target: mockTarget,
                        progressHandler: { [weak self] progress in
                            Task { @MainActor [weak self] in
                                self?.progress = progress
                            }
                        }
                    )
                    results.append(result)
                    
                case .batchAlign:
                    let mockTargets = [
                        createMockAudioData(duration: 8.0, label: "target1"),
                        createMockAudioData(duration: 12.0, label: "target2"),
                        createMockAudioData(duration: 10.0, label: "target3")
                    ]
                    
                    let batchResult = try await syncEngine.alignBatch(
                        reference: mockReference,
                        targets: mockTargets,
                        progressHandler: { [weak self] progress in
                            Task { @MainActor [weak self] in
                                self?.progress = progress
                            }
                        }
                    )
                    
                    results.append(contentsOf: batchResult.results)
                }
                
            } catch {
                if error is CancellationError {
                    progress = SyncProgress(
                        stage: .loading,
                        percentage: 0.0,
                        currentOperation: "Cancelled"
                    )
                } else {
                    progress = SyncProgress(
                        stage: .loading,
                        percentage: 0.0,
                        currentOperation: "Error: \(error.localizedDescription)"
                    )
                }
            }
            
            isProcessing = false
        }
        
        do {
            try await currentTask?.value
        } catch {
            // Error handling is done above
        }
        
        currentTask = nil
    }
    
    private func createMockAudioData(duration: TimeInterval, label: String) -> AudioDecoder.AudioData {
        let sampleRate = 44100.0
        let sampleCount = Int(duration * sampleRate)
        
        // Generate simple sine wave for testing
        var samples: [Float] = []
        let frequency: Float = 440.0 // A4 note
        
        for i in 0..<sampleCount {
            let time = Float(i) / Float(sampleRate)
            let sample = sin(2.0 * Float.pi * frequency * time) * 0.5
            samples.append(sample)
        }
        
        return AudioDecoder.AudioData(
            samples: samples,
            sampleRate: sampleRate,
            duration: duration,
            channels: 1
        )
    }
}

// MARK: - Preview

#if DEBUG
struct AsyncSyncDemoView_Previews: PreviewProvider {
    static var previews: some View {
        AsyncSyncDemoView()
    }
}
#endif