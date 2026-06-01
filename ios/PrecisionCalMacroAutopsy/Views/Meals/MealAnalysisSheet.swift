import SwiftUI

struct MealAnalysisSheet: View {
    @Bindable var meal: Meal
    let quickItems: [String]
    let currentPass: Int
    @Environment(\.dismiss) private var dismiss

    @State private var showMirror: Bool = false
    @State private var showRipple: Bool = false
    @State private var showEdit: Bool = false
    @State private var macroExpanded: Bool = false

    var body: some View {
        ZStack {
            MeshBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerImage

                    statusBlock

                    if meal.status == "complete" && showMirror {
                        MetabolicMirrorCard(meal: meal)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                                removal: .opacity
                            ))
                    }

                    if meal.status == "failed" {
                        failureCard
                    } else if !meal.items.isEmpty {
                        nutritionSummary
                        if meal.lipidSheenDetected && meal.hiddenFatAddedCalories > 0 {
                            hiddenFatAlertCard
                        }
                        macroCalibrationCard
                        if !meal.micronutrients.isEmpty {
                            micronutrientMatrixCard
                        }
                        itemsList
                    } else if !quickItems.isEmpty {
                        quickItemsList
                    } else {
                        scanningPlaceholder
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)

            if showRipple {
                SoftMilkRipple(onFinished: { showRipple = false })
                    .transition(.opacity)
            }
        }
        .onAppear {
            if meal.status == "complete" { showMirror = true }
        }
        .onChange(of: meal.status) { _, newValue in
            guard newValue == "complete" else { return }
            showRipple = true
            withAnimation(.easeOut(duration: 0.8).delay(0.35)) {
                showMirror = true
            }
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 10) {
                if meal.status == "complete" {
                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(PrecisionCalMacroAutopsyTheme.glassStroke, lineWidth: 1))
                    }
                }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(PrecisionCalMacroAutopsyTheme.glassStroke, lineWidth: 1))
                }
            }
            .padding(.top, 14)
            .padding(.trailing, 18)
        }
        .sheet(isPresented: $showEdit) {
            EditMealView(meal: meal)
                .presentationDetents([.large])
        }
    }

    private var headerImage: some View {
        Color(.secondarySystemBackground)
            .frame(height: 220)
            .overlay {
                if let data = meal.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 48))
                        .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracotta)
                }
            }
            .clipShape(.rect(cornerRadius: 22))
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(.rect(cornerRadius: 22))
                .frame(height: 100)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(meal.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
                }
                .padding(16)
            }
    }

    private var statusBlock: some View {
        Group {
            if meal.status == "analyzing" {
                AnalysisProgressBar(currentPass: currentPass)
            }
        }
    }

    private var failureCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PrecisionCalMacroAutopsyTheme.fatColor)
                    Text("Analysis failed")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                }
                Text(meal.qcNotes.isEmpty ? "Something went wrong while analyzing your meal. Please try again with a clearer photo." : meal.qcNotes)
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    dismiss()
                } label: {
                    Text("Try again")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(PrecisionCalMacroAutopsyTheme.terracotta, in: .rect(cornerRadius: 14))
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
    }

    private var quickItemsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Identified items")
            ForEach(Array(quickItems.enumerated()), id: \.offset) { idx, name in
                IdentifiedItemRow(name: name, delay: Double(idx) * 0.08)
            }
        }
    }

    private var scanningPlaceholder: some View {
        GlassCard {
            HStack(spacing: 14) {
                BreathingOrb(size: 36)
                Text("Scanning your meal…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
                Spacer()
            }
            .padding(20)
        }
    }

    private var nutritionSummary: some View {
        GlassCard {
            HStack(spacing: 0) {
                NutritionStat(value: "\(Int(meal.totalCalories))", unit: "calories", color: PrecisionCalMacroAutopsyTheme.textPrimary)
                Divider().frame(height: 36).background(PrecisionCalMacroAutopsyTheme.glassStroke)
                NutritionStat(value: "\(Int(meal.totalFiber))g", unit: "fiber", color: PrecisionCalMacroAutopsyTheme.mint)
                Divider().frame(height: 36).background(PrecisionCalMacroAutopsyTheme.glassStroke)
                NutritionStat(value: "\(Int(meal.totalSugar))g", unit: "sugar", color: PrecisionCalMacroAutopsyTheme.fatColor)
                Divider().frame(height: 36).background(PrecisionCalMacroAutopsyTheme.glassStroke)
                NutritionStat(value: "\(Int(meal.waterContentMl))ml", unit: "water", color: PrecisionCalMacroAutopsyTheme.hydrationColor)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Card 1 — Hidden Fat Alert

    private var hiddenFatAlertCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("⚠️")
                    .font(.system(size: 20))
                Text("Hidden Fat Alert: +\(Int(meal.hiddenFatAddedCalories.rounded())) kcal (+\(formatG(meal.hiddenFatAddedFatG))g Fat)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("\(hiddenFatSubtext)")
                .font(.system(size: 13))
                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(PrecisionCalMacroAutopsyTheme.amber.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PrecisionCalMacroAutopsyTheme.amber.opacity(0.65), lineWidth: 1.5)
        )
        .shadow(color: PrecisionCalMacroAutopsyTheme.amber.opacity(0.30), radius: 18, x: 0, y: 6)
    }

    private var hiddenFatSubtext: String {
        let mechanism = meal.hiddenFatMechanism.isEmpty ? "lipid sheen confirmation via Pass 3 macro-zoom" : meal.hiddenFatMechanism
        let target = meal.hiddenFatTargetItem.isEmpty ? "the plate" : meal.hiddenFatTargetItem
        return "\(mechanism.prefix(1).capitalized + mechanism.dropFirst()) on '\(target)'. Base metrics mathematically adjusted."
    }

    // MARK: - Card 2 — Advanced Macro Calibration

    private var macroCalibrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Advanced Macro Calibration")
            GlassCard {
                VStack(spacing: 16) {
                    MacroBar(label: "Protein", grams: meal.totalProtein, color: PrecisionCalMacroAutopsyTheme.proteinColor, scale: 80)
                    MacroBar(label: "Carbs", grams: meal.totalCarbs, color: PrecisionCalMacroAutopsyTheme.carbColor, scale: 120)
                    MacroBar(label: "Fat", grams: meal.totalFat, color: PrecisionCalMacroAutopsyTheme.fatColor, scale: 50)

                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            macroExpanded.toggle()
                        }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Text(macroExpanded ? "Hide breakdown" : "Show breakdown")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .rotationEffect(.degrees(macroExpanded ? 180 : 0))
                        }
                        .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracottaDeep)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if macroExpanded {
                        VStack(spacing: 0) {
                            subMacroRow("Net Carbs", value: max(0, meal.totalCarbs - meal.totalFiber), color: PrecisionCalMacroAutopsyTheme.carbColor)
                            subDivider
                            subMacroRow("Fiber", value: meal.totalFiber, color: PrecisionCalMacroAutopsyTheme.sage)
                            subDivider
                            subMacroRow("Saturated Fats", value: meal.saturatedFat, color: PrecisionCalMacroAutopsyTheme.fatColor)
                            subDivider
                            subMacroRow("Unsaturated Fats", value: meal.unsaturatedFat, color: PrecisionCalMacroAutopsyTheme.hydrationColor)
                            if meal.transFat > 0 {
                                subDivider
                                subMacroRow("Trans Fats", value: meal.transFat, color: PrecisionCalMacroAutopsyTheme.terracottaDeep)
                            }
                        }
                        .padding(.top, 4)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                    }
                }
                .padding(20)
            }
        }
    }

    private func subMacroRow(_ label: String, value: Double, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
            Spacer()
            Text("\(formatG(value))g")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
        }
        .padding(.vertical, 9)
    }

    private var subDivider: some View {
        Rectangle()
            .fill(PrecisionCalMacroAutopsyTheme.glassStroke.opacity(0.4))
            .frame(height: 1)
    }

    // MARK: - Card 3 — Clinical Micronutrient Matrix

    private var micronutrientMatrixCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Clinical Micronutrient Matrix")
            GlassCard {
                VStack(spacing: 16) {
                    ForEach(meal.micronutrients) { nutrient in
                        MicronutrientRow(nutrient: nutrient)
                    }
                }
                .padding(20)
            }
        }
    }

    private func formatG(_ v: Double) -> String {
        if v >= 10 || v == v.rounded() {
            return String(Int(v.rounded()))
        }
        return String(format: "%.1f", v)
    }

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Items")
            ForEach(meal.items) { item in
                GlassCard(cornerRadius: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                            Text("\(Int(item.grams))g • \(item.preparation)")
                                .font(.system(size: 12))
                                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textTertiary)
                        }
                        Spacer()
                        Text("\(Int(item.calories)) calories")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracotta)
                    }
                    .padding(14)
                }
            }
        }
    }

    private func sectionLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(2.5)
            .foregroundStyle(PrecisionCalMacroAutopsyTheme.textTertiary)
            .padding(.horizontal, 4)
    }
}

