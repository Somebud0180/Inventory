//
//  InventoryViewModel.swift
//  Inventory
//
//  Created by Ethan John Lagera on 7/3/25.
//
//  Centralizes shared inventory logic such as sorting, selection, and deletion.

import SwiftUI
import SwiftData
import Combine

enum SortType: String, CaseIterable {
    case order = "Order"
    case alphabetical = "Alphabetical"
    case dateModified = "Date Modified"
}

let itemColumns = [
    GridItem(.adaptive(minimum: 150, maximum: 300), spacing: 16)
]

class InventoryViewModel: ObservableObject {
    @Published var selectedSortType: SortType = .order
    @Published var selectedCategory: String = "All Items"
    @Published var selectedItemIDs: Set<UUID> = []
    
    // Provide sorting for any provided item array
    func filteredItems(from items: [Item]) -> [Item] {
        switch selectedSortType {
        case .order:
            return items.sorted(by: { $0.sortOrder < $1.sortOrder })
        case .alphabetical:
            return items.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        case .dateModified:
            return items.sorted(by: { ($0.modifiedDate) > ($1.modifiedDate) })
        }
    }
    
    func deleteSelectedItems(allItems: [Item], modelContext: ModelContext) {
        let itemsToDelete = allItems.filter { selectedItemIDs.contains($0.id) }
        for item in itemsToDelete {
            item.deleteItem(context: modelContext)
        }
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete items: \(error.localizedDescription)")
        }
        selectedItemIDs.removeAll()
    }
    
    func clearSelection() {
        selectedItemIDs.removeAll()
    }
    
    /// A label for the category picker that dynamically adjusts its width based on the category name.
    struct CategoryPickerLabel: View {
        @Environment(\.colorScheme) private var colorScheme
        let categoryName: String
        @Binding var menuPresented: Bool
        @State private var displayedWidth: CGFloat = 100
        @State private var measuredWidth: CGFloat = 100
        @State private var lastCategoryName: String = ""
        
        init(categoryName: String, menuPresented: Binding<Bool>) {
            self.categoryName = categoryName
            self._menuPresented = menuPresented
            _lastCategoryName = State(initialValue: categoryName)
        }
        
        var body: some View {
            ZStack {
                // Visible label
                HStack {
                    Text(categoryName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
                .frame(minHeight: 32)
                .frame(width: displayedWidth)
                .foregroundColor(.primary)
                .background(colorScheme == .light ? .white.opacity(0.01) : .black.opacity(0.01), in: Capsule())
                
                // Hidden label for measurement
                HStack {
                    Text(categoryName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
                .frame(minHeight: 32)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: CategoryWidthPreferenceKey.self, value: geo.size.width)
                    }
                )
                .hidden()
            }
            .onPreferenceChange(CategoryWidthPreferenceKey.self) { newWidth in
                let width = max(newWidth, 20)
                measuredWidth = width
                displayedWidth = measuredWidth
            }
            .onChange(of: categoryName) {
                lastCategoryName = categoryName
                // Wait until menu is closed before expanding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if !menuPresented {
                        displayedWidth = measuredWidth
                    }
                }
            }
            .onChange(of: menuPresented) {
                if !menuPresented {
                    displayedWidth = measuredWidth
                }
            }
            .onAppear {
                displayedWidth = measuredWidth
            }
        }
    }
    
    /// Preference key to measure width of the dynamic category label
    struct CategoryWidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 100
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
    
    /// A label for the sort picker that dynamically adjusts its width based on the selected sort type.
    struct SortPickerLabel: View {
        let selectedSortType: SortType
        let symbolName: String
        @Binding var menuPresented: Bool
        @State private var displayedWidth: CGFloat = 50
        @State private var measuredWidth: CGFloat = 50
        @State private var lastSortType: SortType
        
        init(selectedSortType: SortType, symbolName: String, menuPresented: Binding<Bool>) {
            self.selectedSortType = selectedSortType
            self.symbolName = symbolName
            self._menuPresented = menuPresented
            _lastSortType = State(initialValue: selectedSortType)
        }
        
        var body: some View {
            ZStack {
                // Visible label
                HStack(spacing: 6) {
                    Image(systemName: symbolName)
                        .font(.body)
                    Text(selectedSortType.rawValue)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(width: displayedWidth)
                .frame(minHeight: 44)
                .foregroundColor(.primary)
                .background(.white.opacity(0.01), in: Capsule())
                
                // Hidden label for measurement
                HStack(spacing: 6) {
                    Image(systemName: symbolName)
                        .font(.body)
                    Text(selectedSortType.rawValue)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: SortWidthPreferenceKey.self, value: geo.size.width)
                    }
                )
                .hidden()
            }
            .adaptiveGlassButton(tintStrength: 0.0)
            .onPreferenceChange(SortWidthPreferenceKey.self) { newWidth in
                let width = max(newWidth, 50)
                measuredWidth = width
                displayedWidth = measuredWidth
            }
            .onChange(of: selectedSortType) {
                lastSortType = selectedSortType
                // Wait until menu is closed before expanding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if !menuPresented {
                        displayedWidth = measuredWidth
                    }
                }
            }
            .onChange(of: menuPresented) {
                if !menuPresented {
                    displayedWidth = measuredWidth
                }
            }
            .onAppear {
                displayedWidth = measuredWidth
            }
        }
    }
    
    /// Preference key to measure width of the dynamic sort label
    struct SortWidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 100
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = nextValue()
        }
    }
    
    /// Creates a reusable category picker menu with a dynamic label.
    /// - Parameters:
    ///   - selectedCategory: The currently selected category name.
    ///   - categories: The list of all category names to choose from.
    ///   - menuPresented: A binding to track whether the menu is presented.
    ///   - onCategorySelected: A closure called when a category is selected.
    /// - Returns: A view representing the category picker menu.
    @ViewBuilder
    static func categoryPicker(
        selectedCategory: String,
        categories: [Category],
        menuPresented: Binding<Bool>,
        onCategorySelected: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(categories, id: \.id) { category in
                Button(action: {
                    onCategorySelected(category.name)
                }) {
                    Text(category.name)
                        .background(.white.opacity(0.01), in: Capsule())
                }
            }
        } label: {
            CategoryPickerLabel(categoryName: selectedCategory, menuPresented: menuPresented)
        }
    }
    
    /// Creates a reusable sort picker menu with a dynamic label.
    /// - Parameters:
    ///   - selectedSortType: The currently selected sort type.
    ///   - menuPresented: A binding to track whether the menu is presented.
    ///   - onSortTypeSelected: A closure called when a sort type is selected.
    /// - Returns: A view representing the sort picker menu.
    @ViewBuilder
    static func sortPicker(
        selectedSortType: SortType,
        menuPresented: Binding<Bool>,
        onSortTypeSelected: @escaping (SortType) -> Void
    ) -> some View {
        Menu {
            ForEach(SortType.allCases, id: \.self) { sortType in
                Button(action: {
                    onSortTypeSelected(sortType)
                }) {
                    Text(sortType.rawValue)
                }
            }
        } label: {
            SortPickerLabel(selectedSortType: selectedSortType, symbolName: symbolName(for: selectedSortType), menuPresented: menuPresented)
        }
    }
    
    /// Returns the appropriate symbol name based on the sort type.
    /// - Parameter type: The sort type for which to get the symbol name.
    static func symbolName(for type: SortType) -> String {
        switch type {
        case .order: return "line.3.horizontal"
        case .alphabetical: return "textformat.abc"
        case .dateModified: return "calendar"
        }
    }
}
