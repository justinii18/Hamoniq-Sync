//
//  ConfidenceIndicatorView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct ConfidenceIndicatorView: View {
    let confidence: Double
    let configuration: ConfidenceConfiguration
    let onTapped: (() -> Void)?
    
    @State private var animatedConfidence: Double = 0
    
    init(
        confidence: Double,
        configuration: ConfidenceConfiguration = ConfidenceConfiguration(),
        onTapped: (() -> Void)? = nil
    ) {
        self.confidence = max(0, min(1, confidence))
        self.configuration = configuration
        self.onTapped = onTapped
    }
    
    var body: some View {
        Group {
            switch configuration.style {
            case .bar:
                barIndicator
            case .circle:
                circularIndicator
            case .meter:
                meterIndicator
            case .badge:
                badgeIndicator
            case .text:
                textIndicator
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTapped?()
        }
        .onAppear {
            withAnimation(.easeOut(duration: configuration.animationDuration)) {
                animatedConfidence = confidence
            }
        }
        .onChange(of: confidence) { newValue in
            withAnimation(.easeInOut(duration: configuration.animationDuration)) {
                animatedConfidence = newValue
            }
        }
    }
    
    @ViewBuilder
    private var barIndicator: some View {
        VStack(alignment: .leading, spacing: 4) {
            if configuration.showLabel {
                HStack {
                    Text(configuration.label)
                        .font(configuration.labelFont)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if configuration.showPercentage {
                        Text("\(Int(confidence * 100))%")
                            .font(configuration.valueFont)
                            .foregroundColor(confidenceColor)
                            .monospacedDigit()
                    }
                }
            }
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: configuration.barHeight / 2)
                    .fill(configuration.backgroundColor)
                    .frame(height: configuration.barHeight)
                
                RoundedRectangle(cornerRadius: configuration.barHeight / 2)
                    .fill(confidenceGradient)
                    .frame(width: configuration.barWidth * animatedConfidence, height: configuration.barHeight)
                    .animation(.easeInOut(duration: configuration.animationDuration), value: animatedConfidence)
                
                if configuration.showThreshold {
                    thresholdIndicator
                }
            }
            .frame(width: configuration.barWidth, height: configuration.barHeight)
        }
    }
    
    @ViewBuilder
    private var circularIndicator: some View {
        ZStack {
            Circle()
                .stroke(configuration.backgroundColor, lineWidth: configuration.lineWidth)
                .frame(width: configuration.circleSize, height: configuration.circleSize)
            
            Circle()
                .trim(from: 0, to: animatedConfidence)
                .stroke(
                    confidenceGradient,
                    style: StrokeStyle(
                        lineWidth: configuration.lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: configuration.circleSize, height: configuration.circleSize)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: configuration.animationDuration), value: animatedConfidence)
            
            if configuration.showPercentage {
                Text("\(Int(confidence * 100))%")
                    .font(configuration.valueFont)
                    .fontWeight(.semibold)
                    .foregroundColor(confidenceColor)
                    .monospacedDigit()
            }
        }
    }
    
    @ViewBuilder
    private var meterIndicator: some View {
        VStack(spacing: 8) {
            if configuration.showLabel {
                Text(configuration.label)
                    .font(configuration.labelFont)
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 2) {
                ForEach(0..<configuration.meterSegments, id: \.self) { index in
                    let segmentValue = Double(index + 1) / Double(configuration.meterSegments)
                    let isActive = animatedConfidence >= segmentValue
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? segmentColor(for: segmentValue) : configuration.backgroundColor)
                        .frame(width: configuration.segmentWidth, height: configuration.segmentHeight)
                        .animation(
                            .easeInOut(duration: configuration.animationDuration)
                            .delay(Double(index) * 0.05),
                            value: animatedConfidence
                        )
                }
            }
            
            if configuration.showPercentage {
                Text("\(Int(confidence * 100))%")
                    .font(configuration.valueFont)
                    .foregroundColor(confidenceColor)
                    .monospacedDigit()
            }
        }
    }
    
    @ViewBuilder
    private var badgeIndicator: some View {
        Text(badgeText)
            .font(configuration.valueFont)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(confidenceColor, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            }
    }
    
    @ViewBuilder
    private var textIndicator: some View {
        HStack(spacing: 6) {
            if configuration.showLabel {
                Text(configuration.label)
                    .font(configuration.labelFont)
                    .foregroundColor(.primary)
            }
            
            Text(confidenceDescription)
                .font(configuration.valueFont)
                .fontWeight(.medium)
                .foregroundColor(confidenceColor)
            
            if configuration.showPercentage {
                Text("(\(Int(confidence * 100))%)")
                    .font(configuration.labelFont)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    @ViewBuilder
    private var thresholdIndicator: some View {
        let thresholdPosition = configuration.barWidth * configuration.threshold
        
        Rectangle()
            .fill(.white)
            .frame(width: 2, height: configuration.barHeight + 4)
            .position(x: thresholdPosition, y: configuration.barHeight / 2)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0)
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...: return configuration.highConfidenceColor
        case 0.6..<0.8: return configuration.mediumConfidenceColor
        default: return configuration.lowConfidenceColor
        }
    }
    
    private var confidenceGradient: LinearGradient {
        LinearGradient(
            colors: [confidenceColor.opacity(0.8), confidenceColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func segmentColor(for value: Double) -> Color {
        switch value {
        case 0.8...: return configuration.highConfidenceColor
        case 0.6..<0.8: return configuration.mediumConfidenceColor
        default: return configuration.lowConfidenceColor
        }
    }
    
    private var badgeText: String {
        switch confidence {
        case 0.9...: return "Excellent"
        case 0.8..<0.9: return "High"
        case 0.7..<0.8: return "Good"
        case 0.6..<0.7: return "Fair"
        case 0.4..<0.6: return "Low"
        default: return "Poor"
        }
    }
    
    private var confidenceDescription: String {
        switch confidence {
        case 0.85...: return "Excellent"
        case 0.7..<0.85: return "High"
        case 0.5..<0.7: return "Medium"
        case 0.3..<0.5: return "Low"
        default: return "Poor"
        }
    }
}

struct ConfidenceConfiguration {
    let style: IndicatorStyle
    let label: String
    let showLabel: Bool
    let showPercentage: Bool
    let showThreshold: Bool
    let threshold: Double
    let animationDuration: TimeInterval
    
    // Colors
    let highConfidenceColor: Color
    let mediumConfidenceColor: Color
    let lowConfidenceColor: Color
    let backgroundColor: Color
    
    // Bar style properties
    let barWidth: CGFloat
    let barHeight: CGFloat
    
    // Circle style properties
    let circleSize: CGFloat
    let lineWidth: CGFloat
    
    // Meter style properties
    let meterSegments: Int
    let segmentWidth: CGFloat
    let segmentHeight: CGFloat
    
    // Typography
    let labelFont: Font
    let valueFont: Font
    
    init(
        style: IndicatorStyle = .bar,
        label: String = "Confidence",
        showLabel: Bool = true,
        showPercentage: Bool = true,
        showThreshold: Bool = false,
        threshold: Double = 0.7,
        animationDuration: TimeInterval = 0.6,
        highConfidenceColor: Color = .green,
        mediumConfidenceColor: Color = .orange,
        lowConfidenceColor: Color = .red,
        backgroundColor: Color = Color(.separatorColor),
        barWidth: CGFloat = 120,
        barHeight: CGFloat = 8,
        circleSize: CGFloat = 60,
        lineWidth: CGFloat = 6,
        meterSegments: Int = 10,
        segmentWidth: CGFloat = 8,
        segmentHeight: CGFloat = 20,
        labelFont: Font = .caption,
        valueFont: Font = .caption
    ) {
        self.style = style
        self.label = label
        self.showLabel = showLabel
        self.showPercentage = showPercentage
        self.showThreshold = showThreshold
        self.threshold = threshold
        self.animationDuration = animationDuration
        self.highConfidenceColor = highConfidenceColor
        self.mediumConfidenceColor = mediumConfidenceColor
        self.lowConfidenceColor = lowConfidenceColor
        self.backgroundColor = backgroundColor
        self.barWidth = barWidth
        self.barHeight = barHeight
        self.circleSize = circleSize
        self.lineWidth = lineWidth
        self.meterSegments = meterSegments
        self.segmentWidth = segmentWidth
        self.segmentHeight = segmentHeight
        self.labelFont = labelFont
        self.valueFont = valueFont
    }
}

enum IndicatorStyle {
    case bar
    case circle
    case meter
    case badge
    case text
}

// MARK: - Confidence Summary View

struct ConfidenceSummaryView: View {
    let confidenceData: [ConfidenceDataPoint]
    let configuration: ConfidenceConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sync Confidence Analysis")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Average: \(Int(averageConfidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(confidenceData, id: \.id) { dataPoint in
                    HStack {
                        Text(dataPoint.label)
                            .font(.body)
                            .frame(width: 100, alignment: .leading)
                        
                        ConfidenceIndicatorView(
                            confidence: dataPoint.confidence,
                            configuration: ConfidenceConfiguration(
                                style: .bar,
                                showLabel: false,
                                barWidth: 80,
                                barHeight: 6
                            )
                        )
                        
                        Text("\(Int(dataPoint.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            }
            
            confidenceDistribution
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    @ViewBuilder
    private var confidenceDistribution: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Distribution")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack(spacing: 2) {
                ForEach(confidenceRanges, id: \.range) { item in
                    Rectangle()
                        .fill(item.color)
                        .frame(width: CGFloat(item.percentage) * 2, height: 8)
                }
                
                Spacer()
            }
            
            HStack {
                ForEach(Array(confidenceRanges.enumerated()), id: \.element.range) { index, item in
                    Text(item.label)
                        .font(.caption2)
                        .foregroundColor(item.color)
                    
                    if index < confidenceRanges.count - 1 {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var averageConfidence: Double {
        guard !confidenceData.isEmpty else { return 0 }
        return confidenceData.map(\.confidence).reduce(0, +) / Double(confidenceData.count)
    }
    
    private var confidenceRanges: [(range: String, label: String, color: Color, percentage: Double)] {
        let total = Double(confidenceData.count)
        let high = confidenceData.filter { $0.confidence >= 0.8 }.count
        let medium = confidenceData.filter { $0.confidence >= 0.6 && $0.confidence < 0.8 }.count
        let low = confidenceData.filter { $0.confidence < 0.6 }.count
        
        return [
            ("high", "High", .green, Double(high) / total * 100),
            ("medium", "Medium", .orange, Double(medium) / total * 100),
            ("low", "Low", .red, Double(low) / total * 100)
        ]
    }
}

struct ConfidenceDataPoint {
    let id = UUID()
    let label: String
    let confidence: Double
}

// MARK: - Real-time Confidence Monitor

struct RealTimeConfidenceMonitor: View {
    @State private var confidenceHistory: [Double] = []
    @State private var currentConfidence: Double = 0
    let maxHistoryPoints: Int
    
    init(maxHistoryPoints: Int = 50) {
        self.maxHistoryPoints = maxHistoryPoints
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Real-time Confidence")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                ConfidenceIndicatorView(
                    confidence: currentConfidence,
                    configuration: ConfidenceConfiguration(
                        style: .circle,
                        showLabel: false,
                        circleSize: 40,
                        lineWidth: 4
                    )
                )
            }
            
            confidenceChart
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            startMonitoring()
        }
    }
    
    @ViewBuilder
    private var confidenceChart: some View {
        Canvas { context, size in
            drawConfidenceChart(context: context, size: size)
        }
        .frame(height: 60)
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    
    private func drawConfidenceChart(context: GraphicsContext, size: CGSize) {
        guard confidenceHistory.count > 1 else { return }
        
        let pointWidth = size.width / CGFloat(maxHistoryPoints - 1)
        let maxHeight = size.height - 20
        
        var path = Path()
        
        for (index, confidence) in confidenceHistory.enumerated() {
            let x = CGFloat(index) * pointWidth
            let y = size.height - (CGFloat(confidence) * maxHeight + 10)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        context.stroke(path, with: .color(.blue), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        
        // Draw confidence zones
        let highZone = Rectangle()
        context.fill(
            highZone.path(in: CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.2)),
            with: .color(.green.opacity(0.1))
        )
        
        let mediumZone = Rectangle()
        context.fill(
            mediumZone.path(in: CGRect(x: 0, y: size.height * 0.2, width: size.width, height: size.height * 0.2)),
            with: .color(.orange.opacity(0.1))
        )
    }
    
    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Simulate confidence updates
            let newConfidence = Double.random(in: 0.3...0.95)
            currentConfidence = newConfidence
            
            confidenceHistory.append(newConfidence)
            if confidenceHistory.count > maxHistoryPoints {
                confidenceHistory.removeFirst()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            ConfidenceIndicatorView(
                confidence: 0.87,
                configuration: ConfidenceConfiguration(style: .bar)
            )
            
            ConfidenceIndicatorView(
                confidence: 0.67,
                configuration: ConfidenceConfiguration(style: .circle)
            )
            
            ConfidenceIndicatorView(
                confidence: 0.92,
                configuration: ConfidenceConfiguration(style: .meter)
            )
        }
        
        HStack(spacing: 16) {
            ConfidenceIndicatorView(
                confidence: 0.45,
                configuration: ConfidenceConfiguration(style: .badge)
            )
            
            ConfidenceIndicatorView(
                confidence: 0.78,
                configuration: ConfidenceConfiguration(style: .text)
            )
        }
        
        ConfidenceSummaryView(
            confidenceData: [
                ConfidenceDataPoint(label: "Audio 1", confidence: 0.89),
                ConfidenceDataPoint(label: "Audio 2", confidence: 0.76),
                ConfidenceDataPoint(label: "Audio 3", confidence: 0.45),
                ConfidenceDataPoint(label: "Audio 4", confidence: 0.92)
            ],
            configuration: ConfidenceConfiguration()
        )
        
        RealTimeConfidenceMonitor()
    }
    .padding()
}
