//
//  PerformanceProfiler.swift
//  HarmoniqSyncKit
//
//  Performance profiling and validation for async operations
//

import Foundation

// MARK: - Performance Metrics

public struct PerformanceMetrics: Sendable {
    public let operationType: String
    public let totalDuration: TimeInterval
    public let stageDurations: [SyncProgress.Stage: TimeInterval]
    public let memoryUsage: MemoryUsage
    public let cpuUsage: Double?
    public let progressUpdateCount: Int
    public let averageProgressInterval: TimeInterval
    
    public struct MemoryUsage: Sendable {
        public let peakMemoryMB: Double
        public let averageMemoryMB: Double
        public let memoryGrowthMB: Double
    }
    
    public var formattedSummary: String {
        var summary = """
        Performance Metrics for \(operationType):
        Total Duration: \(String(format: "%.3f", totalDuration))s
        Memory Peak: \(String(format: "%.1f", memoryUsage.peakMemoryMB))MB
        Progress Updates: \(progressUpdateCount) (\(String(format: "%.0f", averageProgressInterval * 1000))ms avg)
        
        Stage Breakdown:
        """
        
        for stage in [SyncProgress.Stage.loading, .preprocessing, .analyzing, .correlating, .finalizing] {
            if let duration = stageDurations[stage] {
                let percentage = (duration / totalDuration) * 100
                summary += "\n  \(stage.displayName): \(String(format: "%.3f", duration))s (\(String(format: "%.1f", percentage))%)"
            }
        }
        
        return summary
    }
}

// MARK: - Performance Profiler

public class PerformanceProfiler: @unchecked Sendable {
    
    private let lock = NSLock()
    private var startTime: Date?
    private var stageStartTimes: [SyncProgress.Stage: Date] = [:]
    private var stageDurations: [SyncProgress.Stage: TimeInterval] = [:]
    private var progressUpdates: [(timestamp: Date, stage: SyncProgress.Stage)] = []
    private var memoryMeasurements: [Double] = []
    private var operationType: String = "Unknown"
    private var isActive = false
    
    // MARK: - Profiling Control
    
    public func startProfiling(operationType: String) {
        lock.lock()
        defer { lock.unlock() }
        
        self.operationType = operationType
        self.startTime = Date()
        self.isActive = true
        self.stageDurations.removeAll()
        self.progressUpdates.removeAll()
        self.memoryMeasurements.removeAll()
        
        measureMemory()
    }
    
    public func stopProfiling() -> PerformanceMetrics? {
        lock.lock()
        defer { lock.unlock() }
        
        guard isActive, let startTime = startTime else { return nil }
        
        self.isActive = false
        let totalDuration = Date().timeIntervalSince(startTime)
        
        measureMemory() // Final measurement
        
        let metrics = PerformanceMetrics(
            operationType: operationType,
            totalDuration: totalDuration,
            stageDurations: stageDurations,
            memoryUsage: calculateMemoryUsage(),
            cpuUsage: nil, // CPU monitoring not implemented in this version
            progressUpdateCount: progressUpdates.count,
            averageProgressInterval: calculateAverageProgressInterval()
        )
        
        return metrics
    }
    
    // MARK: - Event Tracking
    
    public func recordStageStart(_ stage: SyncProgress.Stage) {
        lock.lock()
        defer { lock.unlock() }
        
        guard isActive else { return }
        
        // End previous stage if any
        if let currentStage = stageStartTimes.keys.first,
           let stageStart = stageStartTimes[currentStage] {
            stageDurations[currentStage] = Date().timeIntervalSince(stageStart)
            stageStartTimes.removeValue(forKey: currentStage)
        }
        
        // Start new stage
        stageStartTimes[stage] = Date()
        measureMemory()
    }
    
