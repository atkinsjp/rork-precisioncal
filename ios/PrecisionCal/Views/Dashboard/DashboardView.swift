import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \Meal.createdAt, order: .reverse) private var meals: [Meal]
    @Query(sort: \WaterEntry.createdAt, order: .reverse) private var waters: [WaterEntry]
    @Query private var products: [ScannedProduct]
    @Query(sort: \Calibration.createdAt, order: .reverse) private var calibrations: [Calibration]
    @Environment(\.modelContext) private var modelContext

    @State private var directive: String = ""
    @State private var directiveLoading: Bool = false
    @State private var directiveDate: Date? = nil
    @State private var drawerOffset: CGFloat = 0
    @State private var drawerOpen: Bool = false
    @State private var fallbackIndex: Int = 0

    /// Curated complete focus directives, used for instant tap-to-cycle
    /// and as fallback when the AI returns a fragment.
    private let curatedFocus: [String] = [
        "Hydrate first, then build each meal around protein and color.",
        "Move gently for ten minutes, then notice how your body responds.",
        "Choose whole foods today; let texture and warmth guide your portions.",
        "Pause before eating — three slow breaths reset hunger and fullness signals.",
        "Pair every carb with protein or fat to steady your energy.",
        "Front-load protein at breakfast; your afternoon cravings will quiet down.",
        "Drink a full glass of water before each meal and after waking.",
        "Walk after your largest meal — even five minutes blunts the glucose curve.",
        "Eat slowly enough to taste, then stop at comfortably satisfied.",
        "Add one extra plant to every plate; fiber feeds your microbiome."
    ]

    private var profile: UserProfile? { profiles.first }
    private var latestCalibration: Calibration? { calibrations.first }
    private var activeCalibration: Calibration? {
        guard let c = latestCalibration, !c.acknowledged else { return nil }
        return c
    }

    private var todayMeals: [Meal] {
        meals.filter { Calendar.current.isDateInToday($0.createdAt) && $0.status == "complete" }
    }
    private var yesterdayMeals: [Meal] {
        meals.filter {
            Calendar.current.isDateInYesterday($0.createdAt) && $0.status == "complete"
        }
    }
    private var todayWater: [WaterEntry] {
        waters.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var caloriesToday: Double { todayMeals.reduce(0) { $0 + $1.totalCalories } }
    private var proteinToday: Double { todayMeals.reduce(0) { $0 + $1.totalProtein } }
    private var carbsToday: Double { todayMeals.reduce(0) { $0 + $1.totalCarbs } }
    private var fatToday: Double { todayMeals.reduce(0) { $0 + $1.totalFat } }
    private var waterToday: Double {
        todayWater.reduce(0) { $0 + $1.amountMl } + todayMeals.reduce(0) { $0 + $1.waterContentMl }
    }

    private var hydrationProgress: Double {
        let target = Double(profile?.dailyWaterTargetMl ?? 2400)
        return min(1, waterToday / max(target, 1))
    }
    private var macroProgress: Double {
        let cT = Double(profile?.dailyCalorieTarget ?? 2000)
        let pT = Double(profile?.dailyProteinTarget ?? 130)
        let kT = Double(profile?.dailyCarbTarget ?? 220)
        let fT = Double(profile?.dailyFatTarget ?? 65)
        let parts = [
            min(1, caloriesToday / max(cT, 1)),
            min(1, proteinToday / max(pT, 1)),
            min(1, carbsToday / max(kT, 1)),
            min(1, fatToday / max(fT, 1)),
        ]
        return parts.reduce(0, +) / Double(parts.count)
    }
    /// Adherence = average of macro + hydration progress, weighted by today's meal scores.
    private var adherence: Double {
        let base = (macroProgress + hydrationProgress) / 2
        guard !todayMeals.isEmpty else { return base * 0.5 }
        let avgScore = Double(todayMeals.reduce(0) { $0 + $1.mealScore }) / Double(todayMeals.count) / 100.0
        return min(1, base * 0.6 + avgScore * 0.4)
    }

    private var latestMetabolicImpact: String {
        todayMeals.first?.metabolicImpact
            ?? yesterdayMeals.first?.metabolicImpact
            ?? ""
    }
    private var nutrientDensity: Int {
        guard !todayMeals.isEmpty else { return 0 }
        let avg = Double(todayMeals.reduce(0) { $0 + $1.mealScore }) / Double(todayMeals.count)
        return Int(avg.rounded())
    }
    private var hazards: [HazardWarning] {
        guard let p = profile else { return [] }
        let userAllergies = Set(p.allergies.map { $0.lowercased() })
        let userGoals = Set(p.goalsTags.map { $0.lowercased() })
        var out: [HazardWarning] = []
        let recent = products.sorted(by: { $0.lastScannedAt > $1.lastScannedAt }).prefix(20)
        for prod in recent {
            let flags = prod.allergyFlags
                .lowercased()
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            let conflict = flags.first(where: { userAllergies.contains($0) && !$0.isEmpty })
            if let c = conflict {
                out.append(HazardWarning(
                    productName: prod.name.isEmpty ? "Scanned product" : prod.name,
                    reason: "Contains \(c) — flagged in your profile.",
                    kind: "allergy"
                ))
                continue
            }
            if prod.riskLevel == "high" {
                out.append(HazardWarning(
                    productName: prod.name.isEmpty ? "Scanned product" : prod.name,
                    reason: prod.additiveRisk.isEmpty
                        ? "High additive load — review before consuming again."
                        : prod.additiveRisk,
                    kind: "additive"
                ))
                continue
            }
            if userGoals.contains(where: { $0.contains("sugar") }) && prod.sugar > 15 {
                out.append(HazardWarning(
                    productName: prod.name.isEmpty ? "Scanned product" : prod.name,
                    reason: "High sugar (\(Int(prod.sugar))g) — conflicts with your goal.",
                    kind: "goal"
                ))
            }
        }
        return Array(out.prefix(4))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                DailyDirectiveCard(
                    directive: directive,
                    isLoading: directiveLoading,
                    onTap: { cycleFocus() }
                )

                if let cal = activeCalibration {
                    SundayCalibrationCard(calibration: cal) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            cal.acknowledged = true
                            try? modelContext.save()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }

                bloomSection

                if drawerOpen {
                    DeepDiveDrawer(
                        metabolicImpact: latestMetabolicImpact,
                        nutrientDensity: nutrientDensity,
                        hazards: hazards
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                }

                HydrationScoreCard(
                    waterMl: waterToday,
                    targetMl: Double(profile?.dailyWaterTargetMl ?? 2400)
                )

                if !todayMeals.isEmpty {
                    recentMealsSection
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .task {
            await refreshDirective(force: false)
        }
        .task {
            await SundayCalibrationService.shared.runIfDue(
                context: modelContext,
                profile: profile,
                recentMeals: meals,
                latest: latestCalibration
            )
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 18) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, height: 180)
                .clipShape(.rect(cornerRadius: 40))
                .shadow(color: PrecisionCalTheme.terracotta.opacity(0.25), radius: 24, x: 0, y: 12)
                .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text(greeting().uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("PrecisionCal")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 12)
    }

    private var bloomSection: some View {
        VStack(spacing: 14) {
            VitalityBloom(
                hydration: hydrationProgress,
                macros: macroProgress,
                adherence: adherence
            )
            .frame(height: 260)
            .overlay(alignment: .center) {
                VStack(spacing: 2) {
                    Text("\(Int(caloriesToday))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .contentTransition(.numericText(value: caloriesToday))
                    Text("of \(profile?.dailyCalorieTarget ?? 2000) calories")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
                .allowsHitTesting(false)
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height < -40 {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                drawerOpen = true
                            }
                        } else if value.translation.height > 40 {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                drawerOpen = false
                            }
                        }
                    }
            )
            .onTapGesture {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    drawerOpen.toggle()
                }
            }

            HStack(spacing: 18) {
                BloomLegend(label: "Hydration", value: hydrationProgress, color: PrecisionCalTheme.hydrationColor)
                BloomLegend(label: "Macros", value: macroProgress, color: PrecisionCalTheme.carbColor)
                BloomLegend(label: "Adherence", value: adherence, color: PrecisionCalTheme.terracotta)
            }
            .padding(.horizontal, 6)

            HStack(spacing: 6) {
                Image(systemName: drawerOpen ? "chevron.down" : "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                Text(drawerOpen ? "Hide PhD breakdown" : "Swipe up for PhD breakdown")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
            }
            .foregroundStyle(PrecisionCalTheme.textTertiary)
        }
    }

    private var recentMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent meals")
                .font(.system(size: 13, weight: .semibold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
                .padding(.horizontal, 4)

            ForEach(todayMeals.prefix(4)) { meal in
                MealRow(meal: meal)
            }
        }
    }

    // MARK: - Helpers

    private func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }

    /// Instantly swap to the next curated focus directive on tap.
    /// Keeps interaction snappy without waiting on the network.
    private func cycleFocus() {
        withAnimation(.easeInOut(duration: 0.6)) {
            fallbackIndex = (fallbackIndex + 1) % curatedFocus.count
            directive = curatedFocus[fallbackIndex]
            directiveDate = Date()
        }
    }

    private func refreshDirective(force: Bool) async {
        if !force, let d = directiveDate, Calendar.current.isDateInToday(d), !directive.isEmpty {
            return
        }
        guard !directiveLoading else { return }
        directiveLoading = true
        defer { directiveLoading = false }

        let summary: String = {
            guard let p = profile else { return "Anonymous user." }
            return """
            Goal: \(p.goal). Tags: \(p.goalsTags.joined(separator: ", ")).
            Conditions: \(p.specificConditions.joined(separator: ", ")).
            Allergies: \(p.allergies.joined(separator: ", ")).
            Activity: \(p.activityLevel). Targets: \(p.dailyCalorieTarget) kcal, \(p.dailyProteinTarget)g protein.
            """
        }()
        let yCal = yesterdayMeals.reduce(0) { $0 + $1.totalCalories }
        let yProt = yesterdayMeals.reduce(0) { $0 + $1.totalProtein }
        let yStats = yesterdayMeals.isEmpty
            ? "No meals logged yesterday."
            : "Yesterday \(Int(yCal)) kcal, \(Int(yProt))g protein, \(yesterdayMeals.count) meals."
        let hydration = "\(Int(waterToday)) of \(profile?.dailyWaterTargetMl ?? 2400) ml"

        do {
            let result = try await AIService.shared.generateDailyDirective(
                profileSummary: summary,
                yesterdayStats: yStats,
                currentHydration: hydration
            )
            // Reject obvious fragments — must end with punctuation and have at least 6 words.
            let wordCount = result.split(whereSeparator: { $0.isWhitespace }).count
            let endsCleanly = result.hasSuffix(".") || result.hasSuffix("!") || result.hasSuffix("?")
            await MainActor.run {
                if wordCount >= 6 && endsCleanly {
                    directive = result
                } else if directive.isEmpty {
                    directive = curatedFocus[fallbackIndex]
                }
                directiveDate = Date()
            }
        } catch {
            // soft fallback
            await MainActor.run {
                if directive.isEmpty {
                    directive = curatedFocus[fallbackIndex]
                    directiveDate = Date()
                }
            }
        }
    }
}

