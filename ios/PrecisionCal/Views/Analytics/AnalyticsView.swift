import SwiftUI
import SwiftData
import Charts

enum AnalyticsRange: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        case .all: nil
        }
    }
}

enum AnalyticsTab: String, CaseIterable, Identifiable {
    case nutrition = "Nutrition"
    case water = "Water"
    case weight = "Weight"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nutrition: "leaf.fill"
        case .water: "drop.fill"
        case .weight: "figure.stand"
        }
    }
}

struct AnalyticsView: View {
    @State private var tab: AnalyticsTab = .nutrition
    @State private var range: AnalyticsRange = .month

    var body: some View {
        ZStack {
            MeshBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    tabSwitcher

                    rangePicker

                    Group {
                        switch tab {
                        case .nutrition: NutritionAnalyticsSection(range: range)
                        case .water: WaterAnalyticsSection(range: range)
                        case .weight: WeightAnalyticsSection(range: range)
                        }
                    }
                    .id("\(tab.rawValue)-\(range.rawValue)")
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 14)),
                        removal: .opacity
                    ))

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: tab)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: range)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ANALYTICS")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.terracotta)
            Text("Your trajectory")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tabSwitcher: some View {
        GlassCard(cornerRadius: 22) {
            HStack(spacing: 4) {
                ForEach(AnalyticsTab.allCases) { t in
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .soft)
                        gen.impactOccurred()
                        tab = t
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: t.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(t.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(tab == t ? .white : PrecisionCalTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if tab == t {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .matchedGeometryEffect(id: "tabSelect", in: ns)
                                    .shadow(color: PrecisionCalTheme.terracotta.opacity(0.3), radius: 8, y: 4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
        }
    }

    @Namespace private var ns

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(AnalyticsRange.allCases) { r in
                Button {
                    let gen = UISelectionFeedbackGenerator()
                    gen.selectionChanged()
                    range = r
                } label: {
                    Text(r.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(range == r ? .white : PrecisionCalTheme.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background {
                            Capsule()
                                .fill(range == r ? PrecisionCalTheme.textPrimary : Color.white.opacity(0.5))
                                .overlay(
                                    Capsule().stroke(PrecisionCalTheme.glassStroke, lineWidth: 1)
                                )
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

// MARK: - Nutrition

enum Nutrient: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case protein = "Protein"
    case carbs = "Carbs"
    case fat = "Fat"
    case fiber = "Fiber"
    case sugar = "Sugar"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .calories: "calories"
        default: "g"
        }
    }

    var color: Color {
        switch self {
        case .calories: PrecisionCalTheme.terracotta
        case .protein: PrecisionCalTheme.proteinColor
        case .carbs: PrecisionCalTheme.carbColor
        case .fat: PrecisionCalTheme.fatColor
        case .fiber: PrecisionCalTheme.sage
        case .sugar: Color(red: 0.85, green: 0.55, blue: 0.65)
        }
    }

    func value(from meal: Meal) -> Double {
        switch self {
        case .calories: meal.totalCalories
        case .protein: meal.totalProtein
        case .carbs: meal.totalCarbs
        case .fat: meal.totalFat
        case .fiber: meal.totalFiber
        case .sugar: meal.totalSugar
        }
    }
}

struct NutritionAnalyticsSection: View {
    let range: AnalyticsRange
    @Query(sort: \Meal.createdAt, order: .reverse) private var meals: [Meal]
    @State private var selected: Set<Nutrient> = [.calories, .protein]
    @State private var animate: Bool = false

    private var filteredMeals: [Meal] {
        guard let days = range.days else { return meals.filter { $0.status == "complete" } }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return meals.filter { $0.status == "complete" && $0.createdAt >= start }
    }

    private func dailyTotals(for nutrient: Nutrient) -> [DailyPoint] {
        let cal = Calendar.current
        var bucket: [Date: Double] = [:]
        for meal in filteredMeals {
            let day = cal.startOfDay(for: meal.createdAt)
            bucket[day, default: 0] += nutrient.value(from: meal)
        }
        return bucket.keys.sorted().map { day in
            DailyPoint(date: day, value: bucket[day] ?? 0, nutrient: nutrient.rawValue)
        }
    }

    private var allPoints: [DailyPoint] {
        selected.flatMap { dailyTotals(for: $0) }
    }

    private var summaryStats: [(Nutrient, Double, Double)] {
        // (nutrient, total, dailyAvg)
        selected.sorted(by: { $0.rawValue < $1.rawValue }).map { n in
            let pts = dailyTotals(for: n)
            let total = pts.reduce(0) { $0 + $1.value }
            let avg = pts.isEmpty ? 0 : total / Double(pts.count)
            return (n, total, avg)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            nutrientChips

            chartCard

            if !summaryStats.isEmpty {
                summaryCard
            }

            if filteredMeals.isEmpty {
                emptyCard
            }
        }
        .onAppear {
            animate = false
            withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.05)) {
                animate = true
            }
        }
    }

    private var nutrientChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Nutrient.allCases) { n in
                    let isOn = selected.contains(n)
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        if isOn {
                            if selected.count > 1 { selected.remove(n) }
                        } else {
                            selected.insert(n)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(n.color)
                                .frame(width: 8, height: 8)
                            Text(n.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(isOn ? PrecisionCalTheme.textPrimary : PrecisionCalTheme.textTertiary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background {
                            Capsule()
                                .fill(isOn ? n.color.opacity(0.18) : Color.white.opacity(0.4))
                                .overlay(
                                    Capsule().stroke(isOn ? n.color.opacity(0.6) : PrecisionCalTheme.glassStroke, lineWidth: 1)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, 4)
    }

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("DAILY INTAKE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(PrecisionCalTheme.textTertiary)

                Chart(allPoints) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Amount", animate ? p.value : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Nutrient", p.nutrient))
                    .symbol(by: .value("Nutrient", p.nutrient))
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("Amount", animate ? p.value : 0)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Nutrient", p.nutrient))
                    .opacity(0.12)
                }
                .chartForegroundStyleScale(
                    domain: Nutrient.allCases.map { $0.rawValue },
                    range: Nutrient.allCases.map { $0.color }
                )
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(PrecisionCalTheme.glassStroke.opacity(0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: false)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(PrecisionCalTheme.glassStroke.opacity(0.4))
                        AxisValueLabel()
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                }
                .frame(height: 220)
                .animation(.spring(response: 1.0, dampingFraction: 0.78), value: animate)
            }
            .padding(20)
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 10) {
            ForEach(Array(summaryStats.enumerated()), id: \.offset) { idx, row in
                let (n, total, avg) = row
                GlassCard(cornerRadius: 18) {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [n.color, n.color.opacity(0.6)],
                                    center: .topLeading, startRadius: 2, endRadius: 30
                                )
                            )
                            .frame(width: 14, height: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PrecisionCalTheme.textPrimary)
                            Text("Daily avg \(formatted(avg)) \(n.unit)")
                                .font(.system(size: 12))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatted(total))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(n.color)
                            Text("total \(n.unit)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                        }
                    }
                    .padding(14)
                }
                .opacity(animate ? 1 : 0)
                .offset(y: animate ? 0 : 18)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.08 * Double(idx) + 0.2), value: animate)
            }
        }
    }

    private var emptyCard: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 28))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                Text("No meals in this range")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                Text("Log a meal to start your trend.")
                    .font(.system(size: 12))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    private func formatted(_ v: Double) -> String {
        if v >= 100 { return String(Int(v.rounded())) }
        return String(format: "%.1f", v)
    }
}

