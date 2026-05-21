import SwiftUI
import SwiftData

/// The Steward's Review Queue — surfaces all content the AI Steward has flagged.
/// Flags are designed to STAND OUT: warning-stripe banners, severity ribbons,
/// pulsing alert dots, and a dedicated alarm-amber palette so the reviewer
/// can scan and act in seconds.
struct ReviewQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<SanctuaryPost> { $0.stateRaw == "flagged" },
           sort: \SanctuaryPost.createdAt, order: .reverse)
    private var flaggedPosts: [SanctuaryPost]

    @Query(filter: #Predicate<SanctuaryComment> { $0.stateRaw == "flagged" },
           sort: \SanctuaryComment.createdAt, order: .reverse)
    private var flaggedComments: [SanctuaryComment]

    @State private var pulse: Bool = false
    @State private var stripeOffset: CGFloat = 0

    // Alarm palette — deliberately louder than the rest of the warm sanctuary.
    private let alarm = Color(red: 0xC0 / 255, green: 0x39 / 255, blue: 0x2B / 255)
    private let alarmDeep = Color(red: 0x8E / 255, green: 0x21 / 255, blue: 0x1B / 255)
    private let amber = Color(red: 0xE6 / 255, green: 0x9A / 255, blue: 0x2E / 255)

    private var totalCount: Int { flaggedPosts.count + flaggedComments.count }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground().ignoresSafeArea()

                if totalCount == 0 {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            alarmBanner
                            if !flaggedPosts.isEmpty {
                                sectionLabel("Flagged posts", count: flaggedPosts.count)
                                ForEach(flaggedPosts) { post in
                                    FlaggedPostRow(
                                        post: post,
                                        alarm: alarm,
                                        alarmDeep: alarmDeep,
                                        amber: amber,
                                        onApprove: { approve(post) },
                                        onRemove: { remove(post) }
                                    )
                                }
                            }
                            if !flaggedComments.isEmpty {
                                sectionLabel("Flagged comments", count: flaggedComments.count)
                                ForEach(flaggedComments) { c in
                                    FlaggedCommentRow(
                                        comment: c,
                                        alarm: alarm,
                                        alarmDeep: alarmDeep,
                                        onApprove: { approve(c) },
                                        onRemove: { remove(c) }
                                    )
                                }
                            }
                            Color.clear.frame(height: 40)
                        }
                        .padding(20)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Steward · Review Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                stripeOffset = 40
            }
        }
    }

    // MARK: - Banner

    private var alarmBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(alarm.opacity(0.18))
                    .frame(width: 48, height: 48)
                    .scaleEffect(pulse ? 1.18 : 1.0)
                Circle()
                    .fill(alarm)
                    .frame(width: 14, height: 14)
                    .shadow(color: alarm.opacity(0.7), radius: 8)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(totalCount) ITEM\(totalCount == 1 ? "" : "S") AWAITING REVIEW")
                    .font(.system(size: 11, weight: .black))
                    .tracking(2)
                    .foregroundStyle(alarmDeep)
                Text("The Steward held these back from the Sanctuary feed.")
                    .font(.custom("Georgia-Italic", size: 13))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0xFD / 255, green: 0xF4 / 255, blue: 0xF1 / 255))
                warningStripes
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(alarm.opacity(0.6), lineWidth: 1.5)
            }
        }
    }

    private var warningStripes: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 14
            let total = size.width + size.height + spacing
            ctx.opacity = 0.06
            var x: CGFloat = -size.height + stripeOffset
            while x < total {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + 6, y: 0))
                path.addLine(to: CGPoint(x: x + 6, y: size.height))
                path.closeSubpath()
                ctx.fill(path, with: .color(alarmDeep))
                x += spacing
            }
        }
        .allowsHitTesting(false)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(PrecisionCalTheme.sage.opacity(0.15))
                    .frame(width: 78, height: 78)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(PrecisionCalTheme.sage)
            }
            Text("The Sanctuary is calm.")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("Nothing is waiting for your review.")
                .font(.custom("Georgia-Italic", size: 14))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
        }
        .padding(40)
    }

    private func sectionLabel(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            Text("\(count)")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(alarm))
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Actions

    private func approve(_ post: SanctuaryPost) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeInOut(duration: 0.35)) {
            post.state = .approved
            post.stewardReason = ""
            try? modelContext.save()
        }
    }

    private func remove(_ post: SanctuaryPost) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.easeInOut(duration: 0.35)) {
            modelContext.delete(post)
            try? modelContext.save()
        }
    }

    private func approve(_ comment: SanctuaryComment) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeInOut(duration: 0.35)) {
            comment.state = .approved
            comment.stewardReason = ""
            try? modelContext.save()
        }
    }

    private func remove(_ comment: SanctuaryComment) {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        withAnimation(.easeInOut(duration: 0.35)) {
            modelContext.delete(comment)
            try? modelContext.save()
        }
    }
}

// MARK: - Flagged post row

private struct FlaggedPostRow: View {
    let post: SanctuaryPost
    let alarm: Color
    let alarmDeep: Color
    let amber: Color
    var onApprove: () -> Void
    var onRemove: () -> Void

