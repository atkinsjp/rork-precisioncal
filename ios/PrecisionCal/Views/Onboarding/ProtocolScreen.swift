import SwiftUI

struct ProtocolScreen: View {
    let profileSummary: String
    @Binding var healthProtocol: String
    let onBegin: () -> Void

    @State private var isLoading = true
    @State private var error: String?
    @State private var revealedChars: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("YOUR PROTOCOL")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("Dr. PrecisionCal's note")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text("A personalized 300-word plan, written just now from your answers.")
                    .font(.system(size: 16))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)
            .padding(.bottom, 16)

            ScrollView(showsIndicators: false) {
                parchmentCard
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }

            PearlescentButton(action: onBegin) {
                HStack(spacing: 10) {
                    Text(isLoading ? "Synthesizing…" : "Begin my journey")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    if !isLoading {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .opacity(isLoading ? 0.55 : 1)
            .disabled(isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .task {
            await synthesize()
        }
    }

    private var parchmentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("A note for you")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
            }

            Divider().background(PrecisionCalTheme.glassStroke)

            ZStack(alignment: .topLeading) {
                if isLoading {
                    HStack(spacing: 16) {
                        BreathingOrb(size: 60)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Reading your profile…")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PrecisionCalTheme.textPrimary)
                            Text("Cross-referencing nutrition science.")
                                .font(.system(size: 13))
                                .foregroundStyle(PrecisionCalTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 24)
                } else if let error {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                        Button {
                            Task { await synthesize() }
                        } label: {
                            Text("Try again")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(PrecisionCalTheme.terracotta)
                        }
                    }
                    .padding(.vertical, 16)
                } else {
                    Text(displayedText)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !isLoading && error == nil {
                HStack {
                    Spacer()
                    Text("— Dr. PrecisionCal")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(PrecisionCalTheme.terracottaDeep)
                        .padding(.top, 6)
                }
            }
        }
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(PrecisionCalTheme.parchment)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.35)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1)
                }
                .shadow(color: PrecisionCalTheme.terracotta.opacity(0.10), radius: 24, x: 0, y: 14)
        }
    }

    private var displayedText: String {
        let chars = healthProtocol.prefix(revealedChars)
        return String(chars)
    }

    private func synthesize() async {
        isLoading = true
        error = nil
        do {
            let text = try await AIService.shared.generateHealthProtocol(profileSummary: profileSummary)
            await MainActor.run {
                healthProtocol = text
                isLoading = false
                animateReveal()
            }
        } catch {
            await MainActor.run {
                self.error = "Couldn't synthesize your protocol just yet. Please check your connection and try again."
                isLoading = false
            }
        }
    }

    private func animateReveal() {
        revealedChars = 0
        let total = healthProtocol.count
        guard total > 0 else { return }
        let step = max(1, total / 180)
        Task { @MainActor in
            while revealedChars < total {
                try? await Task.sleep(nanoseconds: 18_000_000)
                revealedChars = min(total, revealedChars + step)
            }
        }
    }
}