struct DailyPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let nutrient: String
}

// MARK: - Water

struct WaterAnalyticsSection: View {
    let range: AnalyticsRange
    @Query(sort: \WaterEntry.createdAt, order: .reverse) private var entries: [WaterEntry]
    @Query private var profiles: [UserProfile]
    @State private var animate: Bool = false

    private var target: Double { Double(profiles.first?.dailyWaterTargetMl ?? 2400) }

    private var filtered: [WaterEntry] {
        guard let days = range.days else { return entries }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { $0.createdAt >= start }
    }

    private var dailyTotals: [DailyPoint] {
        let cal = Calendar.current
        var bucket: [Date: Double] = [:]
        for e in filtered {
            let day = cal.startOfDay(for: e.createdAt)
            bucket[day, default: 0] += e.amountMl
        }
        return bucket.keys.sorted().map { DailyPoint(date: $0, value: bucket[$0] ?? 0, nutrient: "Water") }
    }

    private var avg: Double {
        let pts = dailyTotals
        return pts.isEmpty ? 0 : pts.reduce(0) { $0 + $1.value } / Double(pts.count)
    }

    private var streak: Int {
        let cal = Calendar.current
        var s = 0
        var day = cal.startOfDay(for: Date())
        let totals = Dictionary(grouping: filtered, by: { cal.startOfDay(for: $0.createdAt) })
            .mapValues { $0.reduce(0) { $0 + $1.amountMl } }
        while (totals[day] ?? 0) >= target {
            s += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartCard
            statsRow
            if dailyTotals.isEmpty {
                GlassCard {
                    Text("Log some water to see your trend.")
                        .font(.system(size: 13))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            animate = false
            withAnimation(.spring(response: 0.9, dampingFraction: 0.78).delay(0.05)) {
                animate = true
            }
        }
    }

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("DAILY WATER")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                    Spacer()
                    Text("Target \(Int(target)) ml")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.hydrationColor)
                }

