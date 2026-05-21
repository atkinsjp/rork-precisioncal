import SwiftUI

struct MedicalHistoryScreen: View {
    @Binding var selected: [String]
    let onContinue: () -> Void
    let onBack: () -> Void

    private let options: [(String, String, String)] = [
        ("Nothing notable", "I'm generally healthy", "checkmark.seal"),
        ("Medical conditions", "I'd like to share a few specifics", "stethoscope"),
        ("Family history of disease", "Genetics I want to be mindful of", "person.2.crop.square.stack"),
        ("Recent surgery or recovery", "Healing or rehab in progress", "bandage"),
        ("Pregnancy or postpartum", "Nutrition for two", "heart")
    ]

    var body: some View {
        WizardScreen(
            title: "Anything we should know?",
            subtitle: "This stays private. It helps Cal tailor safer educational guidance.",
            eyebrow: "Medical history",
            canContinue: !selected.isEmpty,
            onContinue: onContinue,
            onBack: onBack
        ) {
            ForEach(options, id: \.0) { opt in
                ChoiceCard(
                    title: opt.0,
                    subtitle: opt.1,
                    icon: opt.2,
                    isSelected: selected.contains(opt.0)
                ) { toggle(opt.0) }
            }
        }
    }

    private func toggle(_ s: String) {
        if s == "Nothing notable" {
            selected = selected.contains(s) ? [] : [s]
            return
        }
        // Selecting any other clears "Nothing notable"
        selected.removeAll { $0 == "Nothing notable" }
        if let i = selected.firstIndex(of: s) {
            selected.remove(at: i)
        } else {
            selected.append(s)
        }
    }
}

struct ConditionsScreen: View {
    @Binding var selected: [String]
    let onContinue: () -> Void
    let onBack: () -> Void

    private let options: [(String, String, String)] = [
        ("Type 2 Diabetes", "Carbohydrate awareness", "drop.degreesign"),
        ("Pre-diabetes / Insulin resistance", "Glucose stability", "waveform.path"),
        ("Hypertension", "Sodium and potassium balance", "heart.text.square"),
        ("High cholesterol", "Saturated fats and fiber", "chart.line.uptrend.xyaxis"),
        ("PCOS", "Insulin and inflammation", "circle.grid.cross"),
        ("Hypothyroidism", "Iodine, selenium, energy", "thermometer.medium"),
        ("IBS / Gut sensitivity", "Low-FODMAP and gentle fiber", "leaf.circle"),
        ("Anxiety / Sleep issues", "Magnesium and rituals", "moon.zzz")
    ]

    var body: some View {
        WizardScreen(
            title: "Which conditions apply?",
            subtitle: "Select all that apply. Skip anything that doesn't.",
            eyebrow: "Specific conditions",
            canContinue: true,
            primaryLabel: selected.isEmpty ? "Skip" : "Continue",
            onContinue: onContinue,
            onBack: onBack
        ) {
            ForEach(options, id: \.0) { opt in
                ChoiceCard(
                    title: opt.0,
                    subtitle: opt.1,
                    icon: opt.2,
                    isSelected: selected.contains(opt.0)
                ) { toggle(opt.0) }
            }
        }
    }

    private func toggle(_ s: String) {
        if let i = selected.firstIndex(of: s) {
            selected.remove(at: i)
        } else {
            selected.append(s)
        }
    }
}
