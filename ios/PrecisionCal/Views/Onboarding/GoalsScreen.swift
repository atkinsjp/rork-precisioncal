import SwiftUI

struct GoalsScreen: View {
    @Binding var selected: [String]
    let onContinue: () -> Void
    let onBack: () -> Void

    private let options: [(String, String, String)] = [
        ("I struggle with sugar cravings", "Even out energy and reduce spikes", "drop.degreesign"),
        ("I want to gain muscle", "Hit protein targets and recovery", "figure.strengthtraining.traditional"),
        ("I want to lose weight gently", "Sustainable, kind to the body", "leaf"),
        ("I want more steady energy", "Less afternoon crash", "sun.max"),
        ("I'm rebuilding gut health", "Fiber, fermented foods, water", "circle.hexagongrid"),
        ("I want to sleep better", "Magnesium, timing, evening rituals", "moon.stars")
    ]

    var body: some View {
        WizardScreen(
            title: "What brings you here?",
            subtitle: "Pick one or more — speak as you would to a friend.",
            eyebrow: "Your intention",
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
        if let i = selected.firstIndex(of: s) {
            selected.remove(at: i)
        } else {
            selected.append(s)
        }
    }
}