                Chart {
                    ForEach(dailyTotals) { p in
                        AreaMark(
                            x: .value("Date", p.date),
                            y: .value("ml", animate ? p.value : 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [PrecisionCalTheme.hydrationColor.opacity(0.5), PrecisionCalTheme.hydrationColor.opacity(0.05)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Date", p.date),
                            y: .value("ml", animate ? p.value : 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(PrecisionCalTheme.hydrationColor)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value("Date", p.date),
                            y: .value("ml", animate ? p.value : 0)
                        )
                        .foregroundStyle(PrecisionCalTheme.hydrationColor)
                        .symbolSize(animate ? 36 : 0)
                    }

                    RuleMark(y: .value("Target", target))
                        .foregroundStyle(PrecisionCalTheme.terracotta.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(PrecisionCalTheme.glassStroke.opacity(0.5))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(PrecisionCalTheme.glassStroke.opacity(0.4))
                        AxisValueLabel()
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                }
                .frame(height: 220)
                .animation(.spring(response: 1.0, dampingFraction: 0.78), value: animate)
            }
            .padding(20)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(label: "Daily avg", value: "\(Int(avg))", unit: "ml", color: PrecisionCalTheme.hydrationColor, delay: 0.2)
            statTile(label: "Streak", value: "\(streak)", unit: streak == 1 ? "day" : "days", color: PrecisionCalTheme.terracotta, delay: 0.3)
            statTile(label: "Logs", value: "\(filtered.count)", unit: "sips", color: PrecisionCalTheme.sage, delay: 0.4)
        }
    }

    private func statTile(label: String, value: String, unit: String, color: Color, delay: Double) -> some View {
        GlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animate)
    }
}

// MARK: - Weight

