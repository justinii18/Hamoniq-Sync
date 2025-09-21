//
//  ActionButtonGroupView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct ActionButtonGroupView: View {
    let buttons: [ActionButton]
    let configuration: ButtonGroupConfiguration
    
    @State private var hoveredButtonId: UUID?
    
    init(
        buttons: [ActionButton],
        configuration: ButtonGroupConfiguration = ButtonGroupConfiguration()
    ) {
        self.buttons = buttons
        self.configuration = configuration
    }
    
    var body: some View {
        Group {
            switch configuration.layout {
            case .horizontal:
                horizontalLayout
            case .vertical:
                verticalLayout
            case .grid(let columns):
                gridLayout(columns: columns)
            }
        }
        .background {
            if configuration.showGroupBackground {
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .fill(configuration.backgroundColor)
                    .stroke(configuration.borderColor, lineWidth: configuration.borderWidth)
            }
        }
        .padding(configuration.groupPadding)
    }
    
    @ViewBuilder
    private var horizontalLayout: some View {
        HStack(spacing: configuration.spacing) {
            ForEach(buttons) { button in
                buttonView(for: button)
            }
        }
    }
    
    @ViewBuilder
    private var verticalLayout: some View {
        VStack(spacing: configuration.spacing) {
            ForEach(buttons) { button in
                buttonView(for: button)
            }
        }
    }
    
    @ViewBuilder
    private func gridLayout(columns: Int) -> some View {
        let gridItems = Array(repeating: GridItem(.flexible(), spacing: configuration.spacing), count: columns)
        
        LazyVGrid(columns: gridItems, spacing: configuration.spacing) {
            ForEach(buttons) { button in
                buttonView(for: button)
            }
        }
    }
    
    @ViewBuilder
    private func buttonView(for button: ActionButton) -> some View {
        Button {
            button.action()
        } label: {
            HStack(spacing: 8) {
                if let icon = button.icon {
                    Image(systemName: icon)
                        .font(.system(size: configuration.iconSize))
                        .foregroundColor(buttonIconColor(for: button))
                }
                
                if configuration.showLabels {
                    Text(button.title)
                        .font(.system(size: configuration.fontSize, weight: configuration.fontWeight))
                        .foregroundColor(buttonTextColor(for: button))
                }
                
                if button.showBadge, button.badgeCount > 0 {
                    badgeView(count: button.badgeCount)
                }
                
                if button.showProgress {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            .padding(configuration.buttonPadding)
            .frame(maxWidth: configuration.fillWidth ? .infinity : nil)
            .background {
                RoundedRectangle(cornerRadius: configuration.buttonCornerRadius)
                    .fill(buttonBackgroundColor(for: button))
                    .stroke(buttonBorderColor(for: button), lineWidth: configuration.buttonBorderWidth)
            }
            .scaleEffect(hoveredButtonId == button.id ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: hoveredButtonId)
        }
        .buttonStyle(.plain)
        .disabled(button.isDisabled)
        .onHover { hovering in
            hoveredButtonId = hovering ? button.id : nil
        }
        .tooltip(button.tooltip)
    }
    
    @ViewBuilder
    private func badgeView(count: Int) -> some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.red, in: Capsule())
    }
    
    private func buttonBackgroundColor(for button: ActionButton) -> Color {
        if button.isDisabled {
            return configuration.disabledBackgroundColor
        }
        
        if hoveredButtonId == button.id {
            return button.style.hoverBackgroundColor
        }
        
        return button.style.backgroundColor
    }
    
    private func buttonBorderColor(for button: ActionButton) -> Color {
        if button.isDisabled {
            return configuration.disabledBorderColor
        }
        
        return button.style.borderColor
    }
    
    private func buttonTextColor(for button: ActionButton) -> Color {
        if button.isDisabled {
            return configuration.disabledTextColor
        }
        
        if hoveredButtonId == button.id {
            return button.style.hoverTextColor
        }
        
        return button.style.textColor
    }
    
    private func buttonIconColor(for button: ActionButton) -> Color {
        if button.isDisabled {
            return configuration.disabledTextColor
        }
        
        if hoveredButtonId == button.id {
            return button.style.hoverIconColor ?? button.style.hoverTextColor
        }
        
        return button.style.iconColor ?? button.style.textColor
    }
}

struct ActionButton: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    let tooltip: String
    let isDisabled: Bool
    let showBadge: Bool
    let badgeCount: Int
    let showProgress: Bool
    
    init(
        title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void,
        tooltip: String = "",
        isDisabled: Bool = false,
        showBadge: Bool = false,
        badgeCount: Int = 0,
        showProgress: Bool = false
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
        self.tooltip = tooltip.isEmpty ? title : tooltip
        self.isDisabled = isDisabled
        self.showBadge = showBadge
        self.badgeCount = badgeCount
        self.showProgress = showProgress
    }
}

