import SwiftUI

struct AllergiesScreen: View {
    @Binding var selected: [String]
    let onContinue: () -> Void
    let onBack: () -> Void

    private let options: [(String, String, String)] = [
        ("None", "No food allergies", "checkmark.seal"),
        ("Dairy", "Lactose / casein", "cup.and.saucer"),
        ("Gluten", "Wheat, barley, rye", "leaf.arrow.circlepath"),
        ("Peanuts / Tree nuts", "Common cross-contamination", "circle.grid.2x2"),
        ("Shellfish", "Shrimp, crab, lobster", "fish"),
        ("Eggs", "Whole egg or whites", "oval"),
        ("Soy", "Tofu, tempeh, edamame", "leaf"),
        ("Other", "I'll note it later", "ellipsis.circle")
    ]

    var body: some View {
        WizardScreen(
            title: "Any allergies?",
            subtitle: "We'll keep these in mind for every meal recommendation.",
            eyebrow: "Allergies",
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
        if s == "None" {
            selected = selected.contains(s) ? [] : [s]
            return
        }
        selected.removeAll { $0 == "None" }
        if let i = selected.firstIndex(of: s) {
            selected.remove(at: i)
        } else {
            selected.append(s)
        }
    }
}
