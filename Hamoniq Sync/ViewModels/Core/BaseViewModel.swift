//
//  BaseViewModel.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class BaseViewModel: ObservableObject, ErrorHandling, ProgressReporting, ViewModelLifecycle {
    
    // MARK: - Common Published Properties
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    @Published var progress: Float = 0.0
    @Published var statusMessage: String = ""
    
    // MARK: - Internal Properties
    
    internal var cancellables = Set<AnyCancellable>()
    private var lifecycleState: ViewModelLifecycleState = .initialized
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        onInitialized()
    }
    
    deinit {
        Task {
            await cleanup()
        }
    }
    
    // MARK: - Lifecycle Methods
    
    func onAppear() {
        guard lifecycleState != .appeared else { return }
        lifecycleState = .appeared
        setupAppearanceBindings()
    }
    
    func onDisappear() {
        guard lifecycleState != .disappeared else { return }
        lifecycleState = .disappeared
        cleanupAppearanceBindings()
    }
    
    func onAppWillTerminate() {
        cleanup()
    }
    
    func onMemoryWarning() {
        // Override in subclasses to handle memory warnings
        clearCaches()
    }
    
    // MARK: - Setup Methods (Override in subclasses)
    
    func setupBindings() {
        // Override in subclasses for initial setup
    }
    
    func setupAppearanceBindings() {
        // Override in subclasses for appearance-specific setup
    }
    
    func cleanupAppearanceBindings() {
        // Override in subclasses for appearance-specific cleanup
    }
    
    private func onInitialized() {
        lifecycleState = .initialized
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        cancellables.removeAll()
        clearCaches()
    }
    
    private func clearCaches() {
        // Override in subclasses to clear specific caches
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showingError = true
        isLoading = false
        
        // Log error for debugging
        print("ViewModel Error: \(error)")
        
        // Post notification for global error handling
        NotificationCenter.default.post(
            name: .viewModelError,
            object: self,
            userInfo: ["error": error]
        )
    }
    
    func clearError() {
        errorMessage = nil
        showingError = false
    }
    
    // MARK: - Progress Reporting
    
    func updateProgress(_ progress: Float, status: String = "") {
        self.progress = max(0.0, min(1.0, progress))
        if !status.isEmpty {
            self.statusMessage = status
        }
    }
    
    func resetProgress() {
        progress = 0.0
        statusMessage = ""
    }
    
    // MARK: - Loading State Management
    
    func setLoading(_ loading: Bool, status: String = "") {
        isLoading = loading
        if loading {
            clearError()
            if !status.isEmpty {
                statusMessage = status
            }
        } else {
            if statusMessage.isEmpty {
                statusMessage = "Ready"
            }
        }
    }
    
    // MARK: - Common Operations
    
    func performOperation<T>(
        _ operation: @escaping () async throws -> T,
        loadingMessage: String = "Loading...",
        onSuccess: @escaping (T) -> Void = { _ in },
        onFailure: @escaping (Error) -> Void = { _ in }
    ) {
        setLoading(true, status: loadingMessage)
        
        Task {
            do {
                let result = try await operation()
                
                await MainActor.run {
                    setLoading(false)
                    onSuccess(result)
                }
            } catch {
                await MainActor.run {
                    setLoading(false)
                    handleError(error)
                    onFailure(error)
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func addCancellable(_ cancellable: AnyCancellable) {
        cancellable.store(in: &cancellables)
    }
    
    func debounce<T>(
        for publisher: AnyPublisher<T, Never>,
        duration: TimeInterval = 0.3,
        scheduler: DispatchQueue = .main
    ) -> AnyPublisher<T, Never> {
        return publisher
            .debounce(for: .seconds(duration), scheduler: scheduler)
            .eraseToAnyPublisher()
    }
    
    func throttle<T>(
        for publisher: AnyPublisher<T, Never>,
        duration: TimeInterval = 0.1,
        scheduler: DispatchQueue = .main,
        latest: Bool = true
    ) -> AnyPublisher<T, Never> {
        return publisher
            .throttle(for: .seconds(duration), scheduler: scheduler, latest: latest)
            .eraseToAnyPublisher()
    }
}

// MARK: - Lifecycle State

private enum ViewModelLifecycleState {
    case initialized
    case appeared
    case disappeared
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let viewModelError = Notification.Name("viewModelError")
    static let viewModelStateChanged = Notification.Name("viewModelStateChanged")
}
