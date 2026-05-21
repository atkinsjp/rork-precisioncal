import SwiftUI
import UIKit

/// Vellum card (#FDFBF7) used for every Sanctuary post.
struct SanctuaryPostCard: View {
    let post: SanctuaryPost
    var onHeart: () -> Void = {}
    var onComment: () -> Void = {}
    var onReport: () -> Void = {}

    @Environment(\.openURL) private var openURL
    @State private var heartPulse: Bool = false
    @State private var revealed: Bool = false
    @State private var showReportConfirm: Bool = false

    private let supportEmail = "support@atkins-media.com"

    private var vellum: Color { Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            switch post.kind {
            case .bloom:
                bloomBody
            case .mealAnalysis:
                mealBody
            case .encouragement:
                encouragementBody
            }

            footer
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(vellum)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    PrecisionCalTheme.glassStroke.opacity(0.7),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: PrecisionCalTheme.terracotta.opacity(0.06), radius: 18, x: 0, y: 8)
        }
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) { revealed = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PrecisionCalTheme.terracotta.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(post.authorInitial)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PrecisionCalTheme.terracottaDeep)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(post.authorName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                Text(kindLabel + " · " + relativeTime)
                    .font(.system(size: 11, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(PrecisionCalTheme.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                kindBadge
                if post.userReported {
                    reportedBadge
                }
            }
        }
    }

    private var reportedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "flag.fill")
                .font(.system(size: 9, weight: .bold))
            Text("REPORTED")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            PrecisionCalTheme.terracotta,
                            PrecisionCalTheme.terracottaDeep,
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.5), lineWidth: 0.8)
        )
        .shadow(color: PrecisionCalTheme.terracotta.opacity(0.4), radius: 4, x: 0, y: 2)
    }

    private var kindBadge: some View {
        let label: String
        let icon: String
        let color: Color
        switch post.kind {
        case .bloom:
            label = "BLOOM"; icon = "circle.hexagongrid.fill"; color = PrecisionCalTheme.sage
        case .mealAnalysis:
            label = "PHD"; icon = "leaf.fill"; color = PrecisionCalTheme.terracotta
        case .encouragement:
            label = "VOICE"; icon = "quote.bubble.fill"; color = PrecisionCalTheme.fatColor
        }
        return HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(label).font(.system(size: 9, weight: .bold)).tracking(1.4)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.8))
    }

    private var kindLabel: String {
        switch post.kind {
        case .bloom: "Vitality Bloom"
        case .mealAnalysis: "Meal Analysis"
        case .encouragement: "Encouragement"
        }
    }

    private var relativeTime: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: post.createdAt, relativeTo: Date())
    }

    // MARK: - Bloom body

    private var bloomBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !post.bodyText.isEmpty {
                Text(post.bodyText)
                    .font(.system(size: 15))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineSpacing(3)
            }
            HStack(spacing: 12) {
                miniStat("Hydration", post.hydrationProgress, PrecisionCalTheme.hydrationColor)
                miniStat("Macros", post.macroProgress, PrecisionCalTheme.carbColor)
                miniStat("Adherence", post.adherenceProgress, PrecisionCalTheme.terracotta)
            }
            if !post.mood.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text(post.mood)
                        .font(.custom("Georgia-Italic", size: 13))
                }
                .foregroundStyle(PrecisionCalTheme.textSecondary)
            }
        }
    }

    private func miniStat(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.14))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, value))))
                }
            }
            .frame(height: 6)
            Text("\(Int(value * 100))%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Meal body

    private var mealBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Color(.secondarySystemBackground)
                    .frame(width: 76, height: 76)
                    .overlay {
                        if let data = post.imageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        } else {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 22))
                                .foregroundStyle(PrecisionCalTheme.sage)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.mealTitle.isEmpty ? "Meal" : post.mealTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineLimit(2)
                    if !post.metabolicImpact.isEmpty {
                        Text(post.metabolicImpact)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(PrecisionCalTheme.textSecondary)
                    }
                    HStack(spacing: 8) {
                        scoreBadge
                        if post.lipidSheen {
                            HStack(spacing: 4) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text("LIPID SHEEN")
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1.2)
                            }
                            .foregroundStyle(PrecisionCalTheme.fatColor)
                            .padding(.horizontal, 7).padding(.vertical, 4)
                            .background(Capsule().fill(PrecisionCalTheme.fatColor.opacity(0.15)))
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                macroChip("cal", "\(Int(post.calories))", PrecisionCalTheme.terracotta)
                macroChip("P", "\(Int(post.protein))g", PrecisionCalTheme.proteinColor)
                macroChip("C", "\(Int(post.carbs))g", PrecisionCalTheme.carbColor)
                macroChip("F", "\(Int(post.fat))g", PrecisionCalTheme.fatColor)
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.55))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PrecisionCalTheme.glassStroke.opacity(0.4), lineWidth: 1))
            }

            if !post.bodyText.isEmpty {
                Text(post.bodyText)
                    .font(.system(size: 14))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineSpacing(2)
            }
        }
    }

    private var scoreBadge: some View {
        let color: Color = post.mealScore >= 80
            ? PrecisionCalTheme.sage
            : (post.mealScore >= 60 ? PrecisionCalTheme.fatColor : PrecisionCalTheme.terracotta)
        return Text("Score \(post.mealScore)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.15)))
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.8))
    }

    private func macroChip(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Encouragement

    private var encouragementBody: some View {
        Text(post.bodyText)
            .font(.custom("Georgia", size: 17))
            .foregroundStyle(PrecisionCalTheme.textPrimary)
            .lineSpacing(4)
            .padding(.vertical, 6)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button {
                let gen = UIImpactFeedbackGenerator(style: .soft)
                gen.impactOccurred()
                heartPulse = true
                onHeart()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { heartPulse = false }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                        .scaleEffect(heartPulse ? 1.35 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: heartPulse)
                    Text("\(post.hearts)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                        .contentTransition(.numericText(value: Double(post.hearts)))
                }
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onComment()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(post.comments.filter { $0.state == .approved }.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showReportConfirm = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: post.userReported ? "flag.checkered" : "flag.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(post.userReported ? "Reported" : "Report")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundStyle(post.userReported ? Color.white : PrecisionCalTheme.terracottaDeep.opacity(0.75))
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(post.userReported ? PrecisionCalTheme.terracotta : PrecisionCalTheme.terracotta.opacity(0.08))
                        .overlay(Capsule().stroke(PrecisionCalTheme.terracotta.opacity(0.3), lineWidth: 0.8))
                )
            }
            .buttonStyle(.plain)
            .disabled(post.userReported)
            .confirmationDialog(
                "Flag this post?",
                isPresented: $showReportConfirm,
                titleVisibility: .visible
            ) {
                Button("Disrespectful", role: .destructive) { flag(reason: "Disrespectful") }
                Button("Medically dangerous", role: .destructive) { flag(reason: "Medically dangerous") }
                Button("Improper / spam", role: .destructive) { flag(reason: "Improper or spam") }
                Button("Sexual / hateful", role: .destructive) { flag(reason: "Sexual or hateful content") }
                Button("Other", role: .destructive) { flag(reason: "Other") }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The post will be hidden from the feed, routed to the Steward, and a report will be emailed to \(supportEmail).")
            }

            Spacer()

            if post.state == .approved {
                stewardBadge("Steward · cleared", color: PrecisionCalTheme.sage, icon: "checkmark.seal.fill")
            } else if post.state == .reviewing {
                stewardBadge("Steward reviewing", color: PrecisionCalTheme.textTertiary, icon: "hourglass")
            } else {
                stewardBadge("In review queue", color: PrecisionCalTheme.terracottaDeep, icon: "exclamationmark.triangle.fill")
            }
        }
    }

    private func stewardBadge(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(text).font(.system(size: 9, weight: .bold)).tracking(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.10)))
    }

    // MARK: - Flag flow

    private func flag(reason: String) {
        onReport()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        sendReportEmail(reason: reason)
    }

    private func sendReportEmail(reason: String) {
        let subject = "Sanctuary post report — \(reason)"
        let preview = post.bodyText.isEmpty ? "(no body text)" : String(post.bodyText.prefix(400))
        let bodyText = """
        A community member has flagged a Sanctuary post.

        Reason: \(reason)
        Post kind: \(post.kind.rawValue)
        Author (display): \(post.authorName)
        Posted: \(post.createdAt)

        Post excerpt:
        \(preview)

        —
        Sent from PrecisionCal in-app report flow.
        """
        let allowed = CharacterSet.urlQueryAllowed
        let s = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let b = bodyText.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        if let url = URL(string: "mailto:\(supportEmail)?subject=\(s)&body=\(b)") {
            openURL(url)
        }
    }
}
