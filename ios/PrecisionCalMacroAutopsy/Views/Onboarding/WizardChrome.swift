import SwiftUI

/// Shared chrome for the step-by-step onboarding wizard.
struct WizardScreen<Content: View>: View {
    let title: String
    let subtitle: String
    let eyebrow: String
    var canContinue: Bool = true
    var primaryLabel: String = "Continue"
    let onContinue: () -> Void
    var onBack: (() -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let onBack {
                    Button {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(PrecisionCalMacroAutopsyTheme.glassStroke, lineWidth: 1))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.terracotta)
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 22)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    content()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            PearlescentButton(action: onContinue) {
                Text(primaryLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .opacity(canContinue ? 1 : 0.55)
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
    }
}

/// A natural-language toggle pill used across wizard steps.
struct ChoiceCard: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
            action()
        } label: {
            HStack(spacing: 14) {
                if let icon {
                    ZStack {
                        Circle()
                            .fill(isSelected ? PrecisionCalMacroAutopsyTheme.terracotta.opacity(0.18) : Color.white.opacity(0.55))
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isSelected ? PrecisionCalMacroAutopsyTheme.terracotta : PrecisionCalMacroAutopsyTheme.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PrecisionCalMacroAutopsyTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(PrecisionCalMacroAutopsyTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                ZStack {
                    Circle()
                        .stroke(isSelected ? PrecisionCalMacroAutopsyTheme.terracotta : PrecisionCalMacroAutopsyTheme.glassStroke, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(PrecisionCalMacroAutopsyTheme.terracotta)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSelected ? PrecisionCalMacroAutopsyTheme.terracotta.opacity(0.06) : PrecisionCalMacroAutopsyTheme.cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? PrecisionCalMacroAutopsyTheme.terracotta.opacity(0.55) : PrecisionCalMacroAutopsyTheme.glassStroke, lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