struct AnalysisProgressBar: View {
    let currentPass: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracotta)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Pass \(currentPass) of 6")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PrecisionCalMacroAutopsyTheme.textTertiary)
                        Text(passLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .contentTransition(.opacity)
                    }
                    Spacer(minLength: 0)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PrecisionCalMacroAutopsyTheme.glassStroke.opacity(0.5)).frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(colors: [PrecisionCalMacroAutopsyTheme.terracotta, PrecisionCalMacroAutopsyTheme.fatColor], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(currentPass) / 6, height: 4)
                            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: currentPass)
                    }
                }
                .frame(height: 4)
            }
            .padding(16)
        }
    }

    private var passLabel: String {
        switch currentPass {
        case 1: return "Isolation: enumerating every item"
        case 2: return "Lipid discovery: surface reflectivity scan"
        case 3: return "Macro-zoom: magnified texture & viscosity"
        case 4: return "Dimensional: 3D volume from depth cues"
        case 5: return "Comparison: cross-referencing USDA DB"
        default: return "Synthesis: final verified profile"
        }
    }
}

struct IdentifiedItemRow: View {
    let name: String
    let delay: Double
    @State private var appeared = false

    var body: some View {
        GlassCard(cornerRadius: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(PrecisionCalMacroAutopsyTheme.terracotta.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracotta)
                    }
                Text(name.capitalized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                Spacer()
                BreathingOrb(size: 22, color: PrecisionCalMacroAutopsyTheme.terracotta)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                appeared = true
            }
        }
    }
}

