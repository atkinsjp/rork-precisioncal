import Foundation
import SwiftData

/// Local mirror of the Global_Nutrition_Index. Each barcode is cached
/// after first lookup so subsequent scans across the user base stay instant.
@Model
final class ScannedProduct {
    @Attribute(.unique) var barcode: String
    var name: String
    var brand: String
    var servingSizeG: Double
    var servingDescription: String

    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodiumMg: Double

    /// Comma-separated ingredient list (lowercased, trimmed).
    var ingredients: String

    /// Comma-separated allergen flags (e.g. "milk, soy, gluten").
    var allergyFlags: String

    /// PhD-level additive risk summary.
    var additiveRisk: String
    /// Risk band: "low" | "moderate" | "high"
    var riskLevel: String

    /// AI commentary on the product as a whole (1–2 sentences).
    var clinicalNote: String

    var scanCount: Int
    var lastScannedAt: Date

    init(
        barcode: String,
        name: String = "",
        brand: String = "",
        servingSizeG: Double = 0,
        servingDescription: String = "",
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double = 0,
        sugar: Double = 0,
        sodiumMg: Double = 0,
        ingredients: String = "",
        allergyFlags: String = "",
        additiveRisk: String = "",
        riskLevel: String = "low",
        clinicalNote: String = "",
        scanCount: Int = 1,
        lastScannedAt: Date = Date()
    ) {
        self.barcode = barcode
        self.name = name
        self.brand = brand
        self.servingSizeG = servingSizeG
        self.servingDescription = servingDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodiumMg = sodiumMg
        self.ingredients = ingredients
        self.allergyFlags = allergyFlags
        self.additiveRisk = additiveRisk
        self.riskLevel = riskLevel
        self.clinicalNote = clinicalNote
        self.scanCount = scanCount
        self.lastScannedAt = lastScannedAt
    }
}