// MARK: - Bloom legend chip

private struct BloomLegend: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text("\(Int(value * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Hydration card (compact, complementary to the bloom)

struct HydrationScoreCard: View {
    let waterMl: Double
    let targetMl: Double

    private var progress: Double { min(1, waterMl / max(targetMl, 1)) }

    var body: some View {
        GlassCard {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(PrecisionCalTheme.glassStroke.opacity(0.5), lineWidth: 8)
                        .frame(width: 78, height: 78)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [PrecisionCalTheme.hydrationColor, PrecisionCalTheme.sageLight], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 78, height: 78)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(PrecisionCalTheme.hydrationColor)
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("HYDRATION")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2.5)
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                    Text("\(Int(waterMl)) ml")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .contentTransition(.numericText(value: waterMl))
                    Text("of \(Int(targetMl)) ml • includes meal water")
                        .font(.system(size: 12))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                Spacer()
            }
            .padding(18)
        }
    }
}

struct MealRow: View {
    let meal: Meal

    var body: some View {
        GlassCard(cornerRadius: 18) {
            HStack(spacing: 14) {
                Color(.secondarySystemBackground)
                    .frame(width: 56, height: 56)
                    .overlay {
                        if let data = meal.imageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        } else {
                            Image(systemName: "fork.knife")
                                .foregroundStyle(PrecisionCalTheme.sage)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineLimit(1)
                    Text(meal.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(meal.totalCalories))")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    Text("calories")
                        .font(.system(size: 11))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                MealScoreBadge(score: meal.mealScore)
            }
            .padding(12)
        }
    }
}

struct MealScoreBadge: View {
    let score: Int

    private var color: Color {
        switch score {
        case 80...: return PrecisionCalTheme.sage
        case 60..<80: return PrecisionCalTheme.fatColor
        default: return PrecisionCalTheme.terracotta
        }
    }

    var body: some View {
        Text("\(score)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background {
                Circle().fill(color.opacity(0.15))
                Circle().stroke(color.opacity(0.5), lineWidth: 1.5)
            }
    }
}
