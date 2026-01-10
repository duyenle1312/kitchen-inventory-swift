//
//  EditShoppingListView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import SwiftUI
internal import Auth


struct EditShoppingListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    let item: ShoppingList
    @ObservedObject var viewModel: ShoppingListViewModel

    // Form fields
    @State private var itemName = ""
    @State private var description = ""
    @State private var location = ""
    @State private var quantity = ""
    @State private var unitPrice = ""
    @State private var priority = 0
    @State private var purchased = false
    @State private var hasScheduledDate = false
    @State private var scheduledDate = Date()
    @State private var hasAvailabilityDates = false
    @State private var availableDateStart = Date()
    @State private var availableDateEnd = Date().addingTimeInterval(86400 * 7)

    @State private var isSubmitting = false
    @State private var showingDeleteAlert = false
    @FocusState private var focusedField: Field?

    enum Field {
        case item, description, location, quantity, unitPrice
    }

    var isFormValid: Bool {
        !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Calculated Total

    private var calculatedTotal: String {
        guard let qtyInt = Int(quantity),
              let priceDecimal = Decimal.fromString(unitPrice),
              qtyInt > 0 else {
            return "0.00"
        }

        let total = priceDecimal * Decimal(qtyInt)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return formatter.string(from: total as NSDecimalNumber) ?? "0.00"
    }

    var body: some View {
        NavigationView {
            Form {
                // Purchase Status
                Section {
                    Toggle("Purchased", isOn: $purchased)

                    if purchased {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Item marked as purchased")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Basic Information
                Section("Item Details") {
                    TextField("Item name", text: $itemName)
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

                    if let qty = Int(quantity),
                       let price = Decimal.fromString(unitPrice),
                       qty > 0, price > 0 {
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

                // Metadata
                Section("Information") {
                    LabeledContent("Created", value: item.created_at, format: .dateTime)
                    LabeledContent("Last Updated", value: item.updated_at, format: .dateTime)
                }

                // Delete Button
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Item")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
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
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
            .onAppear {
                loadItemData()
            }
        }
    }

    // MARK: - Load

    private func loadItemData() {
        itemName = item.item
        description = item.description ?? ""
        location = item.location ?? ""
        quantity = item.quantity.map { String($0) } ?? ""
        unitPrice = item.unitPriceDecimal.map {
            NumberFormatter.localizedString(from: $0 as NSDecimalNumber, number: .decimal)
        } ?? ""
        priority = item.priority ?? 0
        purchased = item.purchased

        if let scheduled = item.scheduled_date {
            hasScheduledDate = true
            scheduledDate = scheduled
        } else {
            hasScheduledDate = false
            scheduledDate = Date()
        }

        if let start = item.available_date_start,
           let end = item.available_date_end {
            hasAvailabilityDates = true
            availableDateStart = start
            availableDateEnd = end
        } else {
            hasAvailabilityDates = false
            availableDateStart = Date()
            availableDateEnd = Date().addingTimeInterval(86400 * 7)
        }
    }

    // MARK: - Save

    private func saveChanges() {
        guard isFormValid else { return }

        isSubmitting = true
        focusedField = nil

        let trimmedItem = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLoc = location.trimmingCharacters(in: .whitespacesAndNewlines)

        let quantityInt = Int(quantity)
        let unitPriceDecimal = Decimal.fromString(unitPrice)

        let calendar = Calendar.current
        let scheduledDateSafe = hasScheduledDate ? calendar.noon(for: scheduledDate) : nil
        let availableDateStartSafe = hasAvailabilityDates ? calendar.noon(for: availableDateStart) : nil
        let availableDateEndSafe = hasAvailabilityDates ? calendar.noon(for: availableDateEnd) : nil

        Task {
            await viewModel.updateShoppingList(
                id: item.id,
                item: trimmedItem,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                location: trimmedLoc.isEmpty ? nil : trimmedLoc,
                availableDateStart: availableDateStartSafe,
                availableDateEnd: availableDateEndSafe,
                unitPrice: unitPriceDecimal,
                quantity: quantityInt,
                purchased: purchased,
                scheduledDate: scheduledDateSafe,
                priority: priority > 0 ? priority : nil
            )

            isSubmitting = false
            dismiss()
        }
    }

    private func deleteItem() {
        Task {
            await viewModel.deleteShoppingList(id: item.id)
            dismiss()
        }
    }
}

