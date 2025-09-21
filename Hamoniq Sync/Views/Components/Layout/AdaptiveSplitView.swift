//
//  AdaptiveSplitView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct AdaptiveSplitView<Sidebar: View, Detail: View>: View {
    let sidebar: Sidebar
    let detail: Detail
    let configuration: SplitConfiguration
    
    @State private var sidebarWidth: CGFloat
    @State private var isDragging = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    init(
        configuration: SplitConfiguration = SplitConfiguration(),
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebar = sidebar()
        self.detail = detail()
        self.configuration = configuration
        self._sidebarWidth = State(initialValue: configuration.defaultSidebarWidth)
    }
    
    var body: some View {
        GeometryReader { geometry in
            if shouldUseCompactLayout(geometry: geometry) {
                compactLayout
            } else {
                regularLayout(geometry: geometry)
            }
        }
    }
    
    @ViewBuilder
    private var compactLayout: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(ideal: configuration.defaultSidebarWidth)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    @ViewBuilder
    private func regularLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            sidebarSection
                .frame(width: sidebarWidth)
                .clipped()
            
            resizeHandle
            
            detailSection
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var sidebarSection: some View {
        sidebar
            .background(Color(.controlBackgroundColor))
            .overlay(alignment: .trailing) {
                if configuration.showSidebarBorder {
                    Rectangle()
                        .fill(Color(.separatorColor))
                        .frame(width: 1)
                }
            }
    }
    
    @ViewBuilder
    private var detailSection: some View {
        detail
            .background(Color(.windowBackgroundColor))
    }
    
    @ViewBuilder
    private var resizeHandle: some View {
        Rectangle()
            .fill(isDragging ? .blue.opacity(0.3) : .clear)
            .frame(width: configuration.resizeHandleWidth)
            .contentShape(Rectangle())
            .cursor(.resizeLeftRight)
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        
                        let newWidth = sidebarWidth + value.translation.width
                        sidebarWidth = clampSidebarWidth(newWidth)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
    
    private func shouldUseCompactLayout(geometry: GeometryProxy) -> Bool {
        if configuration.forceRegularLayout {
            return false
        }
        
        return horizontalSizeClass == .compact || 
               geometry.size.width < configuration.compactThreshold
    }
    
    private func clampSidebarWidth(_ width: CGFloat) -> CGFloat {
        max(configuration.minSidebarWidth, 
            min(configuration.maxSidebarWidth, width))
    }
}

struct SplitConfiguration {
    let defaultSidebarWidth: CGFloat
    let minSidebarWidth: CGFloat
    let maxSidebarWidth: CGFloat
    let resizeHandleWidth: CGFloat
    let compactThreshold: CGFloat
    let showSidebarBorder: Bool
    let forceRegularLayout: Bool
    
    init(
        defaultSidebarWidth: CGFloat = 280,
        minSidebarWidth: CGFloat = 200,
        maxSidebarWidth: CGFloat = 400,
        resizeHandleWidth: CGFloat = 8,
        compactThreshold: CGFloat = 800,
        showSidebarBorder: Bool = true,
        forceRegularLayout: Bool = false
    ) {
        self.defaultSidebarWidth = defaultSidebarWidth
        self.minSidebarWidth = minSidebarWidth
        self.maxSidebarWidth = maxSidebarWidth
        self.resizeHandleWidth = resizeHandleWidth
        self.compactThreshold = compactThreshold
        self.showSidebarBorder = showSidebarBorder
        self.forceRegularLayout = forceRegularLayout
    }
}

// MARK: - Cursor Support

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Three Pane Split View

struct ThreePaneSplitView<Leading: View, Center: View, Trailing: View>: View {
    let leading: Leading
    let center: Center
    let trailing: Trailing
    let configuration: ThreePaneConfiguration
    
    @State private var leadingWidth: CGFloat
    @State private var trailingWidth: CGFloat
    @State private var isDraggingLeading = false
    @State private var isDraggingTrailing = false
    
