import SwiftUI

struct CalibrationScreen: View {
    @Binding var ageYears: Int
    @Binding var weightKg: Double
    @Binding var goal: String
    let onContinue: () -> Void

    private let goals = ["Lose", "Maintain", "Gain"]
    @State private var weightUnit: WeightUnit = .lb

    enum WeightUnit: String, CaseIterable, Identifiable {
        case kg, lb
        var id: String { rawValue }
        var label: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CALIBRATION")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("Tune your targets")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text("No typing. Just turn.")
                    .font(.system(size: 16))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    OneThumbDial(
                        title: "Age",
                        unit: "yrs",
                        value: Binding(
                            get: { Double(ageYears) },
                            set: { ageYears = Int($0) }
                        ),
                        range: 16...80,
                        step: 1
                    )

                    OneThumbDial(
                        title: "Weight",
                        unit: weightUnit.label,
                        value: Binding(
                            get: {
                                weightUnit == .kg ? weightKg : weightKg * 2.20462
                            },
                            set: { newValue in
                                weightKg = weightUnit == .kg ? newValue : newValue / 2.20462
                            }
                        ),
                        range: weightUnit == .kg ? 35...200 : 77...440,
                        step: weightUnit == .kg ? 0.5 : 1,
                        accessory: AnyView(
                            UnitToggle(unit: $weightUnit)
                        )
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Goal")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(2)
                                .foregroundStyle(PrecisionCalTheme.textSecondary)
                            HStack(spacing: 10) {
                                ForEach(goals, id: \.self) { g in
                                    GoalChip(label: g, isSelected: goal == g) {
                                        let gen = UISelectionFeedbackGenerator()
                                        gen.selectionChanged()
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                            goal = g
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                    }
                }
                .padding(.horizontal, 20)
            }

            PearlescentButton(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

struct GoalChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? .white : PrecisionCalTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? PrecisionCalTheme.terracotta : Color.white.opacity(0.55))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.clear : PrecisionCalTheme.glassStroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct UnitToggle: View {
    @Binding var unit: CalibrationScreen.WeightUnit

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalibrationScreen.WeightUnit.allCases) { u in
                Button {
                    let gen = UISelectionFeedbackGenerator()
                    gen.selectionChanged()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        unit = u
                    }
                } label: {
                    Text(u.rawValue.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(unit == u ? .white : PrecisionCalTheme.textSecondary)
                        .frame(width: 30, height: 22)
                        .background {
                            if unit == u {
                                Capsule().fill(PrecisionCalTheme.terracotta)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background {
            Capsule().fill(Color.white.opacity(0.55))
        }
        .overlay {
            Capsule().stroke(PrecisionCalTheme.glassStroke, lineWidth: 1)
        }
    }
}
