import Foundation
import UIKit

nonisolated struct MealAnalysisResult: Codable, Sendable {
    let title: String
    let items: [Item]
    let metabolicImpact: String
    let mealScore: Int
    let qcNotes: String
    let lipidSheenDetected: Bool
    let lipidNote: String

    // Granular fat subcategories (g) — sat + unsat + trans reconcile to total fat.
    let saturatedFat: Double
    let unsaturatedFat: Double
    let transFat: Double

    // Hidden Fat telemetry (verified lipid sheen adjustments)
    let hiddenFatAddedCalories: Double
    let hiddenFatAddedFatG: Double
    let hiddenFatTargetItem: String
    let hiddenFatMechanism: String

    // Clinical micronutrient matrix
    let micronutrients: [Micronutrient]

    nonisolated struct Item: Codable, Sendable {
        let name: String
        let preparation: String
        let grams: Double
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double
        let sugar: Double
        let waterMl: Double
        /// How the gram weight was derived: "visual" from the AI estimate, or "default" from a reference/unit fallback.
        let weightSource: String
    }
}

nonisolated enum AnalysisEvent: Sendable {
    case pass1Identified(items: [String], title: String)
    case pass2LipidDiscovered
    case pass3LipidVerified
    case pass4Weighed
    case pass5Mapped
    case pass6Synthesized(MealAnalysisResult)
}

nonisolated enum AIError: Error, LocalizedError, Sendable {
    case authError
    case insufficientBalance
    case rateLimited
    case serverError(Int)
    case decodingError(String)
    case imageTooLarge
    case visionFailed

    var errorDescription: String? {
        switch self {
        case .authError: "AI features are unavailable. Please restart the app."
        case .insufficientBalance: "AI features are temporarily unavailable."
        case .rateLimited: "Too many requests. Please wait a moment."
        case .serverError(let c): "Server error (\(c)). Please try again."
        case .decodingError(let m): "Couldn't read the analysis: \(m)"
        case .imageTooLarge: "Photo is too large. Try a smaller image."
        case .visionFailed: "I couldn't identify the food. Try a clearer photo."
        }
    }
}

nonisolated struct DoctorChatTurn: Sendable {
    let role: String // "user" or "assistant"
    let content: String
}

nonisolated struct Pass1Item: Codable, Sendable {
    let name: String
    let preparation: String
    let visual: String?
    let category: String?
    /// Whether the item comes in distinct, countable units (pancakes, eggs, slices).
    let isDiscrete: Bool?
    /// Exact number of units when discrete (e.g. 4 pancakes).
    let discreteCount: Int?
    /// Physical size anchor for ONE unit (e.g. "medium (approx 5-6 inch diameter)").
    let estimatedSize: String?
    /// How the units appear (e.g. "stacked", "spread", "fanned", "cut in half").
    let state: String?
}

nonisolated struct Pass1Output: Codable, Sendable {
    let items: [Pass1Item]
    let plateDetails: String?
    let depthCues: String?
    let title: String?
}

nonisolated struct Pass2Item: Codable, Sendable {
    let name: String
    let preparation: String
    let estimatedWeightG: Double
}

nonisolated struct Pass2Output: Codable, Sendable {
    let items: [Pass2Item]
    let totalWeightG: Double?
}

nonisolated struct Pass3Item: Codable, Sendable {
    let name: String
    let preparation: String
    let grams: Double
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sugar: Double
    let waterMl: Double
}

nonisolated struct Pass3Output: Codable, Sendable {
    let items: [Pass3Item]
}

nonisolated struct Pass4Output: Codable, Sendable {
    let title: String?
    let items: [Pass3Item]
    let metabolicImpact: String?
    let mealScore: Int?
    let qcNotes: String?
    let saturatedFatG: Double?
    let unsaturatedFatG: Double?
    let transFatG: Double?
    let micronutrients: [Micronutrient]?
}

nonisolated struct Pass5Adjustment: Codable, Sendable {
    let name: String
    let lipidSheenDetected: Bool
    let inferredFat: String?
    let addedFatG: Double
    let addedCalories: Double
    let confidence: Int
}

nonisolated struct Pass5Output: Codable, Sendable {
    let adjustments: [Pass5Adjustment]
    let summaryNote: String?
}

/// Pass 2 — Lipid Sheen Discovery: a wide-angle surface-physics scan that flags
/// candidate regions exhibiting oil/butter reflectivity for the macro-zoom pass to verify.
nonisolated struct LipidCandidate: Codable, Sendable {
    let name: String
    let sheenSuspected: Bool
    /// Approximate target region/coordinates for the Pass 3 macro-zoom (e.g. "center-left, top of chicken").
    let region: String?
    let reflectivityNote: String?
}

nonisolated struct LipidDiscoveryOutput: Codable, Sendable {
    let candidates: [LipidCandidate]
    let note: String?
}