enum ButtonStyle {
    case primary
    case secondary
    case destructive
    case success
    case warning
    case subtle
    case custom(
        backgroundColor: Color,
        textColor: Color,
        borderColor: Color,
        hoverBackgroundColor: Color,
        hoverTextColor: Color,
        iconColor: Color? = nil,
        hoverIconColor: Color? = nil
    )
    
    var backgroundColor: Color {
        switch self {
        case .primary: return .blue
        case .secondary: return Color(.controlBackgroundColor)
        case .destructive: return .red
        case .success: return .green
        case .warning: return .orange
        case .subtle: return .clear
        case .custom(let backgroundColor, _, _, _, _, _, _): return backgroundColor
        }
    }
    
    var textColor: Color {
        switch self {
        case .primary, .destructive, .success, .warning: return .white
        case .secondary, .subtle: return .primary
        case .custom(_, let textColor, _, _, _, _, _): return textColor
        }
    }
    
    var borderColor: Color {
        switch self {
        case .primary: return .blue
        case .secondary: return Color(.separatorColor)
        case .destructive: return .red
        case .success: return .green
        case .warning: return .orange
        case .subtle: return .clear
        case .custom(_, _, let borderColor, _, _, _, _): return borderColor
        }
    }
    
    var hoverBackgroundColor: Color {
        switch self {
        case .primary: return .blue.opacity(0.8)
        case .secondary: return Color(.controlBackgroundColor).opacity(0.8)
        case .destructive: return .red.opacity(0.8)
        case .success: return .green.opacity(0.8)
        case .warning: return .orange.opacity(0.8)
        case .subtle: return Color(.controlBackgroundColor).opacity(0.3)
        case .custom(_, _, _, let hoverBackgroundColor, _, _, _): return hoverBackgroundColor
        }
    }
    
    var hoverTextColor: Color {
        switch self {
        case .primary, .destructive, .success, .warning: return .white
        case .secondary, .subtle: return .primary
        case .custom(_, _, _, _, let hoverTextColor, _, _): return hoverTextColor
        }
    }
    
    var iconColor: Color? {
        switch self {
        case .custom(_, _, _, _, _, let iconColor, _): return iconColor
        default: return nil
        }
    }
    
    var hoverIconColor: Color? {
        switch self {
        case .custom(_, _, _, _, _, _, let hoverIconColor): return hoverIconColor
        default: return nil
        }
    }
}

struct ButtonGroupConfiguration {
    let layout: GroupLayout
    let spacing: CGFloat
    let showLabels: Bool
    let fillWidth: Bool
    let showGroupBackground: Bool
    let backgroundColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let groupPadding: EdgeInsets
    let buttonPadding: EdgeInsets
    let buttonCornerRadius: CGFloat
    let buttonBorderWidth: CGFloat
    let iconSize: CGFloat
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let disabledBackgroundColor: Color
    let disabledTextColor: Color
    let disabledBorderColor: Color
    
    init(
        layout: GroupLayout = .horizontal,
        spacing: CGFloat = 8,
        showLabels: Bool = true,
        fillWidth: Bool = false,
        showGroupBackground: Bool = false,
        backgroundColor: Color = Color(.controlBackgroundColor),
        borderColor: Color = Color(.separatorColor),
        borderWidth: CGFloat = 1,
        cornerRadius: CGFloat = 8,
        groupPadding: EdgeInsets = EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8),
        buttonPadding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12),
        buttonCornerRadius: CGFloat = 6,
        buttonBorderWidth: CGFloat = 1,
        iconSize: CGFloat = 16,
        fontSize: CGFloat = 14,
        fontWeight: Font.Weight = .medium,
        disabledBackgroundColor: Color = Color(.controlBackgroundColor).opacity(0.5),
        disabledTextColor: Color = Color(.disabledControlTextColor),
        disabledBorderColor: Color = Color(.separatorColor).opacity(0.5)
    ) {
        self.layout = layout
        self.spacing = spacing
        self.showLabels = showLabels
        self.fillWidth = fillWidth
        self.showGroupBackground = showGroupBackground
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.groupPadding = groupPadding
        self.buttonPadding = buttonPadding
        self.buttonCornerRadius = buttonCornerRadius
        self.buttonBorderWidth = buttonBorderWidth
        self.iconSize = iconSize
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.disabledBackgroundColor = disabledBackgroundColor
        self.disabledTextColor = disabledTextColor
        self.disabledBorderColor = disabledBorderColor
    }
}

