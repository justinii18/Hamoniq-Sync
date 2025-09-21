//
//  TooltipView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct TooltipView: View {
    let text: String
    let isVisible: Bool
    let position: TooltipPosition
    
    var body: some View {
        if isVisible {
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .overlay {
                    tooltipArrow
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .animation(.easeInOut(duration: 0.2), value: isVisible)
        }
    }
    
    @ViewBuilder
    private var tooltipArrow: some View {
        switch position {
        case .top:
            Triangle()
                .fill(.regularMaterial)
                .frame(width: 8, height: 4)
                .offset(y: 12)
        case .bottom:
            Triangle()
                .fill(.regularMaterial)
                .frame(width: 8, height: 4)
                .rotationEffect(.degrees(180))
                .offset(y: -12)
        case .leading:
            Triangle()
                .fill(.regularMaterial)
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(-90))
                .offset(x: 12)
        case .trailing:
            Triangle()
                .fill(.regularMaterial)
                .frame(width: 4, height: 8)
                .rotationEffect(.degrees(90))
                .offset(x: -12)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

enum TooltipPosition {
    case top, bottom, leading, trailing
}

// MARK: - View Modifier

struct TooltipModifier: ViewModifier {
    let text: String
    let position: TooltipPosition
    let delay: TimeInterval
    
    @State private var isVisible = false
    @State private var hoverTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: overlayAlignment) {
                TooltipView(text: text, isVisible: isVisible, position: position)
                    .allowsHitTesting(false)
                    .zIndex(1000)
            }
            .onHover { hovering in
                hoverTask?.cancel()
                
                if hovering {
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        if !Task.isCancelled {
                            withAnimation {
                                isVisible = true
                            }
                        }
                    }
                } else {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
    }
    
    private var overlayAlignment: Alignment {
        switch position {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

extension View {
    func tooltip(
        _ text: String,
        position: TooltipPosition = .top,
        delay: TimeInterval = 0.5
    ) -> some View {
        modifier(TooltipModifier(text: text, position: position, delay: delay))
    }
}

#Preview {
    VStack(spacing: 40) {
        Button("Hover for tooltip") {}
            .tooltip("This is a helpful tooltip", position: .top)
        
        Button("Bottom tooltip") {}
            .tooltip("This tooltip appears below", position: .bottom)
        
        HStack(spacing: 40) {
            Button("Left") {}
                .tooltip("Leading tooltip", position: .leading)
            
            Button("Right") {}
                .tooltip("Trailing tooltip", position: .trailing)
        }
    }
    .padding(60)
}