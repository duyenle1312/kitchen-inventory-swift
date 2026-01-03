//
//  AddShoppingListView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import SwiftUI
internal import Auth

struct AddShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: ShoppingListViewModel
    
    // Form fields
    @State private var item = ""
    @State private var description = ""
    @State private var location = ""
    @State private var quantity = ""
    @State private var unitPrice = ""
    @State private var priority = 3
    @State private var hasScheduledDate = false
    @State private var scheduledDate = Date()
    @State private var hasAvailabilityDates = false
    
    @State private var availableDateStart = Calendar.current.noon(for: Date())
    @State private var availableDateEnd = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.noon(for: Date()))!

    
//    @State private var availableDateStart = Date()
//    @State private var availableDateEnd = Date().addingTimeInterval(86400 * 7) // 7 days later
    
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case item, description, location, quantity, unitPrice
    }
    
    var isFormValid: Bool {
        !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // Computed property for calculated total
    private var calculatedTotal: String {
        guard let qtyInt = Int(quantity), qtyInt > 0,
              let priceDecimal = Decimal(string: unitPrice), priceDecimal > 0 else {
            return "0.00"
        }
        let total = priceDecimal * Decimal(qtyInt)
        return String(format: "%.2f", NSDecimalNumber(decimal: total).doubleValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section("Item Details") {
                    TextField("Item name", text: $item)
                        .focused($focusedField, equals: .item)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .focused($focusedField, equals: .description)
                        .lineLimit(2...4)
                    
                    TextField("Location/Store (optional)", text: $location)
                        .focused($focusedField, equals: .location)
                }
                
                // Quantity and Price
                Section("Quantity & Price") {
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("0", text: $quantity)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .quantity)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Unit Price")
                        Spacer()
                        TextField("0.00", text: $unitPrice)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .unitPrice)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    if !quantity.isEmpty && !unitPrice.isEmpty,
                       Int(quantity) ?? 0 > 0,
                       (Decimal(string: unitPrice) ?? 0) > 0 {
                        HStack {
                            Text("Total")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text("€\(calculatedTotal)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Priority
                Section("Priority") {
                    Picker("Priority Level", selection: $priority) {
                        Text("None").tag(0)
                        Text("⭐ Low").tag(1)
                        Text("⭐⭐ Medium").tag(2)
                        Text("⭐⭐⭐ High").tag(3)
                        Text("⭐⭐⭐⭐ Urgent").tag(4)
                        Text("⭐⭐⭐⭐⭐ Critical").tag(5)
                    }
                    .pickerStyle(.menu)
                }
                
                // Scheduled Date
                Section {
                    Toggle("Set scheduled date", isOn: $hasScheduledDate)
                    
                    if hasScheduledDate {
                        DatePicker(
                            "Scheduled for",
                            selection: $scheduledDate,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Set a date when you plan to purchase this item")
                }
                
                // Availability Dates
                Section {
                    Toggle("Set availability period", isOn: $hasAvailabilityDates)
                    
                    if hasAvailabilityDates {
                        DatePicker(
                            "Available from",
                            selection: $availableDateStart,
                            displayedComponents: .date
                        )
                        
                        DatePicker(
                            "Available until",
                            selection: $availableDateEnd,
                            in: availableDateStart...,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("Availability")
                } footer: {
                    Text("Useful for seasonal items or limited-time offers")
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addItem()
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .foregroundColor(!isFormValid || isSubmitting ? .gray : .blue)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                focusedField = .item
            }
        }
    }
    
    private func addItem() {
        guard isFormValid,
              let user = authViewModel.currentUser else {
            print("Invalid form or no current user")
            return
        }
        
        isSubmitting = true
        focusedField = nil
        
        let accountId = user.id
        let itemName = item.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let loc = location.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get dates at start of day to avoid timezone issues
        let unitPriceDecimal = Decimal.fromString(unitPrice)

        let calendar = Calendar.current
        
        let scheduledDateAtStartOfDay = hasScheduledDate ? calendar.noon(for: scheduledDate) : nil
        let availableStartAtStartOfDay = hasAvailabilityDates ? calendar.noon(for: availableDateStart) : nil
        let availableEndAtStartOfDay = hasAvailabilityDates ? calendar.noon(for: availableDateEnd) : nil

        
        Task {
            await viewModel.addShoppingList(
                accountId: accountId,
                item: itemName,
                description: desc.isEmpty ? nil : desc,
                location: loc.isEmpty ? nil : loc,
                availableDateStart: availableStartAtStartOfDay,
                availableDateEnd: availableEndAtStartOfDay,
                unitPrice: unitPriceDecimal,
                quantity: Int(quantity),
                purchased: false,
                scheduledDate: scheduledDateAtStartOfDay,
                priority: priority > 0 ? priority : nil
            )
            
            isSubmitting = false
            dismiss()
        }
    }
}

#Preview {
    AddShoppingListView(viewModel: ShoppingListViewModel())
        .environmentObject(AuthViewModel())
}
