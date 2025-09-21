//
//  ServiceProtocol.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import Combine

// MARK: - Base Service Protocol

protocol ServiceProtocol {
    var isInitialized: Bool { get }
    
    func initialize() async throws
    func shutdown() async
    func reset() async throws
}

// MARK: - Data Service Protocol

protocol DataServiceProtocol: ServiceProtocol {
    associatedtype DataType
    associatedtype IDType: Hashable
    
    func create(_ item: DataType) async throws -> DataType
    func read(_ id: IDType) async throws -> DataType?
    func update(_ item: DataType) async throws -> DataType
    func delete(_ id: IDType) async throws
    func list() async throws -> [DataType]
}

// MARK: - Progress Reporting Service Protocol

protocol ProgressReportingServiceProtocol: AnyObject {
    var progressPublisher: AnyPublisher<(Float, String), Never> { get }
    
    func updateProgress(_ progress: Float, status: String)
    func resetProgress()
}

// MARK: - Error Handling Service Protocol

protocol ErrorHandlingServiceProtocol: AnyObject {
    var errorPublisher: AnyPublisher<Error, Never> { get }
    
    func handleError(_ error: Error)
    func clearErrors()
}

// MARK: - Cancellable Service Protocol

protocol CancellableServiceProtocol: AnyObject {
    var isCancelled: Bool { get }
    
    func cancel()
}

// MARK: - Observable Service Protocol

protocol ObservableServiceProtocol: AnyObject, ObservableObject {
    associatedtype State
    
    var state: State { get }
}

// MARK: - Configuration Service Protocol

protocol ConfigurableServiceProtocol: ServiceProtocol {
    associatedtype Configuration
    
    var configuration: Configuration { get set }
    
    func updateConfiguration(_ newConfiguration: Configuration) async throws
    func resetToDefaultConfiguration() async throws
}

// MARK: - Validation Service Protocol

protocol ValidationServiceProtocol: ServiceProtocol {
    associatedtype ValidationTarget
    
    func validate(_ target: ValidationTarget) async throws -> ValidationResult
    func isValid(_ target: ValidationTarget) async throws -> Bool
}

// MARK: - Cache Service Protocol

protocol CacheServiceProtocol: ServiceProtocol {
    associatedtype CacheKey: Hashable
    associatedtype CacheValue
    
    func get(_ key: CacheKey) async -> CacheValue?
    func set(_ key: CacheKey, value: CacheValue) async
    func remove(_ key: CacheKey) async
    func clear() async
    func size() async -> Int
}

// MARK: - Background Service Protocol

protocol BackgroundServiceProtocol: ServiceProtocol {
    var isRunning: Bool { get }
    
    func start() async throws
    func stop() async
    func pause() async
    func resume() async throws
}

// MARK: - Export Service Protocol

protocol ExportServiceProtocol: ServiceProtocol {
    associatedtype ExportData
    associatedtype ExportConfiguration
    associatedtype ExportResult
    
    func export(
        data: ExportData,
        configuration: ExportConfiguration,
        progressCallback: ((Float, String) -> Void)?
    ) async throws -> ExportResult
    
    func getSupportedFormats() -> [String]
    func validateConfiguration(_ configuration: ExportConfiguration) async throws -> Bool
}

// MARK: - Import Service Protocol

protocol ImportServiceProtocol: ServiceProtocol {
    associatedtype ImportSource
    associatedtype ImportResult
    associatedtype ImportConfiguration
    
    func `import`(
        from source: ImportSource,
        configuration: ImportConfiguration,
        progressCallback: ((Float, String) -> Void)?
    ) async throws -> ImportResult
    
    func getSupportedFormats() -> [String]
    func validateSource(_ source: ImportSource) async throws -> Bool
}

// MARK: - Sync Service Protocol

protocol SyncServiceProtocol: ServiceProtocol, ProgressReportingServiceProtocol, ErrorHandlingServiceProtocol, CancellableServiceProtocol {
    associatedtype SyncSource
    associatedtype SyncTarget
    associatedtype SyncResult
    associatedtype SyncConfiguration
    
    func sync(
        source: SyncSource,
        target: SyncTarget,
        configuration: SyncConfiguration
    ) async throws -> SyncResult
    
    func batchSync(
        sources: [SyncSource],
        targets: [SyncTarget],
        configuration: SyncConfiguration
    ) async throws -> [SyncResult]
}

// MARK: - Storage Service Protocol

protocol StorageServiceProtocol: ServiceProtocol {
    func store<T: Codable>(_ object: T, withKey key: String) async throws
    func retrieve<T: Codable>(_ type: T.Type, withKey key: String) async throws -> T?
    func remove(withKey key: String) async throws
    func exists(withKey key: String) async -> Bool
    func clear() async throws
}

// MARK: - Network Service Protocol

protocol NetworkServiceProtocol: ServiceProtocol {
    var isConnected: Bool { get }
    var connectionType: NetworkConnectionType { get }
    
    func checkConnection() async -> Bool
    func performRequest<T: Codable>(_ request: NetworkRequest) async throws -> T
}

// MARK: - Supporting Types

enum NetworkConnectionType {
    case none
    case wifi
    case cellular
    case ethernet
    case unknown
}

struct NetworkRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?
    let timeout: TimeInterval
    
    enum HTTPMethod: String {
        case GET, POST, PUT, DELETE, PATCH
    }
}

// MARK: - Service Manager Protocol

protocol ServiceManagerProtocol: AnyObject {
    func register<T: ServiceProtocol>(_ service: T, for type: T.Type)
    func resolve<T: ServiceProtocol>(_ type: T.Type) -> T?
    func initializeAllServices() async throws
    func shutdownAllServices() async
}

// MARK: - Service Lifecycle

enum ServiceState {
    case uninitialized
    case initializing
    case ready
    case error(Error)
    case shuttingDown
    case shutdown
}

// MARK: - Service Registry

@MainActor
final class ServiceRegistry: ServiceManagerProtocol {
    static let shared = ServiceRegistry()
    
    private var services: [ObjectIdentifier: Any] = [:]
    private var serviceStates: [ObjectIdentifier: ServiceState] = [:]
    
    private init() {}
    
    func register<T: ServiceProtocol>(_ service: T, for type: T.Type) {
        let key = ObjectIdentifier(type)
        services[key] = service
        serviceStates[key] = .uninitialized
    }
    
    func resolve<T: ServiceProtocol>(_ type: T.Type) -> T? {
        let key = ObjectIdentifier(type)
        return services[key] as? T
    }
    
    func initializeAllServices() async throws {
        for (key, service) in services {
            serviceStates[key] = .initializing
            
            do {
                if let service = service as? ServiceProtocol {
                    try await service.initialize()
                    serviceStates[key] = .ready
                }
            } catch {
                serviceStates[key] = .error(error)
                throw error
            }
        }
    }
    
    func shutdownAllServices() async {
        for (key, service) in services {
            serviceStates[key] = .shuttingDown
            
            if let service = service as? ServiceProtocol {
                await service.shutdown()
                serviceStates[key] = .shutdown
            }
        }
    }
    
    func getServiceState<T: ServiceProtocol>(_ type: T.Type) -> ServiceState {
        let key = ObjectIdentifier(type)
        return serviceStates[key] ?? .uninitialized
    }
}

// MARK: - Service Resolution Helper

extension ServiceRegistry {
    func require<T: ServiceProtocol>(_ type: T.Type) -> T {
        guard let service = resolve(type) else {
            fatalError("Service of type \(type) is not registered")
        }
        return service
    }
}