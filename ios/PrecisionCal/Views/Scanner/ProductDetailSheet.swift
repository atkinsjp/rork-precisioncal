import SwiftUI

struct ProductDetailSheet: View {
    let product: ScannedProduct
    let profile: UserProfile?

    @Environment(\.dismiss) private var dismiss

    private var allergyHits: [String] {
        guard let profile, !profile.allergies.isEmpty else { return [] }
        let flags = product.allergyFlags
            .lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let userAllergies = profile.allergies.map { $0.lowercased() }
        return flags.filter { flag in
            userAllergies.contains { $0.contains(flag) || flag.contains($0) }
        }
    }

    private var matchesGoals: Bool {
        guard let profile, !profile.goalsTags.isEmpty else { return false }
        let g = profile.goalsTags.map { $0.lowercased() }.joined(separator: " ")
        // Crude heuristic: high protein + low sugar + low risk = aligns with most goals
        let proteinDense = product.protein >= 12 && product.calories > 0 && product.protein / max(product.calories, 1) > 0.05
        let lowSugar = product.sugar < 8
        let cleanish = product.riskLevel == "low"
        if g.contains("muscle") || g.contains("protein") { return proteinDense && cleanish }
        if g.contains("sugar") || g.contains("diabet") { return lowSugar && cleanish }
        if g.contains("clean") || g.contains("whole") { return cleanish }
        return proteinDense && lowSugar && cleanish
    }

    private var hasAllergyConflict: Bool { !allergyHits.isEmpty }

    var body: some View {
        ZStack {
            MeshBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard
                    if hasAllergyConflict { allergyCard }
                    if matchesGoals { recommendationBadge }
                    nutritionCard
                    additiveRiskCard
                    if !product.clinicalNote.isEmpty { clinicalCard }
                    if !product.ingredients.isEmpty { ingredientsCard }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
            }
            .padding(.top, 14)
            .padding(.trailing, 18)
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    if hasAllergyConflict {
                        Label("ALLERGY ALERT", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(.white)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(PrecisionCalTheme.terracotta, in: .capsule)
                    } else {
                        Text(product.brand.isEmpty ? "PRODUCT" : product.brand.uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                    }
                    Spacer()
                    Text(product.barcode)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                Text(product.name.isEmpty ? "Unknown product" : product.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineLimit(3)
                if !product.servingDescription.isEmpty {
                    Text("Serving: \(product.servingDescription)")
                        .font(.system(size: 13))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            // Header tint when allergy hit
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(PrecisionCalTheme.terracotta.opacity(hasAllergyConflict ? 0.10 : 0))
                .allowsHitTesting(false)
        )
    }

    private var allergyCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .padding(10)
                .background(PrecisionCalTheme.terracotta, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Gentle warning")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                Text("Contains \(allergyHits.joined(separator: ", "))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PrecisionCalTheme.terracotta.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PrecisionCalTheme.terracotta.opacity(0.45), lineWidth: 1)
                )
        }
    }

    private var recommendationBadge: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .padding(10)
                .background(PrecisionCalTheme.sage, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Clinical recommendation")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                Text("Aligns with your goals")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PrecisionCalTheme.sage.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(PrecisionCalTheme.sage.opacity(0.45), lineWidth: 1)
                )
        }
    }

    private var nutritionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("PER SERVING")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                HStack(spacing: 0) {
                    NutritionStat(value: "\(Int(product.calories))", unit: "calories", color: PrecisionCalTheme.textPrimary)
                    Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                    NutritionStat(value: "\(Int(product.protein))g", unit: "protein", color: PrecisionCalTheme.proteinColor)
                    Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                    NutritionStat(value: "\(Int(product.carbs))g", unit: "carbs", color: PrecisionCalTheme.carbColor)
                    Divider().frame(height: 36).background(PrecisionCalTheme.glassStroke)
                    NutritionStat(value: "\(Int(product.fat))g", unit: "fat", color: PrecisionCalTheme.fatColor)
                }
                HStack(spacing: 16) {
                    miniStat(label: "Fiber", value: "\(Int(product.fiber))g")
                    miniStat(label: "Sugar", value: "\(Int(product.sugar))g")
                    miniStat(label: "Sodium", value: "\(Int(product.sodiumMg))mg")
                }
            }
            .padding(20)
        }
    }

    private var additiveRiskCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("ADDITIVE RISK")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                    Spacer()
                    Text(product.riskLevel.capitalized)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(riskColor, in: .capsule)
                }
                Text(product.additiveRisk.isEmpty ? "No additive concerns identified." : product.additiveRisk)
                    .font(.system(size: 14))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var clinicalCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "stethoscope")
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                    Text("PHD REVIEW")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                }
                Text(product.clinicalNote)
                    .font(.system(size: 14))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ingredientsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("INGREDIENTS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
                Text(product.ingredients)
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var riskColor: Color {
        switch product.riskLevel {
        case "high": PrecisionCalTheme.terracotta
        case "moderate": PrecisionCalTheme.fatColor
        default: PrecisionCalTheme.sage
        }
    }
}

