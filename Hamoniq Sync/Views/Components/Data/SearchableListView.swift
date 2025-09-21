//
//  SearchableListView.swift
//  Hamoniq Sync
//
//  Created by Claude on 20/09/2025.
//

import SwiftUI

struct SearchableListView<Item: Identifiable & Searchable, RowContent: View>: View {
    let items: [Item]
    let configuration: SearchListConfiguration
    let rowContent: (Item) -> RowContent
    let onItemSelected: ((Item) -> Void)?
    let onItemsSelected: (([Item]) -> Void)?
    
    @State private var searchText = ""
    @State private var selectedItems: Set<Item.ID> = []
    @State private var sortOrder: SortOrder = .ascending
    @FocusState private var isSearchFocused: Bool
    
    init(
        items: [Item],
        configuration: SearchListConfiguration = SearchListConfiguration(),
        onItemSelected: ((Item) -> Void)? = nil,
        onItemsSelected: (([Item]) -> Void)? = nil,
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) {
        self.items = items
        self.configuration = configuration
        self.onItemSelected = onItemSelected
        self.onItemsSelected = onItemsSelected
        self.rowContent = rowContent
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if configuration.showSearchBar {
                searchBarSection
            }
            
            if configuration.showToolbar {
                toolbarSection
            }
            
            listSection
        }
        .background(configuration.backgroundColor)
    }
    
    @ViewBuilder
    private var searchBarSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                
                TextField(configuration.searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.controlBackgroundColor))
                    .stroke(isSearchFocused ? .blue : Color(.separatorColor), lineWidth: 1)
            }
            
            if configuration.showFilterButton {
                Menu {
                    filterMenuContent
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .menuStyle(.borderlessButton)
            }
            
            if configuration.allowsMultipleSelection && !selectedItems.isEmpty {
                Text("\(selectedItems.count) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(configuration.searchBarPadding)
        .background(Color(.controlBackgroundColor))
        
        if configuration.showSearchDivider {
            Divider()
        }
    }
    
    @ViewBuilder
    private var toolbarSection: some View {
        HStack {
            if configuration.showItemCount {
                Text("\(filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if configuration.showSortButton {
                Menu {
                    sortMenuContent
                } label: {
                    HStack(spacing: 4) {
                        Text("Sort")
                            .font(.caption)
                        Image(systemName: sortOrder == .ascending ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }
            
            if configuration.allowsMultipleSelection {
                Menu {
                    selectionMenuContent
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, configuration.searchBarPadding.leading)
        .padding(.vertical, 8)
        
        Divider()
    }
    
    @ViewBuilder
    private var listSection: some View {
        if filteredItems.isEmpty {
            emptyStateView
        } else {
            List(filteredItems, id: \.id, selection: configuration.allowsMultipleSelection ? $selectedItems : nil) { item in
                listRowView(for: item)
            }
            .listStyle(configuration.listStyle)
            .onChange(of: selectedItems) { newSelection in
                let selectedItemsArray = items.filter { newSelection.contains($0.id) }
                onItemsSelected?(selectedItemsArray)
            }
        }
    }
    
    @ViewBuilder
    private func listRowView(for item: Item) -> some View {
        HStack {
            if configuration.allowsMultipleSelection {
                Image(systemName: selectedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedItems.contains(item.id) ? .blue : .secondary)
                    .font(.system(size: 16))
                    .onTapGesture {
                        toggleSelection(for: item)
                    }
            }
            
            rowContent(item)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if configuration.allowsMultipleSelection {
                        toggleSelection(for: item)
                    } else {
                        onItemSelected?(item)
                    }
                }
        }
        .padding(.vertical, 2)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        if searchText.isEmpty {
            EmptyStateView(
                configuration: EmptyStateConfiguration(
                    title: "No Items",
                    subtitle: "No items to display",
                    systemImage: "tray"
                )
            )
        } else {
            SearchEmptyState(
                searchQuery: searchText,
                onClearSearch: { searchText = "" },
                onRefineSearch: { }
            )
        }
    }
    
    @ViewBuilder
    private var filterMenuContent: some View {
        // Implementation depends on the specific filtering needs
        Text("All Items")
        Text("Recent")
        Text("Favorites")
        Divider()
        Text("Custom Filter...")
    }
    
    @ViewBuilder
    private var sortMenuContent: some View {
        Button("Name") { /* Sort by name */ }
        Button("Date Modified") { /* Sort by date */ }
        Button("Size") { /* Sort by size */ }
        Divider()
        Button(sortOrder == .ascending ? "Descending" : "Ascending") {
            sortOrder = sortOrder == .ascending ? .descending : .ascending
        }
    }
    
    @ViewBuilder
    private var selectionMenuContent: some View {
        Button("Select All") {
            selectedItems = Set(filteredItems.map(\.id))
        }
        .disabled(selectedItems.count == filteredItems.count)
        
        Button("Deselect All") {
            selectedItems.removeAll()
        }
        .disabled(selectedItems.isEmpty)
        
        Divider()
        
        Button("Invert Selection") {
            let allIds = Set(filteredItems.map(\.id))
            selectedItems = allIds.subtracting(selectedItems)
        }
    }
    
    private var filteredItems: [Item] {
        let filtered = searchText.isEmpty ? items : items.filter { item in
            item.searchableContent.localizedCaseInsensitiveContains(searchText)
        }
        
        // Sort items based on current sort order
        return filtered.sorted { first, second in
            let comparison = first.searchableContent.localizedCompare(second.searchableContent)
            return sortOrder == .ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }
    
    private func toggleSelection(for item: Item) {
        if selectedItems.contains(item.id) {
            selectedItems.remove(item.id)
        } else {
            selectedItems.insert(item.id)
        }
    }
}

protocol Searchable {
    var searchableContent: String { get }
}

enum SortOrder {
    case ascending
    case descending
}

struct SearchListConfiguration {
    let showSearchBar: Bool
    let showToolbar: Bool
    let showFilterButton: Bool
    let showSortButton: Bool
    let showItemCount: Bool
    let showSearchDivider: Bool
    let allowsMultipleSelection: Bool
    let searchPlaceholder: String
    let backgroundColor: Color
    let listStyle: PlainListStyle
    let searchBarPadding: EdgeInsets
    
    init(
        showSearchBar: Bool = true,
        showToolbar: Bool = true,
        showFilterButton: Bool = true,
        showSortButton: Bool = true,
        showItemCount: Bool = true,
        showSearchDivider: Bool = true,
        allowsMultipleSelection: Bool = false,
        searchPlaceholder: String = "Search...",
        backgroundColor: Color = Color(.windowBackgroundColor),
        listStyle: PlainListStyle = PlainListStyle(),
        searchBarPadding: EdgeInsets = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
    ) {
        self.showSearchBar = showSearchBar
        self.showToolbar = showToolbar
        self.showFilterButton = showFilterButton
        self.showSortButton = showSortButton
        self.showItemCount = showItemCount
        self.showSearchDivider = showSearchDivider
        self.allowsMultipleSelection = allowsMultipleSelection
        self.searchPlaceholder = searchPlaceholder
        self.backgroundColor = backgroundColor
        self.listStyle = listStyle
        self.searchBarPadding = searchBarPadding
    }
}

// MARK: - Sample Implementation

struct MediaFileItem: Identifiable, Searchable {
    let id = UUID()
    let name: String
    let type: String
    let size: String
    let date: Date
    
    var searchableContent: String {
        "\(name) \(type)"
    }
}

struct MediaFileListView: View {
    let mediaFiles: [MediaFileItem]
    let onFileSelected: (MediaFileItem) -> Void
    
    var body: some View {
        SearchableListView(
            items: mediaFiles,
            configuration: SearchListConfiguration(
                allowsMultipleSelection: true,
                searchPlaceholder: "Search media files..."
            ),
            onItemSelected: onFileSelected
        ) { file in
            HStack {
                Image(systemName: file.type == "audio" ? "waveform" : "video")
                    .foregroundColor(file.type == "audio" ? .blue : .green)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    HStack {
                        Text(file.type.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(file.size)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(file.date, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Paginated List View

struct PaginatedListView<Item: Identifiable, RowContent: View>: View {
    let items: [Item]
    let pageSize: Int
    let configuration: SearchListConfiguration
    let rowContent: (Item) -> RowContent
    
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    
    init(
        items: [Item],
        pageSize: Int = 50,
        configuration: SearchListConfiguration = SearchListConfiguration(),
        @ViewBuilder rowContent: @escaping (Item) -> RowContent
    ) {
        self.items = items
        self.pageSize = pageSize
        self.configuration = configuration
        self.rowContent = rowContent
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(visibleItems, id: \.id) { item in
                    rowContent(item)
                        .onAppear {
                            if item.id == visibleItems.last?.id {
                                loadMoreIfNeeded()
                            }
                        }
                }
                
                if hasMoreItems {
                    HStack {
                        Spacer()
                        if isLoadingMore {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button("Load More") {
                                loadMoreItems()
                            }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }
            }
            .listStyle(configuration.listStyle)
            
            if configuration.showItemCount {
                HStack {
                    Text("\(visibleItems.count) of \(items.count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
    
    private var visibleItems: [Item] {
        let endIndex = min((currentPage + 1) * pageSize, items.count)
        return Array(items[0..<endIndex])
    }
    
    private var hasMoreItems: Bool {
        visibleItems.count < items.count
    }
    
    private func loadMoreIfNeeded() {
        guard !isLoadingMore && hasMoreItems else { return }
        
        let threshold = visibleItems.count - 5
        if visibleItems.count >= threshold {
            loadMoreItems()
        }
    }
    
    private func loadMoreItems() {
        guard !isLoadingMore && hasMoreItems else { return }
        
        isLoadingMore = true
        
        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            currentPage += 1
            isLoadingMore = false
        }
    }
}

#Preview {
    let sampleFiles = (1...100).map { index in
        MediaFileItem(
            name: "Sample File \(index)",
            type: index % 2 == 0 ? "audio" : "video",
            size: "\(Int.random(in: 1...100)) MB",
            date: Date().addingTimeInterval(-Double.random(in: 0...86400*30))
        )
    }
    
    return MediaFileListView(mediaFiles: Array(sampleFiles.prefix(20))) { file in
        print("Selected: \(file.name)")
    }
    .frame(height: 500)
}