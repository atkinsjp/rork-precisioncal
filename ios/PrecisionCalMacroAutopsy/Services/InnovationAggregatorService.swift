import Foundation
import SwiftData

/// The Creator's Lens — once a week, Gemini scans the top 50 posts/comments
/// and surfaces a Product Roadmap Suggestion to the Founder Dashboard.
@MainActor
final class InnovationAggregatorService {
    static let shared = InnovationAggregatorService()

    private var isRunning = false

    func shouldRun(latest: RoadmapInsight?) -> Bool {
        guard let latest else { return true }
        return Date().timeIntervalSince(latest.createdAt) >= 7 * 24 * 3600
    }

    func runIfDue(
        context: ModelContext,
        posts: [SanctuaryPost],
        latest: RoadmapInsight?
    ) async {
        guard !isRunning, shouldRun(latest: latest) else { return }
        await execute(context: context, posts: posts)
    }

    @discardableResult
    func runManually(context: ModelContext, posts: [SanctuaryPost]) async -> Bool {
        guard !isRunning else { return false }
        return await execute(context: context, posts: posts)
    }

    @discardableResult
    private func execute(context: ModelContext, posts: [SanctuaryPost]) async -> Bool {
        isRunning = true
        defer { isRunning = false }

        let approved = posts.filter { $0.state == .approved }
        let recent = Array(approved.sorted(by: { $0.createdAt > $1.createdAt }).prefix(50))
        guard recent.count >= 3 else { return false }

        let corpus = recent.enumerated().map { idx, p in
            "[\(idx + 1)] \(p.kind.rawValue) by \(p.authorName): \(p.bodyText.prefix(280))"
        }.joined(separator: "\n")

        do {
            let report = try await AIService.shared.innovationAggregate(corpus: corpus)
            for s in report.suggestions {
                let ins = RoadmapInsight(
                    createdAt: Date(),
                    headline: s.headline,
                    rationale: s.rationale,
                    painPoint: s.painPoint,
                    sourceQuotes: s.sourceQuotes,
                    priority: s.priority,
                    acknowledged: false
                )
                context.insert(ins)
            }
            try? context.save()
            return true
        } catch {
            print("[InnovationAggregator] failed: \(error.localizedDescription)")
            return false
        }
    }
}
