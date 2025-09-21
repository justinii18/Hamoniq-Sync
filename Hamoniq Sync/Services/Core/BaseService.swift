//
//  BaseService.swift
//  Hamoniq Sync
//
//  Created by Justin Adjei on 20/09/2025.
//

import Foundation
import Combine

@MainActor
class BaseService: ServiceProtocol, ObservableObject {
    
    // MARK: - Properties
    
    @Published private(set) var isInitialized: Bool = false
    @Published private(set) var state: ServiceState = .uninitialized
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    deinit {
        Task {
            await shutdown()
        }
    }
    
    // MARK: - ServiceProtocol Implementation
    
    func initialize() async throws {
        guard !isInitialized else { return }
        
        state = .initializing
        
        do {
            try await performInitialization()
            isInitialized = true
            state = .ready
            onInitialized()
        } catch {
            state = .error(error)
            throw error
        }
    }
    
    func shutdown() async {
        guard isInitialized else { return }
        
        state = .shuttingDown
        
        await performShutdown()
        
        isInitialized = false
        state = .shutdown
        cancellables.removeAll()
        
        onShutdown()
    }
    
    func reset() async throws {
        await shutdown()
        try await initialize()
    }
    
    // MARK: - Override Points
    
    func performInitialization() async throws {
        // Override in subclasses for specific initialization logic
    }
    
    func performShutdown() async {
        // Override in subclasses for specific shutdown logic
    }
    
    func setupBindings() {
        // Override in subclasses for Combine bindings
    }
    
    func onInitialized() {
        // Override in subclasses for post-initialization logic
    }
    
    func onShutdown() {
        // Override in subclasses for post-shutdown logic
    }
    
    // MARK: - Utility Methods
    
    func requireInitialized() throws {
        guard isInitialized else {
            throw ServiceError.notInitialized
        }
    }
    
    func addCancellable(_ cancellable: AnyCancellable) {
        cancellable.store(in: &cancellables)
    }
    
    func setState(_ newState: ServiceState) {
        state = newState
    }
}

// MARK: - Progress Reporting Service

@MainActor
class ProgressReportingService: BaseService, ProgressReportingServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentProgress: Float = 0.0
    @Published private(set) var currentStatus: String = ""
    
    // MARK: - Publishers
    
    private let progressSubject = PassthroughSubject<(Float, String), Never>()
    
    var progressPublisher: AnyPublisher<(Float, String), Never> {
        progressSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Progress Reporting
    
    func updateProgress(_ progress: Float, status: String = "") {
        let clampedProgress = max(0.0, min(1.0, progress))
        
        currentProgress = clampedProgress
        if !status.isEmpty {
            currentStatus = status
        }
        
        progressSubject.send((clampedProgress, currentStatus))
    }
    
    func resetProgress() {
        currentProgress = 0.0
        currentStatus = ""
        progressSubject.send((0.0, ""))
    }
}

// MARK: - Error Handling Service

@MainActor
class ErrorHandlingService: BaseService, ErrorHandlingServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var lastError: Error?
    @Published private(set) var errorHistory: [ServiceError] = []
    
    // MARK: - Publishers
    
    private let errorSubject = PassthroughSubject<Error, Never>()
    
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Error Handling
    
    func handleError(_ error: Error) {
        lastError = error
        
        let serviceError = ServiceError(
            originalError: error,
            timestamp: Date(),
            context: String(describing: type(of: self))
        )
        
        errorHistory.append(serviceError)
        
        // Limit error history size
        if errorHistory.count > 100 {
            errorHistory.removeFirst(errorHistory.count - 100)
        }
        
        errorSubject.send(error)
        
        // Log error
        print("Service Error [\(serviceError.context)]: \(error.localizedDescription)")
    }
    
    func clearErrors() {
        lastError = nil
        errorHistory.removeAll()
    }
    
    func getRecentErrors(limit: Int = 10) -> [ServiceError] {
        return Array(errorHistory.suffix(limit))
    }
}

// MARK: - Cancellable Service

@MainActor
class CancellableService: ProgressReportingService, CancellableServiceProtocol {
    
    // MARK: - Properties
    
