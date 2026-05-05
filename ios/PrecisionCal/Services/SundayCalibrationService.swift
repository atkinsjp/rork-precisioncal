import Foundation
import SwiftData

/// Background process that runs every 7 days and generates a 'Protocol Pivot'
/// using the 'Senior PhD Clinical Nutritionist' persona.
@MainActor
final class SundayCalibrationService {
    static let shared = SundayCalibrationService()

    private var isRunning = false

    /// Decide whether a fresh calibration should be generated.
    /// Trigger if no record exists OR last record is >= 7 days old.
    func shouldRun(latest: Calibration?) -> Bool {
        guard let latest else { return true }
        let interval = Date().timeIntervalSince(latest.createdAt)
        return interval >= 7 * 24 * 3600
    }

    /// Whether a calibration is currently being generated.
    private(set) var inFlight: Bool = false

    /// Run calibration if due. Safe to call frequently — guards against duplicate runs.
    func runIfDue(context: ModelContext, profile: UserProfile?, recentMeals: [Meal], latest: Calibration?) async {
        guard !isRunning else { return }
        guard shouldRun(latest: latest) else { return }
        await execute(context: context, profile: profile, recentMeals: recentMeals)
    }

    /// Force a fresh calibration regardless of the 7-day window.
    /// Returns true if a new record was inserted.
    @discardableResult
    func runManually(context: ModelContext, profile: UserProfile?, recentMeals: [Meal]) async -> Bool {
        guard !isRunning else { return false }
        return await execute(context: context, profile: profile, recentMeals: recentMeals)
    }

    @discardableResult
    private func execute(context: ModelContext, profile: UserProfile?, recentMeals: [Meal]) async -> Bool {
        guard let profile else { return false }
        isRunning = true
        inFlight = true
        defer { isRunning = false; inFlight = false }

        let cal = Calendar.current
        let weekEnd = Date()
        let weekStart = cal.date(byAdding: .day, value: -7, to: weekEnd) ?? weekEnd
        let weekMeals = recentMeals.filter { $0.createdAt >= weekStart && $0.status == "complete" }

        // Need at least 3 meals to make a meaningful weekly pivot.
        guard weekMeals.count >= 3 else { return false }

        let profileSummary = Self.summarize(profile: profile)
        let weekStats = Self.summarize(meals: weekMeals)

        do {
            let result = try await AIService.shared.generateSundayCalibration(
                profileSummary: profileSummary,
                weekStats: weekStats
            )
            guard !result.pivots.isEmpty else { return false }

            let record = Calibration(
                createdAt: Date(),
                weekStart: weekStart,
                weekEnd: weekEnd,
                summary: result.summary,
                pivotTitles: result.pivots.map { $0.title },
                pivotBodies: result.pivots.map { $0.body },
                acknowledged: false
            )
            context.insert(record)
            try? context.save()
            return true
        } catch {
            // Silent failure — the dashboard simply shows no calibration card this week.
            print("[SundayCalibration] failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Summaries

    private static func summarize(profile: UserProfile) -> String {
        """
        Name: \(profile.name.isEmpty ? "User" : profile.name)
        Age: \(profile.ageYears) Weight: \(Int(profile.weightKg)) kg Height: \(Int(profile.heightCm)) cm
        Goal: \(profile.goal). Goal tags: \(profile.goalsTags.joined(separator: ", "))
        Conditions: \(profile.specificConditions.joined(separator: ", "))
        Medical history: \(profile.medicalHistory.joined(separator: ", "))
        Allergies: \(profile.allergies.joined(separator: ", "))
        Medications: \(profile.medications.joined(separator: ", "))
        Activity: \(profile.activityLevel)
        Daily targets: \(profile.dailyCalorieTarget) kcal, \(profile.dailyProteinTarget)g P / \(profile.dailyCarbTarget)g C / \(profile.dailyFatTarget)g F, \(profile.dailyWaterTargetMl) ml water
        """
    }

    private static func summarize(meals: [Meal]) -> String {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: meals) { cal.startOfDay(for: $0.createdAt) }
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"

        var lines: [String] = []
        for day in grouped.keys.sorted() {
            let dayMeals = grouped[day] ?? []
            let kcal = Int(dayMeals.reduce(0) { $0 + $1.totalCalories })
            let p = Int(dayMeals.reduce(0) { $0 + $1.totalProtein })
            let c = Int(dayMeals.reduce(0) { $0 + $1.totalCarbs })
            let fat = Int(dayMeals.reduce(0) { $0 + $1.totalFat })
            let fiber = Int(dayMeals.reduce(0) { $0 + $1.totalFiber })
            let sugar = Int(dayMeals.reduce(0) { $0 + $1.totalSugar })
            let avgScore = dayMeals.isEmpty ? 0 : dayMeals.reduce(0) { $0 + $1.mealScore } / dayMeals.count
            let lowScores = dayMeals.filter { $0.mealScore < 60 }.map { "\($0.title)(\($0.mealScore))" }
            let lowNote = lowScores.isEmpty ? "" : " low: \(lowScores.joined(separator: ", "))"
            lines.append(
                "\(f.string(from: day)): \(kcal)kcal P\(p) C\(c) F\(fat) fiber\(fiber) sugar\(sugar) avgScore\(avgScore)\(lowNote)"
            )
        }
        return lines.joined(separator: "\n")
    }
}
