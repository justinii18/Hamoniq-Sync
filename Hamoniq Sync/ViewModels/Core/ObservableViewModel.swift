//
//  ObservableViewModel.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ObservableViewModel<State, Action>: AsyncViewModel, ViewModelProtocol, StateManaging, ActionHandling {
    
    // MARK: - State Management
    
    @Published var state: State
    
    // MARK: - Initialization
    
    init(initialState: State) {
        self.state = initialState
        super.init()
    }
    
    // MARK: - State Management
    
    func updateState(_ newState: State) {
        state = newState
        onStateChanged(from: state, to: newState)
    }
    
    func updateState(_ transform: (inout State) -> Void) {
        let oldState = state
        var newState = state
        transform(&newState)
        state = newState
        onStateChanged(from: oldState, to: newState)
    }
    
    // MARK: - Action Handling (Override in subclasses)
    
    func handle(_ action: Action) {
        fatalError("handle(_:) must be implemented by subclasses")
    }
    
    // MARK: - State Change Hooks
    
    func onStateChanged(from oldState: State, to newState: State) {
        // Override in subclasses to respond to state changes
        NotificationCenter.default.post(
            name: .viewModelStateChanged,
            object: self,
            userInfo: [
                "oldState": oldState,
                "newState": newState
            ]
        )
    }
    
    // MARK: - State Validation
    
    func validateState(_ state: State) -> Bool {
        // Override in subclasses for state validation
        return true
    }
    
    // MARK: - State Persistence
    
    func saveState() {
        // Override in subclasses to persist state
    }
    
    func loadState() -> State? {
        // Override in subclasses to load persisted state
        return nil
    }
    
    func restoreStateIfAvailable() {
        if let savedState = loadState(), validateState(savedState) {
            updateState(savedState)
        }
    }
}

// MARK: - Selectable State Management

@MainActor
class SelectableViewModel<Item: Identifiable, State, Action>: ObservableViewModel<State, Action>, SelectionManaging {
    
    // MARK: - Selection Properties
    
    @Published var selectedItems: Set<Item.ID> = []
    @Published var selectedItem: Item? = nil
    
    // MARK: - Selection Management
    
    func select(_ item: Item) {
        selectedItem = item
        selectedItems.insert(item.id)
        onSelectionChanged()
    }
    
    func deselect(_ item: Item) {
        selectedItems.remove(item.id)
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
        onSelectionChanged()
    }
    
    func toggleSelection(_ item: Item) {
        if selectedItems.contains(item.id) {
            deselect(item)
        } else {
            select(item)
        }
    }
    
    func clearSelection() {
        selectedItems.removeAll()
        selectedItem = nil
        onSelectionChanged()
    }
    
    func selectAll(_ items: [Item]) {
        selectedItems = Set(items.map(\.id))
        selectedItem = items.first
        onSelectionChanged()
    }
    
    // MARK: - Selection Computed Properties
    
    var hasSelection: Bool {
        !selectedItems.isEmpty
    }
    
    var selectionCount: Int {
        selectedItems.count
    }
    
    var isMultipleSelection: Bool {
        selectedItems.count > 1
    }
    
    // MARK: - Selection Hooks
    
    func onSelectionChanged() {
        // Override in subclasses to respond to selection changes
    }
}

// MARK: - Filterable State Management

@MainActor
class FilterableViewModel<Item, State, Action>: ObservableViewModel<State, Action>, FilteringAndSearching {
    
    // MARK: - Filter Properties
    
    @Published var searchText: String = ""
    @Published var filteredItems: [Item] = []
    
    private var allItems: [Item] = []
    private var activeFilters: [FilterCriteria] = []
    
    // MARK: - Filter Management
    
    func setItems(_ items: [Item]) {
        allItems = items
        applyFilters()
    }
    
    func addFilter(_ filter: FilterCriteria) {
        activeFilters.append(filter)
        applyFilters()
    }
    
    func removeFilter(_ filter: FilterCriteria) {
        activeFilters.removeAll { $0.id == filter.id }
        applyFilters()
    }
    
    func applyFilters() {
        var filtered = allItems
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filterBySearch(filtered, query: searchText)
        }
        
        // Apply custom filters
        for filter in activeFilters {
            filtered = applyFilter(filter, to: filtered)
        }
        
        filteredItems = filtered
        onFiltersChanged()
    }
    
    func clearFilters() {
        searchText = ""
        activeFilters.removeAll()
        applyFilters()
    }
    
    func search(_ query: String) {
        searchText = query
        applyFilters()
    }
    
    // MARK: - Filter Implementation (Override in subclasses)
    
    func filterBySearch(_ items: [Item], query: String) -> [Item] {
        // Override in subclasses for specific search logic
        return items
    }
    
    func applyFilter(_ filter: FilterCriteria, to items: [Item]) -> [Item] {
        // Override in subclasses for specific filter logic
        return items
    }
    
    // MARK: - Filter Hooks
    
    func onFiltersChanged() {
        // Override in subclasses to respond to filter changes
    }
    
    // MARK: - Computed Properties
    
    var hasActiveFilters: Bool {
        !searchText.isEmpty || !activeFilters.isEmpty
    }
    
    var filterCount: Int {
        activeFilters.count + (searchText.isEmpty ? 0 : 1)
    }
    
    var isFiltered: Bool {
        filteredItems.count != allItems.count
    }
}

// MARK: - Supporting Types

struct FilterCriteria: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let type: FilterType
    let value: Any
    
    static func == (lhs: FilterCriteria, rhs: FilterCriteria) -> Bool {
        lhs.id == rhs.id
    }
}

enum FilterType {
    case text
    case date
    case numeric
    case boolean
    case custom(String)
}

// MARK: - Data Loading ViewModel

@MainActor
class DataLoadingViewModel<State, Action>: ObservableViewModel<State, Action>, DataLoading {
    
    // MARK: - Data Loading Properties
    
    @Published var isDataLoaded: Bool = false
    @Published var lastLoadedAt: Date?
    
    private let cacheTimeout: TimeInterval
    
    // MARK: - Initialization
    
    init(initialState: State, cacheTimeout: TimeInterval = 300) {
        self.cacheTimeout = cacheTimeout
        super.init(initialState: initialState)
    }
    
    // MARK: - Data Loading
    
    func loadData() async throws {
        // Override in subclasses
        fatalError("loadData() must be implemented by subclasses")
    }
    
    func refreshData() async throws {
        lastLoadedAt = nil
        isDataLoaded = false
        try await loadData()
    }
    
    func validateDataFreshness() -> Bool {
        guard let lastLoaded = lastLoadedAt else { return false }
        return Date().timeIntervalSince(lastLoaded) < cacheTimeout
    }
    
    func loadDataIfNeeded() async throws {
        if !isDataLoaded || !validateDataFreshness() {
            try await loadData()
        }
    }
    
    // MARK: - Data Loading Helpers
    
    func markDataAsLoaded() {
        isDataLoaded = true
        lastLoadedAt = Date()
    }
    
    func invalidateData() {
        isDataLoaded = false
        lastLoadedAt = nil
    }
}