    @State private var pulse: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Bold flag ribbon — impossible to miss.
            flagRibbon

            VStack(alignment: .leading, spacing: 12) {
                // Author + kind
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(PrecisionCalTheme.terracotta.opacity(0.15))
                            .frame(width: 30, height: 30)
                        Text(post.authorInitial)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(PrecisionCalTheme.terracottaDeep)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(post.authorName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                        Text(kindLabel.uppercased() + " · " + relativeTime)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(PrecisionCalTheme.textTertiary)
                    }
                    Spacer()
                }

                // Content quote
                if !post.bodyText.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle()
                            .fill(alarm)
                            .frame(width: 3)
                        Text("“\(post.bodyText)”")
                            .font(.custom("Georgia-Italic", size: 14))
                            .foregroundStyle(PrecisionCalTheme.textPrimary)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if post.kind == .mealAnalysis && !post.mealTitle.isEmpty {
                    Text("Meal: \(post.mealTitle) · score \(post.mealScore)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }

                // Steward reason — highlighted
                stewardReasonBlock

                // Actions
                HStack(spacing: 10) {
                    actionButton(label: "Remove",
                                 icon: "trash.fill",
                                 fg: .white,
                                 bg: alarm,
                                 action: onRemove)
                    actionButton(label: "Approve",
                                 icon: "checkmark",
                                 fg: PrecisionCalTheme.sage,
                                 bg: Color.white.opacity(0.9),
                                 strokeColor: PrecisionCalTheme.sage,
                                 action: onApprove)
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0xFD / 255, green: 0xFB / 255, blue: 0xF7 / 255))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(alarm.opacity(0.55), lineWidth: 1.5)
                )
                .shadow(color: alarm.opacity(0.18), radius: 14, x: 0, y: 6)
        }
        .clipShape(.rect(cornerRadius: 18))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var flagRibbon: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .opacity(pulse ? 0.4 : 1.0)
            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .black))
            Text(post.userReported ? "REPORTED BY MEMBER" : "FLAGGED BY STEWARD")
                .font(.system(size: 10, weight: .black))
                .tracking(2.2)
            Spacer()
            Text(severityLabel)
                .font(.system(size: 9, weight: .black))
                .tracking(1.4)
                .foregroundStyle(alarm)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(.white))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(colors: [alarm, alarmDeep],
                           startPoint: .leading, endPoint: .trailing)
        }
    }

    private var stewardReasonBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(amber)
            VStack(alignment: .leading, spacing: 3) {
                Text("STEWARD'S NOTE")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.6)
                    .foregroundStyle(alarmDeep)
                Text(post.stewardReason.isEmpty ? "Routed for human review." : post.stewardReason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(amber.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(amber.opacity(0.5), lineWidth: 1)
                )
        }
    }

    private func actionButton(label: String,
                              icon: String,
                              fg: Color,
                              bg: Color,
                              strokeColor: Color? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(label).font(.system(size: 12, weight: .bold)).tracking(1)
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(strokeColor ?? .clear, lineWidth: strokeColor == nil ? 0 : 1)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var kindLabel: String {
        switch post.kind {
        case .bloom: "Vitality Bloom"
        case .mealAnalysis: "Meal Analysis"
        case .encouragement: "Encouragement"
        }
    }

    private var severityLabel: String {
        let r = post.stewardReason.lowercased()
        if r.contains("danger") || r.contains("medical") { return "MAJOR" }
        if r.contains("disrespect") || r.contains("improper") { return "MINOR" }
        return "REVIEW"
    }

    private var relativeTime: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: post.createdAt, relativeTo: Date())
    }
}

// MARK: - Flagged comment row

private struct FlaggedCommentRow: View {
    let comment: SanctuaryComment
    let alarm: Color
    let alarmDeep: Color
    var onApprove: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 9, weight: .black))
                Text("FLAGGED COMMENT")
                    .font(.system(size: 9, weight: .black))
                    .tracking(1.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(alarm))

            HStack(alignment: .top, spacing: 8) {
                Rectangle().fill(alarm).frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(comment.authorName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                    Text("“\(comment.bodyText)”")
                        .font(.custom("Georgia-Italic", size: 14))
                        .foregroundStyle(PrecisionCalTheme.textPrimary)
                        .lineSpacing(2)
                }
            }

            if !comment.stewardReason.isEmpty {
                Text(comment.stewardReason)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(alarmDeep)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Capsule().fill(alarm.opacity(0.12)))
            }

            HStack(spacing: 10) {
                Button(action: onRemove) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash.fill").font(.system(size: 10, weight: .bold))
                        Text("Remove").font(.system(size: 11, weight: .bold)).tracking(0.8)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(alarm))
                }
                .buttonStyle(.plain)

                Button(action: onApprove) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                        Text("Approve").font(.system(size: 11, weight: .bold)).tracking(0.8)
                    }
                    .foregroundStyle(PrecisionCalTheme.sage)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().stroke(PrecisionCalTheme.sage, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0xFD / 255, green: 0xFB / 255, blue: 0xF7 / 255))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(alarm.opacity(0.45), lineWidth: 1.2)
                )
                .shadow(color: alarm.opacity(0.12), radius: 10, x: 0, y: 4)
        }
    }
}
