import Foundation
import SwiftData

/// A weekly "Sunday Calibration" record — three Protocol Pivots from Dr. PrecisionCal.
@Model
final class Calibration {
    var createdAt: Date
    var weekStart: Date
    var weekEnd: Date
    var summary: String
    var pivotTitles: [String]
    var pivotBodies: [String]
    /// Whether the user has dismissed the notification card.
    var acknowledged: Bool

    init(
        createdAt: Date = Date(),
        weekStart: Date = Date(),
        weekEnd: Date = Date(),
        summary: String = "",
        pivotTitles: [String] = [],
        pivotBodies: [String] = [],
        acknowledged: Bool = false
    ) {
        self.createdAt = createdAt
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.summary = summary
        self.pivotTitles = pivotTitles
        self.pivotBodies = pivotBodies
        self.acknowledged = acknowledged
    }
}

/// Three structured pivots returned by the PhD Clinical Nutritionist persona.
nonisolated struct CalibrationResult: Codable, Sendable {
    let summary: String
    let pivots: [Pivot]

    nonisolated struct Pivot: Codable, Sendable {
        let title: String
        let body: String
    }
}
