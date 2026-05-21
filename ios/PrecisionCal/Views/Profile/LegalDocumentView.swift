import SwiftUI

/// In-app renderer for Privacy Policy and Terms of Service so the links always
/// work, regardless of whether the marketing site is live. Falls back to the
/// hosted URL via a "View on web" link at the bottom for users who prefer it.
struct LegalDocumentView: View {
    enum Kind: Identifiable {
        case privacy
        case terms

        var id: String {
            switch self {
            case .privacy: return "privacy"
            case .terms: return "terms"
            }
        }

        var title: String {
            switch self {
            case .privacy: return "Privacy Policy"
            case .terms: return "Terms of Service"
            }
        }

        var eyebrow: String {
            switch self {
            case .privacy: return "PRIVACY"
            case .terms: return "TERMS"
            }
        }

        var webURL: URL? {
            switch self {
            case .privacy: return URL(string: "https://precisioncal.app/privacy.html")
            case .terms: return URL(string: "https://precisioncal.app/terms.html")
            }
        }
    }

    let kind: Kind
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    ForEach(sections, id: \.0) { (title, body) in
                        section(title: title, body: body)
                    }
                    Text("Last updated: January 2026")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                        .padding(.top, 4)
                    if let url = kind.webURL {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Image(systemName: "safari")
                                Text("View on web")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(PrecisionCalTheme.terracotta)
                        }
                        .padding(.top, 4)
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(kind.title)
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
                Image(systemName: kind == .privacy ? "hand.raised.fill" : "doc.text.fill")
                    .foregroundStyle(PrecisionCalTheme.terracotta)
                Text(kind.eyebrow)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(PrecisionCalTheme.terracotta)
            }
            Text(kind.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("PrecisionCal, operated by Atkins Media.")
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

    private var sections: [(String, String)] {
        switch kind {
        case .privacy: return Self.privacySections
        case .terms: return Self.termsSections
        }
    }

    private static let privacySections: [(String, String)] = [
        ("1. Information We Collect",
         "Account information you provide (name, email, authentication identifiers). Health and nutrition inputs (meal photos, barcodes, weight, goals, allergies, water intake, notes). Derived analyses (meal analyses, metabolic narratives, Sunday Calibration outputs) generated from your inputs. Device and usage data (device type, app version, crash diagnostics, and basic interaction events)."),
        ("2. How We Use Your Information",
         "To generate your personal nutrition analyses and dashboards. To improve accuracy of the Global Nutrition Index using only anonymized barcode-level entries. To respond to support requests sent to support@atkins-media.com. To diagnose crashes and improve product quality. We do not sell your personal data."),
        ("3. AI Processing",
         "Meal photos, barcode data, and profile summaries you provide are sent to our AI vendors (currently Google Gemini via the Rork toolkit) solely to generate the educational nutrition output you requested. Inputs are not used to train third-party models."),
        ("4. Your Choices",
         "You can access, export, or delete your data by emailing support@atkins-media.com. You can sign out at any time from the Profile screen. Deleting the app removes all locally-cached data from your device."),
        ("5. Data Retention",
         "We retain your account and content while your account is active and for a reasonable period after to comply with legal obligations and to resolve disputes. You may request earlier deletion at any time."),
        ("6. Security",
         "We use industry-standard safeguards including HTTPS in transit, encrypted storage at rest, and least-privilege access controls. No method of transmission over the Internet is 100% secure; we cannot guarantee absolute security."),
        ("7. Children",
         "PrecisionCal is not directed to children under 13. If you believe a child has provided us personal information, contact support@atkins-media.com and we will delete it."),
        ("8. International Transfers",
         "Your information may be processed in the United States and other countries where our service providers operate. By using the app you consent to these transfers."),
        ("9. Changes to This Policy",
         "We may update this policy from time to time. Material changes will be announced in-app or by email. Continued use after an update constitutes acceptance of the revised policy."),
        ("10. Contact",
         "Questions or requests: email support@atkins-media.com.")
    ]

    private static let termsSections: [(String, String)] = [
        ("1. Eligibility",
         "You must be at least 13 years old (or the age of digital consent in your country) to use PrecisionCal."),
        ("2. Your Account",
         "You are responsible for maintaining the security of your account and for all activity that occurs under it. Notify us promptly at support@atkins-media.com of any unauthorized use."),
        ("3. Acceptable Use",
         "Do not post content that is disrespectful, medically dangerous, or unlawful. The Stewardship Filter may flag and hide such content and route it for review. Do not attempt to reverse engineer, scrape, or interfere with PrecisionCal's services. Do not use PrecisionCal to provide medical advice to others."),
        ("4. Health Disclaimer",
         "PrecisionCal is an educational wellness companion. It is not a doctor, dietitian, or medical device, and it does not provide medical advice, diagnosis, or treatment. Chats with Cal, meal analyses, calibrations, and product reviews are general educational information only. Always consult a licensed healthcare professional before making changes to your diet, supplements, or medications. In an emergency, call 911 or your local emergency number."),
        ("5. Subscriptions and Billing",
         "Pro subscriptions are billed through Apple's App Store. Payment will be charged to your Apple ID at purchase confirmation. Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple ID account settings."),
        ("6. Intellectual Property",
         "All software, content, and trademarks in PrecisionCal are owned by Atkins Media or its licensors and are protected by intellectual property laws. You retain ownership of the content you submit, and grant us a worldwide, royalty-free license to host and display it solely to operate the service."),
        ("7. Termination",
         "We may suspend or terminate your access at any time for violations of these Terms. You may stop using the app at any time. Sections that by their nature should survive termination will do so."),
        ("8. Disclaimers and Limitation of Liability",
         "The service is provided \"as is\" without warranties of any kind. To the maximum extent permitted by law, Atkins Media will not be liable for indirect, incidental, special, consequential, or punitive damages, or any loss of profits or data."),
        ("9. Governing Law",
         "These Terms are governed by the laws of the State where Atkins Media is organized, without regard to conflict-of-law principles."),
        ("10. Changes to These Terms",
         "We may update these Terms from time to time. Material changes will be announced in-app or by email. Continued use after an update constitutes acceptance."),
        ("11. Contact",
         "Questions: email support@atkins-media.com.")
    ]
}
