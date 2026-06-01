import SwiftUI

struct ActivityScreen: View {
    @Binding var level: String
    let onContinue: () -> Void
    let onBack: () -> Void

    private let options: [(String, String, String)] = [
        ("Sedentary", "Mostly desk-bound, little movement", "laptopcomputer"),
        ("Light", "A few walks or yoga sessions per week", "figure.walk"),
        ("Moderate", "Workouts 3–4 times a week", "figure.run"),
        ("Active", "Daily training or physical job", "flame"),
        ("Very active", "Two-a-days or athlete-level training", "bolt.heart")
    ]

    var body: some View {
        WizardScreen(
            title: "How active is your life?",
            subtitle: "We use this to calibrate your daily energy needs.",
            eyebrow: "Movement",
            canContinue: !level.isEmpty,
            onContinue: onContinue,
            onBack: onBack
        ) {
            ForEach(options, id: \.0) { opt in
                ChoiceCard(
                    title: opt.0,
                    subtitle: opt.1,
                    icon: opt.2,
                    isSelected: level == opt.0
                ) { level = opt.0 }
            }
        }
    }
}
