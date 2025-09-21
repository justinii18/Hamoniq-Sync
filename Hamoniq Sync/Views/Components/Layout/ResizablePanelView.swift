//
//  ResizablePanelView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct ResizablePanelView<Content: View>: View {
    let content: Content
    let configuration: PanelConfiguration
    let onSizeChanged: ((CGSize) -> Void)?
    
    @State private var panelSize: CGSize
    @State private var isDragging = false
    @State private var dragHandle: ResizeHandle?
    
    init(
        configuration: PanelConfiguration = PanelConfiguration(),
        onSizeChanged: ((CGSize) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.configuration = configuration
        self.onSizeChanged = onSizeChanged
        self._panelSize = State(initialValue: configuration.defaultSize)
    }
    
    var body: some View {
        ZStack {
            panelContent
            
            if configuration.isResizable {
                resizeHandles
            }
        }
        .frame(
            width: panelSize.width,
            height: panelSize.height
        )
        .background {
            RoundedRectangle(cornerRadius: configuration.cornerRadius)
                .fill(configuration.backgroundColor)
                .stroke(configuration.borderColor, lineWidth: configuration.borderWidth)
                .shadow(
                    color: configuration.shadowColor,
                    radius: configuration.shadowRadius,
                    x: configuration.shadowOffset.width,
                    y: configuration.shadowOffset.height
                )
                .onChange(of: panelSize) { newSize in
                    onSizeChanged?(newSize)
                }
        }
    }
        
    @ViewBuilder
    private var panelContent: some View {
            content
                .padding(configuration.contentPadding)
                .clipped()
        }
        
    @ViewBuilder
    private var resizeHandles: some View {
            Group {
                // Corner handles
                if configuration.allowsCornerResize {
                    cornerHandle(.topLeading, at: .topLeading)
                    cornerHandle(.topTrailing, at: .topTrailing)
                    cornerHandle(.bottomLeading, at: .bottomLeading)
                    cornerHandle(.bottomTrailing, at: .bottomTrailing)
                }
                
                // Edge handles
                if configuration.allowsEdgeResize {
                    edgeHandle(.top, at: .top)
                    edgeHandle(.bottom, at: .bottom)
                    edgeHandle(.leading, at: .leading)
                    edgeHandle(.trailing, at: .trailing)
                }
            }
        }
        
    @ViewBuilder
    private func cornerHandle(_ handle: ResizeHandle, at alignment: Alignment) -> some View {
            Rectangle()
                .fill(handleColor(for: handle))
                .frame(width: configuration.handleSize, height: configuration.handleSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .contentShape(Rectangle())
                .cursor(handle.cursor)
                .gesture(resizeGesture(for: handle))
        }
        
        @ViewBuilder
        private func edgeHandle(_ handle: ResizeHandle, at alignment: Alignment) -> some View {
            Rectangle()
                .fill(handleColor(for: handle))
                .frame(
                    width: handle.isHorizontal ? nil : configuration.handleSize,
                    height: handle.isVertical ? nil : configuration.handleSize
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .contentShape(Rectangle())
                .cursor(handle.cursor)
                .gesture(resizeGesture(for: handle))
        }
        
    private func handleColor(for handle: ResizeHandle) -> Color {
            if isDragging && dragHandle == handle {
                return .blue.opacity(0.5)
            } else {
                return configuration.showHandles ? .blue.opacity(0.2) : .clear
            }
        }
        
    private func resizeGesture(for handle: ResizeHandle) -> some Gesture {
            DragGesture()
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        dragHandle = handle
                    }
                    
                    let newSize = calculateNewSize(
                        for: handle,
                        translation: value.translation
                    )
                    
                    panelSize = clampSize(newSize)
                }
                .onEnded { _ in
                    isDragging = false
                    dragHandle = nil
                }
        }
        
    private func calculateNewSize(for handle: ResizeHandle, translation: CGSize) -> CGSize {
            var newSize = panelSize
            
            switch handle {
            case .topLeading:
                newSize.width -= translation.width
                newSize.height -= translation.height
            case .top:
                newSize.height -= translation.height
            case .topTrailing:
                newSize.width += translation.width
                newSize.height -= translation.height
            case .trailing:
                newSize.width += translation.width
            case .bottomTrailing:
                newSize.width += translation.width
                newSize.height += translation.height
            case .bottom:
                newSize.height += translation.height
            case .bottomLeading:
                newSize.width -= translation.width
                newSize.height += translation.height
            case .leading:
                newSize.width -= translation.width
            }
            
            return newSize
        }
        
        func clampSize(_ size: CGSize) -> CGSize {
            CGSize(
                width: max(configuration.minSize.width,
                           min(configuration.maxSize.width, size.width)),
                height: max(configuration.minSize.height,
                            min(configuration.maxSize.height, size.height))
            )
        }
    }
    
    enum ResizeHandle: CaseIterable {
        case topLeading, top, topTrailing
        case leading, trailing
        case bottomLeading, bottom, bottomTrailing
        
        var cursor: NSCursor {
            switch self {
            case .topLeading, .bottomTrailing:
                //return .resizeNorthWestSouthEast // TODO: Find correct cursor
                return .resizeUpDown
            case .top, .bottom:
                return .resizeUpDown
            case .topTrailing, .bottomLeading:
                //return .resizeNorthEastSouthWest // TODO: Find correct cursor
                return .resizeUpDown
            case .leading, .trailing:
                return .resizeLeftRight
            }
        }
        
        var isHorizontal: Bool {
            switch self {
            case .leading, .trailing: true
            default: false
            }
        }
        
        var isVertical: Bool {
            switch self {
            case .top, .bottom: true
            default: false
            }
        }
    }
    
    struct PanelConfiguration {
        let defaultSize: CGSize
        let minSize: CGSize
        let maxSize: CGSize
        let isResizable: Bool
        let allowsCornerResize: Bool
        let allowsEdgeResize: Bool
        let handleSize: CGFloat
        let showHandles: Bool
        let backgroundColor: Color
        let borderColor: Color
        let borderWidth: CGFloat
        let cornerRadius: CGFloat
        let shadowColor: Color
        let shadowRadius: CGFloat
        let shadowOffset: CGSize
        let contentPadding: EdgeInsets
        
        init(
            defaultSize: CGSize = CGSize(width: 400, height: 300),
            minSize: CGSize = CGSize(width: 200, height: 150),
            maxSize: CGSize = CGSize(width: 1000, height: 800),
            isResizable: Bool = true,
            allowsCornerResize: Bool = true,
            allowsEdgeResize: Bool = true,
            handleSize: CGFloat = 8,
            showHandles: Bool = false,
            backgroundColor: Color = Color(.windowBackgroundColor),
            borderColor: Color = Color(.separatorColor),
            borderWidth: CGFloat = 1,
            cornerRadius: CGFloat = 8,
            shadowColor: Color = .black.opacity(0.1),
            shadowRadius: CGFloat = 4,
            shadowOffset: CGSize = CGSize(width: 0, height: 2),
            contentPadding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        ) {
            self.defaultSize = defaultSize
            self.minSize = minSize
            self.maxSize = maxSize
            self.isResizable = isResizable
            self.allowsCornerResize = allowsCornerResize
            self.allowsEdgeResize = allowsEdgeResize
            self.handleSize = handleSize
            self.showHandles = showHandles
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
            self.cornerRadius = cornerRadius
            self.shadowColor = shadowColor
            self.shadowRadius = shadowRadius
            self.shadowOffset = shadowOffset
            self.contentPadding = contentPadding
        }
    }
    
    // MARK: - Panel Stack View
    
    struct PanelStackView<Content: View>: View {
        let content: Content
        let configuration: StackConfiguration
        
        @State private var panels: [PanelInfo] = []
        
        init(
            configuration: StackConfiguration = StackConfiguration(),
            @ViewBuilder content: () -> Content
        ) {
            self.content = content()
            self.configuration = configuration
        }
        
        var body: some View {
            ZStack {
                content
                
                ForEach(panels.indices, id: \.self) { index in
                    panelView(for: panels[index], at: index)
                }
            }
        }
        
    private func panelView(for panelInfo: PanelInfo, at index: Int) -> some View {
        ResizablePanelView(
            configuration: panelInfo.configuration
        ) {
            panelInfo.content
        }
        .position(panelInfo.position)
        .zIndex(Double(index))
    }
        
        func addPanel<PanelContent: View>(
            at position: CGPoint = CGPoint(x: 300, y: 200),
            configuration: PanelConfiguration = PanelConfiguration(),
            @ViewBuilder content: () -> PanelContent
        ) {
            let panel = PanelInfo(
                position: position,
                configuration: configuration,
                content: AnyView(content())
            )
            panels.append(panel)
        }
        
        func removePanel(at index: Int) {
            guard index < panels.count else { return }
            panels.remove(at: index)
        }
    }
    
    struct PanelInfo {
        let id = UUID()
        var position: CGPoint
        let configuration: PanelConfiguration
        let content: AnyView
    }
    
    struct StackConfiguration {
        let maxPanels: Int
        let allowsOverlapping: Bool
        let autoArrangeSpacing: CGFloat
        
        init(
            maxPanels: Int = 10,
            allowsOverlapping: Bool = true,
            autoArrangeSpacing: CGFloat = 20
        ) {
            self.maxPanels = maxPanels
            self.allowsOverlapping = allowsOverlapping
            self.autoArrangeSpacing = autoArrangeSpacing
        }
    }
    
    // MARK: - Collapsible Panel
    
    struct CollapsiblePanelView<Content: View, Header: View>: View {
        let header: Header
        let content: Content
        let configuration: CollapsibleConfiguration
        
        @State private var isExpanded: Bool
        
        init(
            isExpanded: Bool = true,
            configuration: CollapsibleConfiguration = CollapsibleConfiguration(),
            @ViewBuilder header: () -> Header,
            @ViewBuilder content: () -> Content
        ) {
            self._isExpanded = State(initialValue: isExpanded)
            self.configuration = configuration
            self.header = header()
            self.content = content()
        }
        
        var body: some View {
            VStack(spacing: 0) {
                headerSection
                
                if isExpanded {
                    contentSection
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .background {
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(configuration.backgroundColor)
                    .stroke(configuration.borderColor, lineWidth: configuration.borderWidth)
            }
            .animation(configuration.animation, value: isExpanded)
        }
        
    @ViewBuilder
    private var headerSection: some View {
            Button {
                isExpanded.toggle()
            } label: {
                HStack {
                    header
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(configuration.headerPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background {
                if configuration.highlightHeader {
                    RoundedRectangle(cornerRadius: configuration.cornerRadius)
                        .fill(Color(.controlBackgroundColor))
                }
            }
        }
        
    @ViewBuilder
    private var contentSection: some View {
            content
                .padding(configuration.contentPadding)
        }
    }
    
    struct CollapsibleConfiguration {
        let backgroundColor: Color
        let borderColor: Color
        let borderWidth: CGFloat
        let cornerRadius: CGFloat
        let highlightHeader: Bool
        let headerPadding: EdgeInsets
        let contentPadding: EdgeInsets
        let animation: Animation
        
        init(
            backgroundColor: Color = Color(.windowBackgroundColor),
            borderColor: Color = Color(.separatorColor),
            borderWidth: CGFloat = 1,
            cornerRadius: CGFloat = 8,
            highlightHeader: Bool = true,
            headerPadding: EdgeInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
            contentPadding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
            animation: Animation = .easeInOut(duration: 0.3)
        ) {
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
            self.cornerRadius = cornerRadius
            self.highlightHeader = highlightHeader
            self.headerPadding = headerPadding
            self.contentPadding = contentPadding
            self.animation = animation
        }
    }
    
    #Preview {
        VStack(spacing: 20) {
            ResizablePanelView(
                configuration: PanelConfiguration(
                    defaultSize: CGSize(width: 300, height: 200),
                    showHandles: true
                )
            ) {
                VStack {
                    Text("Resizable Panel")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Drag the corners and edges to resize this panel.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                    
                    Button("Sample Button") {}
                        .buttonStyle(.borderedProminent)
                }
            }
            
            CollapsiblePanelView {
                Text("Sync Settings")
                    .font(.headline)
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure synchronization parameters for your project.")
                    
                    HStack {
                        Text("Confidence Threshold:")
                        Spacer()
                        Text("70%")
                    }
                    
                    HStack {
                        Text("Algorithm:")
                        Spacer()
                        Text("Spectral Flux")
                    }
                }
            }
            .frame(width: 300)
        }
        .padding()
    }
