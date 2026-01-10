//
//  Account.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//

import Foundation

struct Account: Codable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
    }
}

struct AccountUser: Codable {
    let accountId: UUID
    let userId: UUID
    let role: AccountRole
    let joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}
