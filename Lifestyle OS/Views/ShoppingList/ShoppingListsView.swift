//
//  ShoppingListsView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import SwiftUI
internal import Auth

struct ShoppingListsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ShoppingListViewModel()
    @State private var showingAddSheet = false
    @State private var selectedItem: ShoppingList?
    @State private var showingEditSheet = false
    @State private var filterOption: FilterOption = .all
    @State private var groupingOption: GroupingOption = .none
    @State private var searchText = ""
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case unpurchased = "To Buy"
        case purchased = "Purchased"
        case highPriority = "High Priority"
        case scheduled = "Scheduled"
        case available = "Available Now"
    }
    
    enum GroupingOption: String, CaseIterable {
        case none = "All"
        case location = "By Location"
        case scheduledDate = "By Schedule"
        case priority = "By Priority"
        
        var icon: String {
            switch self {
            case .none: return "list.bullet"
            case .location: return "location.fill"
            case .scheduledDate: return "calendar"
            case .priority: return "star.fill"
            }
        }
        
        var shortName: String {
            switch self {
            case .none: return ""
            case .location: return "Location"
            case .scheduledDate: return "Schedule"
            case .priority: return "Priority"
            }
        }
    }
    
    var filteredItems: [ShoppingList] {
        print("DEBUG: Total shopping items: \(viewModel.shoppingLists.count)")
        print("DEBUG: Search text: '\(searchText)'")
        print("DEBUG: Selected filter: '\(filterOption.rawValue)'")
        
        var items = viewModel.shoppingLists
        
        // Apply filter
        switch filterOption {
        case .all:
            break
        case .unpurchased:
            items = viewModel.unpurchasedItems
        case .purchased:
            items = viewModel.purchasedItems
        case .highPriority:
            items = viewModel.highPriorityItems
        case .scheduled:
            items = items.filter { $0.scheduled_date != nil && !$0.purchased }
        case .available:
            let now = Date()
            items = items.filter { item in
                guard !item.purchased else { return false }
                
                // If no availability dates set, item is always available
                guard let start = item.available_date_start,
                      let end = item.available_date_end else {
                    return true
                }
                
                return now >= start && now <= end
            }
        }
        print("DEBUG: After filter: \(items.count)")
        
        // Apply search
        if !searchText.isEmpty {
            items = items.filter { item in
                item.item.localizedCaseInsensitiveContains(searchText) ||
                (item.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (item.location?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            print("DEBUG: After search: \(items.count)")
        }
        
        print("DEBUG: Final filtered count: \(items.count)")
        return items
    }
    
    // Group items based on grouping option
    var groupedItems: [(String, [ShoppingList])] {
        switch groupingOption {
        case .none:
            return [("All Items", filteredItems)]
            
        case .location:
            let grouped = Dictionary(grouping: filteredItems) { item in
                item.location ?? "No Location"
            }
            return grouped.sorted { $0.key < $1.key }
            
        case .scheduledDate:
            let grouped = Dictionary(grouping: filteredItems) { item -> String in
                guard let scheduledDate = item.scheduled_date else {
                    return "Not Scheduled"
                }
                return formatScheduleGroup(scheduledDate)
            }
            // Sort by date priority: Today, Tomorrow, This Week, etc.
            return grouped.sorted { lhs, rhs in
                let order = ["Overdue", "Today", "Tomorrow", "This Week", "Later", "Not Scheduled"]
                let lhsIndex = order.firstIndex(of: lhs.key) ?? order.count
                let rhsIndex = order.firstIndex(of: rhs.key) ?? order.count
                return lhsIndex < rhsIndex
            }
            
        case .priority:
            let grouped = Dictionary(grouping: filteredItems) { item -> String in
                guard let priority = item.priority, priority > 0 else {
                    return "No Priority"
                }
                switch priority {
                case 5: return "⭐⭐⭐⭐⭐ Critical"
                case 4: return "⭐⭐⭐⭐ Urgent"
                case 3: return "⭐⭐⭐ High"
                case 2: return "⭐⭐ Medium"
                case 1: return "⭐ Low"
                default: return "No Priority"
                }
            }
            return grouped.sorted { lhs, rhs in
                let order = ["⭐⭐⭐⭐⭐ Critical", "⭐⭐⭐⭐ Urgent", "⭐⭐⭐ High", "⭐⭐ Medium", "⭐ Low", "No Priority"]
                let lhsIndex = order.firstIndex(of: lhs.key) ?? order.count
                let rhsIndex = order.firstIndex(of: rhs.key) ?? order.count
                return lhsIndex < rhsIndex
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
//                if !viewModel.shoppingLists.isEmpty {
//                    statsHeader
//                        .padding()
//                        .background(Color(.systemGroupedBackground))
//                }
                
                // Filter Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(FilterOption.allCases, id: \.self) { option in
                            FilterChip(
                                title: option.rawValue,
                                isSelected: filterOption == option
                            ) {
                                filterOption = option
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                
                // Content
                if viewModel.isLoading {
                    ProgressView("Loading shopping lists...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedItems, id: \.0) { groupName, items in
                            Section(header: groupHeaderView(groupName, count: items.count)) {
                                ForEach(items) { item in
                                    ShoppingListRow(item: item) {
                                        selectedItem = item
                                        showingEditSheet = true
                                    } onTogglePurchased: {
                                        Task {
                                            await viewModel.togglePurchased(id: item.id)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            deleteItem(item)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Shopping List")
            .searchable(text: $searchText, prompt: "Search items...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Group By", selection: $groupingOption) {
                            ForEach(GroupingOption.allCases, id: \.self) { option in
                                Label(option.rawValue, systemImage: option.icon)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: groupingOption == .none ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            if groupingOption != .none {
                                Text(groupingOption.shortName)
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddShoppingListView(viewModel: viewModel)
            }
            .sheet(item: $selectedItem) { item in
                EditShoppingListView(item: item, viewModel: viewModel)
            }
            .task {
                if let user = authViewModel.currentUser {
                    print("DEBUG: Loading shopping lists for user: \(user.id)")
                    await viewModel.loadShoppingLists(accountId: user.id)
                    print("DEBUG: Loaded \(viewModel.shoppingLists.count) shopping items")
                    if !viewModel.shoppingLists.isEmpty {
                        print("DEBUG: First item: \(viewModel.shoppingLists[0])")
                    }
                } else {
                    print("DEBUG: No current user")
                }
            }
        }
    }
    
    private func groupHeaderView(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text("\(count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatScheduleGroup(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if date < now {
            return "Overdue"
        } else if let weekFromNow = calendar.date(byAdding: .day, value: 7, to: now),
                  date < weekFromNow {
            return "This Week"
        } else {
            return "Later"
        }
    }
    
//    private var statsHeader: some View {
//        HStack(spacing: 20) {
//            StatCard(
//                title: "Total Items",
//                value: "\(viewModel.itemsCount)",
//                icon: "list.bullet"
//            )
//            
//            StatCard(
//                title: "To Buy",
//                value: "\(viewModel.unpurchasedCount)",
//                icon: "cart"
//            )
//            
//            StatCard(
//                title: "Progress",
//                value: String(format: "%.0f%%", viewModel.completionPercentage),
//                icon: "chart.pie"
//            )
//        }
//    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "No items in your shopping list" : "No items found")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "Tap + to add your first item" : "Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func deleteItem(_ item: ShoppingList) {
        Task {
            await viewModel.deleteShoppingList(id: item.id)
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Shopping List Row
struct ShoppingListRow: View {
    let item: ShoppingList
    let onEdit: () -> Void
    let onTogglePurchased: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onTogglePurchased) {
                Image(systemName: item.purchased ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(item.purchased ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            // Item Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.item)
                        .font(.system(size: 16, weight: .semibold))
                        .strikethrough(item.purchased)
                        .foregroundColor(item.purchased ? .secondary : .primary)
                    
//                    if let priority = item.priority, priority > 0 {
//                        HStack(spacing: 2) {
//                            ForEach(0..<min(priority, 5), id: \.self) { _ in
//                                Image(systemName: "star.fill")
//                                    .font(.caption2)
//                                    .foregroundColor(.orange)
//                            }
//                        }
//                    }
                }
                
                if let description = item.description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 4) {
                    if let location = item.location {
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    if let quantity = item.quantity {
                        if item.location != nil {
                            Text("•")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        Text("Qty: \(quantity)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    if let unitPrice = item.unitPriceDecimal, let quantity = item.quantity {
                        if item.location != nil || item.quantity != nil {
                            Text("•")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        let total = unitPrice * Decimal(quantity)
                        Text("€\(NSDecimalNumber(decimal: total).doubleValue, specifier: "%.2f")")
                            .font(.system(size: 13))
                            .foregroundColor(.blue)
                    }
                }
                
                // Show scheduled date if exists
                if let scheduledDate = item.scheduled_date {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("Scheduled: \(formatScheduledDate(scheduledDate))")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(isOverdue(scheduledDate) ? .red : .blue)
                    .padding(.top, 2)
                }
                
                // Show availability period if exists
                if let start = item.available_date_start, let end = item.available_date_end {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Available: \(formatDateRange(start, end))")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(isAvailableNow(start, end) ? .green : .orange)
                    .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Edit Button
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private func formatScheduledDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: date)
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !item.purchased
    }
    
    private func isAvailableNow(_ start: Date, _ end: Date) -> Bool {
        let now = Date()
        return now >= start && now <= end
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            Text(value)
                .font(.title2)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    ShoppingListsView()
        .environmentObject(AuthViewModel())
}
