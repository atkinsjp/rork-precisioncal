import SwiftUI

/// Read-only legal/medical disclaimer surface, presented from Profile.
struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("disclaimersAcceptedAt") private var acceptedAt: Double = 0

    private var acceptedDateText: String {
        guard acceptedAt > 0 else { return "Not yet recorded" }
        let date = Date(timeIntervalSince1970: acceptedAt)
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    section(
                        title: "Educational use only",
                        body: "PrecisionCal is a wellness companion. All nutrition information, AI insights, meal analyses, scanned product reviews, weekly Sunday Calibrations, and chats with Cal (our educational nutrition guide) are intended for general educational and informational purposes only. They are not official nutrition advice and are not a substitute for professional medical advice, diagnosis, or treatment."
                    )

                    section(
                        title: "Not a medical device",
                        body: "PrecisionCal is not a medical device, is not FDA-approved, and is not intended to diagnose, treat, cure, mitigate, or prevent any disease. Calorie and macronutrient estimates are derived from photos and barcodes and may contain errors. Do not rely on these estimates for clinical, surgical, or pharmaceutical decision-making."
                    )

                    section(
                        title: "Always consult a professional",
                        body: "Always seek the advice of your physician, registered dietitian, or other qualified health provider with any questions you may have regarding a medical condition, medication, or nutritional plan. Never disregard professional medical advice or delay seeking it because of something you have read or seen in this app."
                    )

                    section(
                        title: "Special populations",
                        body: "If you are pregnant, nursing, under 18, an older adult, have a chronic condition, a history of disordered eating, kidney or liver disease, diabetes, an allergy, or are taking prescription medication, speak with your healthcare provider before changing your diet, supplements, or activity level based on this app."
                    )

                    section(
                        title: "Community content",
                        body: "Posts in The Sanctuary reflect personal experience from other users. They are not vetted clinical guidance. Use the flag button on any post to report inappropriate content; it will be hidden from the feed and emailed to support@atkins-media.com for review."
                    )

                    section(
                        title: "Emergencies",
                        body: "PrecisionCal cannot help in an emergency. If you or someone you know may be in danger, call 911 (US) or your local emergency number immediately."
                    )

                    sourcesSection

                    Text("You accepted these terms on \(acceptedDateText).")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                        .padding(.top, 8)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("MEDICAL & LEGAL")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(PrecisionCalTheme.terracotta)
            }
            Text("Educational information only.")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("Always consult a licensed healthcare professional.")
                .font(.system(size: 14))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
        }
    }

    // MARK: - Sources & Citations

    private struct Citation: Identifiable {
        let id = UUID()
        let label: String
        let detail: String
        let url: URL?
    }

    private let citations: [Citation] = [
        Citation(
            label: "Mifflin-St Jeor Equation (BMR)",
            detail: "Mifflin MD, St Jeor ST, et al. A new predictive equation for resting energy expenditure in healthy individuals. Am J Clin Nutr. 1990;51(2):241-247. Used to estimate baseline calorie targets.",
            url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")
        ),
        Citation(
            label: "USDA Dietary Guidelines for Americans, 2020–2025",
            detail: "U.S. Department of Agriculture and U.S. Department of Health and Human Services. Used as the basis for general macronutrient and food-group guidance.",
            url: URL(string: "https://www.dietaryguidelines.gov/")
        ),
        Citation(
            label: "Acceptable Macronutrient Distribution Ranges (AMDR)",
            detail: "Institute of Medicine (now National Academies). Dietary Reference Intakes for Energy, Carbohydrate, Fiber, Fat, Fatty Acids, Cholesterol, Protein, and Amino Acids (2005). Used to inform protein, carb, and fat ranges.",
            url: URL(string: "https://nap.nationalacademies.org/catalog/10490/")
        ),
        Citation(
            label: "Water Intake Recommendations",
            detail: "Institute of Medicine. Dietary Reference Intakes for Water, Potassium, Sodium, Chloride, and Sulfate (2005). Used for daily hydration targets.",
            url: URL(string: "https://nap.nationalacademies.org/catalog/10925/")
        ),
        Citation(
            label: "Protein Requirements",
            detail: "WHO/FAO/UNU Expert Consultation. Protein and amino acid requirements in human nutrition (WHO Technical Report Series 935, 2007).",
            url: URL(string: "https://www.who.int/publications/i/item/WHO-TRS-935")
        ),
        Citation(
            label: "USDA FoodData Central",
            detail: "U.S. Department of Agriculture, Agricultural Research Service. Reference database for food composition and nutrient values used to corroborate AI meal estimates.",
            url: URL(string: "https://fdc.nal.usda.gov/")
        ),
        Citation(
            label: "Physical Activity Guidelines for Americans, 2nd ed.",
            detail: "U.S. Department of Health and Human Services (2018). Used for activity-level adjustments to calorie targets.",
            url: URL(string: "https://health.gov/our-work/nutrition-physical-activity/physical-activity-guidelines")
        )
    ]

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text("Sources & References")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
            }
            Text("Nutrition targets, calorie estimates, and educational guidance in PrecisionCal are derived from the following peer-reviewed and governmental sources. Tap any source to view it.")
                .font(.system(size: 13))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(citations) { c in
                    citationRow(c)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke.opacity(0.55), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func citationRow(_ c: Citation) -> some View {
        if let url = c.url {
            Link(destination: url) {
                citationContent(c)
            }
            .buttonStyle(.plain)
        } else {
            citationContent(c)
        }
    }

    private func citationContent(_ c: Citation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(c.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                if c.url != nil {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                }
            }
            Text(c.detail)
                .font(.system(size: 12))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PrecisionCalTheme.terracotta.opacity(0.18), lineWidth: 1)
                )
        }
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke.opacity(0.55), lineWidth: 1)
                )
        }
    }
}
