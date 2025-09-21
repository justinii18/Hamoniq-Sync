//
//  AnimatedTransitionView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct AnimatedTransitionView<Content: View>: View {
    let content: Content
    let transition: AnimatedTransition
    let isVisible: Bool
    
    init(
        transition: AnimatedTransition = .fade,
        isVisible: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.transition = transition
        self.isVisible = isVisible
    }
    
    var body: some View {
        content
            .opacity(isVisible ? 1 : (transition.includesOpacity ? 0 : 1))
            .scaleEffect(isVisible ? 1 : transition.scaleEffect)
            .offset(
                x: isVisible ? 0 : transition.offsetX,
                y: isVisible ? 0 : transition.offsetY
            )
            .rotationEffect(.degrees(isVisible ? 0 : transition.rotation))
            .blur(radius: isVisible ? 0 : transition.blurRadius)
            .animation(transition.animation, value: isVisible)
    }
}

enum AnimatedTransition {
    case fade
    case scale
    case slideUp
    case slideDown
    case slideLeft
    case slideRight
    case zoom
    case rotate
    case blur
    case spring
    case bounce
    case elastic
    case custom(
        scaleEffect: CGFloat = 1,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0,
        rotation: Double = 0,
        blurRadius: CGFloat = 0,
        includesOpacity: Bool = true,
        animation: Animation = .easeInOut
    )
    
    var scaleEffect: CGFloat {
        switch self {
        case .scale, .zoom: 0.8
        case .bounce: 1.2
        case .elastic: 0.3
        case .custom(let scaleEffect, _, _, _, _, _, _): scaleEffect
        default: 1.0
        }
    }
    
    var offsetX: CGFloat {
        switch self {
        case .slideLeft: -100
        case .slideRight: 100
        case .custom(_, let offsetX, _, _, _, _, _): offsetX
        default: 0
        }
    }
    
    var offsetY: CGFloat {
        switch self {
        case .slideUp: -100
        case .slideDown: 100
        case .custom(_, _, let offsetY, _, _, _, _): offsetY
        default: 0
        }
    }
    
    var rotation: Double {
        switch self {
        case .rotate: 180
        case .custom(_, _, _, let rotation, _, _, _): rotation
        default: 0
        }
    }
    
    var blurRadius: CGFloat {
        switch self {
        case .blur: 10
        case .custom(_, _, _, _, let blurRadius, _, _): blurRadius
        default: 0
        }
    }
    
    var includesOpacity: Bool {
        switch self {
        case .custom(_, _, _, _, _, let includesOpacity, _): includesOpacity
        default: true
        }
    }
    
    var animation: Animation {
        switch self {
        case .fade: .easeInOut(duration: 0.3)
        case .scale: .easeInOut(duration: 0.4)
        case .slideUp, .slideDown, .slideLeft, .slideRight: .easeOut(duration: 0.5)
        case .zoom: .interpolatingSpring(stiffness: 300, damping: 30)
        case .rotate: .easeInOut(duration: 0.6)
        case .blur: .easeInOut(duration: 0.4)
        case .spring: .spring(response: 0.6, dampingFraction: 0.8)
        case .bounce: .interpolatingSpring(stiffness: 200, damping: 10)
        case .elastic: .interpolatingSpring(stiffness: 100, damping: 5)
        case .custom(_, _, _, _, _, _, let animation): animation
        }
    }
}

// MARK: - Sequence Transition

struct SequenceTransitionView<Content: View>: View {
    let content: Content
    let transitions: [AnimatedTransition]
    let delay: TimeInterval
    let isVisible: Bool
    
    @State private var currentTransitionIndex = 0
    @State private var timer: Timer?
    
    init(
        transitions: [AnimatedTransition],
        delay: TimeInterval = 0.3,
        isVisible: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.transitions = transitions
        self.delay = delay
        self.isVisible = isVisible
    }
    
    var body: some View {
        AnimatedTransitionView(
            transition: currentTransition,
            isVisible: isVisible,
            content: { content }
        )
        .onAppear {
            startSequence()
        }
        .onDisappear {
            stopSequence()
        }
    }
    
    private var currentTransition: AnimatedTransition {
        guard !transitions.isEmpty else { return .fade }
        return transitions[currentTransitionIndex % transitions.count]
    }
    
    private func startSequence() {
        guard transitions.count > 1 else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: true) { _ in
            withAnimation {
                currentTransitionIndex = (currentTransitionIndex + 1) % transitions.count
            }
        }
    }
    
    private func stopSequence() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Staggered Animation

