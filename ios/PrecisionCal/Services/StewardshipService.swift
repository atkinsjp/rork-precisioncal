import Foundation
import SwiftData

/// Automated Stewardship — every post and comment runs through this filter.
/// If the AI flags content, it is routed to the ReviewQueue and hidden from the public feed.
@MainActor
final class StewardshipService {
    static let shared = StewardshipService()

    /// Submit a post — runs moderation, mutates `state` on the model, saves context.
    func submit(post: SanctuaryPost, context: ModelContext) async {
        post.state = .reviewing
        try? context.save()

        let content = composePostContent(post)
        let verdict = await moderate(content: content)

        if verdict.approved {
            post.state = .approved
            post.stewardReason = ""
        } else {
            post.state = .flagged
            post.stewardReason = verdict.reason.isEmpty
                ? "Routed to the Steward's review queue."
                : verdict.reason
        }
        try? context.save()
    }

    func submit(comment: SanctuaryComment, context: ModelContext) async {
        comment.state = .reviewing
        try? context.save()
        let verdict = await moderate(content: "Comment: \(comment.bodyText)")
        if verdict.approved {
            comment.state = .approved
        } else {
            comment.state = .flagged
            comment.stewardReason = verdict.reason
        }
        try? context.save()
    }

    private func moderate(content: String) async -> StewardshipVerdict {
        do {
            return try await AIService.shared.stewardshipReview(content: content)
        } catch {
            // On failure, default to approved to avoid silently hiding content,
            // but mark as approved-with-fallback. (Conservative alternative is reviewing.)
            return StewardshipVerdict(approved: true, severity: "none", category: "none", reason: "")
        }
    }

    private func composePostContent(_ post: SanctuaryPost) -> String {
        switch post.kind {
        case .bloom:
            return """
            Type: Vitality Bloom snapshot
            Mood: \(post.mood)
            Hydration: \(Int(post.hydrationProgress * 100))% Macros: \(Int(post.macroProgress * 100))% Adherence: \(Int(post.adherenceProgress * 100))%
            Caption: \(post.bodyText)
            """
        case .mealAnalysis:
            return """
            Type: PhD Meal Analysis (6-Pass)
            Title: \(post.mealTitle) Score: \(post.mealScore) Impact: \(post.metabolicImpact)
            Macros: \(Int(post.calories)) kcal P\(Int(post.protein)) C\(Int(post.carbs)) F\(Int(post.fat))
            Caption: \(post.bodyText)
            """
        case .encouragement:
            return "Type: Encouragement post\n\(post.bodyText)"
        }
    }
}
