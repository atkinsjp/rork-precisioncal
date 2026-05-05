import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var ageYears: Int
    var weightKg: Double
    var heightCm: Double
    var goal: String
    var dailyCalorieTarget: Int
    var dailyProteinTarget: Int
    var dailyCarbTarget: Int
    var dailyFatTarget: Int
    var dailyWaterTargetMl: Int
    var createdAt: Date

    // Dynamic onboarding profile
    var goalsTags: [String]
    var medicalHistory: [String]
    var specificConditions: [String]
    var allergies: [String]
    var medications: [String]
    var activityLevel: String

    // PhD Synthesis (generated at end of onboarding)
    var healthProtocol: String

    init(
        name: String = "",
        ageYears: Int = 28,
        weightKg: Double = 70,
        heightCm: Double = 170,
        goal: String = "Maintain",
        dailyCalorieTarget: Int = 2000,
        dailyProteinTarget: Int = 130,
        dailyCarbTarget: Int = 220,
        dailyFatTarget: Int = 65,
        dailyWaterTargetMl: Int = 2400,
        createdAt: Date = Date(),
        goalsTags: [String] = [],
        medicalHistory: [String] = [],
        specificConditions: [String] = [],
        allergies: [String] = [],
        medications: [String] = [],
        activityLevel: String = "Moderate",
        healthProtocol: String = ""
    ) {
        self.name = name
        self.ageYears = ageYears
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.goal = goal
        self.dailyCalorieTarget = dailyCalorieTarget
        self.dailyProteinTarget = dailyProteinTarget
        self.dailyCarbTarget = dailyCarbTarget
        self.dailyFatTarget = dailyFatTarget
        self.dailyWaterTargetMl = dailyWaterTargetMl
        self.createdAt = createdAt
        self.goalsTags = goalsTags
        self.medicalHistory = medicalHistory
        self.specificConditions = specificConditions
        self.allergies = allergies
        self.medications = medications
        self.activityLevel = activityLevel
        self.healthProtocol = healthProtocol
    }
}

@Model
final class Meal {
    var createdAt: Date
    var title: String
    var imageData: Data?
    var status: String
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbs: Double
    var totalFat: Double
    var totalFiber: Double
    var totalSugar: Double
    var waterContentMl: Double
    var mealScore: Int
    var metabolicImpact: String
    var qcNotes: String
    var lipidSheenDetected: Bool = false
    var lipidNote: String = ""

    @Relationship(deleteRule: .cascade, inverse: \MealItem.meal)
    var items: [MealItem] = []

    init(
        createdAt: Date = Date(),
        title: String = "Meal",
        imageData: Data? = nil,
        status: String = "analyzing",
        totalCalories: Double = 0,
        totalProtein: Double = 0,
        totalCarbs: Double = 0,
        totalFat: Double = 0,
        totalFiber: Double = 0,
        totalSugar: Double = 0,
        waterContentMl: Double = 0,
        mealScore: Int = 0,
        metabolicImpact: String = "",
        qcNotes: String = "",
        lipidSheenDetected: Bool = false,
        lipidNote: String = ""
    ) {
        self.createdAt = createdAt
        self.title = title
        self.imageData = imageData
        self.status = status
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
        self.totalFiber = totalFiber
        self.totalSugar = totalSugar
        self.waterContentMl = waterContentMl
        self.mealScore = mealScore
        self.metabolicImpact = metabolicImpact
        self.qcNotes = qcNotes
        self.lipidSheenDetected = lipidSheenDetected
        self.lipidNote = lipidNote
    }
}

@Model
final class MealItem {
    var name: String
    var preparation: String
    var grams: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var waterMl: Double
    var meal: Meal?

    init(
        name: String,
        preparation: String = "",
        grams: Double = 0,
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double = 0,
        sugar: Double = 0,
        waterMl: Double = 0
    ) {
        self.name = name
        self.preparation = preparation
        self.grams = grams
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.waterMl = waterMl
    }
}

@Model
final class WaterEntry {
    var createdAt: Date
    var amountMl: Double

    init(createdAt: Date = Date(), amountMl: Double) {
        self.createdAt = createdAt
        self.amountMl = amountMl
    }
}
