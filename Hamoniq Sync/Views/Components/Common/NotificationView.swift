//
//  NotificationView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct NotificationView: View {
    let notification: AppNotification
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var dismissTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 12) {
            notificationIcon
            
            VStack(alignment: .leading, spacing: 4) {
                if let title = notification.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text(notification.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            if notification.isDismissible {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .stroke(notification.type.borderColor, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            isVisible = true
            scheduleAutoDismiss()
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }
    
    @ViewBuilder
    private var notificationIcon: some View {
        Image(systemName: notification.type.iconName)
            .font(.title2)
            .foregroundColor(notification.type.iconColor)
            .frame(width: 24, height: 24)
    }
    
    private func dismiss() {
        dismissTask?.cancel()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func scheduleAutoDismiss() {
        guard let duration = notification.autoDismissAfter else { return }
        
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

struct AppNotification: Identifiable, Equatable {
    let id = UUID()
    let type: NotificationType
    let title: String?
    let message: String
    let autoDismissAfter: TimeInterval?
    let isDismissible: Bool
    let action: NotificationAction?
    
    init(
        type: NotificationType,
        title: String? = nil,
        message: String,
        autoDismissAfter: TimeInterval? = 5.0,
        isDismissible: Bool = true,
        action: NotificationAction? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.autoDismissAfter = autoDismissAfter
        self.isDismissible = isDismissible
        self.action = action
    }
    
    static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        lhs.id == rhs.id
    }
}

enum NotificationType {
    case success
    case warning
    case error
    case info
    case sync
    case mediaImport
    case export
    
    var iconName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.circle.fill"
        case .info: "info.circle.fill"
        case .sync: "arrow.triangle.2.circlepath"
        case .mediaImport: "square.and.arrow.down"
        case .export: "square.and.arrow.up"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .success: .green
        case .warning: .orange
        case .error: .red
        case .info: .blue
        case .sync: .purple
        case .mediaImport: .blue
        case .export: .green
        }
    }
    
    var borderColor: Color {
        iconColor.opacity(0.2)
    }
}

struct NotificationAction {
    let title: String
    let action: () -> Void
}

// MARK: - Notification Manager

@MainActor
class NotificationManager: ObservableObject {
    @Published var notifications: [AppNotification] = []
    
    func show(_ notification: AppNotification) {
        notifications.append(notification)
        
        // Limit to 5 notifications maximum
        if notifications.count > 5 {
            notifications.removeFirst()
        }
    }
    
    func dismiss(_ notification: AppNotification) {
        notifications.removeAll { $0.id == notification.id }
    }
    
    func dismissAll() {
        notifications.removeAll()
    }
    
    // Convenience methods
    func showSuccess(_ message: String, title: String? = nil) {
        show(AppNotification(type: .success, title: title, message: message))
    }
    
    func showError(_ message: String, title: String? = nil) {
        show(AppNotification(type: .error, title: title, message: message, autoDismissAfter: 8.0))
    }
    
    func showWarning(_ message: String, title: String? = nil) {
        show(AppNotification(type: .warning, title: title, message: message, autoDismissAfter: 6.0))
    }
    
    func showInfo(_ message: String, title: String? = nil) {
        show(AppNotification(type: .info, title: title, message: message))
    }
    
    func showSyncComplete(_ message: String) {
        show(AppNotification(type: .sync, title: "Sync Complete", message: message))
    }
    
    func showImportComplete(_ count: Int) {
        show(AppNotification(
            type: .mediaImport,
            title: "Import Complete",
            message: "Successfully imported \(count) file\(count == 1 ? "" : "s")"
        ))
    }
    
    func showExportComplete(_ destination: String) {
        show(AppNotification(
            type: .export,
            title: "Export Complete",
            message: "Files exported to \(destination)"
        ))
    }
}

// MARK: - Notification Container

struct NotificationContainer: View {
    @ObservedObject var notificationManager: NotificationManager
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.notifications) { notification in
                NotificationView(notification: notification) {
                    notificationManager.dismiss(notification)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: notificationManager.notifications)
    }
}

// MARK: - Environment Key

private struct NotificationManagerKey: EnvironmentKey {
    @MainActor static var defaultValue: NotificationManager {
        return NotificationManager()
    }
}

extension EnvironmentValues {
    var notificationManager: NotificationManager {
        get { self[NotificationManagerKey.self] }
        set { self[NotificationManagerKey.self] = newValue }
    }
}

#Preview {
    VStack {
        Text("App Content")
            .font(.largeTitle)
            .padding()
        
        Spacer()
    }
    .overlay(alignment: .topTrailing) {
        NotificationContainer(notificationManager: {
            let manager = NotificationManager()
            manager.showSuccess("Sync completed successfully!")
            manager.showWarning("Some files may have low confidence scores")
            manager.showError("Failed to import 2 files", title: "Import Error")
            return manager
        }())
        .padding(.top, 60)
    }
}