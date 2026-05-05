import SwiftUI

/// Swipe-up "PhD Breakdown" drawer revealed from beneath the VitalityBloom.
/// Surfaces metabolic impact, nutrient density, and upcoming hazards.
struct DeepDiveDrawer: View {
    let metabolicImpact: String
    let nutrientDensity: Int        // 0…100
    let hazards: [HazardWarning]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            handle
            sectionHeader("METABOLIC IMPACT", icon: "waveform.path.ecg")
            metabolicCard
            sectionHeader("NUTRIENT DENSITY", icon: "leaf.fill")
            densityCard
            sectionHeader("UPCOMING HAZARDS", icon: "exclamationmark.triangle.fill")
            if hazards.isEmpty {
                clearCard
            } else {
                ForEach(hazards) { h in
                    HazardRow(hazard: h)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private var handle: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(PrecisionCalTheme.textTertiary.opacity(0.5))
                .frame(width: 44, height: 5)
            Spacer()
        }
    }

    private func sectionHeader(_ label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.terracotta)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textSecondary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var metabolicCard: some View {
        GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PrecisionCalTheme.sage.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "flame.fill")
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(metabolicImpact.isEmpty ? "Awaiting today's first meal" : metabolicImpact)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    Text("From your most recent 4-pass analysis.")
                        .font(.system(size: 12))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                Spacer()
            }
            .padding(14)
        }
    }

    private var densityCard: some View {
        GlassCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(PrecisionCalTheme.glassStroke.opacity(0.5), lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(nutrientDensity) / 100)
                        .stroke(
                            LinearGradient(colors: [PrecisionCalTheme.sage, PrecisionCalTheme.terracotta],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 56, height: 56)
                    Text("\(nutrientDensity)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Density score")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                    Text("Average meal score across today's logs.")
                        .font(.system(size: 12))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                Spacer()
            }
            .padding(14)
        }
    }

    private var clearCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(PrecisionCalTheme.sage)
                Text("All clear — no conflicts in your scan history.")
                    .font(.system(size: 14))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                Spacer()
            }
            .padding(14)
        }
    }
}

struct HazardWarning: Identifiable {
    let id = UUID()
    let productName: String
    let reason: String
    /// "allergy" | "goal" | "additive"
    let kind: String
}

private struct HazardRow: View {
    let hazard: HazardWarning

    private var color: Color {
        switch hazard.kind {
        case "allergy": return PrecisionCalTheme.terracotta
        case "additive": return PrecisionCalTheme.fatColor
        default: return PrecisionCalTheme.terracottaDeep
        }
    }

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: hazard.kind == "allergy"
                          ? "allergens"
                          : "exclamationmark.triangle.fill")
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(hazard.productName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineLimit(1)
                    Text(hazard.reason)
                        .font(.system(size: 12))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(14)
        }
    }
}
