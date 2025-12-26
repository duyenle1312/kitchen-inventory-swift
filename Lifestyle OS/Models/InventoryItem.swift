import Foundation

struct InventoryItem: Codable, Identifiable {
    let id: UUID
    let accountId: UUID
    let createdByUserId: UUID
    let name: String
    let quantity: Decimal
    let expirationDate: Date?
    let unit: String?
    let description: String?
    let metadata: [String: AnyCodable]
    let deletedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case createdByUserId = "created_by_user_id"
        case name
        case quantity
        case unit
        case expirationDate = "expiration_date"
        case description
        case metadata
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        accountId = try container.decode(UUID.self, forKey: .accountId)
        createdByUserId = try container.decode(UUID.self, forKey: .createdByUserId)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decode(Decimal.self, forKey: .quantity)
        unit = try container.decodeIfPresent(String.self, forKey: .unit)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        metadata = try container.decode([String: AnyCodable].self, forKey: .metadata)
        
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
        
        expirationDate = decodeDate(forKey: .expirationDate)
        deletedAt = decodeDate(forKey: .deletedAt)
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
    }
}

// Helper for dynamic JSON metadata
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: AnyCodable]:
            try container.encode(dict)
        case let array as [AnyCodable]:
            try container.encode(array)
        default:
            try container.encodeNil()
        }
    }
}
