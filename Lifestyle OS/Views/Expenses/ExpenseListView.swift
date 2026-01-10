//
//  ExpenseListView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import SwiftUI
internal import Auth

struct ExpenseListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ExpenseViewModel()
    @State private var showingAddExpense = false
    @State private var selectedExpense: Expense?
    @State private var searchText = ""
    @State private var selectedCategory: String = "All"
    
    let categories = ["All", "Food & Drink", "Home", "Rent & Utilities", "Gold/Silver", "ETFs", "Transport", "Telecom", "Crochet", "Fun", "Eating Out", "Work", "Other"]
    
    var filteredExpenses: [Expense] {
        print("DEBUG: Total expenses: \(viewModel.expenses.count)")
        print("DEBUG: Search text: '\(searchText)'")
        print("DEBUG: Selected category: '\(selectedCategory)'")
        
        var filtered = viewModel.expenses
        
        // Filter by category
        if selectedCategory != "All" {
            filtered = filtered.filter { expense in
                expense.category == selectedCategory
            }
            print("DEBUG: After category filter: \(filtered.count)")
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { expense in
                let itemMatch = expense.item?.localizedCaseInsensitiveContains(searchText) ?? false
                let descMatch = expense.description?.localizedCaseInsensitiveContains(searchText) ?? false
                let locMatch = expense.location?.localizedCaseInsensitiveContains(searchText) ?? false
                return itemMatch || descMatch || locMatch
            }
            print("DEBUG: After search filter: \(filtered.count)")
        }
        
        print("DEBUG: Final filtered count: \(filtered.count)")
        return filtered
    }
    
    var totalAmount: String {
        let total = filteredExpenses.reduce(0.0) { $0 + $1.amount }
        return String(format: "%.2f", total)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Summary card
                VStack(spacing: 8) {
                    Text("Total Expenses")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(totalAmount)
                        .font(.system(size: 32, weight: .bold))
                    Text(viewModel.expenses.first?.currency ?? "USD")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGroupedBackground))
                
                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryChip(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))
                
                // Expense list
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredExpenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No expenses yet" : "No matching expenses")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if searchText.isEmpty {
                            Text("Tap + to add your first expense")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(groupedExpenses.keys.sorted(by: >), id: \.self) { date in
                            Section(header: Text(formatSectionDate(date))) {
                                ForEach(groupedExpenses[date] ?? []) { expense in
                                    ExpenseRow(expense: expense)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedExpense = expense
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                deleteExpense(expense)
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
            .navigationTitle("Expenses")
            .searchable(text: $searchText, prompt: "Search expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                AddExpenseView(viewModel: viewModel)
            }
            .sheet(item: $selectedExpense) { expense in
                ExpenseDetailView(expense: expense, viewModel: viewModel)
            }
            .task {
                if let user = authViewModel.currentUser {
                    print("DEBUG: Loading expenses for user: \(user.id)")
                    await viewModel.loadExpenses(accountId: user.id)
                    print("DEBUG: Loaded \(viewModel.expenses.count) expenses")
                    if !viewModel.expenses.isEmpty {
                        print("DEBUG: First expense: \(viewModel.expenses[0])")
                    }
                } else {
                    print("DEBUG: No current user")
                }
            }
        }
    }
    
    // Group expenses by date
    private var groupedExpenses: [Date: [Expense]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredExpenses) { expense in
            calendar.startOfDay(for: expense.expense_date)
        }
        return grouped
    }
    
    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "EEEE, MMM d"
        } else {
            formatter.dateFormat = "EEEE, MMM d, yyyy"
        }
        
        return formatter.string(from: date)
    }
    
    private func deleteExpense(_ expense: Expense) {
        Task {
            await viewModel.deleteExpense(id: expense.id)
        }
    }
}

// MARK: - Supporting Views

struct CategoryChip: View {
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

struct ExpenseRow: View {
    let expense: Expense
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIcon)
                    .foregroundColor(categoryColor)
                    .font(.system(size: 18))
            }
            
            // Expense details
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.item ?? expense.category ?? "Expense")
                    .font(.system(size: 16, weight: .semibold))
                
                HStack(spacing: 4) {
                    if let location = expense.location {
//                        Image(systemName: "mappin.circle.fill")
//                            .font(.system(size: 12))
                        Text(location)
                            .font(.system(size: 13))
                    }
                    if let paymentMethod = expense.payment_method {
                        if expense.location != nil {
                            Text("•")
                                .font(.system(size: 13))
                        }
                        Text(paymentMethod)
                            .font(.system(size: 13))
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", expense.amount))
                    .font(.system(size: 16, weight: .bold))
                Text(expense.currency)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    

    private var categoryIcon: String {
        switch expense.category {
            case "Food & Drink": return "fork.knife"
            case "Home": return "cart.fill"
            case "Transport": return "tram.fill"
            case "Telecom": return "iphone.gen1"
            case "Fun": return "figure.strengthtraining.traditional"
            case "Rent & Utilities": return "house.fill"
            case "Work": return "desktopcomputer"
            case "Crochet": return "teddybear.fill"
            case "Eating Out": return "fork.knife"
            case "Gold/Silver": return "eurosign.bank.building.fill"
            case "ETFs": return "building.columns"
            default: return "tag.fill"
        }
    }
    
    private var categoryColor: Color {
        switch expense.category {
            case "Food & Drink": return .blue
            case "Transport": return .orange
            case "Home": return .indigo
            case "Crochet": return .orange
            case "Eating Out": return .pink
            case "Fun": return .purple
            case "Rent & Utilities": return .cyan
            case "Telecom": return .mint
            case "Work": return .gray
            case "Gold/Silver": return .yellow
            case "ETFs": return .green
            default: return .gray
        }
    }
}

// MARK: - Detail View Placeholder
struct ExpenseDetailView: View {
    let expense: Expense
    @ObservedObject var viewModel: ExpenseViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingEditExpense = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Amount") {
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(String(format: "%.2f %@", expense.amount, expense.currency))
                            .font(.headline)
                    }
                    
                    if let unit = expense.unit, let unitPrice = expense.unit_price {
                        HStack {
                            Text("Unit Price")
                            Spacer()
                            Text(String(format: "%.2f × %d", unitPrice, unit))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Details") {
                    if let item = expense.item {
                        LabeledRow(label: "Item", value: item)
                    }
                    if let category = expense.category {
                        LabeledRow(label: "Category", value: category)
                    }
                    LabeledRow(label: "Date", value: formatDate(expense.expense_date))
                    
                    if let location = expense.location {
                        LabeledRow(label: "Location", value: location)
                    }
                    if let paymentMethod = expense.payment_method {
                        LabeledRow(label: "Payment", value: paymentMethod)
                    }
                    if let expireDate = expense.expire_date {
                        LabeledRow(label: "Expires", value: formatDate(expireDate))
                    }
                }
                
                if let description = expense.description {
                    Section("Description") {
                        Text(description)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Expense Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditExpense = true
                    }
                }
            }
            .sheet(isPresented: $showingEditExpense) {
                EditExpenseView(expense: expense, viewModel: viewModel)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct LabeledRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ExpenseListView()
        .environmentObject(AuthViewModel())
}
