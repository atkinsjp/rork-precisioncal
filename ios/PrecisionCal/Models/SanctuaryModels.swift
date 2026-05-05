import Foundation
import SwiftData

/// Post types in The Sanctuary community feed.
nonisolated enum SanctuaryPostKind: String, Codable, Sendable, CaseIterable {
    case bloom        // Vitality Bloom snapshot
    case mealAnalysis // 6-Pass meal results
    case encouragement
}

/// Moderation states routed by the StewardshipFilter.
nonisolated enum StewardshipState: String, Codable, Sendable {
    case approved
    case reviewing
    case flagged
}

@Model
final class SanctuaryPost {
    var createdAt: Date
    var authorName: String
    var authorInitial: String
    var kindRaw: String
    var bodyText: String

    // Bloom snapshot fields
    var hydrationProgress: Double = 0
    var macroProgress: Double = 0
    var adherenceProgress: Double = 0
    var mood: String = ""

    // Meal analysis fields (denormalized for quick render)
    var mealTitle: String = ""
    var mealScore: Int = 0
    var metabolicImpact: String = ""
    var lipidSheen: Bool = false
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var imageData: Data? = nil

    // Stewardship
    var stateRaw: String = StewardshipState.approved.rawValue
    var stewardReason: String = ""
    var userReported: Bool = false
    var reportReason: String = ""
    var hearts: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \SanctuaryComment.post)
    var comments: [SanctuaryComment] = []

    var kind: SanctuaryPostKind {
        get { SanctuaryPostKind(rawValue: kindRaw) ?? .encouragement }
        set { kindRaw = newValue.rawValue }
    }
    var state: StewardshipState {
        get { StewardshipState(rawValue: stateRaw) ?? .approved }
        set { stateRaw = newValue.rawValue }
    }

    init(
        createdAt: Date = Date(),
        authorName: String = "You",
        authorInitial: String = "Y",
        kind: SanctuaryPostKind = .encouragement,
        bodyText: String = "",
        hydrationProgress: Double = 0,
        macroProgress: Double = 0,
        adherenceProgress: Double = 0,
        mood: String = "",
        mealTitle: String = "",
        mealScore: Int = 0,
        metabolicImpact: String = "",
        lipidSheen: Bool = false,
        calories: Double = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        imageData: Data? = nil,
        state: StewardshipState = .reviewing,
        stewardReason: String = "",
        hearts: Int = 0
    ) {
        self.createdAt = createdAt
        self.authorName = authorName
        self.authorInitial = authorInitial
        self.kindRaw = kind.rawValue
        self.bodyText = bodyText
        self.hydrationProgress = hydrationProgress
        self.macroProgress = macroProgress
        self.adherenceProgress = adherenceProgress
        self.mood = mood
        self.mealTitle = mealTitle
        self.mealScore = mealScore
        self.metabolicImpact = metabolicImpact
        self.lipidSheen = lipidSheen
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.imageData = imageData
        self.stateRaw = state.rawValue
        self.stewardReason = stewardReason
        self.hearts = hearts
    }
}

@Model
final class SanctuaryComment {
    var createdAt: Date
    var authorName: String
    var authorInitial: String
    var bodyText: String
    var stateRaw: String = StewardshipState.approved.rawValue
    var stewardReason: String = ""
    var post: SanctuaryPost?

    var state: StewardshipState {
        get { StewardshipState(rawValue: stateRaw) ?? .approved }
        set { stateRaw = newValue.rawValue }
    }

    init(
        createdAt: Date = Date(),
        authorName: String = "You",
        authorInitial: String = "Y",
        bodyText: String = "",
        state: StewardshipState = .reviewing,
        stewardReason: String = ""
    ) {
        self.createdAt = createdAt
        self.authorName = authorName
        self.authorInitial = authorInitial
        self.bodyText = bodyText
        self.stateRaw = state.rawValue
        self.stewardReason = stewardReason
    }
}

@Model
final class RoadmapInsight {
    var createdAt: Date
    var headline: String
    var rationale: String
    var painPoint: String
    var sourceQuotes: [String]
    var priority: String  // "high" | "medium" | "low"
    var acknowledged: Bool

    init(
        createdAt: Date = Date(),
        headline: String = "",
        rationale: String = "",
        painPoint: String = "",
        sourceQuotes: [String] = [],
        priority: String = "medium",
        acknowledged: Bool = false
    ) {
        self.createdAt = createdAt
        self.headline = headline
        self.rationale = rationale
        self.painPoint = painPoint
        self.sourceQuotes = sourceQuotes
        self.priority = priority
        self.acknowledged = acknowledged
    }
}

// MARK: - AI DTOs

nonisolated struct StewardshipVerdict: Codable, Sendable {
    let approved: Bool
    let severity: String   // "none" | "minor" | "major"
    let category: String   // disrespectful | dangerous | improper | none
    let reason: String
}

nonisolated struct InnovationSuggestion: Codable, Sendable {
    let headline: String
    let rationale: String
    let painPoint: String
    let priority: String   // "high" | "medium" | "low"
    let sourceQuotes: [String]
}

nonisolated struct InnovationReport: Codable, Sendable {
    let summary: String
    let suggestions: [InnovationSuggestion]
}
