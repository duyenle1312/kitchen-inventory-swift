//
//  ShoppingListViewModel.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import Foundation
import Combine

@MainActor
class ShoppingListViewModel: ObservableObject {
    @Published var shoppingLists: [ShoppingList] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let shoppingListService = ShoppingListService()
    
    func loadShoppingLists(accountId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            shoppingLists = try await shoppingListService.fetchShoppingLists(accountId: accountId)
            print("inside shopping list view model")
            print(shoppingLists)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addShoppingList(
        accountId: UUID,
        item: String,
        description: String?,
        location: String?,
        availableDateStart: Date?,
        availableDateEnd: Date?,
        unitPrice: Decimal?,
        quantity: Int?,
        purchased: Bool = false,
        scheduledDate: Date?,
        priority: Int?
    ) async {
        do {
            let newShoppingList = try await shoppingListService.createShoppingList(
                accountId: accountId,
                item: item,
                description: description,
                location: location,
                availableDateStart: availableDateStart,
                availableDateEnd: availableDateEnd,
                unitPrice: unitPrice,
                quantity: quantity,
                purchased: purchased,
                scheduledDate: scheduledDate,
                priority: priority
            )
            shoppingLists.append(newShoppingList)
            shoppingLists.sort { $0.created_at > $1.created_at }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateShoppingList(
        id: UUID,
        item: String?,
        description: String?,
        location: String?,
        availableDateStart: Date?,
        availableDateEnd: Date?,
        unitPrice: Decimal?,
        quantity: Int?,
        purchased: Bool?,
        scheduledDate: Date?,
        priority: Int?
    ) async {
        do {
            let updated = try await shoppingListService.updateShoppingList(
                id: id,
                item: item,
                description: description,
                location: location,
                availableDateStart: availableDateStart,
                availableDateEnd: availableDateEnd,
                unitPrice: unitPrice,
                quantity: quantity,
                purchased: purchased,
                scheduledDate: scheduledDate,
                priority: priority
            )
            
            if let index = shoppingLists.firstIndex(where: { $0.id == id }) {
                shoppingLists[index] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
            print(errorMessage)
        }
    }
    
    func deleteShoppingList(id: UUID) async {
        do {
            try await shoppingListService.deleteShoppingList(id: id)
            shoppingLists.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func togglePurchased(id: UUID) async {
        guard let index = shoppingLists.firstIndex(where: { $0.id == id }) else { return }
        let currentStatus = shoppingLists[index].purchased
        
        do {
            let updated = try await shoppingListService.togglePurchased(
                id: id,
                purchased: !currentStatus
            )
            shoppingLists[index] = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // Additional helper methods
    
    func loadPurchasedItems(accountId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            shoppingLists = try await shoppingListService.fetchPurchasedItems(accountId: accountId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadUnpurchasedItems(accountId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            shoppingLists = try await shoppingListService.fetchUnpurchasedItems(accountId: accountId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadShoppingListsByPriority(accountId: UUID, priority: Int) async {
        isLoading = true
        errorMessage = nil
        
        do {
            shoppingLists = try await shoppingListService.fetchShoppingListsByPriority(
                accountId: accountId,
                priority: priority
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadShoppingListsByLocation(accountId: UUID, location: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            shoppingLists = try await shoppingListService.fetchShoppingListsByLocation(
                accountId: accountId,
                location: location
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Computed properties for analytics
    
    var purchasedItems: [ShoppingList] {
        shoppingLists.filter { $0.purchased }
    }
    
    var unpurchasedItems: [ShoppingList] {
        shoppingLists.filter { !$0.purchased }
    }
    
    var totalEstimatedCost: Decimal {
        shoppingLists.reduce(0) { total, item in
            guard let unitPrice = item.unitPriceDecimal,
                  let quantity = item.quantity else {
                return total
            }
            return total + (unitPrice * Decimal(quantity))
        }
    }
    
    var totalPurchasedCost: Decimal {
        purchasedItems.reduce(0) { total, item in
            guard let unitPrice = item.unitPriceDecimal,
                  let quantity = item.quantity else {
                return total
            }
            return total + (unitPrice * Decimal(quantity))
        }
    }
    
    var totalUnpurchasedCost: Decimal {
        unpurchasedItems.reduce(0) { total, item in
            guard let unitPrice = item.unitPriceDecimal,
                  let quantity = item.quantity else {
                return total
            }
            return total + (unitPrice * Decimal(quantity))
        }
    }
    
    var itemsByLocation: [String: [ShoppingList]] {
        Dictionary(grouping: shoppingLists) { item in
            item.location ?? "No Location"
        }
    }
    
    var itemsByPriority: [Int: [ShoppingList]] {
        Dictionary(grouping: shoppingLists) { item in
            item.priority ?? 0
        }
    }
    
    var completionPercentage: Double {
        guard !shoppingLists.isEmpty else { return 0 }
        let purchasedCount = purchasedItems.count
        return (Double(purchasedCount) / Double(shoppingLists.count)) * 100
    }
    
    var highPriorityItems: [ShoppingList] {
        shoppingLists.filter { ($0.priority ?? 0) >= 3 && !$0.purchased }
            .sorted { ($0.priority ?? 0) > ($1.priority ?? 0) }
    }
    
    var itemsCount: Int {
        shoppingLists.count
    }
    
    var purchasedCount: Int {
        purchasedItems.count
    }
    
    var unpurchasedCount: Int {
        unpurchasedItems.count
    }
}
