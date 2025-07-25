//
//  InventoryGridView.swift
//  rInventory
//
//  Created by Ethan John Lagera on 7/13/25.
//

import SwiftUI
import SwiftData

let inventoryGridActivityType = "com.lagera.Inventory.viewingGrid"
let inventoryGridTitleKey = "title"
let inventoryGridPredicateKey = "predicate"
let inventoryGridCategoryKey = "category"
let inventoryGridSortKey = "sort"

struct InventoryGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.editMode) private var editMode
    
    @StateObject var syncEngine: CloudKitSyncEngine
    @Query private var modelItems: [Item]
    @Query private var modelCategories: [Category]
    @Query private var modelLocations: [Location]
    
    // Grab Categories from displayedItems (efficient, deduplicated by id)
    private var categories: [Category] {
        if showCategoryPicker {
            var seen = Set<UUID>()
            var uniqueCategories: [Category] = []
            for item in viewModel.displayedItems {
                if let cat = item.category, !seen.contains(cat.id) {
                    seen.insert(cat.id)
                    uniqueCategories.append(cat)
                }
            }
            return [Category(name: "All Items")] + uniqueCategories
        }
        return [Category(name: "All Items")]
    }
    
    @State var title: String
    @State var predicate: String? = nil
    @State var showCategoryPicker: Bool = false
    @State var showSortPicker: Bool = false
    @Binding var selectedItem: Item?
    @Binding var isInventoryActive: Bool
    @Binding var isInventoryGridActive: Bool
    
    @StateObject private var viewModel: InventoryViewModel
    
    // State variable for UI
    @State private var draggedItem: Item? = nil
    @State private var categoryMenuPresented = false
    @State private var sortMenuPresented = false
    
    // Clean up viewModel on disappear
    @State private var hasAppeared = false
    
    init(syncEngine: CloudKitSyncEngine, title: String, predicate: String? = nil, showCategoryPicker: Bool = false, showSortPicker: Bool = false, showHiddenCategoriesInGrid: Bool = false, showHiddenLocationsInGrid: Bool = false,  selectedItem: Binding<Item?>, isInventoryActive: Binding<Bool>, isInventoryGridActive: Binding<Bool>) {
        _syncEngine = StateObject(wrappedValue: syncEngine)
        self.title = title
        self.predicate = predicate
        self.showCategoryPicker = showCategoryPicker
        self.showSortPicker = showSortPicker
        self._selectedItem = selectedItem
        self._isInventoryActive = isInventoryActive
        self._isInventoryGridActive = isInventoryGridActive
        _viewModel = StateObject(wrappedValue: InventoryViewModel(showHiddenCategories: showHiddenCategoriesInGrid, showHiddenLocations: showHiddenLocationsInGrid))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                HStack(alignment: .bottom) {
                    if showCategoryPicker {
                        categoryPicker
                    }
                    Spacer()
                    if showSortPicker {
                        sortPicker
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView("Loading items...")
                        .padding(10)
                } else if viewModel.filteredItems(from: viewModel.displayedItems).isEmpty {
                    Text("No items found")
                        .foregroundColor(.gray)
                        .padding(10)
                } else {
                    inventoryGrid
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if editMode?.wrappedValue.isEditing == true && !viewModel.selectedItemIDs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteSelectedItems(modelContext: modelContext, cloudKitSyncEngine: syncEngine, allItems: modelItems)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .padding(.horizontal, 16)
        .refreshable {
            viewModel.updateDisplayedItems(from: modelItems, predicate: predicate)
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                isInventoryGridActive = true
                let sortTypeIndex = AppDefaults.shared.defaultInventorySort
                viewModel.selectedSortType =
                ([SortType.order, .alphabetical, .dateModified].indices.contains(sortTypeIndex) ? [SortType.order, .alphabetical, .dateModified][sortTypeIndex] : .order)
                viewModel.isLoading = true
                Task {
                    viewModel.updateDisplayedItems(from: modelItems, predicate: predicate)
                }
            }
        }
        .onDisappear {
            hasAppeared = false
        }
        .onChange(of: editMode?.wrappedValue.isEditing == true) {
            if !(editMode?.wrappedValue.isEditing == true) {
                viewModel.selectedItemIDs.removeAll()
            }
        }
        .onChange(of: isInventoryActive) {
            if isInventoryActive {
                isInventoryGridActive = true
            } else {
                isInventoryGridActive = false
            }
        }
        .onChange(of: modelLocations.filter { $0.displayInRow == true }) {
            viewModel.updateDisplayedItems(from: modelItems, predicate: predicate)
        }
        .onChange(of: modelCategories.filter { $0.displayInRow == true }) {
            viewModel.updateDisplayedItems(from: modelItems, predicate: predicate)
        }
        .onChange(of: "\(viewModel.filteredItems(from: modelItems))-\(viewModel.selectedSortType)-\(viewModel.selectedCategory)") {
            viewModel.updateDisplayedItems(from: modelItems, predicate: predicate)
        }
    }
    
    private var inventoryGrid: some View {
        VStack {
            LazyVGrid(columns: itemColumns) {
                ForEach(viewModel.filteredItems(from: viewModel.displayedItems), id: \.id) { item in
                    DraggableItemCard(
                        item: item,
                        colorScheme: colorScheme,
                        showCounterForSingleItems: AppDefaults.shared.showCounterForSingleItems,
                        draggedItem: $draggedItem,
                        onTap: {
                            if editMode?.wrappedValue.isEditing == true {
                                if viewModel.selectedItemIDs.contains(item.id) {
                                    viewModel.selectedItemIDs.remove(item.id)
                                } else {
                                    viewModel.selectedItemIDs.insert(item.id)
                                }
                            } else {
                                selectedItem = item
                            }
                        },
                        onDragChanged: { isDragging in
                            draggedItem = isDragging ? item : nil
                        },
                        onDrop: { droppedItemId in
                            handleDrop(modelItems, filteredItems: viewModel.filteredItems(from: viewModel.displayedItems), draggedItem: $draggedItem, droppedItemId: droppedItemId, target: item)
                        },
                        isEditing: editMode?.wrappedValue.isEditing ?? false,
                        isSelected: editMode?.wrappedValue.isEditing == true && viewModel.selectedItemIDs.contains(item.id)
                    )
                }
            }
            Spacer()
        }
    }
    
    /// Returns a category picker menu for selecting inventory categories.
    private var categoryPicker: some View {
        InventoryViewModel.categoryPicker(
            selectedCategory: viewModel.selectedCategory,
            categories: categories,
            menuPresented: $categoryMenuPresented
        ) { selected in
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.selectedCategory = selected
            }
        }
    }
    
    /// Returns a sort picker menu for selecting how to sort inventory items.
    private var sortPicker: some View {
        InventoryViewModel.sortPicker(
            selectedSortType: viewModel.selectedSortType,
            menuPresented: $sortMenuPresented
        ) { selected in
            withAnimation(.easeInOut(duration: 0.3)) {
                viewModel.selectedSortType = selected
            }
        }
    }
    
    private func updateUserActivity(_ activity: NSUserActivity) {
        var userInfo: [String: Any] = [
            inventoryGridPredicateKey: predicate ?? "",
            inventoryGridTitleKey: title
        ]
        if showCategoryPicker {
            userInfo[inventoryGridCategoryKey] = viewModel.selectedCategory
        }
        if showSortPicker {
            userInfo[inventoryGridSortKey] = viewModel.selectedSortType.rawValue
        }
        
        activity.title = "View \(title)"
        activity.addUserInfoEntries(from: userInfo)
        activity.userInfo = ["tabSelection": 0]
        activity.isEligibleForHandoff = true
        activity.isEligibleForPrediction = true
        activity.isEligibleForSearch = true
    }
}

#Preview {
    @Previewable @StateObject var syncEngine = CloudKitSyncEngine(modelContext: InventoryApp.sharedModelContainer.mainContext)
    @Previewable @State var title: String = "All Items"
    @Previewable @State var selectedItem: Item? = nil
    @Previewable @State var isInventoryActive: Bool = true
    @Previewable @State var isInventoryGridActive: Bool = true
    
    InventoryGridView(syncEngine: syncEngine, title: title, selectedItem: $selectedItem, isInventoryActive: $isInventoryActive, isInventoryGridActive: $isInventoryGridActive)
}
