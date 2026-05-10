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
                        body: "PrecisionCal is a wellness companion. All nutrition information, AI insights, meal analyses, scanned product reviews, weekly Sunday Calibrations, and Dr. PrecisionCal chat replies are intended for general educational and informational purposes only. They are not a substitute for professional medical advice, diagnosis, or treatment."
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
