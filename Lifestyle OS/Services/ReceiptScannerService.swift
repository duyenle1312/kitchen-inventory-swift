// ReceiptScannerService.swift

import Foundation
import UIKit
import Vision
import FirebaseAILogic

class ReceiptScannerService {
    
    // MARK: - Public API
    
    func scanReceipt(from image: UIImage) async throws -> ScannedReceipt {
        guard let cgImage = image.cgImage else {
            throw ReceiptError.invalidImage
        }
        
        // Perform OCR
        let recognizedText = try await performOCR(on: cgImage)
        
        // Send to Gemini API for parsing via Firebase AI Logic
        let receipt = try await parseReceiptWithGemini(rawOCR: recognizedText)
        
        return receipt
    }
    
    // MARK: - Private Methods
    
    private func performOCR(on cgImage: CGImage) async throws -> String {
        print("\n🔍 === STARTING OCR ===")
        print("📸 Image size: \(cgImage.width) x \(cgImage.height)")
        
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("❌ OCR Error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    print("❌ OCR failed: No observations")
                    continuation.resume(throwing: ReceiptError.ocrFailed)
                    return
                }
                
                print("📋 OCR detected \(observations.count) text regions")
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                
                let ocrTime = Date().timeIntervalSince(startTime)
                print("⏱️  OCR took: \(String(format: "%.2f", ocrTime))s")
                print("📝 OCR recognized \(recognizedStrings.count) lines")
                print("\n=== RAW OCR TEXT ===")
                print(fullText)
                print("=== END RAW TEXT ===\n")
                
                continuation.resume(returning: fullText)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["bg", "en"]
            request.usesLanguageCorrection = true
            
            print("🔧 OCR Configuration:")
            print("   - Recognition level: accurate")
            print("   - Languages: Bulgarian, English")
            print("   - Language correction: enabled")
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("❌ OCR Handler Error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func parseReceiptWithGemini(rawOCR: String) async throws -> ScannedReceipt {
        print("\n🤖 === SENDING TO GEMINI API (Firebase AI Logic) ===")
        let apiStartTime = Date()
        
        // Initialize the Gemini Developer API backend service
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        
        // Create a GenerativeModel instance with Gemini 2.5 Flash
        let model = ai.generativeModel(modelName: "gemini-2.5-flash")
        
        let prompt = """
        Extract information from this receipt OCR and translate item names to English. If there is a discount, apply it directly to the item price before listing.
        
        Return the data in this EXACT plain text format (one field per line):
        
        STORE: [store name]
        DATE: [YYYY-MM-DD]
        CURRENCY: [currency code, e.g., EUR, BGN, USD]
        TOTAL: [total amount as decimal number]
        ITEMS_START
        [Item name in English]|[price as decimal]|[quantity as integer]
        [Item name in English]|[price as decimal]|[quantity as integer]
        ITEMS_END
        
        Example output:
        STORE: Lidl
        DATE: 2025-01-10
        CURRENCY: EUR
        TOTAL: 15.50
        ITEMS_START
        White Bread|1.20|1
        Fresh Milk 1L|2.30|2
        Tomatoes|3.50|1
        ITEMS_END
        
        === RAW OCR TEXT ===
        \(rawOCR)
        === END RAW TEXT ===
        """
        
        do {
            // Generate content using Firebase AI Logic
            let response = try await model.generateContent(prompt)
            
            guard let responseText = response.text else {
                throw ReceiptError.invalidAPIResponse
            }
            
            let apiTime = Date().timeIntervalSince(apiStartTime)
            print("⏱️  Gemini API took: \(String(format: "%.2f", apiTime))s")
            
            print("\n📄 Response from Gemini:")
            print(responseText)
            print("=" + String(repeating: "=", count: 50))
            
            // Parse plain text response
            let receipt = try parsePlainTextResponse(responseText, rawOCR: rawOCR)
            
            print("✅ Successfully parsed receipt with \(receipt.items.count) items")
            print("=== GEMINI PARSING COMPLETE ===\n")
            
            return receipt
            
        } catch {
            print("❌ Gemini API Error: \(error.localizedDescription)")
            throw ReceiptError.apiError(message: error.localizedDescription)
        }
    }
    
    private func parsePlainTextResponse(_ text: String, rawOCR: String) throws -> ScannedReceipt {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var storeName: String?
        var dateString: String?
        var currency = "EUR"
        var total: Decimal = 0
        var items: [ReceiptItem] = []
        var inItemsSection = false
        
        for line in lines {
            if line.hasPrefix("STORE:") {
                storeName = line.replacingOccurrences(of: "STORE:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("DATE:") {
                dateString = line.replacingOccurrences(of: "DATE:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("CURRENCY:") {
                currency = line.replacingOccurrences(of: "CURRENCY:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("TOTAL:") {
                let totalStr = line.replacingOccurrences(of: "TOTAL:", with: "").trimmingCharacters(in: .whitespaces)
                total = Decimal(string: totalStr) ?? 0
            } else if line == "ITEMS_START" {
                inItemsSection = true
            } else if line == "ITEMS_END" {
                inItemsSection = false
            } else if inItemsSection {
                // Parse item: Name|Price|Quantity
                let parts = line.components(separatedBy: "|")
                if parts.count == 3 {
                    let name = parts[0].trimmingCharacters(in: .whitespaces)
                    let price = Decimal(string: parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                    let quantity = Int(parts[2].trimmingCharacters(in: .whitespaces)) ?? 1
                    
                    let item = ReceiptItem(
                        name: name,
                        translatedName: name,
                        amount: price,
                        quantity: quantity,
                        category: "Food & Drink"
                    )
                    items.append(item)
                    print("✅ Parsed item: \(name) - \(price) x\(quantity)")
                }
            }
        }
        
        // Parse date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateString.flatMap { dateFormatter.date(from: $0) } ?? Date()
        
        return ScannedReceipt(
            storeName: storeName,
            date: date,
            items: items,
            total: total,
            currency: currency,
            rawText: rawOCR,
            translatedText: storeName
        )
    }
}

// MARK: - Errors

enum ReceiptError: LocalizedError {
    case invalidImage
    case ocrFailed
    case invalidAPIResponse
    case apiError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .ocrFailed:
            return "Failed to recognize text"
        case .invalidAPIResponse:
            return "Invalid API response format"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}
