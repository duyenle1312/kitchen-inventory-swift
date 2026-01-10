//
//  InventoryListView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//

import SwiftUI
internal import Auth

// Add sorting enum
enum SortOption: String, CaseIterable {
    case name = "Name"
    case expirationDate = "Expiration"
    case quantity = "Quantity"
    
    var icon: String {
        switch self {
        case .name: return "textformat"
        case .expirationDate: return "calendar"
        case .quantity: return "number"
        }
    }
}

struct InventoryListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = InventoryViewModel()
    @State private var showAddItem = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .name
    @State private var sortAscending = true
    @State private var selectedFilter: FilterOption = .all
    
    enum FilterOption {
        case all
        case expiringSoon
        case expired
    }
    
    var filteredAndSortedItems: [InventoryItem] {
        var filtered = viewModel.items
        
        switch selectedFilter {
        case .all:
            break
        case .expiringSoon:
            filtered = filtered.filter { item in
                guard let expirationDate = item.expirationDate else { return false }
                let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                return daysUntilExpiration >= 0 && daysUntilExpiration <= 21
            }
        case .expired:
            filtered = filtered.filter { item in
                guard let expirationDate = item.expirationDate else { return false }
                return expirationDate < Date()
            }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { item1, item2 in
            let comparisonResult: ComparisonResult
            switch sortOption {
            case .name:
                comparisonResult = item1.name.localizedCompare(item2.name)
            case .expirationDate:
                if item1.expirationDate == nil && item2.expirationDate == nil {
                    comparisonResult = .orderedSame
                } else if item1.expirationDate == nil {
                    comparisonResult = .orderedDescending
                } else if item2.expirationDate == nil {
                    comparisonResult = .orderedAscending
                } else {
                    comparisonResult = item1.expirationDate!.compare(item2.expirationDate!)
                }
            case .quantity:
                if item1.quantity < item2.quantity {
                    comparisonResult = .orderedAscending
                } else if item1.quantity > item2.quantity {
                    comparisonResult = .orderedDescending
                } else {
                    comparisonResult = .orderedSame
                }
            }
            return sortAscending ? (comparisonResult == .orderedAscending) : (comparisonResult == .orderedDescending)
        }
    }
    
    var groupedItems: [(String, [InventoryItem])] {
        let expired = filteredAndSortedItems.filter { item in
            guard let expirationDate = item.expirationDate else { return false }
            return expirationDate < Date()
        }
        
        let expiringSoon = filteredAndSortedItems.filter { item in
            guard let expirationDate = item.expirationDate else { return false }
            let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
            return daysUntilExpiration >= 0 && daysUntilExpiration <= 21
        }
        
        let fresh = filteredAndSortedItems.filter { item in
            guard let expirationDate = item.expirationDate else { return true }
            let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
            return daysUntilExpiration > 21
        }
        
        var groups: [(String, [InventoryItem])] = []
        if !expired.isEmpty { groups.append(("⚠️ Expired", expired)) }
        if !expiringSoon.isEmpty { groups.append(("⏰ Expiring Soon", expiringSoon)) }
        if !fresh.isEmpty { groups.append(("✓ Fresh", fresh)) }
        return groups
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading inventory...")
                            .foregroundColor(.secondary)
                    }
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        statsHeaderView
                            .padding()
                            .background(Color(.systemGroupedBackground))
                        
                        List {
                            if sortOption == .expirationDate {
                                ForEach(groupedItems, id: \.0) { groupName, items in
                                    Section(header: Text(groupName).font(.headline)) {
                                        ForEach(items) { item in
                                            NavigationLink(destination: InventoryDetailView(item: item, viewModel: viewModel)) {
                                                InventoryRowView(item: item)
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
                            } else {
                                ForEach(filteredAndSortedItems) { item in
                                    NavigationLink(destination: InventoryDetailView(item: item, viewModel: viewModel)) {
                                        InventoryRowView(item: item)
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
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Inventory")
            .searchable(text: $searchText, prompt: "Search items...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Label(option.rawValue, systemImage: option.icon)
                                    .tag(option)
                            }
                        }
                        .pickerStyle(.inline)
                        
                        Divider()
                        
                        Button(action: { sortAscending.toggle() }) {
                            Label(sortAscending ? "Ascending" : "Descending",
                                  systemImage: sortAscending ? "arrow.up" : "arrow.down")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle\(sortOption != .name ? ".fill" : "")")
                            if sortOption != .name { Text(sortOption.rawValue).font(.caption) }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddItem = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddInventoryItemView(viewModel: viewModel).environmentObject(authViewModel)
            }
            .task {
                guard let user = authViewModel.currentUser else { return }
                await viewModel.loadInventory(accountId: user.id)
            }
            .refreshable {
                if let accountId = authViewModel.currentAccountId {
                    await viewModel.loadInventory(accountId: accountId)
                }
            }
        }
    }
    
    private func deleteItem(_ item: InventoryItem) {
        Task {
            await viewModel.deleteItem(id: item.id)
        }
    }
    
    private var statsHeaderView: some View {
        HStack(spacing: 12) {
            InventoryStatCard(title: "Total", value: "\(viewModel.items.count)", icon: "cube.box.fill", color: .blue, isSelected: selectedFilter == .all) {
                selectedFilter = .all
                searchText = ""
            }
            InventoryStatCard(title: "Expiring", value: "\(expiringSoonCount)", icon: "clock.fill", color: .orange, isSelected: selectedFilter == .expiringSoon) {
                selectedFilter = .expiringSoon
                searchText = ""
            }
            InventoryStatCard(title: "Expired", value: "\(expiredCount)", icon: "exclamationmark.triangle.fill", color: .red, isSelected: selectedFilter == .expired) {
                selectedFilter = .expired
                searchText = ""
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.box")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No inventory items yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Track your food and supplies")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                showAddItem = true
            } label: {
                Label("Add Your First Item", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var expiringSoonCount: Int {
        viewModel.items.filter { item in
            guard let expirationDate = item.expirationDate else { return false }
            let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
            return daysUntilExpiration >= 0 && daysUntilExpiration <= 21
        }.count
    }
    
    private var expiredCount: Int {
        viewModel.items.filter { item in
            guard let expirationDate = item.expirationDate else { return false }
            return expirationDate < Date()
        }.count
    }
}

// MARK: - Stat Card
struct InventoryStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? color.opacity(0.15) : Color(.systemBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inventory Row
struct InventoryRowView: View {
    let item: InventoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                
                if let expirationDate = item.expirationDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(formatExpirationText(expirationDate))
                    }
                    .font(.system(size: 13))
                    .foregroundColor(expirationColor(expirationDate))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "infinity")
                            .font(.caption2)
                        Text("No expiration")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Text("Qty: \(formatQuantity(item.quantity))")
                    if let unit = item.unit { Text(unit) }
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        guard let expirationDate = item.expirationDate else { return "cube.box" }
        if expirationDate < Date() { return "exclamationmark.triangle.fill" }
        else if daysUntilExpiration(expirationDate) <= 21 { return "clock.fill" }
        else { return "checkmark.circle.fill" }
    }
    
    private var statusColor: Color {
        guard let expirationDate = item.expirationDate else { return .blue }
        if expirationDate < Date() { return .red }
        else if daysUntilExpiration(expirationDate) <= 21 { return .orange }
        else { return .green }
    }
    
    private func expirationColor(_ date: Date) -> Color {
        if date < Date() { return .red }
        else if daysUntilExpiration(date) <= 21 { return .orange }
        else { return .blue }
    }
    
    private func formatExpirationText(_ date: Date) -> String {
        let days = daysUntilExpiration(date)
        if date < Date() { let daysExpired = abs(days); return "Expired \(daysExpired) day\(daysExpired == 1 ? "" : "s") ago" }
        else if days == 0 { return "Expires today" }
        else if days == 1 { return "Expires tomorrow" }
        else if days <= 7 { return "Expires within 1 week in \(days) days" }
        else if days <= 21 { return "Expires in \(days) days" }
        else { return formatDate(date) }
    }
    
    private func daysUntilExpiration(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatQuantity(_ quantity: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: quantity as NSDecimalNumber) ?? "0"
    }
}

#Preview {
    InventoryListView()
        .environmentObject(AuthViewModel())
}
