//
//  ShoppingListService.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import Foundation
import Supabase

class ShoppingListService {
    private let client = SupabaseService.shared.client
    
    func fetchShoppingLists(accountId: UUID) async throws -> [ShoppingList] {
        
        do {
            let response: [ShoppingList] = try await client
                .from("shopping_lists")
                .select()
                .eq("account_id", value: accountId.uuidString)
                .is("deleted_at", value: nil)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("inside shopping list service: ", response)
            return response
        } catch {
            print("❌ Error:", error)
            if let supabaseError = error as? Error {
                print("Supabase error details:", supabaseError.localizedDescription)
            }
            throw error
        }
    }
    
    func createShoppingList(
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
    ) async throws -> ShoppingList {
        
        struct ShoppingListStruct: Codable {
            let account_id: String
            let created_by_user_id: String
            let item: String
            let description: String?
            let metadata: [String: AnyJSON]
            let location: String?
            let available_date_start: String?
            let available_date_end: String?
            let unit_price: Double?
            let quantity: Int?
            let purchased: Bool
            let scheduled_date: String?
            let priority: Int?
        }
        
        // Format dates properly for Supabase
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let availableDateStartString = availableDateStart.map { formatter.string(from: $0) }
        let availableDateEndString = availableDateEnd.map { formatter.string(from: $0) }
        let scheduledDateString = scheduledDate.map { formatter.string(from: $0) }

        let newShoppingList = ShoppingListStruct(
            account_id: accountId.uuidString,
            created_by_user_id: accountId.uuidString,
            item: item,
            description: description,
            metadata: [:],
            location: location,
            available_date_start: availableDateStartString,
            available_date_end: availableDateEndString,
            unit_price: unitPrice != nil ? NSDecimalNumber(decimal: unitPrice!).doubleValue : nil,
            quantity: quantity,
            purchased: purchased,
            scheduled_date: scheduledDateString,
            priority: priority
        )
        
        print("Attempting to insert shopping list item:", newShoppingList)
        
        do {
            let response: ShoppingList = try await client
                .from("shopping_lists")
                .insert(newShoppingList)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ Shopping list item inserted successfully:", response)
            return response
        } catch {
            print("❌ Error inserting shopping list item:", error)
            if let supabaseError = error as? Error {
                print("Supabase error details:", supabaseError.localizedDescription)
            }
            throw error
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
    ) async throws -> ShoppingList {
        
        print("Updating shopping list item...")
        
        var updates: [String: AnyJSON] = [:]
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Handle fields that should always be updated (even if nil)
        if let item = item {
            updates["item"] = AnyJSON(item)
        }
        
        // Description can be nil (cleared)
        if let description = description {
            updates["description"] = AnyJSON(description)
        } else {
            updates["description"] = AnyJSON(NSNull())
        }
        
        // Location can be nil (cleared)
        if let location = location {
            updates["location"] = AnyJSON(location)
        } else {
            updates["location"] = AnyJSON(NSNull())
        }
        
        // Unit price can be nil (cleared)
        if let unitPrice = unitPrice {
            let unitPriceAsDouble = NSDecimalNumber(decimal: unitPrice).doubleValue
            updates["unit_price"] = AnyJSON(unitPriceAsDouble)
        } else {
            updates["unit_price"] = AnyJSON(NSNull())
        }
        
        // Quantity can be nil (cleared)
        if let quantity = quantity {
            updates["quantity"] = AnyJSON(quantity)
        } else {
            updates["quantity"] = AnyJSON(NSNull())
        }
        
        // Purchased should always be set
        if let purchased = purchased {
            updates["purchased"] = AnyJSON(purchased)
        }
        
        // Priority can be nil (cleared)
        if let priority = priority {
            updates["priority"] = AnyJSON(priority)
        } else {
            updates["priority"] = AnyJSON(NSNull())
        }
        
        // Scheduled date can be nil (cleared)
        if let scheduledDate = scheduledDate {
            let dateString = formatter.string(from: scheduledDate)
            updates["scheduled_date"] = AnyJSON(dateString)
        } else {
            updates["scheduled_date"] = AnyJSON(NSNull())
        }
        
        // Available date start can be nil (cleared)
        if let availableDateStart = availableDateStart {
            let dateString = formatter.string(from: availableDateStart)
            updates["available_date_start"] = AnyJSON(dateString)
        } else {
            updates["available_date_start"] = AnyJSON(NSNull())
        }
        
        // Available date end can be nil (cleared)
        if let availableDateEnd = availableDateEnd {
            let dateString = formatter.string(from: availableDateEnd)
            updates["available_date_end"] = AnyJSON(dateString)
        } else {
            updates["available_date_end"] = AnyJSON(NSNull())
        }
        
        print("Updating shopping list item with id: \(id), updates: \(updates)")
        
        do {
            let response: ShoppingList = try await client
                .from("shopping_lists")
                .update(updates)
                .eq("id", value: id.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ Shopping list item updated successfully:", response)
            return response
        } catch {
            print("❌ Error updating shopping list item:", error)
            if let supabaseError = error as? Error {
                print("Supabase error details:", supabaseError.localizedDescription)
            }
            throw error
        }
    }
    
    func deleteShoppingList(id: UUID) async throws {
        let softDelete: [String: String] = [
            "deleted_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await client
            .from("shopping_lists")
            .update(softDelete)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // Additional helper methods
    
    func fetchPurchasedItems(accountId: UUID) async throws -> [ShoppingList] {
        let response: [ShoppingList] = try await client
            .from("shopping_lists")
            .select()
            .eq("account_id", value: accountId.uuidString)
            .eq("purchased", value: true)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func fetchUnpurchasedItems(accountId: UUID) async throws -> [ShoppingList] {
        let response: [ShoppingList] = try await client
            .from("shopping_lists")
            .select()
            .eq("account_id", value: accountId.uuidString)
            .eq("purchased", value: false)
            .is("deleted_at", value: nil)
            .order("priority", ascending: false)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func fetchShoppingListsByPriority(accountId: UUID, priority: Int) async throws -> [ShoppingList] {
        let response: [ShoppingList] = try await client
            .from("shopping_lists")
            .select()
            .eq("account_id", value: accountId.uuidString)
            .eq("priority", value: priority)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func fetchShoppingListsByLocation(accountId: UUID, location: String) async throws -> [ShoppingList] {
        let response: [ShoppingList] = try await client
            .from("shopping_lists")
            .select()
            .eq("account_id", value: accountId.uuidString)
            .eq("location", value: location)
            .is("deleted_at", value: nil)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func togglePurchased(id: UUID, purchased: Bool) async throws -> ShoppingList {
        let updates: [String: AnyJSON] = [
            "purchased": AnyJSON(purchased)
        ]
        
        let response: ShoppingList = try await client
            .from("shopping_lists")
            .update(updates)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
}
