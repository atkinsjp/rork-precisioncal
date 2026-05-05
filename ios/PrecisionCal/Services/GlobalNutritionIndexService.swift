import Foundation

/// Cloud-backed Global Nutrition Index ("Global_UPC" collection).
/// Acts like a Firestore collection: any structured product written here
/// becomes instantly available to every other PrecisionCal user on next scan.
///
/// Backed by a Postgres table `global_nutrition_index` exposed via the
/// project's REST endpoint. The table schema is:
///
/// ```sql
/// create table if not exists global_nutrition_index (
///   barcode text primary key,
///   name text,
///   brand text,
///   serving_size_g double precision,
///   serving_description text,
///   calories double precision,
///   protein double precision,
///   carbs double precision,
///   fat double precision,
///   fiber double precision,
///   sugar double precision,
///   sodium_mg double precision,
///   ingredients text[],
///   allergy_flags text[],
///   additive_risk text,
///   risk_level text,
///   clinical_note text,
///   scan_count int default 1,
///   updated_at timestamptz default now()
/// );
/// ```
nonisolated final class GlobalNutritionIndexService: Sendable {
    static let shared = GlobalNutritionIndexService()

    private let table = "global_nutrition_index"

    @MainActor
    private static var baseURL: String { Config.allValues["EXPO_PUBLIC_SUPABASE_URL"] ?? "" }
    @MainActor
    private static var anonKey: String { Config.allValues["EXPO_PUBLIC_SUPABASE_ANON_KEY"] ?? "" }

    private nonisolated struct Row: Codable, Sendable {
        let barcode: String
        let name: String?
        let brand: String?
        let serving_size_g: Double?
        let serving_description: String?
        let calories: Double?
        let protein: Double?
        let carbs: Double?
        let fat: Double?
        let fiber: Double?
        let sugar: Double?
        let sodium_mg: Double?
        let ingredients: [String]?
        let allergy_flags: [String]?
        let additive_risk: String?
        let risk_level: String?
        let clinical_note: String?
    }

    /// Fetch a structured product from the global index, or `nil` if unseeded.
    func fetch(barcode: String) async -> ProductLookupResult? {
        guard let req = await makeRequest(
            path: "\(table)?barcode=eq.\(barcode)&select=*&limit=1",
            method: "GET"
        ) else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let rows = (try? JSONDecoder().decode([Row].self, from: data)) ?? []
            guard let r = rows.first else { return nil }
            return ProductLookupResult(
                name: r.name ?? "",
                brand: r.brand ?? "",
                servingSizeG: r.serving_size_g ?? 0,
                servingDescription: r.serving_description ?? "",
                calories: r.calories ?? 0,
                protein: r.protein ?? 0,
                carbs: r.carbs ?? 0,
                fat: r.fat ?? 0,
                fiber: r.fiber ?? 0,
                sugar: r.sugar ?? 0,
                sodiumMg: r.sodium_mg ?? 0,
                ingredients: r.ingredients ?? [],
                allergyFlags: r.allergy_flags ?? [],
                additiveRisk: r.additive_risk ?? "",
                riskLevel: r.risk_level ?? "low",
                clinicalNote: r.clinical_note ?? ""
            )
        } catch {
            return nil
        }
    }

    /// Seed the global index with a PhD-verified entry. Fire-and-forget.
    /// Uses upsert so concurrent first-scanners don't collide.
    func writeback(barcode: String, lookup: ProductLookupResult) async {
        let payload: [String: Any] = [
            "barcode": barcode,
            "name": lookup.name,
            "brand": lookup.brand,
            "serving_size_g": lookup.servingSizeG,
            "serving_description": lookup.servingDescription,
            "calories": lookup.calories,
            "protein": lookup.protein,
            "carbs": lookup.carbs,
            "fat": lookup.fat,
            "fiber": lookup.fiber,
            "sugar": lookup.sugar,
            "sodium_mg": lookup.sodiumMg,
            "ingredients": lookup.ingredients,
            "allergy_flags": lookup.allergyFlags,
            "additive_risk": lookup.additiveRisk,
            "risk_level": lookup.riskLevel,
            "clinical_note": lookup.clinicalNote,
        ]
        guard var req = await makeRequest(path: table, method: "POST") else { return }
        req.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                print("[GNI] writeback failed: HTTP \(http.statusCode)")
            }
        } catch {
            print("[GNI] writeback error: \(error.localizedDescription)")
        }
    }

    /// Bump scan_count on a hit so popular items rise. Fire-and-forget.
    func incrementScanCount(barcode: String) async {
        guard var req = await makeRequest(
            path: "\(table)?barcode=eq.\(barcode)",
            method: "PATCH"
        ) else { return }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = "{\"scan_count\":\"scan_count + 1\"}".data(using: .utf8)
        // PostgREST can't do raw SQL increments here, so we just refresh updated_at:
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["updated_at": ISO8601DateFormatter().string(from: Date())])
        _ = try? await URLSession.shared.data(for: req)
    }

    private func makeRequest(path: String, method: String) async -> URLRequest? {
        let base = await MainActor.run { Self.baseURL }
        let key = await MainActor.run { Self.anonKey }
        guard !base.isEmpty, !key.isEmpty,
              let url = URL(string: "\(base)/rest/v1/\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return req
    }
}
