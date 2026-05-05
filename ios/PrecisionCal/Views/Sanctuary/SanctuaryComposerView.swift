import SwiftUI
import SwiftData

struct SanctuaryComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]
    @Query(sort: \Meal.createdAt, order: .reverse) private var meals: [Meal]
    @Query(sort: \WaterEntry.createdAt, order: .reverse) private var waters: [WaterEntry]

    @State private var kind: SanctuaryPostKind = .encouragement
    @State private var bodyText: String = ""
    @State private var mood: String = ""
    @State private var selectedMealID: PersistentIdentifier? = nil
    @State private var submitting: Bool = false

    private var profile: UserProfile? { profiles.first }

    private var todayMeals: [Meal] {
        meals.filter { Calendar.current.isDateInToday($0.createdAt) && $0.status == "complete" }
    }
    private var todayWater: [WaterEntry] {
        waters.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var hydrationProgress: Double {
        let target = Double(profile?.dailyWaterTargetMl ?? 2400)
        let total = todayWater.reduce(0) { $0 + $1.amountMl }
            + todayMeals.reduce(0) { $0 + $1.waterContentMl }
        return min(1, total / max(target, 1))
    }

    private var macroProgress: Double {
        let cT = Double(profile?.dailyCalorieTarget ?? 2000)
        let kcal = todayMeals.reduce(0) { $0 + $1.totalCalories }
        return min(1, kcal / max(cT, 1))
    }

    private var adherenceProgress: Double {
        guard !todayMeals.isEmpty else { return (hydrationProgress + macroProgress) * 0.3 }
        let avg = Double(todayMeals.reduce(0) { $0 + $1.mealScore }) / Double(todayMeals.count) / 100
        return min(1, (hydrationProgress + macroProgress + avg) / 3)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    kindPicker
                    bodyEditor
                    contextPanel
                    submitButton
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .background {
                MeshBackground().ignoresSafeArea()
            }
            .navigationTitle("Share with the Sanctuary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
            }
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHOOSE A POST TYPE")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            HStack(spacing: 10) {
                kindButton(.encouragement, "Voice", "quote.bubble.fill")
                kindButton(.bloom, "Bloom", "circle.hexagongrid.fill")
                kindButton(.mealAnalysis, "PhD Meal", "leaf.fill")
            }
        }
    }

    private func kindButton(_ k: SanctuaryPostKind, _ label: String, _ icon: String) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { kind = k }
            if k == .mealAnalysis, selectedMealID == nil {
                selectedMealID = todayMeals.first?.persistentModelID
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .bold)).tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(kind == k ? .white : PrecisionCalTheme.terracotta)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(kind == k
                          ? AnyShapeStyle(LinearGradient(colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color.white.opacity(0.5)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PrecisionCalTheme.terracotta.opacity(kind == k ? 0 : 0.4), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var bodyEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(promptLabel.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)

            ZStack(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text(placeholder)
                        .font(.custom("Georgia", size: 16))
                        .foregroundStyle(PrecisionCalTheme.textTertiary.opacity(0.7))
                        .padding(14)
                }
                TextEditor(text: $bodyText)
                    .font(.custom("Georgia", size: 16))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 130)
            }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
            }
        }
    }

    private var promptLabel: String {
        switch kind {
        case .encouragement: "Words of encouragement"
        case .bloom: "Caption for your bloom"
        case .mealAnalysis: "Reflection on this meal"
        }
    }

    private var placeholder: String {
        switch kind {
        case .encouragement: "Speak from where you are. The Sanctuary listens."
        case .bloom: "What does today feel like in your body?"
        case .mealAnalysis: "What did this meal teach you?"
        }
    }

    @ViewBuilder
    private var contextPanel: some View {
        switch kind {
        case .bloom:
            bloomPreview
        case .mealAnalysis:
            mealPicker
        case .encouragement:
            EmptyView()
        }
    }

    private var bloomPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR BLOOM RIGHT NOW")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)

            HStack(spacing: 14) {
                statBubble("Hydration", hydrationProgress, PrecisionCalTheme.hydrationColor)
                statBubble("Macros", macroProgress, PrecisionCalTheme.carbColor)
                statBubble("Adherence", adherenceProgress, PrecisionCalTheme.terracotta)
            }

            HStack(spacing: 8) {
                ForEach(["Steady", "Energized", "Resting", "Re-centering"], id: \.self) { m in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        mood = (mood == m) ? "" : m
                    } label: {
                        Text(m)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(mood == m ? .white : PrecisionCalTheme.textSecondary)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background {
                                Capsule().fill(mood == m ? PrecisionCalTheme.terracotta : Color.white.opacity(0.5))
                                    .overlay(Capsule().stroke(PrecisionCalTheme.glassStroke, lineWidth: 0.8))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
        }
    }

    private func statBubble(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(value * 100))%")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CHOOSE A RECENT MEAL")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)

            if meals.filter({ $0.status == "complete" }).isEmpty {
                Text("Analyze a meal first to share its 6-Pass results.")
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.4)))
            } else {
                VStack(spacing: 8) {
                    ForEach(meals.filter { $0.status == "complete" }.prefix(5)) { meal in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            selectedMealID = meal.persistentModelID
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedMealID == meal.persistentModelID
                                      ? "circle.inset.filled" : "circle")
                                    .foregroundStyle(PrecisionCalTheme.terracotta)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(meal.title).font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                                    Text("Score \(meal.mealScore) · \(Int(meal.totalCalories)) kcal")
                                        .font(.system(size: 11))
                                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(selectedMealID == meal.persistentModelID ? 0.7 : 0.4))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(PrecisionCalTheme.glassStroke.opacity(0.6), lineWidth: 1))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        if submitting { return false }
        switch kind {
        case .encouragement:
            return bodyText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 4
        case .bloom:
            return true
        case .mealAnalysis:
            return selectedMealID != nil
        }
    }

    private var submitButton: some View {
        PearlescentButton(action: submit) {
            HStack(spacing: 8) {
                if submitting {
                    ProgressView().tint(.white).controlSize(.small)
                    Text("Steward is reading...")
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Share with the Sanctuary")
                }
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
        }
        .opacity(canSubmit ? 1 : 0.5)
        .disabled(!canSubmit)
    }

    private func submit() {
        guard canSubmit else { return }
        submitting = true

        let name = profile?.name.isEmpty == false ? profile!.name : "Anonymous"
        let initial = String(name.prefix(1)).uppercased()
        let trimmed = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)

        let post: SanctuaryPost
        switch kind {
        case .encouragement:
            post = SanctuaryPost(
                authorName: name,
                authorInitial: initial,
                kind: .encouragement,
                bodyText: trimmed,
                state: .reviewing
            )
        case .bloom:
            post = SanctuaryPost(
                authorName: name,
                authorInitial: initial,
                kind: .bloom,
                bodyText: trimmed,
                hydrationProgress: hydrationProgress,
                macroProgress: macroProgress,
                adherenceProgress: adherenceProgress,
                mood: mood,
                state: .reviewing
            )
        case .mealAnalysis:
            let meal = meals.first(where: { $0.persistentModelID == selectedMealID })
            post = SanctuaryPost(
                authorName: name,
                authorInitial: initial,
                kind: .mealAnalysis,
                bodyText: trimmed,
                mealTitle: meal?.title ?? "Meal",
                mealScore: meal?.mealScore ?? 0,
                metabolicImpact: meal?.metabolicImpact ?? "",
                lipidSheen: meal?.lipidSheenDetected ?? false,
                calories: meal?.totalCalories ?? 0,
                protein: meal?.totalProtein ?? 0,
                carbs: meal?.totalCarbs ?? 0,
                fat: meal?.totalFat ?? 0,
                imageData: meal?.imageData,
                state: .reviewing
            )
        }

        modelContext.insert(post)
        try? modelContext.save()

        Task {
            await StewardshipService.shared.submit(post: post, context: modelContext)
            await MainActor.run {
                submitting = false
                dismiss()
            }
        }
    }
}
