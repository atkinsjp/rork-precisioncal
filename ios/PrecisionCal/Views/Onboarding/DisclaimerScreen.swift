import SwiftUI

/// Mandatory educational-use disclaimer shown before the rest of onboarding.
/// User must check both boxes to advance. Acceptance is persisted via @AppStorage.
struct DisclaimerScreen: View {
    let onAccept: () -> Void

    @AppStorage("disclaimersAccepted") private var disclaimersAccepted: Bool = false
    @AppStorage("disclaimersAcceptedAt") private var acceptedAt: Double = 0

    @State private var educationalChecked: Bool = false
    @State private var medicalChecked: Bool = false
    @State private var appeared: Bool = false

    private var canContinue: Bool { educationalChecked && medicalChecked }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    bodyCopy
                    bullets
                    checks
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }

            PearlescentButton(action: accept) {
                HStack(spacing: 10) {
                    Image(systemName: canContinue ? "checkmark.seal.fill" : "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Accept & Continue")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
            }
            .opacity(canContinue ? 1 : 0.5)
            .disabled(!canContinue)
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("BEFORE YOU BEGIN")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(PrecisionCalTheme.terracotta)
            }
            Text("Educational use only.")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("PrecisionCal is a wellness companion. It is not a doctor, dietitian, or medical device.")
                .font(.system(size: 15))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineSpacing(2)
        }
    }

    private var bodyCopy: some View {
        Text("All nutrition information, AI insights, meal analyses, and chats with Cal (our educational nutrition guide) are intended for general educational and informational purposes only. They are not official nutrition advice and are not a substitute for professional medical advice, diagnosis, or treatment.")
            .font(.system(size: 14))
            .foregroundStyle(PrecisionCalTheme.textPrimary)
            .lineSpacing(3)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(PrecisionCalTheme.glassStroke.opacity(0.6), lineWidth: 1)
                    )
            }
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 10) {
            disclaimerRow(icon: "stethoscope", text: "Always consult a licensed physician, registered dietitian, or qualified clinician for personal medical or nutrition advice.")
            disclaimerRow(icon: "pills.fill", text: "Never start, stop, or change a medication, supplement, or treatment based on this app.")
            disclaimerRow(icon: "exclamationmark.triangle.fill", text: "If you are pregnant, nursing, have a chronic condition, an eating disorder history, or are taking prescription medication, speak with your provider before changing your diet.")
            disclaimerRow(icon: "phone.fill", text: "In an emergency, call 911 (US) or your local emergency number immediately.")
        }
    }

    private func disclaimerRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.terracotta)
                .frame(width: 22)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var checks: some View {
        VStack(spacing: 10) {
            checkRow(
                isOn: $educationalChecked,
                text: "I understand PrecisionCal provides educational information only and is not official nutrition, medical, or mental-health advice."
            )
            checkRow(
                isOn: $medicalChecked,
                text: "I agree to consult a licensed healthcare professional before making changes to my diet, supplements, or medications based on this app."
            )
        }
        .padding(.top, 6)
    }

    private func checkRow(isOn: Binding<Bool>, text: String) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isOn.wrappedValue ? PrecisionCalTheme.terracotta : PrecisionCalTheme.glassStroke, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isOn.wrappedValue {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(PrecisionCalTheme.terracotta)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 1)
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isOn.wrappedValue ? PrecisionCalTheme.terracotta.opacity(0.5) : PrecisionCalTheme.glassStroke, lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func accept() {
        guard canContinue else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        disclaimersAccepted = true
        acceptedAt = Date().timeIntervalSince1970
        onAccept()
    }
}