    @Published private(set) var isCancelled: Bool = false
    
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Cancellation
    
    func cancel() {
        isCancelled = true
        currentTask?.cancel()
        updateProgress(0.0, status: "Cancelled")
    }
    
    func resetCancellation() {
        isCancelled = false
    }
    
    // MARK: - Task Management
    
    func performCancellableOperation<T>(
        _ operation: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void = { _ in },
        onFailure: @escaping (Error) -> Void = { _ in },
        onCancelled: @escaping () -> Void = {}
    ) {
        resetCancellation()
        
        currentTask = Task {
            do {
                let result = try await operation()
                
                if !isCancelled {
                    await MainActor.run {
                        onSuccess(result)
                    }
                }
            } catch {
                if Task.isCancelled || isCancelled {
                    await MainActor.run {
                        onCancelled()
                    }
                } else {
                    await MainActor.run {
                        onFailure(error)
                    }
                }
            }
        }
    }
    
    override func performShutdown() async {
        cancel()
        await super.performShutdown()
    }
}

// MARK: - Configuration Service

@MainActor
class ConfigurableService<Configuration>: BaseService, ConfigurableServiceProtocol {
    
    // MARK: - Properties
    
    @Published var configuration: Configuration {
        didSet {
            onConfigurationChanged(from: oldValue, to: configuration)
        }
    }
    
    private let defaultConfiguration: Configuration
    
    // MARK: - Initialization
    
    init(defaultConfiguration: Configuration) {
        self.defaultConfiguration = defaultConfiguration
        self.configuration = defaultConfiguration
        super.init()
    }
    
    // MARK: - Configuration Management
    
    func updateConfiguration(_ newConfiguration: Configuration) async throws {
        try requireInitialized()
        
        let oldConfiguration = configuration
        configuration = newConfiguration
        
        do {
            try await applyConfiguration(newConfiguration)
        } catch {
            // Rollback on failure
            configuration = oldConfiguration
            throw error
        }
    }
    
    func resetToDefaultConfiguration() async throws {
        try await updateConfiguration(defaultConfiguration)
    }
    
    // MARK: - Override Points
    
    func applyConfiguration(_ configuration: Configuration) async throws {
        // Override in subclasses to apply configuration changes
    }
    
    func onConfigurationChanged(from oldConfiguration: Configuration, to newConfiguration: Configuration) {
        // Override in subclasses to respond to configuration changes
    }
}

// MARK: - Observable Service

@MainActor
class ObservableService<ObservedState>: BaseService, ObservableServiceProtocol {
    
    // MARK: - State Management
    
    @Published private(set) var observableState: ObservedState
    
    // MARK: - Initialization
    
    init(initialState: ObservedState) {
        self.observableState = initialState
        super.init()
    }
    
    // MARK: - State Updates
    
    func updateState(_ newState: ObservedState) {
        let oldState = observableState
        observableState = newState
        onStateChanged(from: oldState, to: newState)
    }
    
    func updateState(_ transform: (inout ObservedState) -> Void) {
        let oldState = observableState
        var newState = observableState
        transform(&newState)
        observableState = newState
        onStateChanged(from: oldState, to: newState)
    }
    
    // MARK: - Override Points
    
    func onStateChanged(from oldState: ObservedState, to newState: ObservedState) {
        // Override in subclasses to respond to state changes
    }
}

// MARK: - Service Errors

struct ServiceError: Error, LocalizedError {
    let originalError: Error
    let timestamp: Date
    let context: String
    
    var errorDescription: String? {
        return "Service Error in \(context): \(originalError.localizedDescription)"
    }
    
    static let notInitialized = ServiceError(
        originalError: NSError(domain: "ServiceError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Service not initialized"]),
        timestamp: Date(),
        context: "BaseService"
    )
    
    static let alreadyInitialized = ServiceError(
        originalError: NSError(domain: "ServiceError", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Service already initialized"]),
        timestamp: Date(),
        context: "BaseService"
    )
    
    static let initializationFailed = ServiceError(
        originalError: NSError(domain: "ServiceError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Service initialization failed"]),
        timestamp: Date(),
        context: "BaseService"
    )
}