nonisolated final class AIService: Sendable {
    static let shared = AIService()

    private let toolkitURL = "https://toolkit.rork.com"
    private let model = "google/gemini-2.5-flash"
    /// Fixed sampling seed shared by every analysis pass so identical images
    /// produce identical outputs (deterministic sampling, no generative drift).
    private static let deterministicSeed = 7

    @MainActor
    private static var secret: String { Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY }

    // MARK: - Product (barcode) parsing

    /// Structure raw UPC JSON into a clean, scored product record.
    /// Adds PhD-level additive risk + allergen flags so we can cross-reference the user's profile.
    func parseProductData(barcode: String, rawJSON: String) async throws -> ProductLookupResult {
        let system = """
        You are PrecisionCalMacroAutopsy's product database curator. You receive raw UPC/Open Food Facts JSON and must return a clean, normalized product record.
        Score additive risk like a PhD nutritionist:
        - 'low': whole-food / minimal additives
        - 'moderate': common emulsifiers, refined sugars, seed oils, NOVA 3
        - 'high': artificial sweeteners, controversial preservatives (BHT, BHA, nitrites, propylparaben), artificial colors, NOVA 4 ultra-processed
        Detect allergens (milk, eggs, gluten, wheat, peanuts, tree nuts, soy, fish, shellfish, sesame).
        Per 100g unless serving info is reliable. Convert sodium to mg.
        Return STRICT JSON only:
        {"name":"...","brand":"...","servingSizeG":number,"servingDescription":"e.g. 1 cup (240g)","calories":number,"protein":number,"carbs":number,"fat":number,"fiber":number,"sugar":number,"sodiumMg":number,"ingredients":["..."],"allergyFlags":["milk","soy"],"additiveRisk":"one short sentence","riskLevel":"low|moderate|high","clinicalNote":"1-2 sentence PhD review of this product as part of a daily diet"}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "Barcode: \(barcode)\nRaw product data:\n\(rawJSON.prefix(8000))"],
            ],
            "temperature": 0.0,
            "seed": Self.deterministicSeed,
            "max_tokens": 1800,
        ]
        let raw = try await postChat(body: body)
        return try decode(ProductLookupResult.self, from: raw)
    }

    // MARK: - PhD Synthesis

    /// Generate a personalized 300-word health protocol from a profile snapshot.
    /// Returns plain prose, no markdown.
    func generateHealthProtocol(profileSummary: String) async throws -> String {
        let system = """
        You are a PhD Nutritionist and integrative-health practitioner. Read the user's profile and write a warm, encouraging, deeply personalized health protocol of approximately 130 words (STRICT: never exceed 160 words). 
        Reference specific details from their profile (goals, conditions, allergies, medication interactions, activity). Provide concrete daily guidance on macronutrients, hydration, meal timing, and one simple ritual to anchor the day. 
        Be concise and complete: ALWAYS finish your final sentence — never stop mid-thought. 
        Tone: thoughtful, sanctuary-like, never clinical or scolding. You are Cal, an educational nutrition guide — NOT a doctor, dietitian, or medical professional. Never refer to yourself with a clinical title (no 'Dr.', no 'PhD', no 'clinician'). Do NOT add a signature or sign-off — the app appends it. 
        Output: plain prose only. No markdown, no headings, no bullet lists.
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "Profile:\n\(profileSummary)\n\nWrite the concise (~130 word) health protocol now. Finish every sentence."],
            ],
            "temperature": 0.7,
            "max_tokens": 400,
        ]
        let raw = try await postChat(body: body)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Sunday Calibration (weekly Protocol Pivot)

    /// Generate a weekly 'Protocol Pivot' from a Senior PhD Clinical Nutritionist.
    /// Returns exactly THREE specific adjustments based on the past 7 days vs the user's goals/allergies.
    func generateSundayCalibration(
        profileSummary: String,
        weekStats: String
    ) async throws -> CalibrationResult {
        let system = """
        You are a Senior PhD Clinical Nutritionist running the user's weekly 'Sunday Calibration'.
        Read the user's profile (goals, conditions, allergies, medications, daily targets) and the last 7 days of macronutrient + mealScore data.
        Identify the THREE most impactful adjustments for the coming week. Each must be:
        - Specific (cite a day, meal, macro, or score from the data when possible).
        - Actionable (a measurable behavior change, e.g. 'add 15g fiber at lunch').
        - Aligned with the user's goals and respectful of allergies / conditions.
        Tone: warm, encouraging, sanctuary-like, never scolding. No markdown.
        Return STRICT JSON only:
        {"summary":"one-sentence weekly observation, ≤22 words","pivots":[{"title":"≤6 word headline","body":"1-2 sentence specific recommendation"}]}
        Always return exactly 3 pivots.
        """
        let user = """
        USER PROFILE:
        \(profileSummary)

        LAST 7 DAYS:
        \(weekStats)

        Generate the Sunday Calibration now.
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "temperature": 0.5,
            "max_tokens": 1200,
        ]
        let raw = try await postChat(body: body)
        return try decode(CalibrationResult.self, from: raw)
    }

    // MARK: - Daily PhD Directive

    /// Generate a 15-word PhD focus directive based on today's snapshot.
    /// Returns a single sentence, no markdown.
    func generateDailyDirective(
        profileSummary: String,
        yesterdayStats: String,
        currentHydration: String
    ) async throws -> String {
        let system = """
        You are a PhD Nutritionist. Provide a single, warm, encouraging daily focus directive of EXACTLY 15 words or fewer.
        Reference the user's profile, yesterday's performance, and today's hydration so far.
        No greetings, no markdown, no quotation marks. Plain prose only. End with a period.
        """
        let user = """
        Profile: \(profileSummary)
        Yesterday: \(yesterdayStats)
        Hydration today: \(currentHydration)
        Write the 15-word focus directive now.
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "temperature": 0.6,
            "max_tokens": 120,
        ]
        let raw = try await postChat(body: body)
        return raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    // MARK: - The Sanctuary — Stewardship moderation

    /// Run the StewardshipFilter on a post or comment.
    /// Returns a verdict; the caller decides whether to publish or route to ReviewQueue.
    func stewardshipReview(content: String) async throws -> StewardshipVerdict {
        let system = """
        You are the Community Steward for a PhD-led health sanctuary called PrecisionCalMacroAutopsy.
        Your sole job is to flag content that is:
        - DISRESPECTFUL: harassment, slurs, hostile attacks on a person.
        - MEDICALLY DANGEROUS: pro-eating-disorder content, extreme fasting promotion, dangerous supplement claims, advising specific medication doses, advocating to ignore a doctor.
        - IMPROPER: spam, sexual content, hate speech, doxxing, illegal goods.
        Personal struggle, vulnerability, gentle disagreement, or imperfect meals are NEVER flagged. The Sanctuary embraces honest experiences.
        Return STRICT JSON only:
        {\"approved\":true|false,\"severity\":\"none|minor|major\",\"category\":\"disrespectful|dangerous|improper|none\",\"reason\":\"one short sentence; empty if approved\"}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": content],
            ],
            "temperature": 0.0,
            "max_tokens": 300,
        ]
        let raw = try await postChat(body: body)
        return try decode(StewardshipVerdict.self, from: raw)
    }

    // MARK: - The Creator's Lens — Innovation Aggregator

    /// Scan recent community posts and surface 1-3 product roadmap suggestions.
    func innovationAggregate(corpus: String) async throws -> InnovationReport {
        let system = """
        You are PrecisionCalMacroAutopsy's 'Innovation Aggregator' for the founder. Read recent community posts and identify recurring user pain points or feature requests that could become product opportunities.
        Be concrete. Quote 1-3 short fragments verbatim from the corpus to support each suggestion.
        Prioritize: high (mentioned by ≥3 users or safety-critical), medium (clear pattern, ≥2 users), low (single but compelling).
        Return STRICT JSON only:
        {\"summary\":\"one-sentence theme of the week (≤22 words)\",\"suggestions\":[{\"headline\":\"≤8 word product headline\",\"rationale\":\"1-2 sentences why this matters\",\"painPoint\":\"the underlying user need in 1 sentence\",\"priority\":\"high|medium|low\",\"sourceQuotes\":[\"...\"]}]}
        Return 1 to 3 suggestions, ordered by priority.
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "COMMUNITY CORPUS (top 50 recent posts/comments):\n\(corpus.prefix(12000))\n\nGenerate the roadmap report now."],
            ],
            "temperature": 0.4,
            "max_tokens": 1500,
        ]
        let raw = try await postChat(body: body)
        return try decode(InnovationReport.self, from: raw)
    }

    // MARK: - Cal — Nutrition Guide Chat

    /// Conversational nutrition guide (educational, non-clinical). Returns warm, plain prose tied to the user's profile.
    func chatWithCal(
        profileSummary: String,
        history: [DoctorChatTurn],
        userMessage: String
    ) async throws -> String {
        let system = """
        You are Cal, a friendly, well-read NUTRITION GUIDE inside the PrecisionCalMacroAutopsy app. You provide EDUCATIONAL nutrition information only. You are NOT a doctor, dietitian, nutritionist, therapist, or any other licensed professional, and you must never identify yourself as one or use a clinical title. Do not give diagnoses, prescriptions, dosages, or personalized medical or official nutrition advice. Frame guidance as general educational information that the user should discuss with a licensed professional before acting on.

        ANSWER DIRECTLY. Do NOT open with filler such as "Great question", "That's a thoughtful question", "I'm glad you asked", "Wonderful", or any other acknowledgement of the question itself. Skip pleasantries and start the FIRST sentence with the actual substantive educational answer, mechanism, or food guidance. Never restate the user's question back to them.

        Speak with warmth and clarity, but be direct, specific, and useful. Never scold.
        Always personalize using the USER PROFILE below — reference their goals, conditions, allergies, medications, and activity level when relevant — but frame everything as general educational information, not personal medical advice. Use language like "research suggests", "foods commonly studied for", "many people find", and "a registered dietitian can help you tailor this to your situation".
        Address how foods, nutrients, and meal timing are generally understood to relate to common conditions and goals. Provide concrete educational examples (specific foods, gram ranges, timing windows, swaps) rather than vague generalities.
        If a question is outside general nutrition education (e.g. specific medication dosing, diagnosis, mental health crisis, eating disorder treatment), give a brief general educational answer and clearly redirect the user to a licensed clinician for personal guidance.
        Keep replies focused and COMPLETE: 2–5 short paragraphs of plain prose. Always finish your final sentence — never trail off mid-thought. If you sense you're getting long, tighten earlier paragraphs so the closing thought, citations, and disclaimer all fit. Use a single short list ONLY when itemizing concrete steps. No markdown headings, no asterisks, no bold.

        CITATIONS — REQUIRED:
        Any factual nutrition or physiology claim must be supported by a numbered citation like [1], [2] placed inline at the end of the relevant sentence.
        After the prose, add a single line break and a 'Sources:' section listing each citation as:
            [1] Source Name — short descriptor (Year if relevant)
        Prefer authoritative sources: NIH / NIH ODS, USDA FoodData Central, WHO, CDC, Mayo Clinic, Harvard T.H. Chan School of Public Health, Cleveland Clinic, peer-reviewed journals (PubMed PMID), or Academy of Nutrition and Dietetics. Use 1–4 citations per reply. Never invent sources; if uncertain, omit the claim.

        EDUCATIONAL DISCLAIMER — MANDATORY ON EVERY REPLY:
        End every reply with this exact line on its own (no variation):
            Educational nutrition information only — not medical or official nutrition advice. Consult a licensed healthcare professional.

        USER PROFILE:
        \(profileSummary)
        """
        var messages: [[String: Any]] = [["role": "system", "content": system]]
        for turn in history.suffix(24) {
            messages.append(["role": turn.role, "content": turn.content])
        }
        messages.append(["role": "user", "content": userMessage])
        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.6,
            "max_tokens": 2200,
        ]
        let raw = try await postChat(body: body)
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Defensive scrub: strip any clinical title the model may still emit.
        cleaned = Self.stripClinicalTitles(from: cleaned)
        // Guarantee the per-reply educational disclaimer is present, even if the model omits it.
        let disclaimer = "Educational nutrition information only — not medical or official nutrition advice. Consult a licensed healthcare professional."
        let lowered = cleaned.lowercased()
        if !(lowered.contains("educational") && lowered.contains("not medical")) {
            cleaned += "\n\n" + disclaimer
        }
        return cleaned
    }

    /// Remove any clinical self-identification the model may emit
    /// (e.g. "Dr. PrecisionCalMacroAutopsy", "Dr. Cal", "Cal, PhD", "PhD Nutritionist").
    nonisolated static func stripClinicalTitles(from text: String) -> String {
        var out = text
        let patterns: [(String, String)] = [
            ("Dr\\.?\\s*PrecisionCalMacroAutopsy", "Cal"),
            ("Dr\\.?\\s*Precision\\s*Cal", "Cal"),
            ("Dr\\.?\\s*Cal\\b", "Cal"),
            ("\\bCal,\\s*Ph\\.?D\\.?", "Cal"),
            ("\\bCal\\s+Ph\\.?D\\.?", "Cal"),
            ("\\bPh\\.?D\\.?\\s+Nutritionist\\b", "nutrition guide"),
            ("\\bPh\\.?D\\.?\\s+Clinical\\s+Nutritionist\\b", "nutrition guide"),
            ("\\bPh\\.?D\\.?\\s+Dietitian\\b", "nutrition guide"),
        ]
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(out.startIndex..., in: out)
                out = regex.stringByReplacingMatches(in: out, options: [], range: range, withTemplate: replacement)
            }
        }
        return out
    }

    // MARK: - 6-Pass Sequential Chain

    func analyzeChain(
        imageData: Data,
        onProgress: @escaping @Sendable (AnalysisEvent) -> Void
    ) async throws -> MealAnalysisResult {
        let base64 = try resizeForUpload(imageData: imageData, maxBytes: 1_400_000)

        // Pass 1 — Isolation (Vision): enumerate and isolate every food item. Fall back if it fails.
        let p1: Pass1Output
        do {
            p1 = try await runPass1(base64: base64)
        } catch {
            print("[AIService] Pass1 (Isolation) failed (\(error)) — falling back to single-shot analysis.")
            return try await singleShotFallback(base64: base64, onProgress: onProgress)
        }
        guard !p1.items.isEmpty else {
            print("[AIService] Pass1 (Isolation) returned no items — falling back to single-shot analysis.")
            return try await singleShotFallback(base64: base64, onProgress: onProgress)
        }
        let p1ForFallback = p1  // capture for fallback routes that need the canonical item list
        let title = (p1.title?.isEmpty == false ? p1.title! : defaultTitle(from: p1.items))
        onProgress(.pass1Identified(items: p1.items.map { $0.name }, title: title))

        // Pass 2 — Lipid Sheen Discovery (Vision): wide-angle surface-physics reflectivity scan.
        // Best-effort: a failure degrades gracefully but still advances the pipeline.
        let discovery = (try? await runLipidDiscovery(base64: base64, p1: p1))
            ?? LipidDiscoveryOutput(candidates: [], note: nil)
        onProgress(.pass2LipidDiscovered)

        // Pass 3 — High-Res Macro-Zoom Verification (Vision): magnified micro-texture/viscosity
        // check targeting the candidate regions surfaced by Pass 2. Best-effort.
        let lipid = (try? await runLipidVerification(base64: base64, p1: p1, discovery: discovery))
            ?? Pass5Output(adjustments: [], summaryNote: nil)
        onProgress(.pass3LipidVerified)

        // Pass 4 — Dimensional (Vision): spatial volume + gram estimation. Fall back if it fails.
        let p2: Pass2Output
        do {
            let p2Raw = try await runPass2(base64: base64, p1: p1)
            // VOLUMETRIC DRIFT GUARDRAIL: clamp discrete-item estimates to the
            // anchored range around count × reference unit weight, then enforce
            // portion-reality caps for garnishes, sauces, and proteins.
            let anchored = anchorDiscreteWeights(p1Items: p1.items, weights: p2Raw)
            p2 = clampReasonableWeights(p1Items: p1.items, weights: anchored)
        } catch {
            print("[AIService] Pass4 (Dimensional) failed (\(error)) — falling back to single-shot.")
            return try await singleShotFallback(base64: base64, p1: p1ForFallback, p2: nil, onProgress: onProgress)
        }
        onProgress(.pass4Weighed)

        // Pass 5 — Comparison (Data Mapping): cross-reference against USDA / verified databases.
        let p3: Pass3Output
        do {
            p3 = try await runPass3(p1: p1, p2: p2)
        } catch {
            print("[AIService] Pass5 (Comparison) failed (\(error)) — falling back to single-shot.")
            return try await singleShotFallback(base64: base64, p1: p1ForFallback, p2: p2, onProgress: onProgress)
        }
        onProgress(.pass5Mapped)

        // Pass 6 — Synthesis (Cognitive): senior QC consolidates every layer into the final report.
        let p4: Pass4Output
        do {
            p4 = try await runPass4(p1: p1, p3: p3)
        } catch {
            print("[AIService] Pass6 (Synthesis) failed (\(error)) — falling back to single-shot.")
            return try await singleShotFallback(base64: base64, p1: p1ForFallback, p2: p2, onProgress: onProgress)
        }
        guard !p4.items.isEmpty else {
            print("[AIService] Pass6 (Synthesis) returned no items — falling back to single-shot.")
            return try await singleShotFallback(base64: base64, p1: p1ForFallback, p2: p2, onProgress: onProgress)
        }

        // Consolidate the verified lipid adjustments (discovered in Pass 2, confirmed in Pass 3)
        // into the final synthesized payload.
        let p5 = lipid
        let finalTitle = (p4.title?.isEmpty == false ? p4.title! : title)

        // STRUCTURAL INTEGRITY GUARDRAIL:
        // Downstream passes (weighing → USDA mapping → synthesis) occasionally drop sides or
        // zero-out carbohydrate macros on identified starches/vegetables. Reconcile the
        // synthesized items back against the canonical Pass 1 enumeration: re-attach any
        // dropped item from baseline values, and backfill 0-carb/0-fiber/0-sugar plant foods.
        let reconciledItems = reconcileItems(p1Items: p1.items, weights: p2.items, mapped: p4.items)

        // Integrity: 1g of detected hidden fat == 9 kcal. We derive calories from grams
        // (never trusting the model's kcal) so totals stay perfectly synchronized.
        let mergedItems: [MealAnalysisResult.Item] = reconciledItems.map { item in
            let adj = p5.adjustments.first { matchName($0.name, item.name) && $0.lipidSheenDetected }
            let addedFat = max(0, adj?.addedFatG ?? 0)
            let addedKcal = (addedFat * 9).rounded()
            return MealAnalysisResult.Item(
                name: item.name,
                preparation: item.preparation,
                grams: item.grams,
                calories: item.calories + addedKcal,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat + addedFat,
                fiber: item.fiber,
                sugar: item.sugar,
                waterMl: item.waterMl,
                weightSource: item.weightSource
            )
        }
        let qcCombined: String = {
            let base = p4.qcNotes ?? ""
            guard let note = p5.summaryNote, !note.isEmpty else { return base }
            if base.isEmpty { return note }
            return base + " " + note
        }()
        // Hidden Fat telemetry — aggregate all confirmed lipid adjustments (9 kcal/g enforced).
        let confirmed = p5.adjustments.filter { $0.lipidSheenDetected }
        let sheenDetected = !confirmed.isEmpty
        let addedFatTotal = confirmed.reduce(0.0) { $0 + max(0, $1.addedFatG) }
        let addedKcalTotal = (addedFatTotal * 9).rounded()
        let topAdj = confirmed.max { max(0, $0.addedFatG) < max(0, $1.addedFatG) }
        let targetItem = topAdj?.name ?? ""
        let mechanism: String = {
            guard sheenDetected else { return "" }
            let fat = topAdj?.inferredFat
            if let fat, !fat.isEmpty, fat.lowercased() != "null" {
                return "\(fat) sheen confirmation via Pass 3 macro-zoom"
            }
            return "lipid sheen confirmation via Pass 3 macro-zoom"
        }()

        // Fat subcategories — reconcile sat + unsat + trans to the merged total fat.
        let totalFat = mergedItems.reduce(0.0) { $0 + $1.fat }
        let sat = max(0, min(totalFat, p4.saturatedFatG ?? (totalFat * 0.32).rounded()))
        let trans = max(0, min(totalFat - sat, p4.transFatG ?? 0))
        let unsat = max(0, totalFat - sat - trans)

        let result = MealAnalysisResult(
            title: finalTitle,
            items: mergedItems,
            metabolicImpact: (p4.metabolicImpact?.isEmpty == false ? p4.metabolicImpact! : "Balanced"),
            mealScore: resolveMealScore(modelValue: p4.mealScore, items: mergedItems, saturatedFat: sat),
            qcNotes: qcCombined,
            lipidSheenDetected: sheenDetected,
            lipidNote: p5.summaryNote ?? "",
            saturatedFat: sat,
            unsaturatedFat: unsat,
            transFat: trans,
            hiddenFatAddedCalories: addedKcalTotal,
            hiddenFatAddedFatG: addedFatTotal,
            hiddenFatTargetItem: targetItem,
            hiddenFatMechanism: mechanism,
            micronutrients: (p4.micronutrients ?? []).filter { $0.amountMg >= 0 }
        )
        let totalCal = mergedItems.reduce(0.0) { $0 + $1.calories }
        print("[AIService] Final result: \(result.title) — \(mergedItems.count) item(s), \(Int(totalCal)) kcal: \(mergedItems.map { $0.name }.joined(separator: ", "))")
        if mergedItems.count < 2, countFoodTerms(in: finalTitle) > 1 {
            print("[AIService] WARNING: final result under-enumerated despite title implying multiple foods.")
        }
        onProgress(.pass6Synthesized(result))
        return result
    }

    /// Fallback: ask the model to produce the full report in one shot. Used when the 6-pass chain fails.
    /// Still sequences across all 6 events so the UI advances cleanly from 1 → 6.
    /// If the earlier chain already enumerated items (p1) and/or estimated weights (p2), those
    /// are passed through so the final result can be rebuilt against the Pass 1 canonical list —
    /// no identified item is silently dropped.
    private func singleShotFallback(
        base64: String,
        p1: Pass1Output? = nil,
        p2: Pass2Output? = nil,
        onProgress: @escaping @Sendable (AnalysisEvent) -> Void
    ) async throws -> MealAnalysisResult {
        var result = try await runFullAnalysis(base64: base64, p1: p1) { items, title in
            onProgress(.pass1Identified(items: items, title: title))
        }
        // If the chain already identified items, ensure the single-shot result keeps every one of them.
        let clamped = clampResultItems(result.items)
        let finalized = finalizeItems(
            p1Items: p1?.items ?? [],
            weights: p2?.items ?? [],
            modelItems: clamped
        )
        if finalized.count != result.items.count {
            print("[AIService] Single-shot fallback recovered \(finalized.count - result.items.count) dropped item(s).")
        }
        result = MealAnalysisResult(
            title: result.title,
            items: finalized,
            metabolicImpact: result.metabolicImpact,
            mealScore: result.mealScore,
            qcNotes: result.qcNotes,
            lipidSheenDetected: result.lipidSheenDetected,
            lipidNote: result.lipidNote,
            saturatedFat: result.saturatedFat,
            unsaturatedFat: result.unsaturatedFat,
            transFat: result.transFat,
            hiddenFatAddedCalories: result.hiddenFatAddedCalories,
            hiddenFatAddedFatG: result.hiddenFatAddedFatG,
            hiddenFatTargetItem: result.hiddenFatTargetItem,
            hiddenFatMechanism: result.hiddenFatMechanism,
            micronutrients: result.micronutrients
        )
        onProgress(.pass2LipidDiscovered)
        onProgress(.pass3LipidVerified)
        onProgress(.pass4Weighed)
        onProgress(.pass5Mapped)
        onProgress(.pass6Synthesized(result))
        return result
    }

    private func matchName(_ a: String, _ b: String) -> Bool {
        let na = a.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let nb = b.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if na == nb { return true }
        return na.contains(nb) || nb.contains(na)
    }

    // MARK: - Discrete unit anchoring (volumetric drift guardrail)

    /// Clamp dimensional estimates for discrete items (e.g. "4 pancakes") into
    /// [0.5, 2.0] × (count × reference unit weight). Identical re-scans can then
    /// never swing by hundreds of grams: a 4-pancake stack is anchored near 240g,
    /// not treated as one unconstrained mass. Estimates without a reference unit
    /// pass through unchanged.
    private func anchorDiscreteWeights(p1Items: [Pass1Item], weights: Pass2Output) -> Pass2Output {
        var items = weights.items
        for idx in items.indices {
            guard let p1 = p1Items.first(where: { matchName($0.name, items[idx].name) }),
                  p1.isDiscrete == true,
                  let count = p1.discreteCount, count >= 1,
                  let unitG = UnitReference.gramsPerUnit(forName: p1.name) else { continue }
            let anchor = Double(count) * unitG
            let estimate = items[idx].estimatedWeightG
            let clamped = min(max(estimate, anchor * 0.5), anchor * 2.0).rounded()
            if abs(clamped - estimate) > 1 {
                items[idx] = Pass2Item(name: items[idx].name, preparation: items[idx].preparation, estimatedWeightG: clamped)
                print("[AIService] Drift guardrail: '\(p1.name)' ×\(count) anchored to \(Int(clamped))g (model said \(Int(estimate))g; reference \(Int(anchor))g).")
            }
        }
        return Pass2Output(items: items, totalWeightG: items.reduce(0.0) { $0 + $1.estimatedWeightG })
    }

    /// Gram weight for a dropped discrete item: count × reference unit weight.
    private func discreteAnchoredGrams(for p1: Pass1Item) -> Double? {
        guard p1.isDiscrete == true,
              let count = p1.discreteCount, count >= 1,
              let unitG = UnitReference.gramsPerUnit(forName: p1.name) else { return nil }
        return (Double(count) * unitG).rounded()
    }

    /// Hard safety clamp for amorphous/garnish/protein items that the model frequently overestimates.
    /// This is a last-resort guardrail; prompts already ask for reasonable portions, but vision models
    /// can confuse a heavy sprinkle of seeds with a 100g side dish or a single bowl protein with 1kg.
    private func clampReasonableWeights(p1Items: [Pass1Item], weights: Pass2Output) -> Pass2Output {
        var items = weights.items
        for idx in items.indices {
            let name = items[idx].name.lowercased()
            let category = p1Items.first { matchName($0.name, items[idx].name) }?.category?.lowercased() ?? ""
            let estimate = items[idx].estimatedWeightG
            var clamped = estimate

            // Garnish / sprinkle items: seeds, herbs, chopped scallions, chili flakes, spices.
            let garnish = ["sesame", "seed", "seeds", "scallion", "green onion", "spring onion",
                           "chili flake", "pepper flake", "red pepper flake", "flake",
                           "herb", "cilantro", "parsley", "basil", "dill", "chive",
                           "oregano", "thyme", "rosemary", "spice", "spices"]
            if garnish.contains(where: { name.contains($0) }) {
                clamped = min(clamped, 15)
                if clamped != estimate {
                    print("[AIService] Garnish clamp: '\(items[idx].name)' \(Int(estimate))g → \(Int(clamped))g.")
                }
            }

            // Sauce / glaze / dressing: usually a coating, not a soup.
            let sauce = ["glaze", "sauce", "dressing", "vinaigrette", "gravy", "ketchup",
                         "mustard", "mayo", "mayonnaise", "dip", "salsa", "marinara"]
            if sauce.contains(where: { name.contains($0) }) {
                clamped = min(clamped, 80)
                if clamped != estimate {
                    print("[AIService] Sauce clamp: '\(items[idx].name)' \(Int(estimate))g → \(Int(clamped))g.")
                }
            }

            // Potato wedges / fries: a single wedge is ~40-70g; total plate rarely exceeds 350g.
            let wedgeFries = ["wedge", "fries", "fry", "roasted potato"]
            if wedgeFries.contains(where: { name.contains($0) }) {
                clamped = min(clamped, 350)
                if clamped != estimate {
                    print("[AIService] Wedge/fries clamp: '\(items[idx].name)' \(Int(estimate))g → \(Int(clamped))g.")
                }
            }

            // Protein in a single meal: rarely exceeds 350g in a regular bowl/plate.
            let proteinKeywords = ["chicken", "beef", "steak", "pork", "lamb", "fish", "salmon",
                                   "tuna", "cod", "shrimp", "tofu", "tempeh", "seitan"]
            let isProtein = category == "protein" || proteinKeywords.contains(where: { name.contains($0) })
            if isProtein {
                clamped = min(clamped, 350)
                if clamped != estimate {
                    print("[AIService] Protein clamp: '\(items[idx].name)' \(Int(estimate))g → \(Int(clamped))g.")
                }
            }

            items[idx] = Pass2Item(name: items[idx].name, preparation: items[idx].preparation, estimatedWeightG: clamped)
        }
        return Pass2Output(items: items, totalWeightG: items.reduce(0.0) { $0 + $1.estimatedWeightG })
    }

    /// Apply the same portion sanity clamps to final result items (used by single-shot fallback).
    private func clampResultItems(_ items: [MealAnalysisResult.Item]) -> [MealAnalysisResult.Item] {
        return items.map { item in
            let name = item.name.lowercased()
            var grams = item.grams
            var calories = item.calories
            var protein = item.protein
            var carbs = item.carbs
            var fat = item.fat
            var fiber = item.fiber
            var sugar = item.sugar

            if ["sesame", "seed", "seeds", "scallion", "green onion", "spring onion",
                "chili flake", "pepper flake", "herb", "cilantro", "parsley", "basil",
                "dill", "chive", "spice"].contains(where: { name.contains($0) }) {
                grams = min(grams, 15)
            } else if ["glaze", "sauce", "dressing", "vinaigrette", "gravy", "ketchup",
                       "mustard", "mayo", "dip", "salsa"].contains(where: { name.contains($0) }) {
                grams = min(grams, 80)
            } else if ["chicken", "beef", "steak", "pork", "lamb", "fish", "salmon",
                       "tuna", "cod", "shrimp", "tofu", "tempeh"].contains(where: { name.contains($0) }) {
                grams = min(grams, 350)
            } else if ["wedge", "fries", "fry", "roasted potato"].contains(where: { name.contains($0) }) {
                grams = min(grams, 350)
            }

            if grams != item.grams {
                // Recalibrate macros proportionally to the new weight so totals stay consistent.
                let ratio = grams / max(item.grams, 1)
                calories = (item.calories * ratio).rounded()
                protein = (item.protein * ratio).rounded()
                carbs = (item.carbs * ratio).rounded()
                fat = (item.fat * ratio).rounded()
                fiber = (item.fiber * ratio).rounded()
                sugar = (item.sugar * ratio).rounded()
                print("[AIService] Final clamp: '\(item.name)' \(Int(item.grams))g → \(Int(grams))g.")
            }

            return MealAnalysisResult.Item(
                name: item.name,
                preparation: item.preparation,
                grams: grams,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                fiber: fiber,
                sugar: sugar,
                waterMl: item.waterMl,
                weightSource: item.weightSource
            )
        }
    }

    // MARK: - Meal score

    /// Resolve the final meal score. Trusts the model's value when it's a sane non-zero number;
    /// otherwise derives a deterministic 0–100 score from the actual macros so the reveal screen
    /// never shows a flat 0 just because synthesis omitted the field.
    private func resolveMealScore(modelValue: Int?, items: [MealAnalysisResult.Item], saturatedFat: Double) -> Int {
        if let v = modelValue, v > 0 { return max(0, min(100, v)) }
        return computeFallbackScore(items: items, saturatedFat: saturatedFat)
    }

    /// Deterministic nutrition score from macros: rewards protein adequacy and fiber,
    /// penalizes heavy sugar and saturated-fat loads. Clamped to 30–96 so it always reads as a real grade.
    private func computeFallbackScore(items: [MealAnalysisResult.Item], saturatedFat: Double) -> Int {
        let calories = items.reduce(0.0) { $0 + $1.calories }
        let protein = items.reduce(0.0) { $0 + $1.protein }
        let fiber = items.reduce(0.0) { $0 + $1.fiber }
        let sugar = items.reduce(0.0) { $0 + $1.sugar }
        guard calories > 0 else { return 60 }

        var score = 62.0
        // Protein density (g per 100 kcal): ~7g/100kcal is excellent.
        let proteinDensity = protein / (calories / 100)
        score += min(18, proteinDensity * 2.6)
        // Fiber: meaningful fiber lifts the score.
        score += min(16, fiber * 1.6)
        // Sugar load relative to calories penalizes sugary meals.
        let sugarRatio = (sugar * 4) / calories
        score -= min(22, sugarRatio * 60)
        // Saturated-fat load penalty.
        let satRatio = (saturatedFat * 9) / calories
        score -= min(16, satRatio * 45)

        return Int(max(30, min(96, score.rounded())))
    }

    // MARK: - Structural integrity (item reconciliation & macro backfill)

    /// Round to one decimal place.
    private func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }

    /// Reconcile the synthesized nutrition items against the canonical Pass 1 enumeration so
    /// that no identified item is silently dropped and no plant/starch item renders 0 carbs.
    private func reconcileItems(
        p1Items: [Pass1Item],
        weights: [Pass2Item],
        mapped: [Pass3Item]
    ) -> [MealAnalysisResult.Item] {
        let modelItems = mapped.map { backfill(item: $0, name: $0.name, category: nil) }
        return finalizeItems(p1Items: p1Items, weights: weights, modelItems: modelItems)
    }

    /// Ensure the final item list contains every item identified in Pass 1, using model-derived
    /// nutrition when a name match exists and reconstructing any missing item from its best
    /// available weight (Pass 2 → discrete unit reference → category default) plus the USDA baseline.
    /// This is the ultimate source-of-truth guardrail: no identified food may be dropped.
    /// Weight source is preserved: matched model items are "visual"; rebuilt items use the
    /// Pass 2 visual weight if available, otherwise fall back to a default reference weight.
    private func finalizeItems(
        p1Items: [Pass1Item],
        weights: [Pass2Item],
        modelItems: [MealAnalysisResult.Item]
    ) -> [MealAnalysisResult.Item] {
        var output: [MealAnalysisResult.Item] = []
        var consumed = [Bool](repeating: false, count: modelItems.count)

        for p1 in p1Items {
            var matchIdx: Int? = nil
            for i in modelItems.indices where !consumed[i] {
                if matchName(modelItems[i].name, p1.name) { matchIdx = i; break }
            }
            if let i = matchIdx {
                consumed[i] = true
                output.append(modelItems[i])
            } else {
                // Item enumerated in Pass 1 but dropped by the nutrition passes — rebuild it.
                let source: String
                let grams: Double
                if let weight = weights.first(where: { matchName($0.name, p1.name) }) {
                    grams = weight.estimatedWeightG
                    source = "visual"
                } else if let anchored = discreteAnchoredGrams(for: p1) {
                    grams = anchored
                    source = "default"
                } else {
                    grams = FoodBaseline.defaultGrams(category: p1.category)
                    source = "default"
                }
                print("[AIService] Finalize: re-attaching dropped item '\(p1.name)' (\(Int(grams))g) from \(source) baseline.")
                output.append(baselineItem(name: p1.name, preparation: p1.preparation, grams: grams, category: p1.category, weightSource: source))
            }
        }
        // Preserve any model-returned item that didn't match a Pass 1 entry (rare).
        for i in modelItems.indices where !consumed[i] {
            output.append(modelItems[i])
        }
        return output.isEmpty ? modelItems : output
    }

    /// Convert a mapped nutrition item into a final item, backfilling zeroed carbohydrate macros
    /// for plant/starch/fruit/sauce foods from USDA baseline values (calories kept in sync at 4 kcal/g).
    /// Source is "visual" because the item originated from a model-derived pass (even if macros were repaired).
    private func backfill(item: Pass3Item, name: String, category: String?) -> MealAnalysisResult.Item {
        var carbs = item.carbs
        var fiber = item.fiber
        var sugar = item.sugar
        var calories = item.calories

        if FoodBaseline.carriesCarbs(name: name, category: category) {
            let profile = FoodBaseline.profile(forName: name, category: category)
            let grams = item.grams > 0 ? item.grams : FoodBaseline.defaultGrams(category: category)
            let factor = grams / 100
            if carbs <= 0, profile.carbPer100 > 0 {
                let newCarbs = (profile.carbPer100 * factor).rounded()
                calories += max(0, newCarbs - carbs) * 4
                carbs = newCarbs
            }
            if fiber <= 0, profile.fiberPer100 > 0 { fiber = round1(profile.fiberPer100 * factor) }
            if sugar <= 0, profile.sugarPer100 > 0 { sugar = round1(profile.sugarPer100 * factor) }
            // Sugar + fiber cannot exceed total carbs.
            if sugar > carbs { sugar = carbs }
        }

        return MealAnalysisResult.Item(
            name: item.name,
            preparation: item.preparation,
            grams: item.grams,
            calories: calories,
            protein: item.protein,
            carbs: carbs,
            fat: item.fat,
            fiber: fiber,
            sugar: sugar,
            waterMl: item.waterMl,
            weightSource: "visual"
        )
    }

    /// Build a complete item entirely from baseline USDA values (used when a pass dropped the item).
    /// Source defaults to "default" because the weight was not derived from the model's visual estimate.
    private func baselineItem(name: String, preparation: String, grams: Double, category: String?, weightSource: String = "default") -> MealAnalysisResult.Item {
        let profile = FoodBaseline.profile(forName: name, category: category)
        let g = grams > 0 ? grams : 100
        let factor = g / 100
        return MealAnalysisResult.Item(
            name: name,
            preparation: preparation,
            grams: g,
            calories: (profile.kcalPer100 * factor).rounded(),
            protein: round1(profile.proteinPer100 * factor),
            carbs: (profile.carbPer100 * factor).rounded(),
            fat: round1(profile.fatPer100 * factor),
            fiber: round1(profile.fiberPer100 * factor),
            sugar: round1(profile.sugarPer100 * factor),
            waterMl: 0,
            weightSource: weightSource
        )
    }

    private func runFullAnalysis(
        base64: String,
        p1: Pass1Output? = nil,
        onItemsIdentified: @Sendable @escaping ([String], String) -> Void
    ) async throws -> MealAnalysisResult {
        let identifiedContext: String = {
            guard let p1, !p1.items.isEmpty else { return "" }
            let list = p1.items.map { "- \($0.name)" }.joined(separator: "\n")
            return """

            CANONICAL ITEM LIST — these items were already identified in the meal. You MUST return ALL of them in your final JSON, each as its own entry with a real gram weight and full nutrition. Do not merge any of these into another item, do not drop "minor" items, and do not return fewer items than listed:
            \(list)
            """
        }()
        let system = """
        You are PrecisionCalMacroAutopsy, a senior nutritionist with computer-vision expertise. Analyze the meal photo end-to-end:
        1. EXHAUSTIVELY identify every distinct food item, side, vegetable, starch, sauce, dip, garnish, and condiment visible. Do NOT collapse sides into the main dish. Typical plates have 3–6 items; if you only see one, look again for missed carbs/vegetables/sauces. Large visible components like a broccoli cluster or grain mound are NEVER optional.\(identifiedContext)
        2. Estimate gram weights from plate size and depth cues. Use density constants (g/cm^3): chicken 1.05, beef 1.05, fish 1.0, rice 0.85, quinoa 0.75, pasta 1.10, bread 0.30, oil 0.92, butter 0.91, leafy veg 0.30, root veg 0.65, broccoli 0.35, beans 1.20, cheese 1.10, fruit 0.85. For DISCRETE countable foods (pancakes, waffles, eggs, bread slices, burger patties, sausages, whole fruit, lemon wedges), COUNT the units and compute unit weight × count (e.g. 4 medium pancakes ≈ 4 × 60g = 240g) — never treat a multi-unit stack as one unconstrained mass.
        PORTION REALITY CHECK — MANDATORY:
        - A single restaurant bowl or plate should rarely exceed 1,200g total.
        - A single serving of chicken/pork/beef/fish in a bowl is typically 120–250g cooked; only large platters should exceed 300g.
        - A sprinkle of seeds, chopped herbs, scallions, or chili flakes is a GARNISH, not a side dish: 2–10g total. Never return 100g of sesame seeds.
        - A lemon/lime wedge is ~58g each; count the wedges and multiply.
        - A sauce or glaze coating is usually 15–60g total, not 100g+ unless swimming in it.
        - Grains (rice, quinoa) in a bowl are typically 120–250g cooked.
        - Vegetables such as broccoli, carrots, or peppers should reflect visual coverage: a large portion is 150–250g, not 50g.
        - A single potato wedge or fry is ~40–70g. Five wedges should be 200–350g total, not 1kg. Count the wedges and multiply.
        3. Map weights to USDA FoodData Central nutrition. Account for prep (frying adds oil; grilling does not). Fiber and sugar MUST be non-zero for plant foods (carrots ~2.8g fiber/100g, potatoes ~2.2g/100g, broccoli ~2.6g/100g, tomato ~1.2g/100g, quinoa ~2.8g/100g, BBQ sauce ~25g sugar/100g, sesame seeds ~12g fiber/100g, fruit ~2–10g sugar/100g). Returning 0 fiber and 0 sugar on a meal with vegetables/starch/fruit/sauce is a BUG.
        4. QC: kcal/g should be 0.5 to 6 for most foods, 9 for pure oil, 0.2 to 0.4 for leafy veg. Reconcile macros (4/4/9 kcal per g). Adjust water for cooking method. Cooked chicken breast is ~31g protein/100g — do not over-attribute protein. Do not label a sauced/glazed item as "fried" unless it has visible batter/breading; glossy sauce is "glazed".
        ITEM CONTINUITY GUARANTEE: The final JSON must contain a separate `items` entry for every food you can see. A breakfast plate with toast, avocado, egg, and seasonings must return four or more items, not one merged "toast" entry. A grain bowl with chicken, quinoa, broccoli, lemon wedges, sesame seeds, and scallions must return six or more items.
        Score the meal 0 to 100 on protein adequacy, fiber, sugar load, prep, and balance.
        metabolicImpact must be ONE short label like "Steady energy", "Quick spike", "Slow burn", "Recovery boost", or "Light & lean".
        qcNotes is ONE concise sentence.
        GRANULAR BREAKDOWN — required, numeric only (never strings or ranges):
        - Fat subcategories for the WHOLE meal: saturatedFatG, unsaturatedFatG, transFatG; they MUST sum to total fat grams.
        - micronutrients: array of notable micronutrients (Sodium, Potassium, Magnesium, Calcium, Iron, Vitamin C, etc.) each with amountMg (convert mcg to mg) and pctDailyValue (integer percent). Include at least 4 for a real meal.
        Return STRICT JSON only with this exact shape:
        {"title":"short meal name","items":[{"name":"...","preparation":"grilled|fried|baked|raw|steamed|boiled|roasted|sauteed|glazed|sauced|other","grams":number,"calories":number,"protein":number,"carbs":number,"fat":number,"fiber":number,"sugar":number,"waterMl":number}],"metabolicImpact":"...","mealScore":number,"qcNotes":"...","saturatedFatG":number,"unsaturatedFatG":number,"transFatG":number,"micronutrients":[{"name":"Sodium","amountMg":number,"pctDailyValue":number}]}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": "Analyze this meal. Return ONLY the JSON object specified."],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ]],
            ],
            "temperature": 0.0,
            "seed": Self.deterministicSeed,
            "max_tokens": 4096,
        ]
        let raw = try await postChat(body: body)
        let p4 = try decode(Pass4Output.self, from: raw)
        guard !p4.items.isEmpty else { throw AIError.visionFailed }

        let title = (p4.title?.isEmpty == false ? p4.title! : defaultTitle(fromItems: p4.items.map { $0.name }))
        onItemsIdentified(p4.items.map { $0.name }, title)

        // Backfill zeroed carbohydrate macros on any plant/starch item the single-shot model returned.
        let fallbackItems = p4.items.map { backfill(item: $0, name: $0.name, category: nil) }

        let totalFat = fallbackItems.reduce(0.0) { $0 + $1.fat }
        let sat = max(0, min(totalFat, p4.saturatedFatG ?? (totalFat * 0.32).rounded()))
        let trans = max(0, min(totalFat - sat, p4.transFatG ?? 0))
        let unsat = max(0, totalFat - sat - trans)

        return MealAnalysisResult(
            title: title,
            items: fallbackItems,
            metabolicImpact: (p4.metabolicImpact?.isEmpty == false ? p4.metabolicImpact! : "Balanced"),
            mealScore: resolveMealScore(modelValue: p4.mealScore, items: fallbackItems, saturatedFat: sat),
            qcNotes: p4.qcNotes ?? "",
            lipidSheenDetected: false,
            lipidNote: "",
            saturatedFat: sat,
            unsaturatedFat: unsat,
            transFat: trans,
            hiddenFatAddedCalories: 0,
            hiddenFatAddedFatG: 0,
            hiddenFatTargetItem: "",
            hiddenFatMechanism: "",
            micronutrients: (p4.micronutrients ?? []).filter { $0.amountMg >= 0 }
        )
    }

    private func defaultTitle(fromItems names: [String]) -> String {
        let joined = names.prefix(3).map { $0.capitalized }.joined(separator: ", ")
        return joined.isEmpty ? "Meal" : joined
    }

    private func defaultTitle(from items: [Pass1Item]) -> String {
        let names = items.prefix(3).map { $0.name.capitalized }.joined(separator: ", ")
        return names.isEmpty ? "Meal" : names
    }

    // MARK: - Pass implementations

    /// Two-tier Pass 1: first ask for a plain enumerated list (model is more reliable at listing
    /// when not distracted by a complex JSON schema), then ask for the detailed JSON with that
    /// exact list. If the detailed JSON still collapses items, retry once with a sterner prompt
    /// that includes the previously enumerated names as a locked list.
    private func runPass1(base64: String) async throws -> Pass1Output {
        let enumerated = try await enumerateFoods(base64: base64)
        print("[AIService] Pre-enumeration found: \(enumerated.joined(separator: ", "))")
        let firstTry = try await runPass1Detail(base64: base64, enumerated: enumerated, strict: false)
        let mergedFirst = mergeEnumeration(enumerated: enumerated, into: firstTry)
        print("[AIService] Pass1 detail returned \(firstTry.items.count) item(s): \(firstTry.items.map { $0.name }.joined(separator: ", ")); merged to \(mergedFirst.items.count)")
        let detected = countFoodTerms(in: mergedFirst.title) + mergedFirst.items.count
        if mergedFirst.items.count < 2 && detected > 1 {
            print("[AIService] Pass1 under-enumerated (title implies \(detected) foods, got \(mergedFirst.items.count) items). Retrying with locked list.")
            let retry = try await runPass1Detail(base64: base64, enumerated: enumerated, strict: true)
            let mergedRetry = mergeEnumeration(enumerated: enumerated, into: retry)
            print("[AIService] Pass1 retry returned \(retry.items.count) item(s); merged to \(mergedRetry.items.count)")
            return mergedRetry.items.count >= mergedFirst.items.count ? mergedRetry : mergedFirst
        }
        return mergedFirst
    }

    /// Ensures the canonical Pass 1 item list contains every food from the pre-enumeration step,
    /// while collapsing duplicate or near-duplicate entries (e.g. "chicken pieces" and "orange-glazed
    /// chicken", or a coating and the item it coats) so the same food is not counted twice.
    private func mergeEnumeration(enumerated: [String], into output: Pass1Output) -> Pass1Output {
        var mergedNames: [String] = []
        for name in enumerated {
            let lower = name.lowercased().trimmingCharacters(in: .whitespaces)
            if lower.isEmpty { continue }
            if let existingIdx = mergedNames.firstIndex(where: { $0.lowercased().trimmingCharacters(in: .whitespaces) == lower }) {
                continue
            }
            // Merge a coating into the coated item: if this name is a sub-phrase of an already-kept item
            // (e.g. "orange glaze" inside "orange-glazed chicken") or vice versa, keep only the more
            // specific item (the longer one). This is a last-resort safety net beyond the prompt rules.
            if let subMatchIdx = mergedNames.firstIndex(where: { kept in
                let keptLower = kept.lowercased().trimmingCharacters(in: .whitespaces)
                return keptLower.contains(lower) || lower.contains(keptLower)
            }) {
                let kept = mergedNames[subMatchIdx].lowercased().trimmingCharacters(in: .whitespaces)
                if lower.count > kept.count {
                    mergedNames[subMatchIdx] = name
                }
                continue
            }
            mergedNames.append(name)
        }

        var existing = output.items
        var known = Set(existing.map { $0.name.lowercased().trimmingCharacters(in: .whitespaces) })
        for name in mergedNames {
            let key = name.lowercased().trimmingCharacters(in: .whitespaces)
            if known.contains(key) { continue }
            // If an existing item is a substring/superstring of this new item, merge into the longer name.
            if let idx = existing.firstIndex(where: { key.contains($0.name.lowercased().trimmingCharacters(in: .whitespaces)) || $0.name.lowercased().trimmingCharacters(in: .whitespaces).contains(key) }) {
                let existingName = existing[idx].name.lowercased().trimmingCharacters(in: .whitespaces)
                if key.count > existingName.count {
                    existing[idx] = Pass1Item(
                        name: name,
                        preparation: existing[idx].preparation,
                        visual: existing[idx].visual,
                        category: existing[idx].category,
                        isDiscrete: existing[idx].isDiscrete,
                        discreteCount: existing[idx].discreteCount,
                        estimatedSize: existing[idx].estimatedSize,
                        state: existing[idx].state
                    )
                    known.remove(existingName)
                    known.insert(key)
                }
                continue
            }
            let inferredCategory = inferCategory(for: name)
            existing.append(Pass1Item(
                name: name,
                preparation: inferPreparation(for: name),
                visual: "",
                category: inferredCategory,
                isDiscrete: false,
                discreteCount: 1,
                estimatedSize: "",
                state: ""
            ))
            known.insert(key)
        }
        return Pass1Output(items: existing, plateDetails: output.plateDetails, depthCues: output.depthCues, title: output.title)
    }

    private func inferCategory(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("chicken") || lower.contains("beef") || lower.contains("pork") || lower.contains("fish") || lower.contains("salmon") || lower.contains("tuna") || lower.contains("shrimp") || lower.contains("tofu") || lower.contains("egg") { return "protein" }
        if lower.contains("rice") || lower.contains("quinoa") || lower.contains("pasta") || lower.contains("noodle") || lower.contains("potato") || lower.contains("bread") || lower.contains("tortilla") || lower.contains("fries") || lower.contains("wedge") || lower.contains("oat") || lower.contains("bean") || lower.contains("lentil") || lower.contains("corn") { return "carb" }
        if lower.contains("broccoli") || lower.contains("carrot") || lower.contains("pepper") || lower.contains("onion") || lower.contains("tomato") || lower.contains("spinach") || lower.contains("kale") || lower.contains("lettuce") || lower.contains("scallion") || lower.contains("mushroom") || lower.contains("zucchini") || lower.contains("squash") || lower.contains("pea") || lower.contains("green bean") || lower.contains("asparagus") || lower.contains("cauliflower") { return "veg" }
        if lower.contains("lemon") || lower.contains("lime") || lower.contains("orange") || lower.contains("apple") || lower.contains("banana") || lower.contains("berry") || lower.contains("grape") || lower.contains("avocado") { return "fruit" }
        if lower.contains("cheese") || lower.contains("yogurt") || lower.contains("milk") || lower.contains("sour cream") || lower.contains("butter") { return "dairy" }
        if lower.contains("sauce") || lower.contains("glaze") || lower.contains("dressing") || lower.contains("gravy") || lower.contains("vinaigrette") || lower.contains("ketchup") || lower.contains("bbq") || lower.contains("teriyaki") { return "sauce" }
        if lower.contains("oil") || lower.contains("sesame") || lower.contains("seed") || lower.contains("nut") || lower.contains("almond") || lower.contains("peanut") { return "fat" }
        return "other"
    }

    private func inferPreparation(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("glaze") || lower.contains("glazed") { return "glazed" }
        if lower.contains("sauce") || lower.contains("dressed") { return "sauced" }
        if lower.contains("roasted") || lower.contains("roast") { return "roasted" }
        if lower.contains("grilled") || lower.contains("grill") { return "grilled" }
        if lower.contains("fried") || lower.contains("crispy") { return "fried" }
        if lower.contains("steamed") || lower.contains("steam") { return "steamed" }
        if lower.contains("raw") || lower.contains("fresh") || lower.contains("wedge") { return "raw" }
        if lower.contains("sauteed") || lower.contains("sauté") { return "sauteed" }
        if lower.contains("baked") || lower.contains("bake") { return "baked" }
        return "other"
    }

    /// Step 1: get a plain numbered list of every distinct food. This avoids the model shortcutting
    /// by returning a single merged "bowl" item in JSON.
    private func enumerateFoods(base64: String) async throws -> [String] {
        let system = """
        You are a food-vision assistant. Look at the meal photo and list EVERY distinct edible component you can see.

        RULES:
        - Do not group items. "Bowl" is not an item; list the ingredients inside it.
        - Do not skip small items: seeds, scallions, lemon wedges, sauces, condiments, and garnishes all count.
        - A large broccoli cluster or grain mound is a PRIMARY item, not garnish.
        - Use the exact visible food name (e.g. "orange-glazed chicken", "quinoa", "roasted broccoli", "lemon wedges", "white sesame seeds", "black sesame seeds", "scallions").
        - NO DOUBLE LISTING. If the same food appears twice with different names, write it only once. "chicken pieces" and "orange-glazed chicken" are the SAME item. "sesame seeds" on the chicken and "sesame seeds" in a side dish are the SAME ingredient if they are identical — but if they are in clearly separate piles/bowls, you may list them twice.
        - COATINGS ARE PART OF THE ITEM. A glaze, sauce, marinade, or seasoning that coats a piece of chicken, tofu, or vegetables is NOT a separate item. Only list a sauce or glaze separately if it is a distinct puddle, side cup, or uncoated drizzle on the plate. Example: "orange glaze" on chicken should be merged into "orange-glazed chicken"; do not create a separate "orange glaze" item.
        - If a protein is coated in sauce, use the combined name (e.g. "orange-glazed chicken", "teriyaki salmon", "BBQ chicken").
        - IGNORE WATER AND ICE. A glass of water, ice cubes, or a beverage cup is NOT a food item and has zero calories. Do not list water or ice in the numbered list.

        Return ONLY a numbered list like:
        1. orange-glazed chicken
        2. quinoa
        3. roasted broccoli
        4. lemon wedges
        5. sesame seeds
        6. scallions

        No JSON, no prose, just the numbered list.
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": "List every distinct food item visible in this photo as a numbered list."],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ]],
            ],
            "temperature": 0.0,
            "seed": Self.deterministicSeed,
            "max_tokens": 1024,
        ]
        let raw = try await postChat(body: body)
        return parseNumberedList(raw)
    }

    private func parseNumberedList(_ text: String) -> [String] {
        var items: [String] = []
        let pattern = "^\\s*\\d+\\.?\\s*"
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.range(of: "^\\s*\\d+\\.?\\s*", options: .regularExpression) != nil else { continue }
            let cleaned = trimmed.replacingOccurrences(of: "^\\s*\\d+\\.?\\s*[-\\-]?\\s*", with: "", options: .regularExpression, range: nil)
            let final = cleaned.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\.$", with: "", options: .regularExpression, range: nil)
            if !final.isEmpty, !final.lowercased().contains("item"), final.count > 2 {
                items.append(final)
            }
        }
        return items
    }

    /// Step 2: ask for detailed JSON given the pre-enumerated list. `strict` adds a locked-list
    /// reminder and a harsh penalty if the JSON deviates from the enumeration.
    private func runPass1Detail(base64: String, enumerated: [String], strict: Bool) async throws -> Pass1Output {
        let lockedList = enumerated.map { "- \($0)" }.joined(separator: "\n")
        let strictPrefix = strict
            ? "!!! STRICT ENFORCEMENT — DO NOT MERGE OR DROP ITEMS !!!\nThe items below are LOCKED. The JSON \"items\" array MUST contain a separate entry for EACH listed food. If you return fewer items than listed, you are wrong.\n\n"
            : ""
        let system = """
        You are PrecisionCalMacroAutopsy Pass 1 (Vision). You have already enumerated the items in the meal photo. Your job now is to produce the detailed JSON report.

        \(strictPrefix)PRE-ENUMERATED ITEMS (each must appear in the JSON items array):
        \(lockedList)

        MANDATORY COVERAGE — list each of the following as its OWN item whenever present:
        - Every protein (chicken, beef, fish, tofu, egg, etc.) — separate cuts if visually distinct
        - Every starch/carb (potato, rice, quinoa, pasta, bread, tortilla, fries, wedges, grains, beans, corn)
        - Every vegetable (carrots, broccoli, greens, peppers, onions, tomatoes, scallions, etc.) — a large broccoli cluster is a PRIMARY item
        - Every fruit, including garnishes (lemon wedge, lime, berries, apple slices, orange segments)
        - Every sauce, dressing, dip, gravy, glaze, or condiment visible
        - Every dairy item (cheese, sour cream, yogurt, butter pat)
        - Visible cooking fats (oil sheen, butter)
        - Beverages if shown

        **BOWL / COMPOSED PLATE EXAMPLES:**
        - A grain bowl with orange-glazed chicken, quinoa, roasted broccoli, lemon wedges, sesame seeds, and scallions must produce at least SIX items: the chicken, the quinoa, the broccoli, the lemon wedges, the sesame seeds, and the scallions.
        - A plate with rice, stir-fried vegetables, and grilled salmon must produce THREE separate items, not one "rice bowl" entry.

        PREPARATION HINTS:
        - "grilled" or "baked" for matte/charred protein with minimal oil
        - "sauteed" or "roasted" for vegetables with slight oil sheen
        - "fried" only when visibly battered/breaded, deep-fried
        - "glazed" or "sauced" when coated in a sticky sauce (orange glaze, teriyaki, BBQ) but not battered
        - "raw" for untouched fruit/vegetable garnishes

        DISCRETE UNIT COUNTING — MANDATORY for countable foods:
        - For any food in distinct units (pancakes, eggs, bread slices, burger patties, sausages, meatballs, nuggets, wings, drumsticks, lemon wedges, scoops), set "isDiscrete": true and count units in "discreteCount".
        - Give "estimatedSize" as a size class for ONE unit (e.g. "medium (approx 5-6 inch diameter)", "large (approx 30g slice)").
        - Give "state" describing the arrangement ("stacked", "spread", "fanned", "cut in half").
        - Amorphous foods (rice, pasta, quinoa, salad, stew, sauces, casseroles, mashed items, loose seeds, chopped scallions) set "isDiscrete": false and "discreteCount": 1.

        Return STRICT JSON only:
        {"title":"short meal name","items":[{"name":"...","preparation":"grilled|fried|baked|raw|steamed|boiled|roasted|sauteed|glazed|sauced|other","visual":"color/texture","category":"protein|carb|veg|fat|fruit|dairy|sauce|other","isDiscrete":true|false,"discreteCount":number,"estimatedSize":"size class for ONE unit or empty","state":"stacked|spread|fanned|cut|other"}],"plateDetails":"diameter cm + shape","depthCues":"shadow/portion notes"}
        """
        let userText = strict
            ? "The enumerated items are locked. Return the JSON with ALL of them as separate entries. Do not merge sides into the main dish."
            : "Produce the detailed JSON report for every distinct food item visible on the plate."
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": userText],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ]],
            ],
            "temperature": 0.0,
            "seed": Self.deterministicSeed,
            "max_tokens": 2048,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass1Output.self, from: raw)
    }

    /// Counts how many known food words appear in the given title, to detect when a title
    /// implies multiple items but the JSON item list is collapsed.
    private func countFoodTerms(in title: String?) -> Int {
        guard let title = title?.lowercased() else { return 0 }
        let foods = ["chicken", "beef", "pork", "fish", "salmon", "tuna", "shrimp", "tofu", "egg",
                     "rice", "quinoa", "pasta", "noodle", "potato", "bread", "toast", "tortilla",
                     "broccoli", "carrot", "pepper", "onion", "tomato", "spinach", "kale", "lettuce",
                     "scallion", "lemon", "lime", "avocado", "mushroom", "corn", "bean", "pea",
                     "sesame", "seed", "cheese", "yogurt", "sauce", "glaze", "dressing"]
        return foods.reduce(0) { title.contains($1) ? $0 + 1 : $0 }
    }

    private func runPass2(base64: String, p1: Pass1Output) async throws -> Pass2Output {
        let itemsJSON = (try? String(data: JSONEncoder().encode(p1.items), encoding: .utf8)) ?? "[]"
        let system = """
        You are PrecisionCalMacroAutopsy Pass 2 (Scale). Estimate gram weights using density constants and the plate context from Pass 1.
        Densities (g/cm³): chicken 1.05, beef 1.05, fish 1.00, rice 0.85, quinoa 0.75, pasta 1.10, bread 0.30, oil 0.92, butter 0.91, leafy veg 0.30, root veg 0.65, broccoli 0.35, beans 1.20, cheese 1.10, fruit 0.85.
        Cross-reference plate diameter (\(p1.plateDetails ?? "unknown")) and depth cues (\(p1.depthCues ?? "unknown")).
        Items from Pass 1: \(itemsJSON).
        CRITICAL: Return EXACTLY ONE entry for EVERY item in the Pass 1 list above — same count, same names. NEVER merge sides into the main dish, and NEVER drop a starch, vegetable, fruit, sauce, or garnish.

        DISCRETE UNIT WEIGHTING — CRITICAL:
        For every item with "isDiscrete": true, estimate the weight of ONE unit from its "estimatedSize" and the reference anchors below, then MULTIPLY by "discreteCount". Report the TOTAL (unit weight × count) as estimatedWeightG — never an unconstrained mass. Reference unit weights: pancake ~60g, waffle ~75g, egg ~50g, bread slice ~30g, burger patty ~113g, sausage ~68g, meatball ~30g, nugget/tender ~25g, muffin ~110g, donut ~60g, cookie ~30g, banana ~118g, apple ~182g, baked potato ~173g, chicken breast ~174g, wing ~40g, drumstick ~62g, lemon/lime wedge ~58g.
        Example: 4 medium pancakes (5–6 inch) = 4 × 60g = 240g TOTAL — not 400–600g.
        Amorphous items ("isDiscrete": false) are estimated from volume × density as usual.

        PORTION REALITY CHECK — MANDATORY:
        - A single restaurant bowl or plate should rarely exceed 1,200g total. If your item estimates sum to more, rescale the largest items down.
        - A single serving of chicken/pork/beef/fish in a bowl is typically 120–250g cooked. Only large platters or multiple pieces should exceed 300g.
        - A sprinkle of seeds, chopped herbs, scallions, or chili flakes is a GARNISH, not a side dish: 2–10g total. Never return 100g of sesame seeds.
        - A lemon/lime wedge is 50–60g each; count the wedges and multiply.
        - A sauce or glaze coating is usually 15–60g total, not 100g+ unless the food is swimming in it.
        - Grains (rice, quinoa) in a bowl are typically 120–250g cooked.
        - Vegetables such as broccoli, carrots, or peppers should reflect their actual visual coverage: a large portion is 150–250g, not 50g.

        Return STRICT JSON only:
        {"items":[{"name":"...","preparation":"...","estimatedWeightG":number}],"totalWeightG":number}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": "Verify portions visually and estimate grams per item."],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ]],
            ],
            "temperature": 0.0,
            "seed": Self.deterministicSeed,
            "max_tokens": 2048,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass2Output.self, from: raw)
    }

    private func runPass3(p1: Pass1Output, p2: Pass2Output) async throws -> Pass3Output {
        let weightsJSON = (try? String(data: JSONEncoder().encode(p2.items), encoding: .utf8)) ?? "[]"
        let system = """
        You are PrecisionCalMacroAutopsy Pass 3 (USDA Database). Map weights to USDA nutritional values per item.
        For each item compute: calories(kcal), protein(g), carbs(g), fat(g), fiber(g), sugar(g), waterMl.
        Use USDA FoodData Central reference values; account for the preparation method (frying adds oil; grilling does not).

        FIBER & SUGAR RULES — DO NOT default to 0:
        - Vegetables, fruits, beans, whole grains, nuts, seeds ALWAYS have measurable fiber. Examples per 100g cooked: carrots ~2.8g fiber / ~4.7g sugar; broccoli ~2.6g / ~1.4g; potato with skin ~2.2g / ~1.2g; sweet potato ~3.0g / ~6.0g; brown rice ~1.8g / ~0.4g; whole-wheat bread ~7g / ~5g; beans ~6–8g / ~0.3g; berries ~5–7g / ~5–10g; apple ~2.4g / ~10g; banana ~2.6g / ~12g; tomatoes ~1.2g / ~2.6g; leafy greens ~2g / ~0.5g.
        - Sauces: BBQ ~0g fiber / ~15–40g sugar per 100g; ketchup ~0.4 / ~22; tomato sauce ~1.5 / ~6; vinaigrette ~0.1 / ~3; cream sauce ~0 / ~3.
        - Dairy: milk ~0 / ~5; yogurt plain ~0 / ~3.6; cheese ~0 / ~0.5.
        - Only return fiber=0 AND sugar=0 if the item is genuinely fiber/sugar-free (pure meat, pure oil/fat, pure egg white, pure broth). Plant foods returning 0 is a BUG.

        ITEM CONTINUITY — MANDATORY: Return EXACTLY ONE nutrition entry for EVERY item in the weights list below — same count, same names. Never merge, collapse, or drop an item. A starch source (potato, rice, pasta, bread) MUST carry its full carbohydrate, fiber, and sugar values; never compress carbs to 0 unless the item is an isolated fat or pure protein source.
        The gram weights below are ANCHORED (discrete unit count × unit weight, density-checked). Use them exactly as given; do NOT rescale them.
        Items with weights: \(weightsJSON).
        Return STRICT JSON only:
        {"items":[{"name":"...","preparation":"...","grams":number,"calories":number,"protein":number,"carbs":number,"fat":number,"fiber":number,"sugar":number,"waterMl":number}]}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "Map all items to USDA nutrition values now."],
            ],
            "temperature": 0.0,
            "seed": Self.deterministicSeed,
            "max_tokens": 4096,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass3Output.self, from: raw)
    }

    /// Pass 2 — Lipid Sheen Discovery (Vision): a wide-angle surface-physics pass that scans the
    /// whole plate for general oil/butter reflectivity anomalies and flags candidate regions.
    private func runLipidDiscovery(base64: String, p1: Pass1Output) async throws -> LipidDiscoveryOutput {
        let names = p1.items.map { $0.name }
        let itemsJSON = (try? String(data: JSONEncoder().encode(names), encoding: .utf8)) ?? "[]"
        let system = """
        You are PrecisionCalMacroAutopsy Pass 2 (Lipid Sheen Discovery). Perform a WIDE-ANGLE surface-physics scan of the entire plate.
        Goal: locate every region that exhibits a possible LIPID SHEEN — glossy oil/butter/fat reflectance, specular highlights, pooled liquid fat, glistening surfaces, oil droplets, or greasy translucency.
        This is a broad reconnaissance pass: do NOT estimate fat grams yet. Simply flag which items/regions look reflective and worth a magnified inspection in the next pass.
        For each flagged item, give an approximate target region/coordinates (e.g. "top-center of the chicken", "pooled at lower-right of the bowl") so the macro-zoom pass can target it.
        Items identified on the plate: \(itemsJSON).
        Return STRICT JSON only:
        {"candidates":[{"name":"...","sheenSuspected":true|false,"region":"short location description","reflectivityNote":"what looks glossy/oily"}],"note":"one short sentence summarizing reflective regions or empty"}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": "Scan the whole plate for oil/butter reflectivity and flag candidate regions for magnified verification."],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ]],
            ],
            "temperature": 0.0,
            "seed": Self.deterministicSeed,
            "max_tokens": 2048,
        ]
        let raw = try await postChat(body: body)
        return try decode(LipidDiscoveryOutput.self, from: raw)
    }

    /// Pass 3 — High-Res Macro-Zoom Verification (Vision): targets the candidate regions from Pass 2
    /// and executes a magnified micro-texture/viscosity check to confirm lipids and estimate added fat.
    private func runLipidVerification(base64: String, p1: Pass1Output, discovery: LipidDiscoveryOutput) async throws -> Pass5Output {
        let candidatesJSON = (try? String(data: JSONEncoder().encode(discovery.candidates), encoding: .utf8)) ?? "[]"
        let prepHints = p1.items.map { ["name": $0.name, "preparation": $0.preparation] }
        let prepJSON = (try? JSONSerialization.data(withJSONObject: prepHints)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let system = """
        You are PrecisionCalMacroAutopsy Pass 3 (High-Res Macro-Zoom Verification). The discovery pass (Pass 2) flagged candidate regions that may carry a lipid sheen. Mentally MAGNIFY each flagged target region and run a micro-texture / viscosity check to confirm whether real glossy oil/butter/fat is present.
        Confirm or reject each candidate: specular highlights, pooled liquid fat, droplet viscosity, and greasy translucency confirm a sheen; matte/dry surfaces or plain moisture do NOT.
        For each CONFIRMED item, infer the most likely fat from the food's typical preparation and estimate the added amount:
        - fried/sauteed proteins → vegetable/seed oil (~5–15g per serving) or butter
        - roasted vegetables with gloss → olive or vegetable oil (~3–10g per serving)
        - pasta/rice with gloss → butter, olive oil, or sauce-fat (~4–10g per serving)
        - greens with sheen → dressing oil (~3–8g per serving)
        - bread with sheen → butter or oil brush (~3–8g per serving)
        Do not over-add. If a candidate is not confirmed, set lipidSheenDetected=false and zero added values.
        Candidate regions from Pass 2: \(candidatesJSON).
        Preparation context: \(prepJSON).
        Return STRICT JSON only:
        {"adjustments":[{"name":"...","lipidSheenDetected":true|false,"inferredFat":"olive oil|butter|vegetable oil|...|null","addedFatG":number,"addedCalories":number,"confidence":0-100}],"summaryNote":"one short sentence on lipid findings or empty"}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": "Macro-zoom each flagged region, confirm the lipid sheen, and return the verified adjustments JSON."],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ]],
            ],
            "temperature": 0.0,
            "seed": Self.deterministicSeed,
            "max_tokens": 2048,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass5Output.self, from: raw)
    }

    private func runPass4(p1: Pass1Output, p3: Pass3Output) async throws -> Pass4Output {
        let nutritionJSON = (try? String(data: JSONEncoder().encode(p3.items), encoding: .utf8)) ?? "[]"
        let p1Names = p1.items.map { "- \($0.name)" }.joined(separator: "\n")
        let system = """
        You are PrecisionCalMacroAutopsy Pass 4 — Senior Nutritionist QC. Audit prior passes and produce the final verified report.
        Sanity checks:
        - kcal/g ratio: most foods 0.5–6 kcal/g; pure oils ~9; leafy veg ~0.2–0.4. Correct any outliers.
        - Protein/carb/fat grams must roughly reconcile with calories (4/4/9 kcal per g).
        - Adjust water content for cooking method (frying reduces water).
        - FIBER/SUGAR AUDIT: any plant food (vegetable, fruit, whole grain, legume, nut, seed, sauce with produce) MUST have non-zero fiber and/or sugar consistent with USDA. If Pass 3 returned 0 for a plant item, CORRECT it using USDA values: carrots ~2.8g fiber/100g, potato ~2.2g/100g, broccoli ~2.6g/100g, tomato ~1.2g/100g, lemon ~2.8g/100g, quinoa ~2.8g/100g, BBQ sauce ~25g sugar/100g, sesame seeds ~12g fiber/100g, etc. Returning 0 fiber on a meal that contains vegetables, fruit, or starch is INCORRECT — fix it.
        - PROTEIN AUDIT: cooked chicken breast is ~31g protein per 100g; glazed chicken with sauce may be slightly less due to sauce weight. Do not over-attribute protein.
        - ITEM CONTINUITY (CRITICAL): Preserve EVERY item from Pass 3 — same count, same names. The canonical Pass 1 enumeration is:\n\(p1Names)\nYour final JSON must include a separate entry for every item in that list. Never merge sides into the entrée or drop a starch/vegetable/fruit/sauce/garnish. A meal that visually contains toast, avocado, egg, and seasonings but returns only "toast" is a BUG and must be corrected.
        - GRAM LOCK: Gram weights from Pass 3 are anchored to discrete unit counts (unit weight × count, e.g. 4 medium pancakes ≈ 240g). Keep them UNCHANGED unless a kcal/g sanity check fails — never rescale a multi-unit item as one unconstrained mass.
        - PORTION REALITY CHECK: A single item of sesame seeds, scallions, herbs, or chili flakes should never exceed 15g. A single chicken/fish/tofu serving in a bowl should not exceed 300g unless it is clearly a large platter. A whole meal total should not exceed 1,200g for a single bowl/plate. Correct any absurd overestimates.
        - PREP CHECK: Do not label a sauced/glazed item as "fried" unless it has visible batter/breading. Glossy sauce is "glazed", not "fried".
        - CARB INTEGRITY RULE: You must ensure the total carbohydrates, sugars, and fibers of identified starch/carb sources (e.g. potatoes, rice, quinoa, pasta, bread) are mathematically present and fully represented. Never compress carbohydrate subcategories to 0 unless the item is an isolated fat or pure protein source.
        Compute:
        - mealScore (0–100): protein adequacy, fiber, sugar load, prep method, balance.
        - metabolicImpact: ONE short label like "Steady energy", "Quick spike", "Slow burn", "Recovery boost", "Light & lean".
        - qcNotes: ONE sentence rationale.
        GRANULAR BREAKDOWN — required, numeric only (never strings or ranges):
        - Fat subcategories for the WHOLE meal: saturatedFatG, unsaturatedFatG, transFatG. They MUST sum to the meal's total fat grams. Estimate from food type (animal fats/butter/cheese ~higher saturated; olive/seed oils/fish/nuts ~mostly unsaturated; fried/processed may carry small trans).
        - micronutrients: an array of every notable micronutrient present (Sodium, Potassium, Magnesium, Calcium, Iron, Vitamin C, Vitamin A, Vitamin D, etc.). For each give amountMg (milligrams; convert mcg to mg) and pctDailyValue (0–100+, integer percent of standard daily value). Include at least 4 when the meal contains real food.
        Pass 1 title: \(p1.title ?? "Meal").
        Pass 3 nutrition: \(nutritionJSON).
        Return STRICT JSON only:
        {"title":"short meal title","items":[{"name":"...","preparation":"...","grams":number,"calories":number,"protein":number,"carbs":number,"fat":number,"fiber":number,"sugar":number,"waterMl":number}],"metabolicImpact":"...","mealScore":0-100,"qcNotes":"...","saturatedFatG":number,"unsaturatedFatG":number,"transFatG":number,"micronutrients":[{"name":"Sodium","amountMg":number,"pctDailyValue":number}]}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "Audit, correct outliers, and produce the verified report."],
            ],
            "temperature": 0.0,
            "seed": Self.deterministicSeed,
            "max_tokens": 4096,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass4Output.self, from: raw)
    }

    // MARK: - Networking

    /// Transient failures (server 5xx, rate limit, gateway/network blips) are retried with
    /// exponential backoff so a momentary proxy hiccup mid-pipeline never surfaces to the user.
    private static let maxAttempts = 3

    private func postChat(body: [String: Any]) async throws -> String {
        var lastError: Error = AIError.serverError(0)
        for attempt in 0..<Self.maxAttempts {
            do {
                return try await postChatOnce(body: body)
            } catch let error as AIError {
                lastError = error
                guard Self.isRetryable(error), attempt < Self.maxAttempts - 1 else { throw error }
                print("[AIService] Transient \(error) — retrying (attempt \(attempt + 2)/\(Self.maxAttempts)).")
            } catch let urlError as URLError where Self.isRetryable(urlError) {
                lastError = urlError
                guard attempt < Self.maxAttempts - 1 else { throw AIError.serverError(0) }
                print("[AIService] Network \(urlError.code) — retrying (attempt \(attempt + 2)/\(Self.maxAttempts)).")
            }
            // Exponential backoff with jitter: ~0.6s, ~1.4s.
            let delayMs = UInt64((attempt + 1) * 600 + Int.random(in: 0...300))
            try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
        }
        throw lastError
    }

    /// Whether an AIError represents a transient server-side condition worth retrying.
    private static func isRetryable(_ error: AIError) -> Bool {
        switch error {
        case .rateLimited: return true
        case .serverError(let code): return code == 0 || code >= 500
        default: return false
        }
    }

    /// Whether a URL-layer failure (timeout, connection drop) is worth retrying.
    private static func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .dnsLookupFailed, .notConnectedToInternet, .badServerResponse:
            return true
        default:
            return false
        }
    }

    private func postChatOnce(body: [String: Any]) async throws -> String {
        guard let url = URL(string: "\(toolkitURL)/v2/vercel/v1/chat/completions") else {
            throw AIError.serverError(0)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = await MainActor.run { Self.secret }
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AIError.serverError(0) }
        switch http.statusCode {
        case 200: break
        case 401: throw AIError.authError
        case 402: throw AIError.insufficientBalance
        case 413: throw AIError.imageTooLarge
        case 429: throw AIError.rateLimited
        case 400:
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[AIService] HTTP 400: \(body.prefix(800))")
            throw AIError.serverError(400)
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[AIService] HTTP \(http.statusCode): \(body.prefix(800))")
            throw AIError.serverError(http.statusCode)
        }
        struct R: Decodable, Sendable {
            struct C: Decodable, Sendable {
                struct M: Decodable, Sendable { let content: String? }
                let message: M
            }
            let choices: [C]
        }
        let parsed = try JSONDecoder().decode(R.self, from: data)
        return parsed.choices.first?.message.content ?? ""
    }

    private func decode<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
        let cleaned = cleanJSON(raw)
        if let data = cleaned.data(using: .utf8),
           let v = try? JSONDecoder().decode(T.self, from: data) {
            return v
        }
        // Attempt to repair truncated JSON (model hit max_tokens mid-output).
        let repaired = repairTruncatedJSON(cleaned)
        guard let data = repaired.data(using: .utf8) else {
            throw AIError.decodingError("encoding")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[AIService] decode failed. Raw (first 600): \(raw.prefix(600))")
            throw AIError.decodingError(String(describing: error))
        }
    }

    /// Best-effort repair of JSON truncated by max_tokens.
    /// Strategy: if we're inside an unterminated string, close it.
    /// Then balance any unclosed arrays/objects in correct nesting order.
    /// If the tail ends with a partial value (e.g. trailing comma or partial number/key),
    /// trim back to the last clean delimiter before closing.
    private func repairTruncatedJSON(_ s: String) -> String {
        var chars = Array(s)
        var inString = false
        var escape = false
        var stack: [Character] = []
        var lastCleanIdx: Int = -1 // index of last char known to be at a 'safe' boundary
        for i in 0..<chars.count {
            let c = chars[i]
            if inString {
                if escape { escape = false; continue }
                if c == "\\" { escape = true; continue }
                if c == "\"" { inString = false; lastCleanIdx = i }
                continue
            }
            switch c {
            case "\"":
                inString = true
            case "{":
                stack.append("}")
            case "[":
                stack.append("]")
            case "}", "]":
                if let top = stack.last, top == c { stack.removeLast(); lastCleanIdx = i }
            case ",":
                lastCleanIdx = i - 1
            case " ", "\n", "\r", "\t":
                break
            default:
                break
            }
        }
        var out = String(chars)
        if inString {
            out.append("\"")
        }
        // If we ended with a dangling partial token (e.g. "name": 12.3 truncated),
        // try trimming to the last clean delimiter to drop the bad partial.
        // Only do this if naive close fails.
        let naive = out + String(stack.reversed())
        if let data = naive.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return naive
        }
        // Trim aggressively to last clean boundary.
        if !inString && lastCleanIdx >= 0 && lastCleanIdx < chars.count {
            // Rebuild stack up to lastCleanIdx
            var s2: [Character] = []
            var inStr2 = false
            var esc2 = false
            for i in 0...lastCleanIdx {
                let c = chars[i]
                if inStr2 {
                    if esc2 { esc2 = false; continue }
                    if c == "\\" { esc2 = true; continue }
                    if c == "\"" { inStr2 = false }
                    continue
                }
                switch c {
                case "\"": inStr2 = true
                case "{": s2.append("}")
                case "[": s2.append("]")
                case "}", "]":
                    if let t = s2.last, t == c { s2.removeLast() }
                default: break
                }
            }
            var trimmed = String(chars[0...lastCleanIdx])
            // Drop trailing comma if any
            while let last = trimmed.last, last == "," || last.isWhitespace {
                trimmed.removeLast()
            }
            trimmed.append(String(s2.reversed()))
            return trimmed
        }
        return naive
    }

    private func cleanJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip code fences (``` or ```json)
        if s.hasPrefix("```") {
            if let firstNewline = s.firstIndex(of: "\n") {
                s = String(s[s.index(after: firstNewline)...])
            }
            if let fenceEnd = s.range(of: "```", options: .backwards) {
                s = String(s[..<fenceEnd.lowerBound])
            }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Extract the FIRST balanced top-level JSON object.
        // The model occasionally emits prose or multiple objects; first/last brace is unsafe.
        guard let start = s.firstIndex(of: "{") else { return s }
        let chars = Array(s[start...])
        var depth = 0
        var inString = false
        var escape = false
        var endOffset: Int? = nil
        for i in 0..<chars.count {
            let c = chars[i]
            if inString {
                if escape { escape = false; continue }
                if c == "\\" { escape = true; continue }
                if c == "\"" { inString = false }
                continue
            }
            switch c {
            case "\"": inString = true
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { endOffset = i; break }
            default: break
            }
            if endOffset != nil { break }
        }
        if let e = endOffset {
            return String(chars[0...e])
        }
        // Unbalanced — return from first '{' to last '}' so repair logic can try.
        if let last = s.lastIndex(of: "}") {
            return String(s[start...last])
        }
        return String(s[start...])
    }

    private func resizeForUpload(imageData: Data, maxBytes: Int) throws -> String {
        guard let image = UIImage(data: imageData) else { throw AIError.imageTooLarge }
        let ladder: [(CGFloat, CGFloat)] = [
            (1280, 0.82), (1024, 0.78), (832, 0.74), (640, 0.70), (512, 0.65)
        ]
        for (maxEdge, quality) in ladder {
            let resized = Self.resize(image: image, maxEdge: maxEdge)
            if let jpeg = resized.jpegData(compressionQuality: quality) {
                let b64 = jpeg.base64EncodedString()
                if b64.utf8.count <= maxBytes {
                    return b64
                }
            }
        }
        throw AIError.imageTooLarge
    }

    private static func resize(image: UIImage, maxEdge: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
