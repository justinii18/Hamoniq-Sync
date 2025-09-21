//
//  EmptyStateView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct EmptyStateView: View {
    let configuration: EmptyStateConfiguration
    let primaryAction: (() -> Void)?
    let secondaryAction: (() -> Void)?
    
    init(
        configuration: EmptyStateConfiguration,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
    }
    
    var body: some View {
        VStack(spacing: configuration.spacing) {
            iconSection
            
            textSection
            
            if primaryAction != nil || secondaryAction != nil {
                actionSection
            }
        }
        .padding(configuration.padding)
        .frame(maxWidth: configuration.maxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(configuration.backgroundColor)
        .multilineTextAlignment(.center)
    }
    
    @ViewBuilder
    private var iconSection: some View {
        ZStack {
            if configuration.showIconBackground {
                Circle()
                    .fill(configuration.iconBackgroundColor)
                    .frame(width: configuration.iconSize + 20, height: configuration.iconSize + 20)
            }
            
            Group {
                if let systemImage = configuration.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: configuration.iconSize, weight: .medium))
                } else if let customImage = configuration.customImage {
                    Image(customImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: configuration.iconSize, height: configuration.iconSize)
                } else {
                    // Default empty state icon
                    Image(systemName: "tray")
                        .font(.system(size: configuration.iconSize, weight: .medium))
                }
            }
            .foregroundColor(configuration.iconColor)
        }
    }
    
    @ViewBuilder
    private var textSection: some View {
        VStack(spacing: 8) {
            Text(configuration.title)
                .font(configuration.titleFont)
                .fontWeight(configuration.titleFontWeight)
                .foregroundColor(configuration.titleColor)
            
            if let subtitle = configuration.subtitle {
                Text(subtitle)
                    .font(configuration.subtitleFont)
                    .foregroundColor(configuration.subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let description = configuration.description {
                Text(description)
                    .font(configuration.descriptionFont)
                    .foregroundColor(configuration.descriptionColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    @ViewBuilder
    private var actionSection: some View {
        VStack(spacing: 12) {
            if let primaryAction = primaryAction, let primaryTitle = configuration.primaryActionTitle {
                Button(primaryTitle) {
                    primaryAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            
            if let secondaryAction = secondaryAction, let secondaryTitle = configuration.secondaryActionTitle {
                Button(secondaryTitle) {
                    secondaryAction()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }
}

struct EmptyStateConfiguration {
    let title: String
    let subtitle: String?
    let description: String?
    let systemImage: String?
    let customImage: String?
    let primaryActionTitle: String?
    let secondaryActionTitle: String?
    
    // Styling
    let iconSize: CGFloat
    let iconColor: Color
    let showIconBackground: Bool
    let iconBackgroundColor: Color
    let spacing: CGFloat
    let padding: EdgeInsets
    let maxWidth: CGFloat?
    let backgroundColor: Color
    
    // Typography
    let titleFont: Font
    let titleFontWeight: Font.Weight
    let titleColor: Color
    let subtitleFont: Font
    let subtitleColor: Color
    let descriptionFont: Font
    let descriptionColor: Color
    
    init(
        title: String,
        subtitle: String? = nil,
        description: String? = nil,
        systemImage: String? = nil,
        customImage: String? = nil,
        primaryActionTitle: String? = nil,
        secondaryActionTitle: String? = nil,
        iconSize: CGFloat = 48,
        iconColor: Color = .secondary,
        showIconBackground: Bool = true,
        iconBackgroundColor: Color = Color.secondary.opacity(0.1),
        spacing: CGFloat = 20,
        padding: EdgeInsets = EdgeInsets(top: 40, leading: 40, bottom: 40, trailing: 40),
        maxWidth: CGFloat? = 400,
        backgroundColor: Color = .clear,
        titleFont: Font = .title2,
        titleFontWeight: Font.Weight = .semibold,
        titleColor: Color = .primary,
        subtitleFont: Font = .body,
        subtitleColor: Color = .secondary,
        descriptionFont: Font = .callout,
        descriptionColor: Color = .secondary
    ) {
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.systemImage = systemImage
        self.customImage = customImage
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.iconSize = iconSize
        self.iconColor = iconColor
        self.showIconBackground = showIconBackground
        self.iconBackgroundColor = iconBackgroundColor
        self.spacing = spacing
        self.padding = padding
        self.maxWidth = maxWidth
        self.backgroundColor = backgroundColor
        self.titleFont = titleFont
        self.titleFontWeight = titleFontWeight
        self.titleColor = titleColor
        self.subtitleFont = subtitleFont
        self.subtitleColor = subtitleColor
        self.descriptionFont = descriptionFont
        self.descriptionColor = descriptionColor
    }
}

// MARK: - Specialized Empty States

struct NoProjectsEmptyState: View {
    let onCreateProject: () -> Void
    let onImportProject: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                title: "No Projects Yet",
                subtitle: "Create your first project to get started",
                description: "Projects help you organize and synchronize your audio and video files for multicam workflows.",
                systemImage: "folder.badge.plus",
                primaryActionTitle: "Create Project",
                secondaryActionTitle: onImportProject != nil ? "Import Project" : nil,
                iconColor: .blue,
                iconBackgroundColor: .blue.opacity(0.1)
            ),
            primaryAction: onCreateProject,
            secondaryAction: onImportProject
        )
    }
}

struct NoMediaEmptyState: View {
    let onImportMedia: () -> Void
    let onBrowseFiles: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                title: "No Media Files",
                subtitle: "Import audio and video files to begin",
                description: "Drag and drop files or use the import button to add media to your project.",
                systemImage: "waveform.and.person.filled",
                primaryActionTitle: "Import Files",
                secondaryActionTitle: onBrowseFiles != nil ? "Browse Files" : nil,
                iconColor: .green,
                iconBackgroundColor: .green.opacity(0.1)
            ),
            primaryAction: onImportMedia,
            secondaryAction: onBrowseFiles
        )
    }
}

struct NoSyncResultsEmptyState: View {
    let onStartSync: () -> Void
    let onLearnMore: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                title: "No Sync Results",
                subtitle: "Run synchronization to see results",
                description: "Synchronize your media files to analyze timing relationships and generate alignment data.",
                systemImage: "arrow.triangle.2.circlepath",
                primaryActionTitle: "Start Sync",
                secondaryActionTitle: onLearnMore != nil ? "Learn More" : nil,
                iconColor: .purple,
                iconBackgroundColor: .purple.opacity(0.1)
            ),
            primaryAction: onStartSync,
            secondaryAction: onLearnMore
        )
    }
}

struct SearchEmptyState: View {
    let searchQuery: String
    let onClearSearch: () -> Void
    let onRefineSearch: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                title: "No Results Found",
                subtitle: "No items match '\(searchQuery)'",
                description: "Try adjusting your search terms or clearing the search to see all items.",
                systemImage: "magnifyingglass",
                primaryActionTitle: "Clear Search",
                secondaryActionTitle: onRefineSearch != nil ? "Search Tips" : nil,
                iconColor: .orange,
                iconBackgroundColor: .orange.opacity(0.1)
            ),
            primaryAction: onClearSearch,
            secondaryAction: onRefineSearch
        )
    }
}

