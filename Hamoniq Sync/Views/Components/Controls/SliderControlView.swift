//
//  SliderControlView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct SliderControlView: View {
    @Binding var value: Double
    let configuration: SliderConfiguration
    let onValueChanged: ((Double) -> Void)?
    
    @State private var isDragging = false
    @State private var dragStartValue: Double = 0
    @GestureState private var dragOffset: CGSize = .zero
    
    init(
        value: Binding<Double>,
        configuration: SliderConfiguration = SliderConfiguration(),
        onValueChanged: ((Double) -> Void)? = nil
    ) {
        self._value = value
        self.configuration = configuration
        self.onValueChanged = onValueChanged
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if configuration.showLabel {
                labelView
            }
            
            sliderView
            
            if configuration.showValueDisplay {
                valueDisplayView
            }
        }
    }
    
    @ViewBuilder
    private var labelView: some View {
        HStack {
            Text(configuration.label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            if configuration.showResetButton {
                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        value = configuration.defaultValue
                    }
                    onValueChanged?(value)
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
    }
    
    @ViewBuilder
    private var sliderView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: configuration.trackHeight / 2)
                    .fill(configuration.trackColor)
                    .frame(height: configuration.trackHeight)
                
                // Track fill
                RoundedRectangle(cornerRadius: configuration.trackHeight / 2)
                    .fill(configuration.fillColor)
                    .frame(width: fillWidth(in: geometry), height: configuration.trackHeight)
                
                // Thumb
                thumbView
                    .position(x: thumbPosition(in: geometry), y: geometry.size.height / 2)
            }
            .frame(height: configuration.thumbSize)
            .gesture(dragGesture(in: geometry))
        }
        .frame(height: configuration.thumbSize)
    }
    
    @ViewBuilder
    private var thumbView: some View {
        ZStack {
            Circle()
                .fill(configuration.thumbColor)
                .frame(width: configuration.thumbSize, height: configuration.thumbSize)
                .shadow(
                    color: .black.opacity(0.2),
                    radius: isDragging ? 4 : 2,
                    x: 0,
                    y: isDragging ? 2 : 1
                )
            
            if configuration.showThumbValue {
                Text(formattedValue)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .scaleEffect(0.8)
            }
        }
        .scaleEffect(isDragging ? 1.2 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
    }
    
    @ViewBuilder
    private var valueDisplayView: some View {
        HStack {
            if configuration.showMinMaxLabels {
                Text(formatValue(configuration.range.lowerBound))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatValue(configuration.range.upperBound))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Spacer()
            }
            
            Text(formattedValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .monospacedDigit()
        }
    }
    
    private func fillWidth(in geometry: GeometryProxy) -> CGFloat {
        let normalizedValue = (value - configuration.range.lowerBound) / 
                             (configuration.range.upperBound - configuration.range.lowerBound)
        return max(0, geometry.size.width * normalizedValue)
    }
    
    private func thumbPosition(in geometry: GeometryProxy) -> CGFloat {
        let normalizedValue = (value - configuration.range.lowerBound) / 
                             (configuration.range.upperBound - configuration.range.lowerBound)
        let thumbOffset = configuration.thumbSize / 2
        let trackWidth = geometry.size.width - configuration.thumbSize
        return thumbOffset + trackWidth * normalizedValue
    }
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { gesture in
                if !isDragging {
                    isDragging = true
                    dragStartValue = value
                }
                
                let thumbOffset = configuration.thumbSize / 2
                let trackWidth = geometry.size.width - configuration.thumbSize
                let dragPosition = gesture.location.x - thumbOffset
                let normalizedPosition = max(0, min(1, dragPosition / trackWidth))
                
                let newValue = configuration.range.lowerBound + 
                              normalizedPosition * (configuration.range.upperBound - configuration.range.lowerBound)
                
                let steppedValue = configuration.step > 0 ? 
                    round(newValue / configuration.step) * configuration.step : newValue
                
                value = max(configuration.range.lowerBound, 
                           min(configuration.range.upperBound, steppedValue))
                
                onValueChanged?(value)
            }
            .onEnded { _ in
                isDragging = false
            }
    }
    
    private var formattedValue: String {
        formatValue(value)
    }
    
    private func formatValue(_ val: Double) -> String {
        switch configuration.valueFormat {
        case .decimal(let places):
            return String(format: "%.\(places)f", val)
        case .percentage:
            return String(format: "%.0f%%", val * 100)
        case .integer:
            return String(Int(val))
        case .time:
            return formatTimeValue(val)
        case .custom(let formatter):
            return formatter(val)
        }
    }
    
    private func formatTimeValue(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct SliderConfiguration {
    let range: ClosedRange<Double>
    let step: Double
    let defaultValue: Double
    let label: String
    let showLabel: Bool
    let showValueDisplay: Bool
    let showMinMaxLabels: Bool
    let showThumbValue: Bool
    let showResetButton: Bool
    let valueFormat: ValueFormat
    let trackHeight: CGFloat
    let thumbSize: CGFloat
    let trackColor: Color
    let fillColor: Color
    let thumbColor: Color
    
    init(
        range: ClosedRange<Double> = 0...1,
        step: Double = 0,
        defaultValue: Double? = nil,
        label: String = "Value",
        showLabel: Bool = true,
        showValueDisplay: Bool = true,
        showMinMaxLabels: Bool = false,
        showThumbValue: Bool = false,
        showResetButton: Bool = false,
        valueFormat: ValueFormat = .decimal(2),
        trackHeight: CGFloat = 4,
        thumbSize: CGFloat = 20,
        trackColor: Color = Color(.separatorColor),
        fillColor: Color = .blue,
        thumbColor: Color = .white
    ) {
        self.range = range
        self.step = step
        self.defaultValue = defaultValue ?? range.lowerBound
        self.label = label
        self.showLabel = showLabel
        self.showValueDisplay = showValueDisplay
        self.showMinMaxLabels = showMinMaxLabels
        self.showThumbValue = showThumbValue
        self.showResetButton = showResetButton
        self.valueFormat = valueFormat
        self.trackHeight = trackHeight
        self.thumbSize = thumbSize
        self.trackColor = trackColor
        self.fillColor = fillColor
        self.thumbColor = thumbColor
    }
}

enum ValueFormat {
    case decimal(Int)
    case percentage
    case integer
    case time
    case custom((Double) -> String)
}

// MARK: - Specialized Sliders

struct ConfidenceSliderView: View {
    @Binding var confidence: Double
    let onChanged: ((Double) -> Void)?
    
    init(confidence: Binding<Double>, onChanged: ((Double) -> Void)? = nil) {
        self._confidence = confidence
        self.onChanged = onChanged
    }
    
    var body: some View {
        SliderControlView(
            value: $confidence,
            configuration: SliderConfiguration(
                range: 0...1,
                step: 0.01,
                defaultValue: 0.7,
                label: "Confidence Threshold",
                showLabel: true,
                showValueDisplay: true,
                showResetButton: true,
                valueFormat: .percentage,
                fillColor: confidenceColor
            ),
            onValueChanged: onChanged
        )
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct VolumeSliderView: View {
    @Binding var volume: Double
    let onChanged: ((Double) -> Void)?
    
    init(volume: Binding<Double>, onChanged: ((Double) -> Void)? = nil) {
        self._volume = volume
        self.onChanged = onChanged
    }
    
    var body: some View {
        SliderControlView(
            value: $volume,
            configuration: SliderConfiguration(
                range: 0...1,
                step: 0.01,
                defaultValue: 0.5,
                label: "Volume",
                showLabel: true,
                showValueDisplay: true,
                valueFormat: .percentage,
                fillColor: .blue
            ),
            onValueChanged: onChanged
        )
    }
}

struct TimeOffsetSliderView: View {
    @Binding var offset: Double
    let onChanged: ((Double) -> Void)?
    
    init(offset: Binding<Double>, onChanged: ((Double) -> Void)? = nil) {
        self._offset = offset
        self.onChanged = onChanged
    }
    
    var body: some View {
        SliderControlView(
            value: $offset,
            configuration: SliderConfiguration(
                range: -300...300,
                step: 0.1,
                defaultValue: 0,
                label: "Time Offset",
                showLabel: true,
                showValueDisplay: true,
                showMinMaxLabels: true,
                showResetButton: true,
                valueFormat: .custom { value in
                    let sign = value >= 0 ? "+" : ""
                    return "\(sign)\(String(format: "%.1f", value))s"
                },
                fillColor: offset >= 0 ? .blue : .orange
            ),
            onValueChanged: onChanged
        )
    }
}

// MARK: - Multi-Value Slider

struct RangeSliderView: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let configuration: SliderConfiguration
    let onChanged: ((Double, Double) -> Void)?
    
    @State private var isDraggingLower = false
    @State private var isDraggingUpper = false
    
    init(
        lowerValue: Binding<Double>,
        upperValue: Binding<Double>,
        configuration: SliderConfiguration = SliderConfiguration(),
        onChanged: ((Double, Double) -> Void)? = nil
    ) {
        self._lowerValue = lowerValue
        self._upperValue = upperValue
        self.configuration = configuration
        self.onChanged = onChanged
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if configuration.showLabel {
                Text(configuration.label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: configuration.trackHeight / 2)
                        .fill(configuration.trackColor)
                        .frame(height: configuration.trackHeight)
                    
                    // Range fill
                    RoundedRectangle(cornerRadius: configuration.trackHeight / 2)
                        .fill(configuration.fillColor)
                        .frame(width: rangeWidth(in: geometry), height: configuration.trackHeight)
                        .offset(x: lowerThumbPosition(in: geometry) - configuration.thumbSize / 2)
                    
                    // Lower thumb
                    Circle()
                        .fill(configuration.thumbColor)
                        .frame(width: configuration.thumbSize, height: configuration.thumbSize)
                        .scaleEffect(isDraggingLower ? 1.2 : 1.0)
                        .position(x: lowerThumbPosition(in: geometry), y: geometry.size.height / 2)
                        .gesture(lowerDragGesture(in: geometry))
                    
                    // Upper thumb
                    Circle()
                        .fill(configuration.thumbColor)
                        .frame(width: configuration.thumbSize, height: configuration.thumbSize)
                        .scaleEffect(isDraggingUpper ? 1.2 : 1.0)
                        .position(x: upperThumbPosition(in: geometry), y: geometry.size.height / 2)
                        .gesture(upperDragGesture(in: geometry))
                }
            }
            .frame(height: configuration.thumbSize)
            
            if configuration.showValueDisplay {
                HStack {
                    Text(formatValue(lowerValue))
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Text("–")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatValue(upperValue))
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isDraggingLower)
        .animation(.easeInOut(duration: 0.15), value: isDraggingUpper)
    }
    
    private func lowerThumbPosition(in geometry: GeometryProxy) -> CGFloat {
        let normalizedValue = (lowerValue - configuration.range.lowerBound) / 
                             (configuration.range.upperBound - configuration.range.lowerBound)
        let thumbOffset = configuration.thumbSize / 2
        let trackWidth = geometry.size.width - configuration.thumbSize
        return thumbOffset + trackWidth * normalizedValue
    }
    
    private func upperThumbPosition(in geometry: GeometryProxy) -> CGFloat {
        let normalizedValue = (upperValue - configuration.range.lowerBound) / 
                             (configuration.range.upperBound - configuration.range.lowerBound)
        let thumbOffset = configuration.thumbSize / 2
        let trackWidth = geometry.size.width - configuration.thumbSize
        return thumbOffset + trackWidth * normalizedValue
    }
    
    private func rangeWidth(in geometry: GeometryProxy) -> CGFloat {
        let lowerPos = lowerThumbPosition(in: geometry)
        let upperPos = upperThumbPosition(in: geometry)
        return abs(upperPos - lowerPos)
    }
    
    private func lowerDragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                if !isDraggingLower {
                    isDraggingLower = true
                }
                
                let thumbOffset = configuration.thumbSize / 2
                let trackWidth = geometry.size.width - configuration.thumbSize
                let dragPosition = gesture.location.x - thumbOffset
                let normalizedPosition = max(0, min(1, dragPosition / trackWidth))
                
                let newValue = configuration.range.lowerBound + 
                              normalizedPosition * (configuration.range.upperBound - configuration.range.lowerBound)
                
                lowerValue = max(configuration.range.lowerBound, min(upperValue, newValue))
                onChanged?(lowerValue, upperValue)
            }
            .onEnded { _ in
                isDraggingLower = false
            }
    }
    
    private func upperDragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { gesture in
                if !isDraggingUpper {
                    isDraggingUpper = true
                }
                
                let thumbOffset = configuration.thumbSize / 2
                let trackWidth = geometry.size.width - configuration.thumbSize
                let dragPosition = gesture.location.x - thumbOffset
                let normalizedPosition = max(0, min(1, dragPosition / trackWidth))
                
                let newValue = configuration.range.lowerBound + 
                              normalizedPosition * (configuration.range.upperBound - configuration.range.lowerBound)
                
                upperValue = min(configuration.range.upperBound, max(lowerValue, newValue))
                onChanged?(lowerValue, upperValue)
            }
            .onEnded { _ in
                isDraggingUpper = false
            }
    }
    
    private func formatValue(_ value: Double) -> String {
        switch configuration.valueFormat {
        case .decimal(let places):
            return String(format: "%.\(places)f", value)
        case .percentage:
            return String(format: "%.0f%%", value * 100)
        case .integer:
            return String(Int(value))
        case .time:
            let minutes = Int(value) / 60
            let seconds = Int(value) % 60
            return String(format: "%d:%02d", minutes, seconds)
        case .custom(let formatter):
            return formatter(value)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        SliderControlView(
            value: .constant(0.75),
            configuration: SliderConfiguration(
                range: 0...1,
                label: "Basic Slider",
                valueFormat: .percentage
            )
        )
        
        ConfidenceSliderView(confidence: .constant(0.8))
        
        VolumeSliderView(volume: .constant(0.6))
        
        TimeOffsetSliderView(offset: .constant(-2.5))
        
        RangeSliderView(
            lowerValue: .constant(0.2),
            upperValue: .constant(0.8),
            configuration: SliderConfiguration(
                range: 0...1,
                label: "Range Slider",
                valueFormat: .percentage
            )
        )
    }
    .padding()
}