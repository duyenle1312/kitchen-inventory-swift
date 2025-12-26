//
//  ShoppingList.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import Foundation

struct ShoppingList: Codable, Identifiable {
    let id: UUID
    let account_id: UUID
    let created_by_user_id: UUID
    let item: String
    let description: String?
    let metadata: [String: AnyJSON]
    let deleted_at: Date?
    let created_at: Date
    let updated_at: Date
    let location: String?
    let available_date_start: Date?
    let available_date_end: Date?
    let unit_price: Double?
    let quantity: Int?
    let purchased: Bool
    let scheduled_date: Date?
    let priority: Int?
    
    var unitPriceDecimal: Decimal? {
        guard let unit_price = unit_price else { return nil }
        return Decimal(unit_price)
    }
    
    // Custom decoding to handle date formats
    enum CodingKeys: String, CodingKey {
        case id, account_id, created_by_user_id, item, description, metadata
        case deleted_at, created_at, updated_at, location, available_date_start
        case available_date_end, unit_price, quantity, purchased, scheduled_date, priority
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        account_id = try container.decode(UUID.self, forKey: .account_id)
        created_by_user_id = try container.decode(UUID.self, forKey: .created_by_user_id)
        item = try container.decode(String.self, forKey: .item)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        metadata = try container.decode([String: AnyJSON].self, forKey: .metadata)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        unit_price = try container.decodeIfPresent(Double.self, forKey: .unit_price)
        quantity = try container.decodeIfPresent(Int.self, forKey: .quantity)
        purchased = try container.decodeIfPresent(Bool.self, forKey: .purchased) ?? false
        priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        
        // Decode dates with proper ISO8601 formatter
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let simpleDateFormatter = ISO8601DateFormatter()
        simpleDateFormatter.formatOptions = [.withFullDate]
        
        // Helper function to decode optional date
        func decodeDate(forKey key: CodingKeys) -> Date? {
            guard let dateString = try? container.decodeIfPresent(String.self, forKey: key) else {
                return nil
            }
            return dateFormatter.date(from: dateString) ?? simpleDateFormatter.date(from: dateString)
        }
        
        available_date_start = decodeDate(forKey: .available_date_start)
        available_date_end = decodeDate(forKey: .available_date_end)
        scheduled_date = decodeDate(forKey: .scheduled_date)
        deleted_at = decodeDate(forKey: .deleted_at)
        
        let createdAtString = try container.decode(String.self, forKey: .created_at)
        created_at = dateFormatter.date(from: createdAtString) ?? Date()
        
        let updatedAtString = try container.decode(String.self, forKey: .updated_at)
        updated_at = dateFormatter.date(from: updatedAtString) ?? Date()
    }
}
