//
//  ExpenseViewModel.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import Foundation
import Combine

@MainActor
class ExpenseViewModel: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let expenseService = ExpenseService()
    
    func loadExpenses(accountId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            expenses = try await expenseService.fetchExpenses(accountId: accountId)
            print("inside expense view model")
            print(expenses)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addExpense(
        accountId: UUID,
        amount: Decimal,
        currency: String,
        expenseDate: Date,
        category: String?,
        description: String?,
        location: String?,
        unit: Int?,
        unitPrice: Decimal?,
        expireDate: Date?,
        paymentMethod: String?,
        item: String?
    ) async {
        do {
            let newExpense = try await expenseService.createExpense(
                accountId: accountId,
                amount: amount,
                currency: currency,
                expenseDate: expenseDate,
                category: category,
                description: description,
                location: location,
                unit: unit,
                unitPrice: unitPrice,
                expireDate: expireDate,
                paymentMethod: paymentMethod,
                item: item
            )
            expenses.append(newExpense)
            expenses.sort { $0.expense_date > $1.expense_date }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateExpense(
        id: UUID,
        amount: Decimal?,
        currency: String?,
        expenseDate: Date?,
        category: String?,
        description: String?,
        location: String?,
        unit: Int?,
        unitPrice: Decimal?,
        expireDate: Date?,
        paymentMethod: String?,
        item: String?
    ) async {
        do {
            let updated = try await expenseService.updateExpense(
                id: id,
                amount: amount,
                currency: currency,
                expenseDate: expenseDate,
                category: category,
                description: description,
                location: location,
                unit: unit,
                unitPrice: unitPrice,
                expireDate: expireDate,
                paymentMethod: paymentMethod,
                item: item
            )
            
            if let index = expenses.firstIndex(where: { $0.id == id }) {
                expenses[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
            print(errorMessage)
        }
    }
    
    func deleteExpense(id: UUID) async {
        do {
            try await expenseService.deleteExpense(id: id)
            expenses.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // Additional helper methods
    
    func loadExpensesByCategory(accountId: UUID, category: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            expenses = try await expenseService.fetchExpensesByCategory(
                accountId: accountId,
                category: category
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadExpensesByDateRange(accountId: UUID, startDate: Date, endDate: Date) async {
        isLoading = true
        errorMessage = nil
        
        do {
            expenses = try await expenseService.fetchExpensesByDateRange(
                accountId: accountId,
                startDate: startDate,
                endDate: endDate
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Computed properties for analytics
    
    var totalExpenses: Decimal {
        expenses.reduce(0) { $0 + Decimal($1.amount) }
    }
    
    var expensesByCategory: [String: Decimal] {
        var categoryTotals: [String: Decimal] = [:]
        
        for expense in expenses {
            let category = expense.category ?? "Uncategorized"
            let amount = Decimal(expense.amount)
            categoryTotals[category, default: 0] += amount
        }
        
        return categoryTotals
    }
    
    var averageExpenseAmount: Decimal {
        guard !expenses.isEmpty else { return 0 }
        return totalExpenses / Decimal(expenses.count)
    }
}
