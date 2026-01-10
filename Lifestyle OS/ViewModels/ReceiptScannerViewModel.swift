// ReceiptScannerViewModel.swift

import Foundation
import UIKit
import SwiftUI
import Combine

@MainActor
class ReceiptScannerViewModel: ObservableObject {
    @Published var scannedReceipt: ScannedReceipt?
    @Published var isScanning = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    
    private let scannerService = ReceiptScannerService()
    private let expenseService = ExpenseService()
    
    func scanReceipt(from image: UIImage) async {
        isScanning = true
        errorMessage = nil
        
        do {
            // Gemini API now handles OCR + translation in one call
            let receipt = try await scannerService.scanReceipt(from: image)
            scannedReceipt = receipt
            
            print("✅ Receipt scanned and translated by Gemini")
            print("   Store: \(receipt.storeName ?? "Unknown")")
            print("   Items: \(receipt.items.count)")
            print("   Total: \(receipt.total) \(receipt.currency)")
            
        } catch {
            print("❌ Scanning error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        
        isScanning = false
    }
    
    func updateItem(at index: Int, name: String?, amount: String?, category: String?) {
        guard var receipt = scannedReceipt, index < receipt.items.count else { return }
        
        if let name = name {
            receipt.items[index].translatedName = name
        }
        
        if let amountStr = amount, let amountValue = Decimal(string: amountStr) {
            receipt.items[index].amount = amountValue
        }
        
        if let category = category {
            receipt.items[index].category = category
        }
        
        // Recalculate total
        receipt.total = receipt.items.reduce(0) { $0 + $1.amount }
        
        scannedReceipt = receipt
    }
    
    func removeItem(at index: Int) {
        guard var receipt = scannedReceipt, index < receipt.items.count else { return }
        receipt.items.remove(at: index)
        
        // Recalculate total
        receipt.total = receipt.items.reduce(0) { $0 + $1.amount }
        
        scannedReceipt = receipt
    }
    
    func saveToExpenses(accountId: UUID) async {
        print("inside saveToExpenses")
        
        guard let receipt = scannedReceipt else { return }
        
        isSaving = true
        errorMessage = nil
        
        do {
            _ = try await expenseService.createExpensesFromReceipt(
                accountId: accountId,
                receipt: receipt,
                items: receipt.items
            )
            
            showSuccess = true
            
            // Reset after short delay
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            scannedReceipt = nil
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
    
    func reset() {
        scannedReceipt = nil
        errorMessage = nil
        showSuccess = false
    }
}


//import Foundation
//import UIKit
//import SwiftUI
//import Translation
//import Combine
//
//@MainActor
//class ReceiptScannerViewModel: ObservableObject {
//    @Published var scannedReceipt: ScannedReceipt?
//    @Published var isScanning = false
//    @Published var isTranslating = false
//    @Published var isSaving = false
//    @Published var errorMessage: String?
//    @Published var showSuccess = false
//    @Published var translationConfiguration: TranslationSession.Configuration?
//    @Published var useAppleTranslation = true // New: allow user to skip Apple Translation
//    
//    private let scannerService = ReceiptScannerService()
//    private let expenseService = ExpenseService()
//    
//    func scanReceipt(from image: UIImage) async {
//        isScanning = true
//        errorMessage = nil
//        
//        do {
//            let receipt = try await scannerService.scanReceipt(from: image)
//            scannedReceipt = receipt
//            
//            // Decide on translation method
//            if useAppleTranslation {
//                if #available(iOS 18.0, *) {
//                    // Try Apple Translation with availability check
//                    await checkTranslationAvailability()
//                } else {
//                    // iOS < 18, use dictionary
//                    print("ℹ️  iOS < 18, using dictionary translation")
//                    await translateWithDictionary()
//                }
//            } else {
//                // User preference: skip Apple Translation
//                print("ℹ️  Apple Translation disabled, using dictionary")
//                await translateWithDictionary()
//            }
//            
//        } catch {
//            print("❌ Scanning error: \(error.localizedDescription)")
//            errorMessage = error.localizedDescription
//        }
//        
//        isScanning = false
//    }
//    
//    @available(iOS 18.0, *)
//    private func checkTranslationAvailability() async {
//        guard let receipt = scannedReceipt, !receipt.items.isEmpty else { return }
//        
//        // Use a more robust text sample
//        let sampleText = receipt.items.first?.name ?? "ХЛЯБ"
//        
//        do {
//            let availability = LanguageAvailability()
//            
//            // Try to check status with timeout
//            let status = try await withTimeout(seconds: 5) {
//                try await availability.status(
//                    for: sampleText,
//                    to: Locale.current.language
//                )
//            }
//            
//            print("📱 Translation status: \(status)")
//            
//            switch status {
//            case .installed, .supported:
//                print("✅ Translation available, triggering batch translation")
//                // Trigger translation task
//                translationConfiguration = .init(
//                    source: Locale.Language(identifier: "bg"),
//                    target: Locale.current.language
//                )
//            case .unsupported:
//                print("⚠️ Language pair not supported, using dictionary fallback")
//                await translateWithDictionary()
//            @unknown default:
//                print("⚠️ Unknown translation status, using dictionary fallback")
//                await translateWithDictionary()
//            }
//        } catch {
//            print("⚠️ Translation availability check failed: \(error.localizedDescription)")
//            print("   Using dictionary fallback")
//            await translateWithDictionary()
//        }
//    }
//    
//    // Helper function to add timeout to async operations
//    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
//        return try await withThrowingTaskGroup(of: T.self) { group in
//            group.addTask {
//                return try await operation()
//            }
//            
//            group.addTask {
//                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
//                throw TimeoutError()
//            }
//            
//            let result = try await group.next()!
//            group.cancelAll()
//            return result
//        }
//    }
//    
//    struct TimeoutError: Error {
//        var localizedDescription: String {
//            return "Operation timed out"
//        }
//    }
//    
//    @available(iOS 18.0, *)
//    func performBatchTranslation(using session: TranslationSession) async {
//        guard var receipt = scannedReceipt else { return }
//        
//        isTranslating = true
//        print("🔄 Starting batch translation for \(receipt.items.count) items...")
//        
//        do {
//            // Create translation requests for all items
//            let requests: [TranslationSession.Request] = receipt.items.map { item in
//                TranslationSession.Request(
//                    sourceText: item.name,
//                    clientIdentifier: item.id.uuidString
//                )
//            }
//            
//            // Batch translate all items at once with timeout
//            let responses = try await withTimeout(seconds: 30) {
//                try await session.translations(from: requests)
//            }
//            
//            print("📦 Received \(responses.count) translation responses")
//            
//            // Match responses back to items
//            for i in 0..<receipt.items.count {
//                let itemId = receipt.items[i].id.uuidString
//                if let response = responses.first(where: { $0.clientIdentifier == itemId }) {
//                    receipt.items[i].translatedName = response.targetText
//                    
//                    if response.targetText != receipt.items[i].name {
//                        print("✅ Translated: '\(receipt.items[i].name)' → '\(response.targetText)'")
//                    } else {
//                        print("ℹ️  No change: '\(receipt.items[i].name)'")
//                    }
//                }
//            }
//            
//            // Translate store name if available
//            if let storeName = receipt.storeName {
//                let storeRequest = TranslationSession.Request(
//                    sourceText: storeName,
//                    clientIdentifier: "store"
//                )
//                
//                let storeResponse = try await withTimeout(seconds: 5) {
//                    try await session.translations(from: [storeRequest])
//                }
//                
//                if let translated = storeResponse.first {
//                    receipt.translatedText = translated.targetText
//                }
//            }
//            
//            scannedReceipt = receipt
//            print("✅ Batch translation complete!")
//            
//        } catch is TimeoutError {
//            print("⏱️ Translation timed out, falling back to dictionary")
//            await translateWithDictionary()
//        } catch {
//            print("❌ Translation error: \(error.localizedDescription)")
//            // Fallback to dictionary
//            await translateWithDictionary()
//        }
//        
//        isTranslating = false
//        // Clear configuration to avoid re-triggering
//        translationConfiguration = nil
//    }
//    
//    private func translateWithDictionary() async {
//        guard var receipt = scannedReceipt else { return }
//        
//        isTranslating = true
//        print("\n📖 === STARTING DICTIONARY TRANSLATION ===")
//        let translateStartTime = Date()
//        
//        print("📝 Items to translate: \(receipt.items.count)")
//        
//        for i in 0..<receipt.items.count {
//            let originalName = receipt.items[i].name
//            let translated = scannerService.translateWithDictionary(originalName)
//            receipt.items[i].translatedName = translated
//            
//            if translated != originalName {
//                print("✅ Item \(i + 1): '\(originalName)' → '\(translated)'")
//            } else {
//                print("ℹ️  Item \(i + 1): '\(originalName)' (no translation needed)")
//            }
//        }
//        
//        if let storeName = receipt.storeName {
//            let translated = scannerService.translateWithDictionary(storeName)
//            receipt.storeName = translated
//            print("🏪 Store: '\(storeName)' → '\(translated)'")
//        }
//        
//        let translateTime = Date().timeIntervalSince(translateStartTime)
//        print("⏱️  Dictionary translation took: \(String(format: "%.2f", translateTime))s")
//        print("=== TRANSLATION COMPLETE ===\n")
//        
//        scannedReceipt = receipt
//        isTranslating = false
//    }
//    
//    func updateItem(at index: Int, name: String?, amount: String?, category: String?) {
//        guard var receipt = scannedReceipt, index < receipt.items.count else { return }
//        
//        if let name = name {
//            receipt.items[index].translatedName = name
//        }
//        
//        if let amountStr = amount, let amountValue = Decimal(string: amountStr) {
//            receipt.items[index].amount = amountValue
//        }
//        
//        if let category = category {
//            receipt.items[index].category = category
//        }
//        
//        // Recalculate total
//        receipt.total = receipt.items.reduce(0) { $0 + $1.amount }
//        
//        scannedReceipt = receipt
//    }
//    
//    func removeItem(at index: Int) {
//        guard var receipt = scannedReceipt, index < receipt.items.count else { return }
//        receipt.items.remove(at: index)
//        
//        // Recalculate total
//        receipt.total = receipt.items.reduce(0) { $0 + $1.amount }
//        
//        scannedReceipt = receipt
//    }
//    
//    func saveToExpenses(accountId: UUID) async {
//        
//        print("inside saveToExpenses")
//        
//        guard let receipt = scannedReceipt else { return }
//        
//        isSaving = true
//        errorMessage = nil
//        
//        do {
//            _ = try await expenseService.createExpensesFromReceipt(
//                accountId: accountId,
//                receipt: receipt,
//                items: receipt.items
//            )
//            
//            showSuccess = true
//            
//            // Reset after short delay
//            try? await Task.sleep(nanoseconds: 1_000_000_000)
//            scannedReceipt = nil
//            
//        } catch {
//            errorMessage = error.localizedDescription
//        }
//        
//        isSaving = false
//    }
//    
//    func reset() {
//        scannedReceipt = nil
//        errorMessage = nil
//        showSuccess = false
//        translationConfiguration = nil
//    }
//}
