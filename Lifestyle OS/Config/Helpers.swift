//
//  Helpers.swift
//  Lifestyle OS
//
//  Created by Le Ngo My Duyen on 3.01.26.
//

import Foundation

// MARK: - Decimal Parsing

extension Decimal {
    static func fromString(_ string: String) -> Decimal? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Count occurrences of '.' and ','
        let dotCount = trimmed.filter { $0 == "." }.count
        let commaCount = trimmed.filter { $0 == "," }.count
        
        var normalized = trimmed
        
        if dotCount > 0 && commaCount > 0 {
            // Both present → last one is decimal separator
            if let lastDot = trimmed.lastIndex(of: "."), let lastComma = trimmed.lastIndex(of: ",") {
                if lastDot > lastComma {
                    // Dot is decimal → remove commas
                    normalized = trimmed.replacingOccurrences(of: ",", with: "")
                } else {
                    // Comma is decimal → remove dots, replace comma with dot
                    normalized = trimmed.replacingOccurrences(of: ".", with: "")
                    normalized = normalized.replacingOccurrences(of: ",", with: ".")
                }
            }
        } else if commaCount > 0 {
            // Only comma → treat as decimal
            normalized = normalized.replacingOccurrences(of: ",", with: ".")
        }
        // else only dot or no separator → leave as is
        
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        
        return formatter.number(from: normalized)?.decimalValue
    }
}


// MARK: - Calendar Helpers

extension Calendar {
    func noon(for date: Date) -> Date {
        self.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
    }
}
