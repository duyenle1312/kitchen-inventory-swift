//
//  AddInventoryItemView.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//

import SwiftUI
internal import Auth

struct AddInventoryItemView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var viewModel: InventoryViewModel
    
    @State private var name = ""
    @State private var quantity = ""
    @State private var unit = ""
    @State private var description = ""
    @State private var expirationDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Name", text: $name)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.decimalPad)
                    // DatePicker for expiration date
                    DatePicker(
                        "Expiration Date",
                        selection: $expirationDate,
                        displayedComponents: .date
                    )
                    TextField("Unit (e.g., kg, pcs)", text: $unit)
                }
                
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
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
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(name.isEmpty || quantity.isEmpty)
                    .foregroundColor(name.isEmpty || quantity.isEmpty ? .gray : .blue)
                }
            }
        }
    }
    
    private func saveItem() {
        guard let user = authViewModel.currentUser else {
            print("No current user")
            return
        }
        
        let accountId = user.id

        let expirationDateToSave = Calendar.current.noon(for: expirationDate)

        
        Task {
            await viewModel.addItem(
                accountId: accountId,
                name: name,
                quantity: Decimal(string: quantity)!,
                expirationDate: expirationDateToSave,
                unit: unit.isEmpty ? nil : unit,
                description: description.isEmpty ? nil : description
            )
            dismiss()
        }
    }
}
