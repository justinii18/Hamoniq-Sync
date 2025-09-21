//
//  ViewModelProtocols.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import Combine

// MARK: - Core ViewModel Protocol

@MainActor
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    associatedtype Action
    
    var state: State { get }
    func handle(_ action: Action)
    func cleanup()
}

// MARK: - State Management Protocol

@MainActor
protocol StateManaging {
    associatedtype State
    var state: State { get set }
    func updateState(_ newState: State)
}

// MARK: - Action Handling Protocol

@MainActor
protocol ActionHandling {
    associatedtype Action
    func handle(_ action: Action)
}

// MARK: - Async Operation Protocol

protocol AsyncOperationHandling: AnyObject {
    var isLoading: Bool { get set }
    var operationProgress: Float { get set }
    var operationStatus: String { get set }
    
    func performAsyncOperation<T>(
        _ operation: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void,
        onFailure: @escaping (Error) -> Void
    )
    
    func cancelCurrentOperation()
}

// MARK: - Error Handling Protocol

protocol ErrorHandling: AnyObject {
    var errorMessage: String? { get set }
    var showingError: Bool { get set }
    
    func handleError(_ error: Error)
    func clearError()
}

// MARK: - Progress Reporting Protocol

protocol ProgressReporting: AnyObject {
    var progress: Float { get set }
    var statusMessage: String { get set }
    
    func updateProgress(_ progress: Float, status: String)
    func resetProgress()
}

// MARK: - Data Loading Protocol

protocol DataLoading: AnyObject {
    var isDataLoaded: Bool { get set }
    var lastLoadedAt: Date? { get set }
    
    func loadData() async throws
    func refreshData() async throws
    func validateDataFreshness() -> Bool
}

// MARK: - Selection Management Protocol

protocol SelectionManaging: AnyObject {
    associatedtype SelectableItem: Identifiable
    
    var selectedItems: Set<SelectableItem.ID> { get set }
    var selectedItem: SelectableItem? { get set }
    
    func select(_ item: SelectableItem)
    func deselect(_ item: SelectableItem)
    func toggleSelection(_ item: SelectableItem)
    func clearSelection()
    func selectAll(_ items: [SelectableItem])
}

// MARK: - Filtering and Searching Protocol

protocol FilteringAndSearching: AnyObject {
    associatedtype FilteredItem
    
    var searchText: String { get set }
    var filteredItems: [FilteredItem] { get set }
    
    func applyFilters()
    func clearFilters()
    func search(_ query: String)
}

// MARK: - Pagination Protocol

protocol Paginating: AnyObject {
    var currentPage: Int { get set }
    var pageSize: Int { get set }
    var totalItems: Int { get set }
    var hasMorePages: Bool { get }
    
    func loadNextPage() async throws
    func loadPreviousPage() async throws
    func resetPagination()
}

// MARK: - Persistence Protocol

protocol Persisting: AnyObject {
    func save() async throws
    func revert()
    var hasUnsavedChanges: Bool { get }
}

// MARK: - Validation Protocol

protocol Validating: AnyObject {
    associatedtype ValidationTarget
    
    func validate(_ target: ValidationTarget) -> ValidationResult
    func isValid(_ target: ValidationTarget) -> Bool
}

// MARK: - Supporting Types

struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    
    var hasErrors: Bool { !errors.isEmpty }
    var hasWarnings: Bool { !warnings.isEmpty }
}

struct ValidationError {
    let field: String
    let message: String
    let code: String?
}

struct ValidationWarning {
    let field: String
    let message: String
    let suggestion: String?
}

// MARK: - Lifecycle Protocol

protocol ViewModelLifecycle: AnyObject {
    func onAppear()
    func onDisappear()
    func onAppWillTerminate()
    func onMemoryWarning()
}

// MARK: - Configuration Protocol

protocol Configurable: AnyObject {
    associatedtype Configuration
    
    var configuration: Configuration { get set }
    func updateConfiguration(_ newConfiguration: Configuration)
    func resetToDefaultConfiguration()
}