struct NetworkEmptyState: View {
    let onRetry: () -> Void
    let onOfflineMode: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                title: "Connection Lost",
                subtitle: "Unable to load content",
                description: "Check your internet connection and try again, or continue working offline.",
                systemImage: "wifi.exclamationmark",
                primaryActionTitle: "Retry",
                secondaryActionTitle: onOfflineMode != nil ? "Work Offline" : nil,
                iconColor: .red,
                iconBackgroundColor: .red.opacity(0.1)
            ),
            primaryAction: onRetry,
            secondaryAction: onOfflineMode
        )
    }
}

struct MaintenanceEmptyState: View {
    let estimatedTime: String?
    let onCheckStatus: (() -> Void)?
    
    var body: some View {
        EmptyStateView(
            configuration: EmptyStateConfiguration(
                title: "Temporary Maintenance",
                subtitle: "Service is currently unavailable",
                description: estimatedTime != nil ? 
                    "We're performing scheduled maintenance. Estimated completion: \(estimatedTime!)" :
                    "We're performing scheduled maintenance. Please check back shortly.",
                systemImage: "wrench.and.screwdriver",
                primaryActionTitle: onCheckStatus != nil ? "Check Status" : nil,
                iconColor: .yellow,
                iconBackgroundColor: .yellow.opacity(0.1)
            ),
            primaryAction: onCheckStatus
        )
    }
}

// MARK: - Empty State with Animation

struct AnimatedEmptyStateView: View {
    let configuration: EmptyStateConfiguration
    let primaryAction: (() -> Void)?
    let secondaryAction: (() -> Void)?
    
    @State private var isVisible = false
    @State private var iconScale: CGFloat = 0.8
    
    var body: some View {
        EmptyStateView(
            configuration: configuration,
            primaryAction: primaryAction,
            secondaryAction: secondaryAction
        )
        .scaleEffect(isVisible ? 1 : 0.95)
        .opacity(isVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.6), value: isVisible)
        .onAppear {
            isVisible = true
            
            // Animate icon with a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    iconScale = 1.0
                }
            }
        }
    }
}

// MARK: - Contextual Empty State Container

struct ContextualEmptyStateContainer<Content: View>: View {
    let isEmpty: Bool
    let emptyStateView: AnyView
    let content: Content
    
    init(
        isEmpty: Bool,
        @ViewBuilder emptyStateView: () -> some View,
        @ViewBuilder content: () -> Content
    ) {
        self.isEmpty = isEmpty
        self.emptyStateView = AnyView(emptyStateView())
        self.content = content()
    }
    
    var body: some View {
        if isEmpty {
            emptyStateView
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else {
            content
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

#Preview {
    TabView {
        NoProjectsEmptyState(
            onCreateProject: { print("Create project") },
            onImportProject: { print("Import project") }
        )
        .tabItem {
            Label("No Projects", systemImage: "folder")
        }
        
        NoMediaEmptyState(
            onImportMedia: { print("Import media") },
            onBrowseFiles: { print("Browse files") }
        )
        .tabItem {
            Label("No Media", systemImage: "waveform")
        }
        
        SearchEmptyState(
            searchQuery: "test query",
            onClearSearch: { print("Clear search") },
            onRefineSearch: { print("Refine search") }
        )
        .tabItem {
            Label("Search", systemImage: "magnifyingglass")
        }
        
        NetworkEmptyState(
            onRetry: { print("Retry") },
            onOfflineMode: { print("Offline mode") }
        )
        .tabItem {
            Label("Network", systemImage: "wifi")
        }
    }
    .frame(height: 500)
}