    init(
        configuration: ThreePaneConfiguration = ThreePaneConfiguration(),
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
        self.configuration = configuration
        self._leadingWidth = State(initialValue: configuration.defaultLeadingWidth)
        self._trailingWidth = State(initialValue: configuration.defaultTrailingWidth)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            leadingPanel
                .frame(width: leadingWidth)
                .clipped()
            
            leadingResizeHandle
            
            centerPanel
                .frame(maxWidth: .infinity)
            
            trailingResizeHandle
            
            trailingPanel
                .frame(width: trailingWidth)
                .clipped()
        }
    }
    
    @ViewBuilder
    private var leadingPanel: some View {
        leading
            .background(Color(.controlBackgroundColor))
            .overlay(alignment: .trailing) {
                if configuration.showBorders {
                    Rectangle()
                        .fill(Color(.separatorColor))
                        .frame(width: 1)
                }
            }
    }
    
    @ViewBuilder
    private var centerPanel: some View {
        center
            .background(Color(.windowBackgroundColor))
    }
    
    @ViewBuilder
    private var trailingPanel: some View {
        trailing
            .background(Color(.controlBackgroundColor))
            .overlay(alignment: .leading) {
                if configuration.showBorders {
                    Rectangle()
                        .fill(Color(.separatorColor))
                        .frame(width: 1)
                }
            }
    }
    
    @ViewBuilder
    private var leadingResizeHandle: some View {
        Rectangle()
            .fill(isDraggingLeading ? .blue.opacity(0.3) : .clear)
            .frame(width: configuration.resizeHandleWidth)
            .contentShape(Rectangle())
            .cursor(.resizeLeftRight)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDraggingLeading {
                            isDraggingLeading = true
                        }
                        
                        let newWidth = leadingWidth + value.translation.width
                        leadingWidth = clampLeadingWidth(newWidth)
                    }
                    .onEnded { _ in
                        isDraggingLeading = false
                    }
            )
    }
    
    @ViewBuilder
    private var trailingResizeHandle: some View {
        Rectangle()
            .fill(isDraggingTrailing ? .blue.opacity(0.3) : .clear)
            .frame(width: configuration.resizeHandleWidth)
            .contentShape(Rectangle())
            .cursor(.resizeLeftRight)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDraggingTrailing {
                            isDraggingTrailing = true
                        }
                        
                        let newWidth = trailingWidth - value.translation.width
                        trailingWidth = clampTrailingWidth(newWidth)
                    }
                    .onEnded { _ in
                        isDraggingTrailing = false
                    }
            )
    }
    
    private func clampLeadingWidth(_ width: CGFloat) -> CGFloat {
        max(configuration.minLeadingWidth,
            min(configuration.maxLeadingWidth, width))
    }
    
    private func clampTrailingWidth(_ width: CGFloat) -> CGFloat {
        max(configuration.minTrailingWidth,
            min(configuration.maxTrailingWidth, width))
    }
}

struct ThreePaneConfiguration {
    let defaultLeadingWidth: CGFloat
    let defaultTrailingWidth: CGFloat
    let minLeadingWidth: CGFloat
    let maxLeadingWidth: CGFloat
    let minTrailingWidth: CGFloat
    let maxTrailingWidth: CGFloat
    let resizeHandleWidth: CGFloat
    let showBorders: Bool
    
    init(
        defaultLeadingWidth: CGFloat = 250,
        defaultTrailingWidth: CGFloat = 300,
        minLeadingWidth: CGFloat = 180,
        maxLeadingWidth: CGFloat = 400,
        minTrailingWidth: CGFloat = 200,
        maxTrailingWidth: CGFloat = 500,
        resizeHandleWidth: CGFloat = 8,
        showBorders: Bool = true
    ) {
        self.defaultLeadingWidth = defaultLeadingWidth
        self.defaultTrailingWidth = defaultTrailingWidth
        self.minLeadingWidth = minLeadingWidth
        self.maxLeadingWidth = maxLeadingWidth
        self.minTrailingWidth = minTrailingWidth
        self.maxTrailingWidth = maxTrailingWidth
        self.resizeHandleWidth = resizeHandleWidth
        self.showBorders = showBorders
    }
}

#Preview {
    AdaptiveSplitView(
        configuration: SplitConfiguration(forceRegularLayout: true)
    ) {
        VStack {
            Text("Sidebar Content")
                .font(.title2)
                .padding()
            
            List(1...10, id: \.self) { item in
                Text("Item \(item)")
                    .padding(.vertical, 4)
            }
        }
    } detail: {
        VStack {
            Text("Detail Content")
                .font(.largeTitle)
                .padding()
            
            Text("This is the main content area that adapts to the available space.")
                .padding()
            
            Spacer()
        }
    }
    .frame(height: 600)
}