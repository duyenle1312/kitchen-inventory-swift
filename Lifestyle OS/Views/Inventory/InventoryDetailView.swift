//
//  InventoryDetailView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//

import SwiftUI

struct InventoryDetailView: View {
    let item: InventoryItem
    @ObservedObject var viewModel: InventoryViewModel

    @State private var isEditing = false
    @State private var editName = ""
    @State private var editQuantity = ""
    @State private var editUnit = ""
    @State private var editDescription = ""
    @State private var hasExpirationDate = false
    @State private var editExpirationDate: Date = Date()
    
    var body: some View {
        List {
            Section("Details") {
                if isEditing {
                    TextField("Name", text: $editName)
                    HStack {
                        TextField("Quantity", text: $editQuantity)
                            .keyboardType(.decimalPad)
                        TextField("Unit", text: $editUnit)
                    }
                    
                    Toggle("Has Expiration Date", isOn: $hasExpirationDate)
                    
                    if hasExpirationDate {
                        DatePicker(
                            "Expiration Date",
                            selection: $editExpirationDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .environment(\.timeZone, TimeZone.current)
                    }
                } else {
                    LabeledContent("Name", value: item.name)
                    LabeledContent("Quantity") {
                        Text("\(formatQuantity(item.quantity)) \(item.unit ?? "")")
                    }
                    
                    LabeledContent("Expires") {
                        if let expirationDate = item.expirationDate {
                            Text("\(formatFullDate(expirationDate))")
                                .foregroundColor(expirationDate < Date() ? .red : .secondary)
                                .lineLimit(1)
                        } else {
                            Text("No expiration")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("Description") {
                if isEditing {
                    TextEditor(text: $editDescription)
                        .frame(minHeight: 100)
                } else {
                    Text(item.description ?? "No description")
                        .foregroundColor(item.description == nil ? .gray : .primary)
                }
            }
            
            Section("Metadata") {
                LabeledContent("Created", value: item.createdAt.formatted())
                LabeledContent("Updated", value: item.updatedAt.formatted())
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveChanges()
                    } else {
                        startEditing()
                    }
                }
            }
        }
    }
    
    private func startEditing() {
        editName = item.name
        editQuantity = formatQuantity(item.quantity)
        editUnit = item.unit ?? ""
        editDescription = item.description ?? ""
        
        if let expirationDate = item.expirationDate {
            hasExpirationDate = true
            editExpirationDate = expirationDate
        } else {
            hasExpirationDate = false
            editExpirationDate = Date()
        }
        
        isEditing = true
    }
    
    private func saveChanges() {
        Task {
            let expirationDateToSave = hasExpirationDate ? Calendar.current.noon(for: editExpirationDate) : nil
            
            await viewModel.updateItem(
                id: item.id,
                name: editName,
                quantity: Decimal(string: editQuantity) ?? 0,
                unit: editUnit.isEmpty ? nil : editUnit,
                description: editDescription.isEmpty ? nil : editDescription,
                expirationDate: expirationDateToSave
            )
            
            isEditing = false
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    private func formatQuantity(_ quantity: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: quantity as NSDecimalNumber) ?? "0"
    }
}