    public func recordProgressUpdate(_ progress: SyncProgress) {
        lock.lock()
        defer { lock.unlock() }
        
        guard isActive else { return }
        
        progressUpdates.append((timestamp: Date(), stage: progress.stage))
        
        // Record stage change if needed
        if let lastUpdate = progressUpdates.dropLast().last,
           lastUpdate.stage != progress.stage {
            recordStageStart(progress.stage)
        }
        
        // Periodic memory measurement
        if progressUpdates.count % 10 == 0 {
            measureMemory()
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func measureMemory() {
        let memoryMB = getCurrentMemoryUsageMB()
        memoryMeasurements.append(memoryMB)
    }
    
    private func getCurrentMemoryUsageMB() -> Double {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        return Double(info.resident_size) / (1024 * 1024) // Convert to MB
    }
    
    private func calculateMemoryUsage() -> PerformanceMetrics.MemoryUsage {
        guard !memoryMeasurements.isEmpty else {
            return PerformanceMetrics.MemoryUsage(peakMemoryMB: 0, averageMemoryMB: 0, memoryGrowthMB: 0)
        }
        
        let peak = memoryMeasurements.max() ?? 0
        let average = memoryMeasurements.reduce(0, +) / Double(memoryMeasurements.count)
        let growth = (memoryMeasurements.last ?? 0) - (memoryMeasurements.first ?? 0)
        
        return PerformanceMetrics.MemoryUsage(
            peakMemoryMB: peak,
            averageMemoryMB: average,
            memoryGrowthMB: growth
        )
    }
    
    private func calculateAverageProgressInterval() -> TimeInterval {
        guard progressUpdates.count > 1 else { return 0.0 }
        
        var totalInterval: TimeInterval = 0.0
        for i in 1..<progressUpdates.count {
            let interval = progressUpdates[i].timestamp.timeIntervalSince(progressUpdates[i-1].timestamp)
            totalInterval += interval
        }
        
        return totalInterval / Double(progressUpdates.count - 1)
    }
}

// MARK: - Performance Test Suite

public class AsyncSyncPerformanceTests {
    
    private let syncEngine = AsyncSyncEngine()
    private let profiler = PerformanceProfiler()
    
    public init() {}
    
    // MARK: - Test Cases
    
    public func runSingleAlignmentPerformanceTest() async -> PerformanceMetrics? {
        let reference = createTestAudioData(duration: 10.0, frequency: 440.0)
        let target = createTestAudioData(duration: 10.0, frequency: 442.0)
        
        profiler.startProfiling(operationType: "Single Alignment (Async)")
        
        do {
            _ = try await syncEngine.align(
                reference: reference,
                target: target,
                method: .hybrid,
                configuration: .standard,
                progressHandler: { [weak self] progress in
                    self?.profiler.recordProgressUpdate(progress)
                }
            )
        } catch {
            print("Performance test error: \(error)")
        }
        
        return profiler.stopProfiling()
    }
    
    public func runBatchAlignmentPerformanceTest() async -> PerformanceMetrics? {
        let reference = createTestAudioData(duration: 10.0, frequency: 440.0)
        let targets = [
            createTestAudioData(duration: 8.0, frequency: 441.0),
            createTestAudioData(duration: 12.0, frequency: 443.0),
            createTestAudioData(duration: 10.0, frequency: 445.0),
            createTestAudioData(duration: 15.0, frequency: 447.0),
            createTestAudioData(duration: 6.0, frequency: 449.0)
        ]
        
        profiler.startProfiling(operationType: "Batch Alignment (5 targets)")
        
        do {
            _ = try await syncEngine.alignBatch(
                reference: reference,
                targets: targets,
                method: .hybrid,
                configuration: .standard,
                progressHandler: { [weak self] progress in
                    self?.profiler.recordProgressUpdate(progress)
                }
            )
        } catch {
            print("Performance test error: \(error)")
        }
        
        return profiler.stopProfiling()
    }
    
    public func runCancellationPerformanceTest() async -> PerformanceMetrics? {
        let reference = createTestAudioData(duration: 30.0, frequency: 440.0)
        let target = createTestAudioData(duration: 30.0, frequency: 442.0)
        
        profiler.startProfiling(operationType: "Cancelled Operation")
        
        let task = Task {
            try await syncEngine.align(
                reference: reference,
                target: target,
                method: .hybrid,
                configuration: .standard,
                progressHandler: { [weak self] progress in
                    self?.profiler.recordProgressUpdate(progress)
                }
            )
        }
        
        // Cancel after 50% completion
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        task.cancel()
        
        do {
            _ = try await task.value
        } catch {
            // Expected cancellation error
        }
        
        return profiler.stopProfiling()
    }
    
    // MARK: - Memory Pressure Test
    
    public func runMemoryPressureTest() async -> [PerformanceMetrics] {
        var results: [PerformanceMetrics] = []
        
        // Test with increasingly large audio data
        let durations: [TimeInterval] = [5.0, 10.0, 30.0, 60.0, 120.0]
        
        for duration in durations {
            let reference = createTestAudioData(duration: duration, frequency: 440.0)
            let target = createTestAudioData(duration: duration, frequency: 442.0)
            
            profiler.startProfiling(operationType: "Memory Test (\(Int(duration))s audio)")
            
            do {
                _ = try await syncEngine.align(
                    reference: reference,
                    target: target,
                    method: .hybrid,
                    configuration: .standard,
                    progressHandler: { [weak self] progress in
                        self?.profiler.recordProgressUpdate(progress)
                    }
                )
            } catch {
                print("Memory pressure test error: \(error)")
            }
            
            if let metrics = profiler.stopProfiling() {
                results.append(metrics)
            }
            
            // Brief pause between tests
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    private func createTestAudioData(duration: TimeInterval, frequency: Float) -> AudioDecoder.AudioData {
        let sampleRate = 44100.0
        let sampleCount = Int(duration * sampleRate)
        
        var samples: [Float] = []
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

// MARK: - Extensions

// Note: CaseIterable conformance is already declared in SyncTypes.swift

// MARK: - Performance Validation

public struct PerformanceValidator {
    
    public static func validateAsyncOverhead(_ metrics: PerformanceMetrics) -> ValidationResult {
        var issues: [String] = []
        var recommendations: [String] = []
        
        // Check total duration (should be reasonable for mock operations)
        if metrics.totalDuration > 5.0 {
            issues.append("Total duration (\(String(format: "%.3f", metrics.totalDuration))s) exceeds expected range")
            recommendations.append("Consider optimizing processing pipeline")
        }
        
        // Check memory growth
        if metrics.memoryUsage.memoryGrowthMB > 50.0 {
            issues.append("Memory growth (\(String(format: "%.1f", metrics.memoryUsage.memoryGrowthMB))MB) is excessive")
            recommendations.append("Review memory management and cleanup")
        }
        
        // Check progress update frequency
        if metrics.averageProgressInterval > 0.2 {
            issues.append("Progress updates too infrequent (\(String(format: "%.0f", metrics.averageProgressInterval * 1000))ms avg)")
            recommendations.append("Increase progress update frequency for better UX")
        } else if metrics.averageProgressInterval < 0.05 {
            issues.append("Progress updates too frequent (\(String(format: "%.0f", metrics.averageProgressInterval * 1000))ms avg)")
            recommendations.append("Reduce progress update frequency to avoid performance overhead")
        }
        
        let isValid = issues.isEmpty
        let score = calculatePerformanceScore(metrics)
        
        return ValidationResult(
            isValid: isValid,
            score: score,
            issues: issues,
            recommendations: recommendations
        )
    }
    
    private static func calculatePerformanceScore(_ metrics: PerformanceMetrics) -> Double {
        var score: Double = 100.0
        
        // Duration penalty (should be fast for mock operations)
        if metrics.totalDuration > 3.0 {
            score -= (metrics.totalDuration - 3.0) * 10.0
        }
        
        // Memory penalty
        if metrics.memoryUsage.memoryGrowthMB > 20.0 {
            score -= (metrics.memoryUsage.memoryGrowthMB - 20.0)
        }
        
        // Progress frequency penalty
        let idealInterval = 0.1 // 100ms
        let intervalDeviation = abs(metrics.averageProgressInterval - idealInterval)
        score -= intervalDeviation * 100.0
        
        return max(0.0, min(100.0, score))
    }
    
    public struct ValidationResult {
        public let isValid: Bool
        public let score: Double
        public let issues: [String]
        public let recommendations: [String]
        
        public var formattedReport: String {
            var report = """
            Performance Validation Report
            Score: \(String(format: "%.1f", score))/100
            Status: \(isValid ? "PASS" : "FAIL")
            
            """
            
            if !issues.isEmpty {
                report += "Issues Found:\n"
                for issue in issues {
                    report += "- \(issue)\n"
                }
                report += "\n"
            }
            
            if !recommendations.isEmpty {
                report += "Recommendations:\n"
                for recommendation in recommendations {
                    report += "- \(recommendation)\n"
                }
            }
            
            return report
        }
    }
}