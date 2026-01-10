//
//  InventoryViewModel.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//

import Foundation
import Combine

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let inventoryService = InventoryService()
    
    func loadInventory(accountId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            items = try await inventoryService.fetchInventoryItems(accountId: accountId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addItem(
        accountId: UUID,
        name: String,
        quantity: Decimal,
        expirationDate: Date?,
        unit: String?,
        description: String?
    ) async {
        do {
            let newItem = try await inventoryService.createInventoryItem(
                accountId: accountId,
                name: name,
                quantity: quantity,
                unit: unit,
                description: description,
                expirationDate: expirationDate
            )
            items.append(newItem)
            items.sort { $0.name < $1.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateItem(
        id: UUID,
        name: String?,
        quantity: Decimal?,
        unit: String?,
        description: String?,
        expirationDate: Date?
    ) async {
        do {
            print("Updating item with expiration date: \(String(describing: expirationDate))")
            
            let updated = try await inventoryService.updateInventoryItem(
                id: id,
                name: name,
                quantity: quantity,
                expirationDate: expirationDate,
                unit: unit,
                description: description
            )
            
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error updating item: \(errorMessage ?? "Unknown error")")
        }
    }
    
    func deleteItem(id: UUID) async {
        do {
            try await inventoryService.deleteInventoryItem(id: id)
            items.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