enum GroupLayout {
    case horizontal
    case vertical
    case grid(columns: Int)
}

// MARK: - Specialized Button Groups

struct SyncControlButtonGroup: View {
    let onStart: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void
    let onSettings: () -> Void
    let isRunning: Bool
    let isPaused: Bool
    
    var body: some View {
        ActionButtonGroupView(
            buttons: [
                ActionButton(
                    title: isRunning ? (isPaused ? "Resume" : "Pause") : "Start",
                    icon: isRunning ? (isPaused ? "play.fill" : "pause.fill") : "play.fill",
                    style: .primary,
                    action: isRunning && !isPaused ? onPause : onStart,
                    tooltip: isRunning ? (isPaused ? "Resume sync process" : "Pause sync process") : "Start synchronization"
                ),
                ActionButton(
                    title: "Stop",
                    icon: "stop.fill",
                    style: .destructive,
                    action: onStop,
                    tooltip: "Stop sync process",
                    isDisabled: !isRunning
                ),
                ActionButton(
                    title: "Settings",
                    icon: "gear",
                    style: .secondary,
                    action: onSettings,
                    tooltip: "Sync settings"
                )
            ],
            configuration: ButtonGroupConfiguration(
                layout: .horizontal,
                showGroupBackground: true
            )
        )
    }
}

struct MediaControlButtonGroup: View {
    let onImport: () -> Void
    let onGroup: () -> Void
    let onClear: () -> Void
    let importCount: Int
    
    var body: some View {
        ActionButtonGroupView(
            buttons: [
                ActionButton(
                    title: "Import",
                    icon: "square.and.arrow.down",
                    style: .primary,
                    action: onImport,
                    tooltip: "Import media files"
                ),
                ActionButton(
                    title: "Group",
                    icon: "rectangle.3.group",
                    style: .secondary,
                    action: onGroup,
                    tooltip: "Auto-group media files",
                    isDisabled: importCount == 0,
                    showBadge: true,
                    badgeCount: importCount
                ),
                ActionButton(
                    title: "Clear",
                    icon: "trash",
                    style: .destructive,
                    action: onClear,
                    tooltip: "Clear all imported files",
                    isDisabled: importCount == 0
                )
            ],
            configuration: ButtonGroupConfiguration(
                layout: .horizontal,
                fillWidth: true
            )
        )
    }
}

struct ExportButtonGroup: View {
    let onQuickExport: () -> Void
    let onCustomExport: () -> Void
    let onPreview: () -> Void
    let isExporting: Bool
    
    var body: some View {
        ActionButtonGroupView(
            buttons: [
                ActionButton(
                    title: "Quick Export",
                    icon: "square.and.arrow.up",
                    style: .success,
                    action: onQuickExport,
                    tooltip: "Export with default settings",
                    showProgress: isExporting
                ),
                ActionButton(
                    title: "Custom Export",
                    icon: "gearshape",
                    style: .secondary,
                    action: onCustomExport,
                    tooltip: "Export with custom settings"
                ),
                ActionButton(
                    title: "Preview",
                    icon: "eye",
                    style: .subtle,
                    action: onPreview,
                    tooltip: "Preview export results"
                )
            ],
            configuration: ButtonGroupConfiguration(
                layout: .vertical,
                fillWidth: true,
                showGroupBackground: true
            )
        )
    }
}

#Preview {
    VStack(spacing: 30) {
        SyncControlButtonGroup(
            onStart: {},
            onPause: {},
            onStop: {},
            onSettings: {},
            isRunning: false,
            isPaused: false
        )
        
        MediaControlButtonGroup(
            onImport: {},
            onGroup: {},
            onClear: {},
            importCount: 5
        )
        
        ExportButtonGroup(
            onQuickExport: {},
            onCustomExport: {},
            onPreview: {},
            isExporting: false
        )
        
        ActionButtonGroupView(
            buttons: [
                ActionButton(title: "Grid 1", icon: "1.circle", style: .primary, action: {}),
                ActionButton(title: "Grid 2", icon: "2.circle", style: .secondary, action: {}),
                ActionButton(title: "Grid 3", icon: "3.circle", style: .success, action: {}),
                ActionButton(title: "Grid 4", icon: "4.circle", style: .warning, action: {})
            ],
            configuration: ButtonGroupConfiguration(
                layout: .grid(columns: 2),
                fillWidth: true,
                showGroupBackground: true
            )
        )
    }
    .padding()
}