struct StaggeredAnimationView<Content: View>: View {
    let content: Content
    let itemCount: Int
    let staggerDelay: TimeInterval
    let transition: AnimatedTransition
    let isVisible: Bool
    
    @State private var visibleItems: Set<Int> = []
    
    init(
        itemCount: Int,
        staggerDelay: TimeInterval = 0.1,
        transition: AnimatedTransition = .slideUp,
        isVisible: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.itemCount = itemCount
        self.staggerDelay = staggerDelay
        self.transition = transition
        self.isVisible = isVisible
    }
    
    var body: some View {
        content
            .onAppear {
                if isVisible {
                    animateItems()
                }
            }
            .onChange(of: isVisible) {
                if isVisible {
                    animateItems()
                } else {
                    visibleItems.removeAll()
                }
            }
    }
    
    private func animateItems() {
        visibleItems.removeAll()
        
        for index in 0..<itemCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * staggerDelay) {
                _ = visibleItems.insert(index)
            }
        }
    }
    
    func isItemVisible(_ index: Int) -> Bool {
        visibleItems.contains(index)
    }
}

// MARK: - Page Transition

struct PageTransitionView<Content: View>: View {
    let content: Content
    let transition: PageTransition
    let isForward: Bool
    
    init(
        transition: PageTransition = .slide,
        isForward: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.transition = transition
        self.isForward = isForward
    }
    
    var body: some View {
        content
            .transition(transition.swiftUITransition(isForward: isForward))
    }
}

enum PageTransition {
    case slide
    case fade
    case scale
    case flip
    case push
    
    func swiftUITransition(isForward: Bool) -> AnyTransition {
        switch self {
        case .slide:
            return .asymmetric(
                insertion: .move(edge: isForward ? .trailing : .leading),
                removal: .move(edge: isForward ? .leading : .trailing)
            )
        case .fade:
            return .opacity
        case .scale:
            return .scale.combined(with: .opacity)
        case .flip:
            return .asymmetric(
                insertion: .modifier(
                    active: FlipModifier(angle: isForward ? 90 : -90),
                    identity: FlipModifier(angle: 0)
                ),
                removal: .modifier(
                    active: FlipModifier(angle: isForward ? -90 : 90),
                    identity: FlipModifier(angle: 0)
                )
            )
        case .push:
            return .asymmetric(
                insertion: .move(edge: isForward ? .bottom : .top),
                removal: .move(edge: isForward ? .top : .bottom)
            )
        }
    }
}

struct FlipModifier: ViewModifier {
    let angle: Double
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0)
            )
    }
}

// MARK: - View Modifiers

struct AnimatedAppearanceModifier: ViewModifier {
    let transition: AnimatedTransition
    let delay: TimeInterval
    
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        AnimatedTransitionView(
            transition: transition,
            isVisible: isVisible
        ) {
            content
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                isVisible = true
            }
        }
    }
}

extension View {
    func animatedAppearance(
        _ transition: AnimatedTransition = .fade,
        delay: TimeInterval = 0
    ) -> some View {
        modifier(AnimatedAppearanceModifier(transition: transition, delay: delay))
    }
    
    func staggeredAnimation(
        itemCount: Int,
        staggerDelay: TimeInterval = 0.1,
        transition: AnimatedTransition = .slideUp
    ) -> some View {
        StaggeredAnimationView(
            itemCount: itemCount,
            staggerDelay: staggerDelay,
            transition: transition
        ) {
            self
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            // Basic transitions
            HStack(spacing: 20) {
                AnimatedTransitionView(transition: .fade) {
                    Text("Fade")
                        .padding()
                        .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                }
                
                AnimatedTransitionView(transition: .scale) {
                    Text("Scale")
                        .padding()
                        .background(.green, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                }
                
                AnimatedTransitionView(transition: .slideUp) {
                    Text("Slide")
                        .padding()
                        .background(.orange, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                }
            }
            
            // Sequence transition
            SequenceTransitionView(
                transitions: [.fade, .scale, .rotate],
                delay: 1.0
            ) {
                Text("Sequence Animation")
                    .font(.title2)
                    .padding()
                    .background(.purple, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.white)
            }
            
            // Staggered items
            VStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { index in
                    Text("Item \(index + 1)")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.red.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                        .animatedAppearance(.slideLeft, delay: Double(index) * 0.2)
                }
            }
        }
        .padding()
    }
}