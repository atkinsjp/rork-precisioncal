import Foundation
import SwiftData

@Model
final class BodyWeightEntry {
    var createdAt: Date
    var weightKg: Double
    var note: String

    init(createdAt: Date = Date(), weightKg: Double, note: String = "") {
        self.createdAt = createdAt
        self.weightKg = weightKg
        self.note = note
    }
}
