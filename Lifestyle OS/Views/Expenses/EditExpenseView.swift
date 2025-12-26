//
//  EditExpenseView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import SwiftUI
internal import Auth

struct EditExpenseView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ExpenseViewModel
    let expense: Expense
    
    @State private var amount = ""
    @State private var currency = "EUR"
    @State private var expenseDate = Date()
    @State private var category = ""
    @State private var description = ""
    @State private var location = ""
    @State private var item = ""
    @State private var unit = ""
    @State private var unitPrice = ""
    @State private var expireDate = Date()
    @State private var paymentMethod = ""
    @State private var hasExpireDate = false
    
    let currencies = ["EUR", "USD", "GBP", "JPY", "BGN", "CNY", "INR"]
    let categories = ["Food & Drink", "Home", "Rent & Utilities", "Gold/Silver", "ETFs", "Transport", "Telecom", "Crochet", "Fun", "Eating Out", "Work", "Other"]
    let paymentMethods = ["Food Voucher", "Trading 212", "Revolut", "UBB", "Curve", "VCB", "Cash", "Other"]
    
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
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateExpense()
                    }
                    .disabled(unit.isEmpty || unitPrice.isEmpty)
                    .foregroundColor(unit.isEmpty || unitPrice.isEmpty ? .gray : .blue)
                }
            }
            .onAppear {
                loadExpenseData()
            }
        }
    }
    
    private func loadExpenseData() {
        currency = expense.currency
        expenseDate = expense.expense_date
        category = expense.category ?? ""
        description = expense.description ?? ""
        location = expense.location ?? ""
        item = expense.item ?? ""
        unit = expense.unit.map { String($0) } ?? ""
        unitPrice = expense.unit_price.map { String(format: "%.2f", $0) } ?? ""
        paymentMethod = expense.payment_method ?? ""
        
        if let expDate = expense.expire_date {
            hasExpireDate = true
            expireDate = expDate
        } else {
            hasExpireDate = false
            expireDate = Date()
        }
    }
    
    private func updateExpense() {
        // Parse numeric values
        guard let unitInt = Int(unit),
              let unitPriceDecimal = Decimal(string: unitPrice) else {
            print("Invalid unit or unit price")
            return
        }
        
        // Calculate total amount
        let amountDecimal = unitPriceDecimal * Decimal(unitInt)
        
        // Create dates at start of day to avoid timezone issues
        let calendar = Calendar.current
        let expenseDateAtStartOfDay = calendar.startOfDay(for: expenseDate)
        let expireDateAtStartOfDay = hasExpireDate ? calendar.startOfDay(for: expireDate) : nil
        
        Task {
            await viewModel.updateExpense(
                id: expense.id,
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
