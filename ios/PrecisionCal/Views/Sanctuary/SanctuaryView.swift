import SwiftUI
import SwiftData

struct SanctuaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SanctuaryPost.createdAt, order: .reverse) private var allPosts: [SanctuaryPost]
    @Query(sort: \RoadmapInsight.createdAt, order: .reverse) private var insights: [RoadmapInsight]

    @AppStorage("isFounder") private var isFounder: Bool = false

    @State private var composerOpen: Bool = false
    @State private var founderOpen: Bool = false
    @State private var seeded: Bool = false
    @State private var commentingPost: SanctuaryPost? = nil

    private var publicFeed: [SanctuaryPost] {
        allPosts.filter { $0.state == .approved || $0.state == .reviewing }
    }
    private var pendingInsights: Int { insights.filter { !$0.acknowledged }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        header
                        if publicFeed.isEmpty {
                            emptyState
                        } else {
                            ForEach(publicFeed) { post in
                                SanctuaryPostCard(
                                    post: post,
                                    onHeart: {
                                        post.hearts += 1
                                        try? modelContext.save()
                                    },
                                    onComment: {
                                        commentingPost = post
                                    },
                                    onReport: {
                                        post.userReported = true
                                        post.state = .flagged
                                        if post.stewardReason.isEmpty {
                                            post.stewardReason = "Reported by a community member."
                                        }
                                        try? modelContext.save()
                                    }
                                )
                            }
                        }
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }
                .scrollIndicators(.hidden)

                composeFAB
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PrecisionCalTheme.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text("THE SANCTUARY")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(PrecisionCalTheme.terracotta)
                        .onLongPressGesture(minimumDuration: 1.2) {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isFounder.toggle()
                            }
                        }
                }
                if isFounder {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            founderOpen = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(PrecisionCalTheme.terracottaDeep)
                                if pendingInsights > 0 {
                                    Circle()
                                        .fill(PrecisionCalTheme.terracotta)
                                        .frame(width: 7, height: 7)
                                        .offset(x: 4, y: -3)
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $composerOpen) {
                SanctuaryComposerView()
            }
            .sheet(item: $commentingPost) { post in
                SanctuaryCommentSheet(post: post)
            }
            .sheet(isPresented: $founderOpen) {
                FounderDashboardView()
            }
            .task {
                if !seeded {
                    seedIfEmpty()
                    seeded = true
                }
                await InnovationAggregatorService.shared.runIfDue(
                    context: modelContext,
                    posts: allPosts,
                    latest: insights.first
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Community")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(PrecisionCalTheme.terracotta)
            Text("The Sanctuary")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(PrecisionCalTheme.textPrimary)
            Text("A quiet, PhD-led circle. Every voice is read by the Steward before it appears.")
                .font(.custom("Georgia-Italic", size: 13))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .lineSpacing(2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 28))
                .foregroundStyle(PrecisionCalTheme.sage)
            Text("Be the first voice in the Sanctuary today.")
                .font(.custom("Georgia-Italic", size: 15))
                .foregroundStyle(PrecisionCalTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - FAB

    private var composeFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    composerOpen = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .bold))
                        Text("Add Post")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background {
                        Capsule().fill(
                            LinearGradient(
                                colors: [PrecisionCalTheme.terracotta, PrecisionCalTheme.terracottaDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: PrecisionCalTheme.terracotta.opacity(0.45), radius: 18, x: 0, y: 10)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 22)
                .padding(.bottom, 22)
            }
        }
    }

    // MARK: - Seed

    private func seedIfEmpty() {
        guard allPosts.isEmpty else { return }
        let now = Date()
        let seeds: [SanctuaryPost] = [
            SanctuaryPost(
                createdAt: now.addingTimeInterval(-3600 * 6),
                authorName: "Maren",
                authorInitial: "M",
                kind: .bloom,
                bodyText: "Quiet morning, slow breathing. I felt my body before I fed it.",
                hydrationProgress: 0.62, macroProgress: 0.48, adherenceProgress: 0.71,
                mood: "Re-centering",
                state: .approved, hearts: 12
            ),
            SanctuaryPost(
                createdAt: now.addingTimeInterval(-3600 * 14),
                authorName: "Theo",
                authorInitial: "T",
                kind: .encouragement,
                bodyText: "On day 12 of rebuilding my relationship with food. Today I plated my lunch instead of standing at the counter. Small, but it mattered.",
                state: .approved, hearts: 24
            ),
            SanctuaryPost(
                createdAt: now.addingTimeInterval(-3600 * 28),
                authorName: "Aria",
                authorInitial: "A",
                kind: .mealAnalysis,
                bodyText: "The 6-pass caught the lipid sheen on my salmon — I would never have noticed.",
                mealTitle: "Salmon, quinoa, roasted greens",
                mealScore: 86,
                metabolicImpact: "Steady energy",
                lipidSheen: true,
                calories: 612, protein: 38, carbs: 52, fat: 24,
                state: .approved, hearts: 31
            ),
        ]
        for p in seeds { modelContext.insert(p) }
        try? modelContext.save()
    }
}
