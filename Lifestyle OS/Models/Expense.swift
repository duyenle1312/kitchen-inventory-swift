//
//  Expense.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 26.12.25.
//

import Foundation

struct Expense: Codable, Identifiable {
    let id: UUID
    let account_id: UUID
    let created_by_user_id: UUID
    let amount: Double
    let currency: String
    let expense_date: Date
    let category: String?
    let description: String?
    let location: String?
    let unit: Int?
    let unit_price: Double?
    let expire_date: Date?
    let payment_method: String?
    let item: String?
    let metadata: [String: AnyJSON]
    let deleted_at: Date?
    let created_at: Date
    let updated_at: Date
    
    var amountDecimal: Decimal {
        Decimal(amount)
    }
    
    var unitPriceDecimal: Decimal? {
        guard let unit_price = unit_price else { return nil }
        return Decimal(unit_price)
    }
    
    // Custom decoding to handle date formats
    enum CodingKeys: String, CodingKey {
        case id, account_id, created_by_user_id, amount, currency, expense_date
        case category, description, location, unit, unit_price, expire_date
        case payment_method, item, metadata, deleted_at, created_at, updated_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        account_id = try container.decode(UUID.self, forKey: .account_id)
        created_by_user_id = try container.decode(UUID.self, forKey: .created_by_user_id)
        amount = try container.decode(Double.self, forKey: .amount)
        currency = try container.decode(String.self, forKey: .currency)
        
        // Decode dates with proper ISO8601 formatter
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let expenseDateString = try container.decode(String.self, forKey: .expense_date)
        if let date = dateFormatter.date(from: expenseDateString) {
            expense_date = date
        } else {
            // Fallback to date-only format
            let simpleDateFormatter = ISO8601DateFormatter()
            simpleDateFormatter.formatOptions = [.withFullDate]
            if let date = simpleDateFormatter.date(from: expenseDateString) {
                expense_date = date
            } else {
                throw DecodingError.dataCorruptedError(forKey: .expense_date, in: container, debugDescription: "Invalid date format: \(expenseDateString)")
            }
        }
        
        category = try container.decodeIfPresent(String.self, forKey: .category)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        unit = try container.decodeIfPresent(Int.self, forKey: .unit)
        unit_price = try container.decodeIfPresent(Double.self, forKey: .unit_price)
        
        if let expireDateString = try container.decodeIfPresent(String.self, forKey: .expire_date) {
            if let date = dateFormatter.date(from: expireDateString) {
                expire_date = date
            } else {
                let simpleDateFormatter = ISO8601DateFormatter()
                simpleDateFormatter.formatOptions = [.withFullDate]
                expire_date = simpleDateFormatter.date(from: expireDateString)
            }
        } else {
            expire_date = nil
        }
        
        payment_method = try container.decodeIfPresent(String.self, forKey: .payment_method)
        item = try container.decodeIfPresent(String.self, forKey: .item)
        metadata = try container.decode([String: AnyJSON].self, forKey: .metadata)
        
        if let deletedAtString = try container.decodeIfPresent(String.self, forKey: .deleted_at) {
            deleted_at = dateFormatter.date(from: deletedAtString)
        } else {
            deleted_at = nil
        }
        
        let createdAtString = try container.decode(String.self, forKey: .created_at)
        created_at = dateFormatter.date(from: createdAtString) ?? Date()
        
        let updatedAtString = try container.decode(String.self, forKey: .updated_at)
        updated_at = dateFormatter.date(from: updatedAtString) ?? Date()
    }
}

// MARK: - AnyJSON Helper
struct AnyJSON: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyJSON].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyJSON].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyJSON($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyJSON($0) })
        case is NSNull:
            try container.encodeNil()
        default:
            try container.encodeNil()
        }
    }
}
