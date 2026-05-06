import SwiftUI
import SwiftData

struct ManualMealEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var fiber: String = ""
    @State private var sugar: String = ""
    @State private var waterMl: String = ""
    @State private var loggedAt: Date = Date()
    @State private var showValidation: Bool = false

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
                        field(label: "Calories (kcal)", placeholder: "e.g. 520", text: $calories, required: true, keyboard: .decimalPad)
                    }

                    section(title: "Optional macros") {
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
                            Text("Save meal")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    }
                    .opacity(canSave ? 1 : 0.5)
                    .disabled(!canSave)
                    .padding(.top, 4)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(MeshBackground().ignoresSafeArea())
            .navigationTitle("Manual entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOG WITHOUT A PHOTO")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.terracotta)
            Text("Add a meal you ate earlier")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("Only meal description and calories are required. Add macros if you have them — your trends get sharper the more you fill in.")
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

    private func save() {
        guard canSave, let cal = caloriesValue else {
            showValidation = true
            return
        }
        let p = Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0
        let c = Double(carbs.replacingOccurrences(of: ",", with: ".")) ?? 0
        let f = Double(fat.replacingOccurrences(of: ",", with: ".")) ?? 0
        let fb = Double(fiber.replacingOccurrences(of: ",", with: ".")) ?? 0
        let sg = Double(sugar.replacingOccurrences(of: ",", with: ".")) ?? 0
        let w = Double(waterMl.replacingOccurrences(of: ",", with: ".")) ?? 0

        let meal = Meal(
            createdAt: loggedAt,
            title: trimmedTitle,
            imageData: nil,
            status: "complete",
            totalCalories: cal,
            totalProtein: p,
            totalCarbs: c,
            totalFat: f,
            totalFiber: fb,
            totalSugar: sg,
            waterContentMl: w,
            mealScore: 0,
            metabolicImpact: "Manually logged",
            qcNotes: "Entered manually by user"
        )

        let item = MealItem(
            name: trimmedTitle,
            preparation: "Manual entry",
            grams: 0,
            calories: cal,
            protein: p,
            carbs: c,
            fat: f,
            fiber: fb,
            sugar: sg,
            waterMl: w
        )
        item.meal = meal
        meal.items.append(item)

        modelContext.insert(meal)
        try? modelContext.save()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
