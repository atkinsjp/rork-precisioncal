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
    }
}

nonisolated enum AnalysisEvent: Sendable {
    case pass1Identified(items: [String], title: String)
    case pass2Weighed
    case pass3Mapped
    case pass4Synthesized
    case pass5LipidScanned(MealAnalysisResult)
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

nonisolated final class AIService: Sendable {
    static let shared = AIService()

    private let toolkitURL = "https://toolkit.rork.com"
    private let model = "google/gemini-2.5-flash"

    @MainActor
    private static var secret: String { Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY }

    // MARK: - Product (barcode) parsing

    /// Structure raw UPC JSON into a clean, scored product record.
    /// Adds PhD-level additive risk + allergen flags so we can cross-reference the user's profile.
    func parseProductData(barcode: String, rawJSON: String) async throws -> ProductLookupResult {
        let system = """
        You are PrecisionCal's product database curator. You receive raw UPC/Open Food Facts JSON and must return a clean, normalized product record.
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
            "temperature": 0.1,
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
        You are a PhD Nutritionist and integrative-health practitioner. Read the user's profile and write a warm, encouraging, deeply personalized health protocol of approximately 300 words. 
        Reference specific details from their profile (goals, conditions, allergies, medication interactions, activity). Provide concrete daily guidance on macronutrients, hydration, meal timing, and one simple ritual to anchor the day. 
        Tone: thoughtful, sanctuary-like, never clinical or scolding. You are Cal, an educational nutrition guide — NOT a doctor, dietitian, or medical professional. Never refer to yourself with a clinical title (no 'Dr.', no 'PhD', no 'clinician'). End with a single one-line signature in italics phrased exactly as: 'In service of your wellness, — Cal'. 
        Output: plain prose only. No markdown, no headings, no bullet lists.
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "Profile:\n\(profileSummary)\n\nWrite the 300-word health protocol now."],
            ],
            "temperature": 0.7,
            "max_tokens": 2000,
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
        You are the Community Steward for a PhD-led health sanctuary called PrecisionCal.
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
        You are PrecisionCal's 'Innovation Aggregator' for the founder. Read recent community posts and identify recurring user pain points or feature requests that could become product opportunities.
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
        You are Cal, a friendly, well-read NUTRITION GUIDE inside the PrecisionCal app. You provide EDUCATIONAL nutrition information only. You are NOT a doctor, dietitian, nutritionist, therapist, or any other licensed professional, and you must never identify yourself as one or use a clinical title. Do not give diagnoses, prescriptions, dosages, or personalized medical or official nutrition advice. Frame guidance as general educational information that the user should discuss with a licensed professional before acting on.

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
        // Guarantee the per-reply educational disclaimer is present, even if the model omits it.
        let disclaimer = "Educational nutrition information only — not medical or official nutrition advice. Consult a licensed healthcare professional."
        let lowered = cleaned.lowercased()
        if !(lowered.contains("educational") && lowered.contains("not medical")) {
            cleaned += "\n\n" + disclaimer
        }
        return cleaned
    }

    // MARK: - 4-Pass Sequential Chain

    func analyzeChain(
        imageData: Data,
        onProgress: @escaping @Sendable (AnalysisEvent) -> Void
    ) async throws -> MealAnalysisResult {
        let base64 = try resizeForUpload(imageData: imageData, maxBytes: 1_400_000)

        // Pass 1 — Vision: identify items. If this fails entirely, fall back to single-shot.
        let p1: Pass1Output
        do {
            p1 = try await runPass1(base64: base64)
        } catch {
            print("[AIService] Pass1 failed (\(error)) — falling back to single-shot analysis.")
            return try await singleShotFallback(base64: base64, onProgress: onProgress)
        }
        guard !p1.items.isEmpty else {
            print("[AIService] Pass1 returned no items — falling back to single-shot analysis.")
            return try await singleShotFallback(base64: base64, onProgress: onProgress)
        }
        let title = (p1.title?.isEmpty == false ? p1.title! : defaultTitle(from: p1.items))
        onProgress(.pass1Identified(items: p1.items.map { $0.name }, title: title))

        // Pass 2 — Vision: dimensional weight estimation. Fall back if it fails.
        let p2: Pass2Output
        do {
            p2 = try await runPass2(base64: base64, p1: p1)
        } catch {
            print("[AIService] Pass2 failed (\(error)) — falling back to single-shot.")
            return try await singleShotFallback(base64: base64, onProgress: onProgress)
        }
        onProgress(.pass2Weighed)

        // Pass 3 — Text-only USDA mapping
        let p3: Pass3Output
        do {
            p3 = try await runPass3(p1: p1, p2: p2)
        } catch {
            print("[AIService] Pass3 failed (\(error)) — falling back to single-shot.")
            return try await singleShotFallback(base64: base64, onProgress: onProgress)
        }
        onProgress(.pass3Mapped)

        // Pass 4 — Text-only QC + synthesis
        let p4: Pass4Output
        do {
            p4 = try await runPass4(p1: p1, p3: p3)
        } catch {
            print("[AIService] Pass4 failed (\(error)) — falling back to single-shot.")
            return try await singleShotFallback(base64: base64, onProgress: onProgress)
        }
        guard !p4.items.isEmpty else {
            print("[AIService] Pass4 returned no items — falling back to single-shot.")
            return try await singleShotFallback(base64: base64, onProgress: onProgress)
        }
        onProgress(.pass4Synthesized)

        // Pass 5 — Vision: magnified lipid-sheen detection per food item (optional)
        let p5 = (try? await runPass5(base64: base64, p4: p4)) ?? Pass5Output(adjustments: [], summaryNote: nil)

        let finalTitle = (p4.title?.isEmpty == false ? p4.title! : title)
        let mergedItems: [MealAnalysisResult.Item] = p4.items.map { item in
            let adj = p5.adjustments.first { matchName($0.name, item.name) && $0.lipidSheenDetected }
            let addedFat = max(0, adj?.addedFatG ?? 0)
            let addedKcal = max(0, adj?.addedCalories ?? (addedFat * 9))
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
                waterMl: item.waterMl
            )
        }
        let qcCombined: String = {
            let base = p4.qcNotes ?? ""
            guard let note = p5.summaryNote, !note.isEmpty else { return base }
            if base.isEmpty { return note }
            return base + " " + note
        }()
        let sheenDetected = p5.adjustments.contains { $0.lipidSheenDetected }
        let result = MealAnalysisResult(
            title: finalTitle,
            items: mergedItems,
            metabolicImpact: (p4.metabolicImpact?.isEmpty == false ? p4.metabolicImpact! : "Balanced"),
            mealScore: max(0, min(100, p4.mealScore ?? 0)),
            qcNotes: qcCombined,
            lipidSheenDetected: sheenDetected,
            lipidNote: p5.summaryNote ?? ""
        )
        onProgress(.pass5LipidScanned(result))
        return result
    }

    /// Fallback: ask the model to produce the full report in one shot. Used when the 5-pass chain fails.
    private func singleShotFallback(
        base64: String,
        onProgress: @escaping @Sendable (AnalysisEvent) -> Void
    ) async throws -> MealAnalysisResult {
        let result = try await runFullAnalysis(base64: base64) { items, title in
            onProgress(.pass1Identified(items: items, title: title))
        }
        onProgress(.pass2Weighed)
        onProgress(.pass3Mapped)
        onProgress(.pass4Synthesized)
        onProgress(.pass5LipidScanned(result))
        return result
    }

    private func matchName(_ a: String, _ b: String) -> Bool {
        let na = a.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let nb = b.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if na == nb { return true }
        return na.contains(nb) || nb.contains(na)
    }

    private func runFullAnalysis(
        base64: String,
        onItemsIdentified: @Sendable @escaping ([String], String) -> Void
    ) async throws -> MealAnalysisResult {
        let system = """
        You are PrecisionCal, a senior nutritionist with computer-vision expertise. Analyze the meal photo end-to-end:
        1. Identify each food item, its preparation method, and visual cues.
        2. Estimate gram weights from plate size and depth cues. Use density constants (g/cm^3): chicken 1.05, beef 1.05, fish 1.0, rice 0.85, pasta 1.10, bread 0.30, oil 0.92, butter 0.91, leafy veg 0.30, root veg 0.65, beans 1.20, cheese 1.10, fruit 0.85.
        3. Map weights to USDA FoodData Central nutrition. Account for prep (frying adds oil; grilling does not).
        4. QC: kcal/g should be 0.5 to 6 for most foods, 9 for pure oil, 0.2 to 0.4 for leafy veg. Reconcile macros (4/4/9 kcal per g). Adjust water for cooking method.
        Score the meal 0 to 100 on protein adequacy, fiber, sugar load, prep, and balance.
        metabolicImpact must be ONE short label like "Steady energy", "Quick spike", "Slow burn", "Recovery boost", or "Light & lean".
        qcNotes is ONE concise sentence.
        Return STRICT JSON only with this exact shape:
        {"title":"short meal name","items":[{"name":"...","preparation":"grilled|fried|baked|raw|steamed|boiled|other","grams":number,"calories":number,"protein":number,"carbs":number,"fat":number,"fiber":number,"sugar":number,"waterMl":number}],"metabolicImpact":"...","mealScore":number,"qcNotes":"..."}
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
            "temperature": 0.1,
            "max_tokens": 4096,
        ]
        let raw = try await postChat(body: body)
        let p4 = try decode(Pass4Output.self, from: raw)
        guard !p4.items.isEmpty else { throw AIError.visionFailed }

        let title = (p4.title?.isEmpty == false ? p4.title! : defaultTitle(fromItems: p4.items.map { $0.name }))
        onItemsIdentified(p4.items.map { $0.name }, title)

        return MealAnalysisResult(
            title: title,
            items: p4.items.map {
                MealAnalysisResult.Item(
                    name: $0.name,
                    preparation: $0.preparation,
                    grams: $0.grams,
                    calories: $0.calories,
                    protein: $0.protein,
                    carbs: $0.carbs,
                    fat: $0.fat,
                    fiber: $0.fiber,
                    sugar: $0.sugar,
                    waterMl: $0.waterMl
                )
            },
            metabolicImpact: (p4.metabolicImpact?.isEmpty == false ? p4.metabolicImpact! : "Balanced"),
            mealScore: max(0, min(100, p4.mealScore ?? 0)),
            qcNotes: p4.qcNotes ?? "",
            lipidSheenDetected: false,
            lipidNote: ""
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

    private func runPass1(base64: String) async throws -> Pass1Output {
        let system = """
        You are PrecisionCal Pass 1 (Vision). Identify food items, preparation methods (oily/dry/grilled/fried/raw/steamed/baked), and plate dimensions from depth/shadow cues.
        Return STRICT JSON only:
        {"title":"short meal name","items":[{"name":"...","preparation":"...","visual":"color/texture","category":"protein|carb|veg|fat|fruit|dairy|other"}],"plateDetails":"diameter cm + shape","depthCues":"shadow/portion notes"}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": "Identify food items, prep, plate size, depth cues."],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ]],
            ],
            "temperature": 0.1,
            "max_tokens": 2048,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass1Output.self, from: raw)
    }

    private func runPass2(base64: String, p1: Pass1Output) async throws -> Pass2Output {
        let itemsJSON = (try? String(data: JSONEncoder().encode(p1.items), encoding: .utf8)) ?? "[]"
        let system = """
        You are PrecisionCal Pass 2 (Scale). Estimate gram weights using density constants and the plate context from Pass 1.
        Densities (g/cm³): chicken 1.05, beef 1.05, fish 1.00, rice 0.85, pasta 1.10, bread 0.30, oil 0.92, butter 0.91, leafy veg 0.30, root veg 0.65, beans 1.20, cheese 1.10, fruit 0.85.
        Cross-reference plate diameter (\(p1.plateDetails ?? "unknown")) and depth cues (\(p1.depthCues ?? "unknown")).
        Items from Pass 1: \(itemsJSON).
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
            "temperature": 0.1,
            "max_tokens": 2048,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass2Output.self, from: raw)
    }

    private func runPass3(p1: Pass1Output, p2: Pass2Output) async throws -> Pass3Output {
        let weightsJSON = (try? String(data: JSONEncoder().encode(p2.items), encoding: .utf8)) ?? "[]"
        let system = """
        You are PrecisionCal Pass 3 (USDA Database). Map weights to USDA nutritional values per item.
        For each item compute: calories(kcal), protein(g), carbs(g), fat(g), fiber(g), sugar(g), waterMl.
        Use USDA FoodData Central reference values; account for the preparation method (frying adds oil; grilling does not).
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
            "temperature": 0.1,
            "max_tokens": 4096,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass3Output.self, from: raw)
    }

    private func runPass5(base64: String, p4: Pass4Output) async throws -> Pass5Output {
        struct Pass5Hint: Encodable { let name: String; let preparation: String; let grams: Double; let fat: Double }
        let hints = p4.items.map { Pass5Hint(name: $0.name, preparation: $0.preparation, grams: $0.grams, fat: $0.fat) }
        let itemsJSON = (try? String(data: JSONEncoder().encode(hints), encoding: .utf8)) ?? "[]"
        let system = """
        You are PrecisionCal Pass 5 (Lipid Sheen Detection). Visually re-examine the photo at slightly increased magnification, food item by food item.
        Goal: detect a LIPID SHEEN — visible glossy oil/butter/fat reflectance — on or around any item. Specular highlights, pooled liquid fat, glistening surfaces, oil droplets, and greasy translucency all count.
        For each item, decide if a sheen is present. If yes, infer the most likely fat in the context of that food's typical preparation:
        - fried/sauteed proteins → likely vegetable/seed oil (~5–15g per serving) or butter
        - roasted vegetables with gloss → olive or vegetable oil (~3–10g per serving)
        - pasta/rice with gloss → butter, olive oil, or sauce-fat (~4–10g per serving)
        - greens with sheen → dressing oil (~3–8g per serving)
        - bread with sheen → butter or oil brush (~3–8g per serving)
        Maintain at least the same confidence (0–100%) as the base estimate; do not over-add. If no sheen, set lipidSheenDetected=false and zero added values.
        Items previously analyzed: \(itemsJSON).
        Return STRICT JSON only:
        {"adjustments":[{"name":"...","lipidSheenDetected":true|false,"inferredFat":"olive oil|butter|vegetable oil|...|null","addedFatG":number,"addedCalories":number,"confidence":0-100}],"summaryNote":"one short sentence on lipid findings or empty"}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": "Magnify mentally and check each item for lipid sheen. Return adjustments JSON."],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                ]],
            ],
            "temperature": 0.1,
            "max_tokens": 2048,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass5Output.self, from: raw)
    }

    private func runPass4(p1: Pass1Output, p3: Pass3Output) async throws -> Pass4Output {
        let nutritionJSON = (try? String(data: JSONEncoder().encode(p3.items), encoding: .utf8)) ?? "[]"
        let system = """
        You are PrecisionCal Pass 4 — Senior Nutritionist QC. Audit prior passes and produce the final verified report.
        Sanity checks:
        - kcal/g ratio: most foods 0.5–6 kcal/g; pure oils ~9; leafy veg ~0.2–0.4. Correct any outliers.
        - Protein/carb/fat grams must roughly reconcile with calories (4/4/9 kcal per g).
        - Adjust water content for cooking method (frying reduces water).
        Compute:
        - mealScore (0–100): protein adequacy, fiber, sugar load, prep method, balance.
        - metabolicImpact: ONE short label like "Steady energy", "Quick spike", "Slow burn", "Recovery boost", "Light & lean".
        - qcNotes: ONE sentence rationale.
        Pass 1 title: \(p1.title ?? "Meal").
        Pass 3 nutrition: \(nutritionJSON).
        Return STRICT JSON only:
        {"title":"short meal title","items":[{"name":"...","preparation":"...","grams":number,"calories":number,"protein":number,"carbs":number,"fat":number,"fiber":number,"sugar":number,"waterMl":number}],"metabolicImpact":"...","mealScore":0-100,"qcNotes":"..."}
        """
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": "Audit, correct outliers, and produce the verified report."],
            ],
            "temperature": 0.1,
            "max_tokens": 4096,
        ]
        let raw = try await postChat(body: body)
        return try decode(Pass4Output.self, from: raw)
    }

    // MARK: - Networking

    private func postChat(body: [String: Any]) async throws -> String {
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
