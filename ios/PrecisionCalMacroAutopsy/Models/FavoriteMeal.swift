import Foundation
import SwiftData

/// Snapshot of a single food item inside a favorite meal.
nonisolated struct FavoriteItem: Codable, Sendable {
    let name: String
    let preparation: String
    let grams: Double
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let waterMl: Double
}

/// A saved meal composition for one-tap logging. Stores a full copy of the item
/// breakdown so future logs don't depend on the original meal record staying alive.
@Model
final class FavoriteMeal {
    var name: String
    var createdAt: Date
    /// Timestamp of the meal this favorite was saved from; used to toggle the star off.
    var sourceCreatedAt: Date
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var totalFiber: Double
    var totalSugar: Double
    var waterContentMl: Double
    var items: [FavoriteItem] = []

    init(
        name: String,
        createdAt: Date = Date(),
        sourceCreatedAt: Date = Date(),
        totalCalories: Double = 0,
        totalProtein: Double = 0,
        totalCarbs: Double = 0,
        totalFat: Double = 0,
        totalFiber: Double = 0,
        totalSugar: Double = 0,
        waterContentMl: Double = 0,
        items: [FavoriteItem] = []
    ) {
        self.name = name
        self.createdAt = createdAt
        self.sourceCreatedAt = sourceCreatedAt
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
        self.totalFiber = totalFiber
        self.totalSugar = totalSugar
        self.waterContentMl = waterContentMl
        self.items = items
    }

    convenience init(meal: Meal) {
        self.init(
            name: meal.title.isEmpty ? "Meal" : meal.title,
            sourceCreatedAt: meal.createdAt,
            totalCalories: meal.totalCalories,
            totalProtein: meal.totalProtein,
            totalCarbs: meal.totalCarbs,
            totalFat: meal.totalFat,
            totalFiber: meal.totalFiber,
            totalSugar: meal.totalSugar,
            waterContentMl: meal.waterContentMl,
            items: meal.items.map { item in
                FavoriteItem(
                    name: item.name,
                    preparation: item.preparation,
                    grams: item.grams,
                    calories: item.calories,
                    protein: item.protein,
                    carbs: item.carbs,
                    fat: item.fat,
                    fiber: item.fiber,
                    sugar: item.sugar,
                    waterMl: item.waterMl
                )
            }
        )
    }
}
