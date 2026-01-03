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
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        return formatter.number(from: string)?.decimalValue
    }
}

// MARK: - Calendar Helpers

extension Calendar {
    func noon(for date: Date) -> Date {
        self.date(bySettingHour: 12, minute: 0, second: 0, of: date)!
    }
}
