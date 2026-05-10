import SwiftUI

struct MealAnalysisSheet: View {
    @Bindable var meal: Meal
    let quickItems: [String]
    let currentPass: Int
    @Environment(\.dismiss) private var dismiss

    @State private var showMirror: Bool = false
    @State private var showRipple: Bool = false
    @State private var showEdit: Bool = false

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
                        macroBars
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
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
                    }
                }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
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
                        .foregroundStyle(PrecisionCalTheme.terracotta)
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
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
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
                        .foregroundStyle(PrecisionCalTheme.fatColor)
                    Text("Analysis failed")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                }
                Text(meal.qcNotes.isEmpty ? "Something went wrong while analyzing your meal. Please try again with a clearer photo." : meal.qcNotes)
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    dismiss()
                } label: {
                    Text("Try again")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(PrecisionCalTheme.terracotta, in: .rect(cornerRadius: 14))
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
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                Spacer()
            }
            .padding(20)
        }
    }

    private var nutritionSummary: some View {
        GlassCard {
            HStack(spacing: 0) {
                NutritionStat(value: "\(Int(meal.totalCalories))", unit: "calories", color: PrecisionCalTheme.textPrimary)
                Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                NutritionStat(value: "\(Int(meal.totalFiber))g", unit: "fiber", color: PrecisionCalTheme.mint)
                Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                NutritionStat(value: "\(Int(meal.totalSugar))g", unit: "sugar", color: PrecisionCalTheme.fatColor)
                Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                NutritionStat(value: "\(Int(meal.waterContentMl))ml", unit: "water", color: PrecisionCalTheme.hydrationColor)
            }
            .padding(.vertical, 16)
        }
    }

    private var macroBars: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Macros")
            GlassCard {
                VStack(spacing: 16) {
                    MacroBar(label: "Protein", grams: meal.totalProtein, color: PrecisionCalTheme.proteinColor, scale: 80)
                    MacroBar(label: "Carbs", grams: meal.totalCarbs, color: PrecisionCalTheme.carbColor, scale: 120)
                    MacroBar(label: "Fat", grams: meal.totalFat, color: PrecisionCalTheme.fatColor, scale: 50)
                }
                .padding(20)
            }
        }
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
                                .foregroundStyle(PrecisionCalTheme.textPrimary)
                            Text("\(Int(item.grams))g • \(item.preparation)")
                                .font(.system(size: 12))
                                .foregroundStyle(PrecisionCalTheme.textTertiary)
                        }
                        Spacer()
                        Text("\(Int(item.calories)) calories")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(PrecisionCalTheme.terracotta)
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
            .foregroundStyle(PrecisionCalTheme.textTertiary)
            .padding(.horizontal, 4)
    }
}

struct AnalysisProgressBar: View {
    let currentPass: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                    Text(passLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .contentTransition(.opacity)
                    Spacer()
                    Text("Pass \(currentPass) of 5")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PrecisionCalTheme.glassStroke.opacity(0.5)).frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.fatColor], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(currentPass) / 5, height: 4)
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
        case 1: return "Isolation + Zoom: items, texture, prep"
        case 2: return "Dimensional: 3D volume from depth cues"
        case 3: return "Comparison: cross-referencing serving DB"
        case 4: return "Synthesis: comprehensive profile"
        default: return "Lipid sheen: detecting hidden fats"
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
                    .fill(PrecisionCalTheme.terracotta.opacity(0.18))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                    }
                Text(name.capitalized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Spacer()
                BreathingOrb(size: 22, color: PrecisionCalTheme.terracotta)
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
                .foregroundStyle(PrecisionCalTheme.textTertiary)
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
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                Spacer()
                Text("\(Int(grams))g")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PrecisionCalTheme.glassStroke.opacity(0.4)).frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(min(1, grams / scale)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
