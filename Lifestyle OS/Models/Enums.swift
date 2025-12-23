//
//  Enum.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 23.12.25.
//

import Foundation

enum AccountRole: String, Codable {
    case owner
    case admin
    case member
    case viewer
}

enum CustomFieldType: String, Codable {
    case text
    case number
    case boolean
    case date
}

enum AuditAction: String, Codable {
    case create
    case update
    case delete
}
