import SwiftUI
import SwiftData

/// The Creator's Lens — a private founder-only dashboard surfacing
/// AI-aggregated product roadmap suggestions from the Sanctuary feed.
struct FounderDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \RoadmapInsight.createdAt, order: .reverse) private var insights: [RoadmapInsight]
    @Query(sort: \SanctuaryPost.createdAt, order: .reverse) private var posts: [SanctuaryPost]

    @State private var running: Bool = false
    @State private var waveOffset: CGFloat = 0
    @State private var queueOpen: Bool = false

    private var pending: [RoadmapInsight] { insights.filter { !$0.acknowledged } }
    private var archived: [RoadmapInsight] { insights.filter { $0.acknowledged } }
    private var queueCount: Int { posts.filter { $0.state == .flagged }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackground().ignoresSafeArea()
                softWaveOverlay
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        statsRow
                        if !pending.isEmpty {
                            section("New roadmap signals", insights: pending)
                        }
                        regenerateButton
                        if !archived.isEmpty {
                            section("Archive", insights: archived)
                        }
                        Color.clear.frame(height: 40)
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Founder · Creator's Lens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                waveOffset = 200
            }
        }
        .sheet(isPresented: $queueOpen) {
            ReviewQueueView()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("CREATOR'S LENS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.5)
            }
            .foregroundStyle(PrecisionCalTheme.terracotta)

            Text("Innovation Aggregator")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("Each week, Gemini reads the top 50 voices in the Sanctuary and surfaces what your users are quietly asking for.")
                .font(.custom("Georgia-Italic", size: 13))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineSpacing(2)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat("Posts read", value: "\(posts.count)", color: PrecisionCalTheme.sage)
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                queueOpen = true
            } label: {
                queueStat
            }
            .buttonStyle(.plain)
            stat("Pending signals", value: "\(pending.count)", color: PrecisionCalTheme.fatColor)
        }
    }

    private var queueStat: some View {
        let alarm = Color(red: 0xC0 / 255, green: 0x39 / 255, blue: 0x2B / 255)
        let hasFlags = queueCount > 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("\(queueCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(hasFlags ? alarm : PrecisionCalTheme.textPrimary)
                if hasFlags {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(alarm)
                }
            }
            Text("REVIEW QUEUE")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(hasFlags ? alarm : PrecisionCalTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(hasFlags
                      ? Color(red: 0xFD / 255, green: 0xF4 / 255, blue: 0xF1 / 255)
                      : Color(red: 0xFD / 255, green: 0xFB / 255, blue: 0xF7 / 255))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(hasFlags ? alarm.opacity(0.6) : PrecisionCalTheme.terracotta.opacity(0.35),
                                lineWidth: hasFlags ? 1.5 : 1)
                )
                .shadow(color: hasFlags ? alarm.opacity(0.18) : .clear, radius: 10, x: 0, y: 4)
        }
    }

    private func stat(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1))
        }
    }

    private func section(_ title: String, insights: [RoadmapInsight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(PrecisionCalTheme.textTertiary)
            ForEach(insights) { ins in
                InsightCard(insight: ins) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        ins.acknowledged.toggle()
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    private var regenerateButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            running = true
            Task {
                _ = await InnovationAggregatorService.shared.runManually(
                    context: modelContext,
                    posts: posts
                )
                await MainActor.run { running = false }
            }
        } label: {
            HStack(spacing: 8) {
                if running {
                    ProgressView().tint(PrecisionCalTheme.terracotta).controlSize(.small)
                    Text("Reading the Sanctuary...")
                } else {
                    Image(systemName: "wand.and.stars")
                    Text("Regenerate this week's signals")
                }
            }
            .font(.system(size: 13, weight: .bold))
            .tracking(1)
            .foregroundStyle(PrecisionCalTheme.terracotta)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PrecisionCalTheme.terracotta.opacity(0.5), lineWidth: 1.2)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.4)))
            }
        }
        .buttonStyle(.plain)
        .disabled(running)
    }

    // MARK: - Soft Wave overlay

    private var softWaveOverlay: some View {
        Canvas { ctx, size in
            for i in 0..<3 {
                let phase = waveOffset + CGFloat(i) * 60
                var path = Path()
                let y = size.height * 0.18 + CGFloat(i) * 32
                path.move(to: CGPoint(x: -50, y: y))
                for x in stride(from: -50, through: size.width + 50, by: 6) {
                    let yy = y + sin((x + phase) / 60) * 8
                    path.addLine(to: CGPoint(x: x, y: yy))
                }
                ctx.stroke(path,
                           with: .color(PrecisionCalTheme.terracotta.opacity(0.05 - Double(i) * 0.012)),
                           lineWidth: 1)
            }
        }
    }
}

private struct InsightCard: View {
    let insight: RoadmapInsight
    var onToggle: () -> Void

    private var priorityColor: Color {
        switch insight.priority {
        case "high": PrecisionCalTheme.terracotta
        case "low": PrecisionCalTheme.textTertiary
        default: PrecisionCalTheme.fatColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(insight.priority.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(priorityColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(priorityColor.opacity(0.15)))
                Spacer()
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    onToggle()
                } label: {
                    Image(systemName: insight.acknowledged ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(insight.acknowledged ? PrecisionCalTheme.sage : PrecisionCalTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Text(insight.headline)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)

            if !insight.painPoint.isEmpty {
                Text(insight.painPoint)
                    .font(.custom("Georgia-Italic", size: 14))
                    .foregroundStyle(PrecisionCalTheme.textSecondary)
                    .lineSpacing(2)
            }

            if !insight.rationale.isEmpty {
                Text(insight.rationale)
                    .font(.system(size: 13))
                    .foregroundStyle(PrecisionCalTheme.textPrimary)
                    .lineSpacing(2)
            }

            if !insight.sourceQuotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("USER VOICES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(PrecisionCalTheme.textTertiary)
                    ForEach(insight.sourceQuotes.prefix(3), id: \.self) { q in
                        HStack(alignment: .top, spacing: 6) {
                            Rectangle()
                                .fill(PrecisionCalTheme.terracotta.opacity(0.5))
                                .frame(width: 2)
                            Text("“\(q)”")
                                .font(.custom("Georgia-Italic", size: 12))
                                .foregroundStyle(PrecisionCalTheme.textSecondary)
                                .lineSpacing(1)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.35)))
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0xFD/255, green: 0xFB/255, blue: 0xF7/255))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(PrecisionCalTheme.glassStroke, lineWidth: 1))
                .shadow(color: priorityColor.opacity(0.10), radius: 14, x: 0, y: 6)
        }
        .opacity(insight.acknowledged ? 0.6 : 1)
    }
}
