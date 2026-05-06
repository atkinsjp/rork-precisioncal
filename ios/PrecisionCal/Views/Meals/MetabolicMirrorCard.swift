import SwiftUI

/// 'Metabolic Mirror' — a Vellum (#FDFBF7) narrative card that synthesizes
/// performanceAnalysis + metabolicImpact in prose instead of a number grid.
/// When a lipid sheen was detected in Pass 3 (or Pass 5), the energy-timing
/// prediction is highlighted to explain the 4-hour sustained release.
struct MetabolicMirrorCard: View {
    let meal: Meal

    private var energyTimingMinutes: Int {
        // Lipid sheen → fats blunt the curve, push the burn out to ~4h.
        if meal.lipidSheenDetected { return 240 }
        // Otherwise, infer from carb/protein ratio.
        let total = max(1, meal.totalCarbs + meal.totalProtein + meal.totalFat)
        let carbShare = meal.totalCarbs / total
        if carbShare > 0.55 { return 90 }
        if carbShare > 0.35 { return 150 }
        return 180
    }

    private var energyTimingLabel: String {
        let m = energyTimingMinutes
        if m >= 240 { return "≈ 4 hours of sustained release" }
        let h = Double(m) / 60.0
        return String(format: "≈ %.1f hours of release", h)
    }

    private var headlineLabel: String {
        meal.metabolicImpact.isEmpty ? "Balanced" : meal.metabolicImpact
    }

    private var performanceNarrative: String {
        let proteinG = Int(meal.totalProtein.rounded())
        let carbG = Int(meal.totalCarbs.rounded())
        let fatG = Int(meal.totalFat.rounded())
        let kcal = Int(meal.totalCalories.rounded())

        var sentences: [String] = []
        sentences.append(
            "This meal lands at roughly \(kcal) calories — \(proteinG) g of protein for repair, \(carbG) g of carbohydrate for fuel, and \(fatG) g of fat to slow absorption."
        )
        if meal.totalProtein >= 25 {
            sentences.append("Protein is generous enough to anchor recovery and keep satiety high.")
        } else if meal.totalProtein < 12 {
            sentences.append("Protein is on the lighter side — a small follow-up snack with a protein source would round it out.")
        }
        if meal.totalFiber >= 6 {
            sentences.append("Fiber is comfortable, which softens the glycemic curve and supports gut microbiota.")
        } else if meal.totalSugar >= 20 {
            sentences.append("Free sugars are elevated; pair the next meal with leafy greens to compensate.")
        }
        return sentences.joined(separator: " ")
    }

    private var metabolicNarrative: String {
        let label = headlineLabel.lowercased()
        return "On the metabolic mirror, this reads as a \(label) profile. Insulin rises gently, energy is metered out rather than dumped, and your body is given a calm runway to absorb what matters."
    }

    private var energyNarrative: String {
        if meal.lipidSheenDetected {
            let inferred = meal.lipidNote.isEmpty
                ? "The added culinary fats — likely oil or butter — coat the carbohydrates, slowing gastric emptying."
                : meal.lipidNote
            return "\(inferred) Expect a sustained energy release for the next 4 hours, with no sharp crash on the back end."
        } else {
            return "With minimal added fat detected, expect energy availability over \(energyTimingLabel), then a soft taper rather than a crash."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("METABOLIC MIRROR")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Spacer()
                MealScoreBadge(score: meal.mealScore)
            }
            .padding(.bottom, 14)

            Text(headlineLabel)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
                .padding(.bottom, 4)

            Text(meal.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PrecisionCalTheme.textTertiary)
                .padding(.bottom, 18)

            // Narrative paragraphs
            VStack(alignment: .leading, spacing: 14) {
                paragraph(performanceNarrative)
                paragraph(metabolicNarrative)
                energyTimingBlock
            }

            if meal.lipidSheenDetected {
                signature
                    .padding(.top, 18)
            }
        }
        .padding(22)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 253/255, green: 251/255, blue: 247/255)) // Vellum #FDFBF7
                .overlay {
                    // subtle parchment grain
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.0), PrecisionCalTheme.terracotta.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PrecisionCalTheme.terracotta.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: PrecisionCalTheme.terracotta.opacity(0.10), radius: 22, x: 0, y: 10)
        }
    }

    private func paragraph(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 15, weight: .regular, design: .serif))
            .foregroundStyle(PrecisionCalTheme.textPrimary.opacity(0.92))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var energyTimingBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: meal.lipidSheenDetected ? "drop.fill" : "clock")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(meal.lipidSheenDetected ? PrecisionCalTheme.fatColor : PrecisionCalTheme.terracotta)
                .frame(width: 28, height: 28)
                .background {
                    Circle().fill(PrecisionCalTheme.terracotta.opacity(0.10))
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(meal.lipidSheenDetected ? "Energy Timing — Lipid Sheen Detected" : "Energy Timing")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                    if meal.lipidSheenDetected {
                        Text("4H")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PrecisionCalTheme.fatColor, in: Capsule())
                    }
                }
                Text(energyNarrative)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(meal.lipidSheenDetected
                      ? PrecisionCalTheme.fatColor.opacity(0.08)
                      : PrecisionCalTheme.terracotta.opacity(0.06))
        }
    }

    private var signature: some View {
        HStack {
            Spacer()
            Text("— Pass 3 lipid signature confirmed")
                .font(.system(size: 12, weight: .regular, design: .serif).italic())
                .foregroundStyle(PrecisionCalTheme.textTertiary)
        }
    }
}

/// Soft Milk ripple — full-screen white expanding circle used as a one-shot
/// reveal transition when the 5-pass analysis completes.
struct SoftMilkRipple: View {
    @State private var progress: CGFloat = 0
    var onFinished: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let maxR = sqrt(geo.size.width * geo.size.width + geo.size.height * geo.size.height) * 0.6
            Canvas { ctx, size in
                let radius = progress * maxR
                let opacity = max(0, (1 - progress)) * 0.55
                let rect = CGRect(
                    x: size.width / 2 - radius,
                    y: size.height / 2 - radius,
                    width: radius * 2, height: radius * 2
                )
                ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
            }
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1)) {
                    progress = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { onFinished() }
            }
        }
        .ignoresSafeArea()
    }
}

