import SwiftUI

struct MedicationScreen: View {
    @Binding var selected: [String]
    let onContinue: () -> Void
    let onBack: () -> Void

    private let options: [(String, String, String)] = [
        ("None", "No regular medication", "checkmark.seal"),
        ("Blood pressure medication", "ACE inhibitors, beta blockers", "heart.text.square"),
        ("Statins / Cholesterol", "Watch grapefruit interactions", "pills"),
        ("GLP-1 / Ozempic / Wegovy", "Appetite and protein focus", "syringe"),
        ("Metformin", "Vitamin B12 awareness", "capsule"),
        ("Antidepressants", "Mood and appetite shifts", "brain.head.profile"),
        ("Thyroid medication", "Calcium / iron timing", "thermometer.medium"),
        ("Hormonal contraception", "B vitamins and folate", "circle.hexagongrid"),
        ("Other", "I'll add details later", "ellipsis.circle")
    ]

    var body: some View {
        WizardScreen(
            title: "Any medications?",
            subtitle: "Some foods interact with medication. We use this to advise you safely.",
            eyebrow: "Medications",
            canContinue: !selected.isEmpty,
            primaryLabel: "Synthesize my protocol",
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
