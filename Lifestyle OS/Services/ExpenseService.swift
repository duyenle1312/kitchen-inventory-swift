import Foundation
import Supabase

class ExpenseService {
    private let client = SupabaseService.shared.client
    
    func fetchExpenses(accountId: UUID) async throws -> [Expense] {
        
        do {
            let response: [Expense] = try await client
                .from("expenses")
                .select()
                .eq("account_id", value: accountId.uuidString)
                .is("deleted_at", value: nil)
                .order("expense_date", ascending: false)
                .execute()
                .value
            
            print("inside expense service: ", response)
            return response
        } catch {
            print("❌ Error:", error)
            if let supabaseError = error as? Error {
                print("Supabase error details:", supabaseError.localizedDescription)
            }
            throw error
        }

    }
    
    func createExpense(
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
    ) async throws -> Expense {
        
        struct ExpenseStruct: Codable {
            let account_id: String
            let created_by_user_id: String
            let amount: Double
            let currency: String
            let expense_date: String
            let category: String?
            let description: String?
            let location: String?
            let unit: Int?
            let unit_price: Double?
            let expire_date: String?
            let payment_method: String?
            let item: String?
            let metadata: [String: AnyJSON]
        }
        
        // Format dates properly for Supabase
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expenseDateString = formatter.string(from: expenseDate)
        let expireDateString = expireDate.map { formatter.string(from: $0) }

        let newExpense = ExpenseStruct(
            account_id: accountId.uuidString,
            created_by_user_id: accountId.uuidString,
            amount: NSDecimalNumber(decimal: amount).doubleValue,
            currency: currency,
            expense_date: expenseDateString,
            category: category,
            description: description,
            location: location,
            unit: unit,
            unit_price: unitPrice != nil ? NSDecimalNumber(decimal: unitPrice!).doubleValue : nil,
            expire_date: expireDateString,
            payment_method: paymentMethod,
            item: item,
            metadata: [:]
        )
        
        print("Attempting to insert expense:", newExpense)
        
        do {
            let response: Expense = try await client
                .from("expenses")
                .insert(newExpense)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ Expense inserted successfully:", response)
            return response
        } catch {
            print("❌ Error inserting expense:", error)
            if let supabaseError = error as? Error {
                print("Supabase error details:", supabaseError.localizedDescription)
            }
            throw error
        }
    }
    
    func createExpensesFromReceipt(
        accountId: UUID,
        receipt: ScannedReceipt,
        items: [ReceiptItem]
    ) async throws -> [Expense] {
        var createdExpenses: [Expense] = []
        
        print("=== CREATING EXPENSES FROM RECEIPT ===")
        print("Account ID: \(accountId)")
        print("Receipt store: \(receipt.storeName ?? "Unknown")")
        print("Receipt date: \(Date())")
        print("Items to create: \(items.count)")
        
        for (index, item) in items.enumerated() {
            let itemName = item.displayName
            let location = receipt.storeName
            
            print("Creating expense \(index + 1)/\(items.count): \(itemName) - \(item.amount) \(receipt.currency)")
            
            do {
                let expense = try await createExpense(
                    accountId: accountId,
                    amount: item.amount,
                    currency: receipt.currency,
                    expenseDate: Date(),
                    category: item.category,
                    description: nil,
                    location: location,
                    unit: 1,
                    unitPrice: item.amount,
                    expireDate: nil,
                    paymentMethod: "Food Voucher",
                    item: itemName
                )
                
                createdExpenses.append(expense)
                print("✅ Created expense: \(expense.item ?? "Unknown")")
            } catch {
                print("❌ Failed to create expense for \(itemName): \(error.localizedDescription)")
                // Continue with other items even if one fails
            }
        }
        
        print("=== RECEIPT IMPORT COMPLETE ===")
        print("Successfully created \(createdExpenses.count) out of \(items.count) expenses")
        
        return createdExpenses
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
    ) async throws -> Expense {
        
        print("Updating expense...")
        
        var updates: [String: AnyJSON] = [:]
        
        if let amount = amount {
            let amountAsDouble = NSDecimalNumber(decimal: amount).doubleValue
            updates["amount"] = AnyJSON(amountAsDouble)
        }
        
        if let unitPrice = unitPrice {
            let unitPriceAsDouble = NSDecimalNumber(decimal: unitPrice).doubleValue
            updates["unit_price"] = AnyJSON(unitPriceAsDouble)
        }
        
        if let expenseDate = expenseDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = formatter.string(from: expenseDate)
            updates["expense_date"] = AnyJSON(dateString)
        }
        
        if let expireDate = expireDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = formatter.string(from: expireDate)
            updates["expire_date"] = AnyJSON(dateString)
        }

        if let currency = currency { updates["currency"] = AnyJSON(currency) }
        if let category = category { updates["category"] = AnyJSON(category) }
        if let description = description { updates["description"] = AnyJSON(description) }
        if let location = location { updates["location"] = AnyJSON(location) }
        if let unit = unit { updates["unit"] = AnyJSON(unit) }
        if let paymentMethod = paymentMethod { updates["payment_method"] = AnyJSON(paymentMethod) }
        if let item = item { updates["item"] = AnyJSON(item) }
        
        print("Updating expense with id: \(id), updates: \(updates)")
        
        do {
            let response: Expense = try await client
                .from("expenses")
                .update(updates)
                .eq("id", value: id.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ Expense updated successfully:", response)
            return response
        } catch {
            print("❌ Error updating expense:", error)
            if let supabaseError = error as? Error {
                print("Supabase error details:", supabaseError.localizedDescription)
            }
            throw error
        }
    }
    
    func deleteExpense(id: UUID) async throws {
        let softDelete: [String: String] = [
            "deleted_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await client
            .from("expenses")
            .update(softDelete)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // Additional helper methods
    
    func fetchExpensesByCategory(accountId: UUID, category: String) async throws -> [Expense] {
        let response: [Expense] = try await client
            .from("expenses")
            .select()
            .eq("account_id", value: accountId.uuidString)
            .eq("category", value: category)
            .is("deleted_at", value: nil)
            .order("expense_date", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func fetchExpensesByDateRange(
        accountId: UUID,
        startDate: Date,
        endDate: Date
    ) async throws -> [Expense] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let response: [Expense] = try await client
            .from("expenses")
            .select()
            .eq("account_id", value: accountId.uuidString)
            .gte("expense_date", value: formatter.string(from: startDate))
            .lte("expense_date", value: formatter.string(from: endDate))
            .is("deleted_at", value: nil)
            .order("expense_date", ascending: false)
            .execute()
            .value
        
        return response
    }
}