struct NutritionStat: View {
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 11))
                .foregroundStyle(PrecisionCalMacroAutopsyTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MacroBar: View {
    let label: String
    let grams: Double
    let color: Color
    let scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
                Spacer()
                Text("\(Int(grams))g")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PrecisionCalMacroAutopsyTheme.glassStroke.opacity(0.4)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(min(1, grams / scale)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct MicronutrientRow: View {
    let nutrient: Micronutrient
    @State private var appeared = false

    private var clampedPct: Double { max(0, min(1, nutrient.pctDailyValue / 100)) }

    private var barColor: Color {
        if nutrient.pctDailyValue >= 75 { return PrecisionCalMacroAutopsyTheme.terracotta }
        if nutrient.pctDailyValue >= 30 { return PrecisionCalMacroAutopsyTheme.sage }
        return PrecisionCalMacroAutopsyTheme.hydrationColor
    }

    private var amountLabel: String {
        let mg = nutrient.amountMg
        if mg >= 1000 {
            return String(format: "%.1fg", mg / 1000)
        }
        if mg >= 10 || mg == mg.rounded() {
            return "\(Int(mg.rounded()))mg"
        }
        return String(format: "%.1fmg", mg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(nutrient.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
                Spacer()
                Text(amountLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textTertiary)
                Text("\(Int(nutrient.pctDailyValue.rounded()))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(barColor)
                    .frame(width: 44, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PrecisionCalMacroAutopsyTheme.glassStroke.opacity(0.35)).frame(height: 5)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(appeared ? clampedPct : 0), height: 5)
                }
            }
            .frame(height: 5)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }
}
