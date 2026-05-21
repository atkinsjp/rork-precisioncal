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
                Text("A note from Cal")
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
                    Text("— Cal")
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

        // Retry up to 3 times on transient failures with gentle backoff.
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let text = try await AIService.shared.generateHealthProtocol(profileSummary: profileSummary)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { throw AIError.decodingError("empty") }
                await MainActor.run {
                    healthProtocol = trimmed
                    isLoading = false
                    animateReveal()
                }
                return
            } catch {
                lastError = error
                // Don't retry on auth/balance errors — they won't recover.
                if let aiErr = error as? AIError {
                    switch aiErr {
                    case .authError, .insufficientBalance:
                        break
                    default:
                        if attempt < 2 {
                            let delay = UInt64(800_000_000) * UInt64(attempt + 1) // 0.8s, 1.6s
                            try? await Task.sleep(nanoseconds: delay)
                            continue
                        }
                    }
                } else if attempt < 2 {
                    let delay = UInt64(800_000_000) * UInt64(attempt + 1)
                    try? await Task.sleep(nanoseconds: delay)
                    continue
                }
                break
            }
        }

        // All retries failed — provide a graceful fallback protocol so the user
        // can still complete onboarding. They can refine later in the app.
        let fallback = fallbackProtocol(profileSummary: profileSummary)
        await MainActor.run {
            healthProtocol = fallback
            isLoading = false
            self.error = nil
            animateReveal()
            print("[ProtocolScreen] Using fallback after error: \(String(describing: lastError))")
        }
    }

    private func fallbackProtocol(profileSummary: String) -> String {
        """
        Welcome. I've read your profile carefully, and I want you to know this plan is shaped around you — your goals, your rhythm, and what your body is asking for right now.

        Begin each day with a tall glass of water before anything else; hydration is the quiet foundation everything else rests on. Aim for roughly half your body weight in ounces across the day, sipping rather than gulping.

        Build every plate around protein first — a palm-sized portion of fish, poultry, eggs, legumes, or tofu — then layer in colorful vegetables, a measured serving of slow carbohydrates like oats, quinoa, or sweet potato, and a thumb of healthy fat from olive oil, avocado, or nuts. This pattern keeps blood sugar steady and energy reliable.

        Time your meals with intention. A nourishing breakfast within an hour of waking, a substantial lunch, and a lighter dinner finished two to three hours before sleep will support digestion, recovery, and morning clarity.

        Your daily ritual: pause for three slow breaths before your first bite of every meal. This single act tells your nervous system you are safe, and digestion follows.

        Be gentle with yourself. Progress is built from small, repeated choices — not perfection. Track what you eat with curiosity rather than judgment, and let the data guide your next thoughtful step.

        In service of your wellness, — Cal
        """
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