struct WeightAnalyticsSection: View {
    let range: AnalyticsRange
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BodyWeightEntry.createdAt, order: .reverse) private var entries: [BodyWeightEntry]
    @Query private var profiles: [UserProfile]
    @State private var animate: Bool = false
    @State private var showAdd: Bool = false

    private var filtered: [BodyWeightEntry] {
        guard let days = range.days else { return entries.sorted { $0.createdAt < $1.createdAt } }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { $0.createdAt >= start }.sorted { $0.createdAt < $1.createdAt }
    }

    private static let kgToLb: Double = 2.20462

    private var points: [DailyPoint] {
        filtered.map { DailyPoint(date: $0.createdAt, value: $0.weightKg * Self.kgToLb, nutrient: "Weight") }
    }

    private var current: Double? { entries.first.map { $0.weightKg * Self.kgToLb } }
    private var change: Double {
        guard let first = filtered.first, let last = filtered.last else { return 0 }
        return (last.weightKg - first.weightKg) * Self.kgToLb
    }
    private var minW: Double { (filtered.map { $0.weightKg }.min() ?? 0) * Self.kgToLb }
    private var maxW: Double { (filtered.map { $0.weightKg }.max() ?? 0) * Self.kgToLb }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartCard

            statsRow

            addEntryButton

            if !entries.isEmpty {
                historyList
            }
        }
        .onAppear {
            animate = false
            withAnimation(.spring(response: 0.9, dampingFraction: 0.78).delay(0.05)) {
                animate = true
            }
        }
        .sheet(isPresented: $showAdd) {
            AddWeightSheet(initial: current ?? profiles.first?.weightKg ?? 70)
                .presentationDetents([.medium])
        }
    }

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("WEIGHT TREND")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                    Spacer()
                    if let cur = current {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(String(format: "%.1f", cur))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(PrecisionCalTheme.textPrimary)
                            Text("lb")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                        }
                    }
                }

                if points.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "scalemass")
                            .font(.system(size: 32))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                        Text("No weigh-ins yet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                    }
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                } else {
                    let lo = max(0, minW - 1.5)
                    let hi = maxW + 1.5
                    Chart {
                        ForEach(points) { p in
                            AreaMark(
                                x: .value("Date", p.date),
                                yStart: .value("lo", lo),
                                yEnd: .value("Weight", animate ? p.value : lo)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [PrecisionCalTheme.terracotta.opacity(0.4), PrecisionCalTheme.terracotta.opacity(0.0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Date", p.date),
                                y: .value("Weight", animate ? p.value : lo)
                            )
                            .interpolationMethod(.monotone)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.fatColor],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                            PointMark(
                                x: .value("Date", p.date),
                                y: .value("Weight", animate ? p.value : lo)
                            )
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                            .symbolSize(animate ? 50 : 0)
                        }
                    }
                    .chartYScale(domain: lo...hi)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine().foregroundStyle(PrecisionCalTheme.glassStroke.opacity(0.5))
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { _ in
                            AxisGridLine().foregroundStyle(PrecisionCalTheme.glassStroke.opacity(0.4))
                            AxisValueLabel()
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                        }
                    }
                    .frame(height: 220)
                    .animation(.spring(response: 1.0, dampingFraction: 0.78), value: animate)
                }
            }
            .padding(20)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            tile("Change", value: String(format: "%+.1f", change), unit: "lb", color: change <= 0 ? PrecisionCalTheme.sage : PrecisionCalTheme.terracotta, delay: 0.2)
            tile("Lowest", value: filtered.isEmpty ? "—" : String(format: "%.1f", minW), unit: "lb", color: PrecisionCalTheme.sage, delay: 0.3)
            tile("Highest", value: filtered.isEmpty ? "—" : String(format: "%.1f", maxW), unit: "lb", color: PrecisionCalTheme.fatColor, delay: 0.4)
        }
    }

    private func tile(_ label: String, value: String, unit: String, color: Color, delay: Double) -> some View {
        GlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animate)
    }

    private var addEntryButton: some View {
        PearlescentButton(action: { showAdd = true }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Log a weigh-in")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
        }
    }

    private var historyList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HISTORY")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
                .padding(.horizontal, 4)
                .padding(.top, 4)

            ForEach(entries.prefix(20)) { e in
                GlassCard(cornerRadius: 14) {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f lb", e.weightKg * 2.20462))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PrecisionCalTheme.textPrimary)
                            if !e.note.isEmpty {
                                Text(e.note)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                            }
                        }
                        Spacer()
                        Text(e.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                    .padding(14)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        modelContext.delete(e)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }
}

struct AddWeightSheet: View {
    let initial: Double
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var weight: Double = 154
    @State private var note: String = ""

    init(initial: Double) {
        self.initial = initial
        _weight = State(initialValue: initial * 2.20462)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        VStack(spacing: 6) {
                            Text(String(format: "%.1f", weight))
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundStyle(PrecisionCalTheme.terracotta)
                                .contentTransition(.numericText(value: weight))
                            Text("lb")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                        }
                        .padding(.top, 24)

                        GlassCard {
                            VStack(spacing: 14) {
                                Slider(value: $weight, in: 66...440, step: 0.1)
                                    .tint(PrecisionCalTheme.terracotta)

                                HStack {
                                    Button { weight = max(66, weight - 0.1) } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                                    }
                                    Spacer()
                                    Text("Adjust")
                                        .font(.system(size: 12, weight: .semibold))
                                        .tracking(2)
                                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                                    Spacer()
                                    Button { weight = min(440, weight + 0.1) } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(PrecisionCalTheme.terracotta)
                                    }
                                }
                            }
                            .padding(20)
                        }

                        GlassCard {
                            TextField("Optional note (e.g. morning, post-workout)", text: $note)
                                .font(.system(size: 14))
                                .padding(16)
                        }

                        PearlescentButton(action: save) {
                            Text("Save weigh-in")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 18)
                }
            }
            .navigationTitle("New weigh-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func save() {
        let entry = BodyWeightEntry(weightKg: weight / 2.20462, note: note)
        modelContext.insert(entry)
        try? modelContext.save()
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        dismiss()
    }
}
