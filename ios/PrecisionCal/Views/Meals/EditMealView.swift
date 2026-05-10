import SwiftUI
import SwiftData

struct EditMealView: View {
    @Bindable var meal: Meal
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var loggedAt: Date
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String
    @State private var sugar: String
    @State private var waterMl: String
    @State private var showDeleteConfirm: Bool = false

    init(meal: Meal) {
        self.meal = meal
        _title = State(initialValue: meal.title)
        _loggedAt = State(initialValue: meal.createdAt)
        _calories = State(initialValue: Self.format(meal.totalCalories))
        _protein = State(initialValue: Self.format(meal.totalProtein))
        _carbs = State(initialValue: Self.format(meal.totalCarbs))
        _fat = State(initialValue: Self.format(meal.totalFat))
        _fiber = State(initialValue: Self.format(meal.totalFiber))
        _sugar = State(initialValue: Self.format(meal.totalSugar))
        _waterMl = State(initialValue: Self.format(meal.waterContentMl))
    }

    private static func format(_ v: Double) -> String {
        if v == 0 { return "" }
        if v.rounded() == v { return String(Int(v)) }
        return String(format: "%.1f", v)
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var caloriesValue: Double? { Double(calories.replacingOccurrences(of: ",", with: ".")) }
    private var canSave: Bool {
        !trimmedTitle.isEmpty && (caloriesValue ?? -1) >= 0 && caloriesValue != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro

                    section(title: "Required") {
                        field(label: "Meal description", placeholder: "e.g. Chicken & rice bowl", text: $title, required: true, keyboard: .default)
                        field(label: "Calories (kcal)", placeholder: "0", text: $calories, required: true, keyboard: .decimalPad)
                    }

                    section(title: "Macros") {
                        field(label: "Protein (g)", placeholder: "0", text: $protein, required: false, keyboard: .decimalPad)
                        field(label: "Carbs (g)", placeholder: "0", text: $carbs, required: false, keyboard: .decimalPad)
                        field(label: "Fat (g)", placeholder: "0", text: $fat, required: false, keyboard: .decimalPad)
                        field(label: "Fiber (g)", placeholder: "0", text: $fiber, required: false, keyboard: .decimalPad)
                        field(label: "Sugar (g)", placeholder: "0", text: $sugar, required: false, keyboard: .decimalPad)
                        field(label: "Water (ml)", placeholder: "0", text: $waterMl, required: false, keyboard: .decimalPad)
                    }

                    section(title: "When") {
                        GlassCard {
                            DatePicker("Logged at", selection: $loggedAt, in: ...Date())
                                .datePickerStyle(.compact)
                                .tint(PrecisionCalTheme.terracotta)
                                .foregroundStyle(PrecisionCalTheme.textPrimary)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 14)
                        }
                    }

                    PearlescentButton(action: save) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Save changes")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    }
                    .opacity(canSave ? 1 : 0.5)
                    .disabled(!canSave)
                    .padding(.top, 4)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Delete meal")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(PrecisionCalTheme.fatColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(PrecisionCalTheme.fatColor.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(MeshBackground().ignoresSafeArea())
            .navigationTitle("Edit meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
            }
            .confirmationDialog(
                "Delete this meal?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { performDelete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently remove the meal from your log.")
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EDIT MEAL")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.terracotta)
            Text("Adjust details")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("Correct anything that was logged wrong — manually or by AI scan. Totals you save here drive your daily numbers.")
                .font(.system(size: 13))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineSpacing(2)
        }
        .padding(.horizontal, 4)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        let inner = content()
        return VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
                .padding(.horizontal, 4)
            GlassCard {
                VStack(spacing: 14) {
                    inner
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
            }
        }
    }

    private func field(label: String, placeholder: String, text: Binding<String>, required: Bool, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                if required {
                    Text("*")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                }
            }
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.55))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PrecisionCalTheme.terracotta.opacity(0.18), lineWidth: 1)
                )
        }
    }

    private func parse(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func save() {
        guard canSave, let cal = caloriesValue else { return }
        meal.title = trimmedTitle
        meal.createdAt = loggedAt
        meal.totalCalories = cal
        meal.totalProtein = parse(protein)
        meal.totalCarbs = parse(carbs)
        meal.totalFat = parse(fat)
        meal.totalFiber = parse(fiber)
        meal.totalSugar = parse(sugar)
        meal.waterContentMl = parse(waterMl)
        if meal.status != "complete" { meal.status = "complete" }

        // Keep items in sync when there's a single item (manual entries),
        // so subsequent edits stay coherent. For multi-item AI scans we
        // leave per-item details alone — the meal totals are what drive
        // daily numbers.
        if meal.items.count == 1, let only = meal.items.first {
            only.name = trimmedTitle
            only.calories = cal
            only.protein = parse(protein)
            only.carbs = parse(carbs)
            only.fat = parse(fat)
            only.fiber = parse(fiber)
            only.sugar = parse(sugar)
            only.waterMl = parse(waterMl)
        }

        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func performDelete() {
        modelContext.delete(meal)
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        dismiss()
    }
}
