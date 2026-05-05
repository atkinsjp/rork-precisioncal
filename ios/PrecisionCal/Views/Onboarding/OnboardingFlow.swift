import SwiftUI
import SwiftData

struct OnboardingFlow: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false

    @State private var step: Int = 0

    // Calibration
    @State private var ageYears: Int = 28
    @State private var weightKg: Double = 70
    @State private var goal: String = "Maintain"
    @State private var dailyWaterTargetMl: Int = 2400

    // Dynamic profile
    @State private var goalsTags: [String] = []
    @State private var activityLevel: String = ""
    @State private var medicalHistory: [String] = []
    @State private var specificConditions: [String] = []
    @State private var allergies: [String] = []
    @State private var medications: [String] = []

    // Synthesis
    @State private var healthProtocol: String = ""

    private enum Stage {
        case vision, calibration, hydration, goals, activity, medical, conditions, allergies, medication, synthesis
    }

    private var hasMedicalConditions: Bool {
        medicalHistory.contains("Medical conditions")
    }

    private var stages: [Stage] {
        var s: [Stage] = [.vision, .calibration, .hydration, .goals, .activity, .medical]
        if hasMedicalConditions { s.append(.conditions) }
        s.append(contentsOf: [.allergies, .medication, .synthesis])
        return s
    }

    private var currentStage: Stage {
        let idx = min(max(0, step), stages.count - 1)
        return stages[idx]
    }

    var body: some View {
        ZStack {
            screen(for: currentStage)
                .id("\(currentStage)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.04)),
                    removal: .opacity.combined(with: .scale(scale: 0.96))
                ))
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.86), value: step)
    }

    @ViewBuilder
    private func screen(for stage: Stage) -> some View {
        switch stage {
        case .vision:
            VisionScreen(onContinue: { advance() })
        case .calibration:
            CalibrationScreen(
                ageYears: $ageYears,
                weightKg: $weightKg,
                goal: $goal,
                onContinue: { advance() }
            )
        case .hydration:
            HydrationScreen(onComplete: { ml in
                dailyWaterTargetMl = ml
                advance()
            })
        case .goals:
            GoalsScreen(selected: $goalsTags, onContinue: { advance() }, onBack: { back() })
        case .activity:
            ActivityScreen(level: $activityLevel, onContinue: { advance() }, onBack: { back() })
        case .medical:
            MedicalHistoryScreen(selected: $medicalHistory, onContinue: { advance() }, onBack: { back() })
        case .conditions:
            ConditionsScreen(selected: $specificConditions, onContinue: { advance() }, onBack: { back() })
        case .allergies:
            AllergiesScreen(selected: $allergies, onContinue: { advance() }, onBack: { back() })
        case .medication:
            MedicationScreen(selected: $medications, onContinue: { advance() }, onBack: { back() })
        case .synthesis:
            ProtocolScreen(
                profileSummary: profileSummary,
                healthProtocol: $healthProtocol,
                onBegin: { complete() }
            )
        }
    }

    private func advance() { step += 1 }
    private func back() { step = max(0, step - 1) }

    private var profileSummary: String {
        let goalsLine = goalsTags.isEmpty ? "(no specific goals)" : goalsTags.joined(separator: ", ")
        let medical = medicalHistory.isEmpty ? "none reported" : medicalHistory.joined(separator: ", ")
        let conditions = specificConditions.isEmpty ? "none" : specificConditions.joined(separator: ", ")
        let allergiesLine = allergies.isEmpty ? "none" : allergies.joined(separator: ", ")
        let meds = medications.isEmpty ? "none" : medications.joined(separator: ", ")
        return """
        Age: \(ageYears)
        Weight: \(Int(weightKg)) kg
        Primary goal: \(goal)
        Daily water target: \(dailyWaterTargetMl) ml
        Personal goals: \(goalsLine)
        Activity level: \(activityLevel.isEmpty ? "Moderate" : activityLevel)
        Medical history: \(medical)
        Specific conditions: \(conditions)
        Allergies: \(allergiesLine)
        Medications: \(meds)
        """
    }

    private func complete() {
        let target = calorieTarget()
        let profile = UserProfile(
            ageYears: ageYears,
            weightKg: weightKg,
            goal: goal,
            dailyCalorieTarget: target,
            dailyProteinTarget: Int(weightKg * 1.8),
            dailyCarbTarget: Int(Double(target) * 0.45 / 4),
            dailyFatTarget: Int(Double(target) * 0.30 / 9),
            dailyWaterTargetMl: dailyWaterTargetMl,
            goalsTags: goalsTags,
            medicalHistory: medicalHistory,
            specificConditions: specificConditions,
            allergies: allergies,
            medications: medications,
            activityLevel: activityLevel.isEmpty ? "Moderate" : activityLevel,
            healthProtocol: healthProtocol
        )
        modelContext.insert(profile)
        try? modelContext.save()
        withAnimation { hasOnboarded = true }
    }

    private func calorieTarget() -> Int {
        let base = 10 * weightKg + 6.25 * 170 - 5 * Double(ageYears) + 5
        let multiplier: Double
        switch activityLevel {
        case "Sedentary": multiplier = 1.25
        case "Light": multiplier = 1.375
        case "Active": multiplier = 1.55
        case "Very active": multiplier = 1.725
        default: multiplier = 1.45
        }
        let activity = base * multiplier
        switch goal {
        case "Lose": return Int(activity - 400)
        case "Gain": return Int(activity + 350)
        default: return Int(activity)
        }
    }
}
