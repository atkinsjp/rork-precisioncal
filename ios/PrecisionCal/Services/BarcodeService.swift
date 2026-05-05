import Foundation
import SwiftData

nonisolated struct ProductLookupResult: Codable, Sendable {
    let name: String
    let brand: String
    let servingSizeG: Double
    let servingDescription: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let sodiumMg: Double
    let ingredients: [String]
    let allergyFlags: [String]
    let additiveRisk: String
    let riskLevel: String
    let clinicalNote: String
}

/// Fetches barcode data with a Firestore-style 'Global_Nutrition_Index' pipeline.
/// 1. Local SwiftData cache (the global mirror).
/// 2. Open Food Facts public API for raw product data.
/// 3. Gemini 2.5 Flash structures + scores additive risk + allergy flags.
/// 4. Result is written back so the next user gets it instantly.
@MainActor
final class BarcodeService {
    static let shared = BarcodeService()

    private let openFoodFactsBase = "https://world.openfoodfacts.org/api/v2/product"

    func fetchProductData(barcodeID: String, context: ModelContext) async throws -> ScannedProduct {
        // 1) Local SwiftData cache hit (this device)
        if let cached = try fetchCached(barcodeID: barcodeID, context: context) {
            cached.scanCount += 1
            cached.lastScannedAt = Date()
            try? context.save()
            // Bump the global index hit counter in the background.
            Task.detached { await GlobalNutritionIndexService.shared.incrementScanCount(barcode: barcodeID) }
            return cached
        }

        // 2) Global Nutrition Index hit (Global_UPC collection) — instant, PhD-verified.
        if let cloud = await GlobalNutritionIndexService.shared.fetch(barcode: barcodeID) {
            let product = makeProduct(barcode: barcodeID, lookup: cloud)
            context.insert(product)
            try? context.save()
            Task.detached { await GlobalNutritionIndexService.shared.incrementScanCount(barcode: barcodeID) }
            return product
        }

        // 3) Cloud miss — pull raw label data from the public UPC source.
        let raw = try await fetchOpenFoodFacts(barcode: barcodeID)

        // 4) Use Gemini 2.5 Flash to parse raw label data into the Nuclear OS itemBreakdown format.
        let lookup = try await AIService.shared.parseProductData(barcode: barcodeID, rawJSON: raw)

        // 5) Seed the Global_UPC collection so every other PrecisionCal user gets it instantly.
        Task.detached { await GlobalNutritionIndexService.shared.writeback(barcode: barcodeID, lookup: lookup) }

        // 6) Mirror locally for offline access.
        let product = makeProduct(barcode: barcodeID, lookup: lookup)
        context.insert(product)
        try? context.save()
        return product
    }

    private func makeProduct(barcode: String, lookup: ProductLookupResult) -> ScannedProduct {
        ScannedProduct(
            barcode: barcode,
            name: lookup.name,
            brand: lookup.brand,
            servingSizeG: lookup.servingSizeG,
            servingDescription: lookup.servingDescription,
            calories: lookup.calories,
            protein: lookup.protein,
            carbs: lookup.carbs,
            fat: lookup.fat,
            fiber: lookup.fiber,
            sugar: lookup.sugar,
            sodiumMg: lookup.sodiumMg,
            ingredients: lookup.ingredients.joined(separator: ", "),
            allergyFlags: lookup.allergyFlags.joined(separator: ", "),
            additiveRisk: lookup.additiveRisk,
            riskLevel: lookup.riskLevel,
            clinicalNote: lookup.clinicalNote
        )
    }

    private func fetchCached(barcodeID: String, context: ModelContext) throws -> ScannedProduct? {
        var descriptor = FetchDescriptor<ScannedProduct>(
            predicate: #Predicate { $0.barcode == barcodeID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchOpenFoodFacts(barcode: String) async throws -> String {
        guard let url = URL(string: "\(openFoodFactsBase)/\(barcode).json?fields=product_name,brands,serving_size,serving_quantity,nutriments,ingredients_text,allergens_tags,additives_tags,nova_group,nutriscore_grade") else {
            throw BarcodeError.invalidBarcode
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 25
        req.setValue("PrecisionCal/1.0 (https://rork.app)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw BarcodeError.notFound
        }
        guard let s = String(data: data, encoding: .utf8) else { throw BarcodeError.notFound }
        // OFF returns {"status":0} when product is unknown. Hand it to Gemini anyway —
        // it can still infer from a brand-only or partial response, otherwise we throw.
        if s.contains("\"status\":0") || s.contains("\"status\": 0") {
            throw BarcodeError.notFound
        }
        return s
    }
}

nonisolated enum BarcodeError: Error, LocalizedError, Sendable {
    case invalidBarcode
    case notFound
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidBarcode: "That barcode doesn't look right. Try again."
        case .notFound: "We couldn't find this product. Try another scan."
        case .parseFailed: "Couldn't read the product details. Please try again."
        }
    }
}
