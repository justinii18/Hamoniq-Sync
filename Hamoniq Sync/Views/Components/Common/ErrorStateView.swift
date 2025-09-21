//
//  ErrorStateView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct ErrorStateView: View {
    let error: Error?
    let title: String?
    let message: String?
    let style: ErrorStyle
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?
    
    init(
        error: Error? = nil,
        title: String? = nil,
        message: String? = nil,
        style: ErrorStyle = .inline,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.error = error
        self.title = title
        self.message = message
        self.style = style
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        VStack(spacing: 16) {
            errorIcon
            
            VStack(spacing: 8) {
                Text(displayTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(displayMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            actionButtons
        }
        .padding(style.padding)
        .background {
            if style.hasBackground {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            }
        }
        .frame(maxWidth: style.maxWidth)
    }
    
    @ViewBuilder
    private var errorIcon: some View {
        switch style {
        case .inline, .card:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: style.iconSize))
                .foregroundColor(.red)
        case .fullScreen:
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Image(systemName: "waveform.path")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
        case .banner:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if let retryAction = retryAction {
                Button("Retry") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(style.controlSize)
            }
            
            if let dismissAction = dismissAction {
                Button("Dismiss") {
                    dismissAction()
                }
                .buttonStyle(.bordered)
                .controlSize(style.controlSize)
            }
        }
    }
    
    private var displayTitle: String {
        if let title = title {
            return title
        }
        
        return switch style {
        case .fullScreen: "Something Went Wrong"
        case .card, .inline: "Error Occurred"
        case .banner: "Error"
        }
    }
    
    private var displayMessage: String {
        if let message = message {
            return message
        }
        
        if let error = error {
            return error.localizedDescription
        }
        
        return "An unexpected error occurred. Please try again."
    }
}

enum ErrorStyle {
    case inline
    case card
    case fullScreen
    case banner
    
    var padding: EdgeInsets {
        switch self {
        case .inline: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        case .card: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        case .fullScreen: EdgeInsets(top: 40, leading: 40, bottom: 40, trailing: 40)
        case .banner: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        }
    }
    
    var hasBackground: Bool {
        switch self {
        case .inline, .card, .banner: true
        case .fullScreen: false
        }
    }
    
    var iconSize: CGFloat {
        switch self {
        case .inline: 20
        case .card: 24
        case .fullScreen: 48
        case .banner: 16
        }
    }
    
    var controlSize: ControlSize {
        switch self {
        case .inline, .card: .regular
        case .fullScreen: .large
        case .banner: .small
        }
    }
    
    var maxWidth: CGFloat? {
        switch self {
        case .inline, .banner: nil
        case .card: 400
        case .fullScreen: 500
        }
    }
}

// MARK: - Specialized Error Views

struct NetworkErrorView: View {
    let retryAction: (() -> Void)?
    
    var body: some View {
        ErrorStateView(
            title: "Network Unavailable",
            message: "Please check your internet connection and try again.",
            style: .card,
            retryAction: retryAction
        )
    }
}

struct SyncErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?
    
    var body: some View {
        ErrorStateView(
            error: error,
            title: "Sync Failed",
            message: "The audio synchronization process encountered an error.",
            style: .card,
            retryAction: retryAction
        )
    }
}

struct ImportErrorView: View {
    let failedFiles: [String]
    let retryAction: (() -> Void)?
    
    var body: some View {
        ErrorStateView(
            title: "Import Failed",
            message: "Failed to import \(failedFiles.count) file(s): \(failedFiles.joined(separator: ", "))",
            style: .card,
            retryAction: retryAction
        )
    }
}

// MARK: - View Modifiers

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: Error?
    let title: String
    
    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
    }
}

extension View {
    func errorAlert(_ error: Binding<Error?>, title: String = "Error") -> some View {
        modifier(ErrorAlertModifier(error: error, title: title))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 30) {
            ErrorStateView(
                title: "Sync Failed",
                message: "Could not synchronize audio files. The reference track may be corrupted.",
                style: .banner,
                retryAction: {},
                dismissAction: {}
            )
            
            ErrorStateView(
                title: "Import Error",
                message: "Failed to import media files. Please check file permissions and try again.",
                style: .card,
                retryAction: {}
            )
            
            ErrorStateView(
                title: "Application Error",
                message: "A critical error has occurred. The application needs to restart to continue.",
                style: .fullScreen,
                retryAction: {}
            )
            
            NetworkErrorView(retryAction: {})
            
            SyncErrorView(
                error: NSError(
                    domain: "SyncError",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Audio analysis failed"]
                ),
                retryAction: {}
            )
        }
        .padding()
    }
}