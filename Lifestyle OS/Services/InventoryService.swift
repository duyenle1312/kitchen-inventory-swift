//
//  InventoryService.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//

import Foundation
import Supabase

class InventoryService {
    private let client = SupabaseService.shared.client
    
    func fetchInventoryItems(accountId: UUID) async throws -> [InventoryItem] {
        let response: [InventoryItem] = try await client
            .from("inventory_items")
            .select()
            .eq("account_id", value: accountId.uuidString)
            .is("deleted_at", value: nil)
            .order("name")
            .execute()
            .value
        
        return response
    }
    
    func createInventoryItem(
        accountId: UUID,
        name: String,
        quantity: Decimal,
        unit: String?,
        description: String?,
        expirationDate: Date?
    ) async throws -> InventoryItem {
        
        struct InventoryItemStruct: Codable {
            let account_id: String
            let created_by_user_id: String
            let name: String
            let quantity: Double
            let expiration_date: String?
            let unit: String?
            let description: String?
            let metadata: [String: AnyCodable]
        }

        // Format expiration date if present
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expirationDateString = expirationDate.map { formatter.string(from: $0) }

        let newItem = InventoryItemStruct(
            account_id: accountId.uuidString,
            created_by_user_id: accountId.uuidString,
            name: name,
            quantity: NSDecimalNumber(decimal: quantity).doubleValue,
            expiration_date: expirationDateString,
            unit: unit,
            description: description,
            metadata: [:]
        )
        
        print("Attempting to insert item:", newItem)
        
        do {
            let response: InventoryItem = try await client
                .from("inventory_items")
                .insert(newItem)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ Item inserted successfully:", response)
            return response
        } catch {
            print("❌ Error inserting item:", error)
            if let supabaseError = error as? Error {
                print("Supabase error details:", supabaseError.localizedDescription)
            }
            throw error
        }
    }
    
    func updateInventoryItem(
        id: UUID,
        name: String?,
        quantity: Decimal?,
        expirationDate: Date?,
        unit: String?,
        description: String?
    ) async throws -> InventoryItem {
        
        print("Updating inventory item...")
        print("Expiration date: \(String(describing: expirationDate))")
        
        var updates: [String: AnyCodable] = [:]
        
        if let quantity = quantity {
            let quantityAsDouble = NSDecimalNumber(decimal: quantity).doubleValue
            updates["quantity"] = AnyCodable(quantityAsDouble)
        }
        
        // Handle optional expiration date
        if let expirationDate = expirationDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = formatter.string(from: expirationDate)
            updates["expiration_date"] = AnyCodable(dateString)
        } else {
            // Explicitly set to null to remove expiration date
            updates["expiration_date"] = AnyCodable(NSNull())
        }

        if let name = name { updates["name"] = AnyCodable(name) }
        if let unit = unit { updates["unit"] = AnyCodable(unit) }
        if let description = description { updates["description"] = AnyCodable(description) }
        
        print("Update payload: \(updates)")
        
        do {
            let response: InventoryItem = try await client
                .from("inventory_items")
                .update(updates)
                .eq("id", value: id.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ Item updated successfully:", response)
            return response
        } catch {
            print("❌ Error updating item:", error)
            if let supabaseError = error as? Error {
                print("Supabase error details:", supabaseError.localizedDescription)
            }
            throw error
        }
    }
    
    func deleteInventoryItem(id: UUID) async throws {
        let softDelete: [String: String] = [
            "deleted_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        try await client
            .from("inventory_items")
            .update(softDelete)
            .eq("id", value: id.uuidString)
            .execute()
    }
}
