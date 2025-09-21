//
//  ContextualSidebarView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct ContextualSidebarView<Content: View>: View {
    let content: Content
    let configuration: SidebarConfiguration
    
    @State private var isVisible: Bool
    @State private var sidebarWidth: CGFloat
    @State private var isDragging = false
    @Namespace private var sidebarNamespace
    
    init(
        isVisible: Bool = true,
        configuration: SidebarConfiguration = SidebarConfiguration(),
        @ViewBuilder content: () -> Content
    ) {
        self._isVisible = State(initialValue: isVisible)
        self._sidebarWidth = State(initialValue: configuration.defaultWidth)
        self.configuration = configuration
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if isVisible {
                sidebarContent
                    .matchedGeometryEffect(id: "sidebar", in: sidebarNamespace)
                    .transition(sidebarTransition)
            }
            
            Spacer()
        }
        .animation(configuration.animationStyle, value: isVisible)
    }
    
    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            if configuration.showHeader {
                sidebarHeader
            }
            
            content
                .frame(maxHeight: .infinity)
            
            if configuration.showFooter {
                sidebarFooter
            }
        }
        .frame(width: sidebarWidth)
        .background(configuration.backgroundColor)
        .overlay(alignment: .trailing) {
            if configuration.showBorder {
                Rectangle()
                    .fill(configuration.borderColor)
                    .frame(width: 1)
            }
        }
        .overlay(alignment: .trailing) {
            if configuration.isResizable {
                resizeHandle
            }
        }
    }
    
    @ViewBuilder
    private var sidebarHeader: some View {
        HStack {
            Text(configuration.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            if configuration.showCollapseButton {
                Button {
                    isVisible = false
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .tooltip("Hide Sidebar")
            }
        }
        .padding(configuration.headerPadding)
        .background(Color(.controlBackgroundColor))
        
        if configuration.showHeaderDivider {
            Divider()
        }
    }
    
    @ViewBuilder
    private var sidebarFooter: some View {
        if configuration.showFooterDivider {
            Divider()
        }
        
        HStack {
            Text("\(configuration.itemCount) items")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(configuration.footerPadding)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
    
    @ViewBuilder
    private var resizeHandle: some View {
        Rectangle()
            .fill(isDragging ? .blue.opacity(0.3) : .clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .cursor(.resizeLeftRight)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        
                        let newWidth = sidebarWidth + value.translation.width
                        sidebarWidth = clampWidth(newWidth)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
    }
    
    private var sidebarTransition: AnyTransition {
        switch configuration.position {
        case .leading:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .trailing:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
    
    private func clampWidth(_ width: CGFloat) -> CGFloat {
        max(configuration.minWidth, min(configuration.maxWidth, width))
    }
    
    func toggleVisibility() {
        isVisible.toggle()
    }
    
    func show() {
        isVisible = true
    }
    
    func hide() {
        isVisible = false
    }
}

struct SidebarConfiguration {
    let position: SidebarPosition
    let defaultWidth: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let isResizable: Bool
    let showBorder: Bool
    let backgroundColor: Color
    let borderColor: Color
    let animationStyle: Animation
    
    // Header configuration
    let showHeader: Bool
    let title: String
    let showCollapseButton: Bool
    let showHeaderDivider: Bool
    let headerPadding: EdgeInsets
    
    // Footer configuration
    let showFooter: Bool
    let itemCount: Int
    let showFooterDivider: Bool
    let footerPadding: EdgeInsets
    
    init(
        position: SidebarPosition = .leading,
        defaultWidth: CGFloat = 280,
        minWidth: CGFloat = 200,
        maxWidth: CGFloat = 400,
        isResizable: Bool = true,
        showBorder: Bool = true,
        backgroundColor: Color = Color(.controlBackgroundColor),
        borderColor: Color = Color(.separatorColor),
        animationStyle: Animation = .easeInOut(duration: 0.3),
        showHeader: Bool = true,
        title: String = "Sidebar",
        showCollapseButton: Bool = true,
        showHeaderDivider: Bool = true,
        headerPadding: EdgeInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
        showFooter: Bool = false,
        itemCount: Int = 0,
        showFooterDivider: Bool = true,
        footerPadding: EdgeInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    ) {
        self.position = position
        self.defaultWidth = defaultWidth
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.isResizable = isResizable
        self.showBorder = showBorder
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.animationStyle = animationStyle
        self.showHeader = showHeader
        self.title = title
        self.showCollapseButton = showCollapseButton
        self.showHeaderDivider = showHeaderDivider
        self.headerPadding = headerPadding
        self.showFooter = showFooter
        self.itemCount = itemCount
        self.showFooterDivider = showFooterDivider
        self.footerPadding = footerPadding
    }
}

enum SidebarPosition {
    case leading
    case trailing
}

// MARK: - Tab Container View

struct TabContainerView<Content: View>: View {
    let tabs: [TabItem]
    let content: Content
    let configuration: TabConfiguration
    
    @State private var selectedTabIndex: Int = 0
    
    init(
        tabs: [TabItem],
        configuration: TabConfiguration = TabConfiguration(),
        @ViewBuilder content: () -> Content
    ) {
        self.tabs = tabs
        self.configuration = configuration
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            tabBar
            
            Divider()
            
            contentArea
        }
        .background(configuration.backgroundColor)
    }
    
    @ViewBuilder
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: configuration.tabSpacing) {
                ForEach(tabs.indices, id: \.self) { index in
                    tabButton(for: tabs[index], at: index)
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, configuration.tabBarPadding.leading)
            .padding(.vertical, configuration.tabBarPadding.top)
        }
        .background(configuration.tabBarBackground)
    }
    
    @ViewBuilder
    private func tabButton(for tab: TabItem, at index: Int) -> some View {
        Button {
            selectedTabIndex = index
        } label: {
            HStack(spacing: 8) {
                if let icon = tab.icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }
                
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
                
                if tab.showBadge, tab.badgeCount > 0 {
                    Text("\(tab.badgeCount)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red, in: Capsule())
                        .foregroundColor(.white)
                }
                
                if tab.isCloseable {
                    Button {
                        // Handle tab close
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if index == selectedTabIndex {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(configuration.selectedTabColor)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.clear)
                }
            }
            .foregroundColor(index == selectedTabIndex ? .primary : .secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var contentArea: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func selectTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        selectedTabIndex = index
    }
    
    var selectedTab: TabItem? {
        guard selectedTabIndex < tabs.count else { return nil }
        return tabs[selectedTabIndex]
    }
}

struct TabItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let isCloseable: Bool
    let showBadge: Bool
    let badgeCount: Int
    
    init(
        title: String,
        icon: String? = nil,
        isCloseable: Bool = false,
        showBadge: Bool = false,
        badgeCount: Int = 0
    ) {
        self.title = title
        self.icon = icon
        self.isCloseable = isCloseable
        self.showBadge = showBadge
        self.badgeCount = badgeCount
    }
}

struct TabConfiguration {
    let backgroundColor: Color
    let tabBarBackground: Color
    let selectedTabColor: Color
    let tabSpacing: CGFloat
    let tabBarPadding: EdgeInsets
    
    init(
        backgroundColor: Color = Color(.windowBackgroundColor),
        tabBarBackground: Color = Color(.controlBackgroundColor),
        selectedTabColor: Color = Color(.selectedContentBackgroundColor),
        tabSpacing: CGFloat = 4,
        tabBarPadding: EdgeInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    ) {
        self.backgroundColor = backgroundColor
        self.tabBarBackground = tabBarBackground
        self.selectedTabColor = selectedTabColor
        self.tabSpacing = tabSpacing
        self.tabBarPadding = tabBarPadding
    }
}

#Preview {
    VStack(spacing: 30) {
        ContextualSidebarView(
            configuration: SidebarConfiguration(
                title: "Project Files",
                showFooter: true,
                itemCount: 12
            )
        ) {
            List(1...10, id: \.self) { item in
                HStack {
                    Image(systemName: "doc.audio")
                        .foregroundColor(.blue)
                    Text("Audio File \(item).wav")
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .listStyle(.sidebar)
        }
        .frame(height: 400)
        
        TabContainerView(
            tabs: [
                TabItem(title: "Import", icon: "square.and.arrow.down"),
                TabItem(title: "Sync", icon: "arrow.triangle.2.circlepath", showBadge: true, badgeCount: 3),
                TabItem(title: "Results", icon: "chart.bar.xaxis"),
                TabItem(title: "Export", icon: "square.and.arrow.up")
            ]
        ) {
            VStack {
                Text("Tab Content Area")
                    .font(.title2)
                    .padding()
                
                Text("Content for the selected tab would appear here.")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .frame(height: 300)
    }
    .padding()
}