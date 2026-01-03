//
//  AddExpenseView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import SwiftUI
internal import Auth

struct AddExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: ExpenseViewModel
    
    @State private var amount = ""
    @State private var currency = "EUR"
    @State private var expenseDate = Date()
    @State private var category = "Food & Drink"
    @State private var description = ""
    @State private var location = ""
    @State private var item = ""
    @State private var unit = "1"
    @State private var unitPrice = ""
    @State private var expireDate = Date()
    @State private var paymentMethod = ""
    @State private var hasExpireDate = false
    
    let currencies = ["EUR", "USD", "GBP", "JPY", "BGN", "CNY", "INR"]
    let categories = ["Food & Drink", "Home", "Rent & Utilities", "Gold/Silver", "ETFs", "Transport", "Telecom", "Crochet", "Fun", "Eating Out", "Work", "Other"]
    let paymentMethods = ["Food Voucher", "T212", "Revolut", "UBB", "Curve", "VCB", "Cash", "Other"]
    
    // Computed property for calculated amount
    private var calculatedAmount: String {
        guard let unitInt = Int(unit), unitInt > 0,
              let unitPriceDecimal = Decimal(string: unitPrice), unitPriceDecimal > 0 else {
            return "0.00"
        }
        let total = unitPriceDecimal * Decimal(unitInt)
        return String(format: "%.2f", NSDecimalNumber(decimal: total).doubleValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                
                Section("Item Details") {
                    TextField("Item Name", text: $item)
                    
                    HStack {
                        TextField("Quantity", text: $unit)
                            .keyboardType(.numberPad)
                        Text("×")
                            .foregroundColor(.secondary)
                        TextField("Unit Price", text: $unitPrice)
                            .keyboardType(.decimalPad)
                    }
                    
                    Toggle("Has Expiration Date", isOn: $hasExpireDate)
                    
                    if hasExpireDate {
                        DatePicker(
                            "Expiration Date",
                            selection: $expireDate,
                            displayedComponents: .date
                        )
                    }
                }
                
                Section("Basic Information") {
                    // Amount (calculated automatically)
                    HStack {
                        Text("Total Amount")
                        Spacer()
                        Text(calculatedAmount)
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    // Currency
                    Picker("Currency", selection: $currency) {
                        ForEach(currencies, id: \.self) { curr in
                            Text(curr).tag(curr)
                        }
                    }
                    
                    // Expense Date
                    DatePicker(
                        "Date",
                        selection: $expenseDate,
                        displayedComponents: .date
                    )
                    
                    // Category
                    Picker("Category", selection: $category) {
                        Text("Select Category").tag("")
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
                
                
                Section("Additional Information") {
                    TextField("Location", text: $location)
                    
                    Picker("Payment Method", selection: $paymentMethod) {
                        Text("Select Method").tag("")
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                }
                
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(unit.isEmpty || unitPrice.isEmpty)
                    .foregroundColor(unit.isEmpty || unitPrice.isEmpty ? .gray : .blue)
                }
            }
        }
    }
    
    private func saveExpense() {
        guard let user = authViewModel.currentUser else {
            print("No current user")
            return
        }
        
        let accountId = user.id
        print("User ID: \(user.id)")
        
        
        // Parse numeric values
        guard let unitInt = Int(unit),
              let unitPriceDecimal = Decimal.fromString(unitPrice) else {
            print("Invalid unit or unit price")
            return
        }

        // Calculate total amount
        let amountDecimal = unitPriceDecimal * Decimal(unitInt)
        
        // Create dates at start of day to avoid timezone issues
        
        let expenseDateAtStartOfDay = hasExpireDate ? Calendar.current.noon(for: expenseDate) : Date()
        
        let expireDateAtStartOfDay = hasExpireDate ? Calendar.current.noon(for: expireDate) : nil

//        
//        let calendar = Calendar.current
//        let expenseDateAtStartOfDay = calendar.startOfDay(for: expenseDate)
//        let expireDateAtStartOfDay = hasExpireDate ? calendar.startOfDay(for: expireDate) : nil
        
        Task {
            await viewModel.addExpense(
                accountId: accountId,
                amount: amountDecimal,
                currency: currency,
                expenseDate: expenseDateAtStartOfDay,
                category: category.isEmpty ? nil : category,
                description: description.isEmpty ? nil : description,
                location: location.isEmpty ? nil : location,
                unit: unitInt,
                unitPrice: unitPriceDecimal,
                expireDate: expireDateAtStartOfDay,
                paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
                item: item.isEmpty ? nil : item
            )
            dismiss()
        }
    }
}

#Preview {
    AddExpenseView(viewModel: ExpenseViewModel())
        .environmentObject(AuthViewModel())
}
