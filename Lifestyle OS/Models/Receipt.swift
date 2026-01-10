//
//  Receipt.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 9.01.26.
//

import Foundation

struct ScannedReceipt: Identifiable {
    let id = UUID()
    var storeName: String?
    var date: Date?
    var items: [ReceiptItem]
    var total: Decimal
    var currency: String
    var rawText: String
    var translatedText: String?
}

struct ReceiptItem: Identifiable {
    let id = UUID()
    var name: String
    var translatedName: String?
    var amount: Decimal
    var quantity: Int?
    var category: String?
    
    var displayName: String {
        translatedName ?? name
    }
}
