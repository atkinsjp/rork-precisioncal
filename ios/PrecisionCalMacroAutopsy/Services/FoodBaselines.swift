import Foundation

/// Reference macro profile per 100g of edible food, sourced from USDA FoodData Central
/// approximations. Used as a strict structural guardrail so that an identified food item
/// can never render 0 carbs / 0 fiber / 0 sugar when its category clearly contains them.
nonisolated struct FoodMacroProfile: Sendable {
    let kcalPer100: Double
    let proteinPer100: Double
    let carbPer100: Double
    let fatPer100: Double
    let fiberPer100: Double
    let sugarPer100: Double
}

/// Baseline nutrition lookup used to repair dropped or zeroed macros in the analysis pipeline.
nonisolated enum FoodBaseline {
    /// Keyword → profile. The first keyword contained in the item name wins, so order from
    /// most-specific to most-generic.
    private static let table: [(keywords: [String], profile: FoodMacroProfile)] = [
        // Starches / carbs (cooked, per 100g)
        (["sweet potato", "yam"], .init(kcalPer100: 90, proteinPer100: 2.0, carbPer100: 20.7, fatPer100: 0.1, fiberPer100: 3.0, sugarPer100: 6.5)),
        (["fries", "wedge", "chips"], .init(kcalPer100: 175, proteinPer100: 2.4, carbPer100: 24.0, fatPer100: 8.0, fiberPer100: 2.4, sugarPer100: 0.4)),
        (["potato", "spud"], .init(kcalPer100: 87, proteinPer100: 1.9, carbPer100: 20.1, fatPer100: 0.1, fiberPer100: 2.2, sugarPer100: 1.2)),
        (["brown rice"], .init(kcalPer100: 123, proteinPer100: 2.7, carbPer100: 25.6, fatPer100: 1.0, fiberPer100: 1.8, sugarPer100: 0.4)),
        (["rice", "risotto"], .init(kcalPer100: 130, proteinPer100: 2.7, carbPer100: 28.0, fatPer100: 0.3, fiberPer100: 0.4, sugarPer100: 0.1)),
        (["pasta", "noodle", "spaghetti", "penne", "macaroni"], .init(kcalPer100: 158, proteinPer100: 5.8, carbPer100: 30.9, fatPer100: 0.9, fiberPer100: 1.8, sugarPer100: 0.6)),
        (["whole wheat bread", "whole-wheat", "whole grain bread"], .init(kcalPer100: 247, proteinPer100: 13.0, carbPer100: 41.0, fatPer100: 3.4, fiberPer100: 7.0, sugarPer100: 5.0)),
        (["bread", "bun", "roll", "toast", "tortilla", "naan", "pita"], .init(kcalPer100: 265, proteinPer100: 9.0, carbPer100: 49.0, fatPer100: 3.2, fiberPer100: 2.7, sugarPer100: 5.0)),
        (["quinoa"], .init(kcalPer100: 120, proteinPer100: 4.4, carbPer100: 21.3, fatPer100: 1.9, fiberPer100: 2.8, sugarPer100: 0.9)),
        (["corn", "maize"], .init(kcalPer100: 96, proteinPer100: 3.4, carbPer100: 21.0, fatPer100: 1.5, fiberPer100: 2.4, sugarPer100: 4.5)),
        (["oat", "oatmeal", "porridge"], .init(kcalPer100: 71, proteinPer100: 2.5, carbPer100: 12.0, fatPer100: 1.5, fiberPer100: 1.7, sugarPer100: 0.3)),
        (["bean", "lentil", "chickpea", "legume"], .init(kcalPer100: 127, proteinPer100: 8.0, carbPer100: 22.0, fatPer100: 0.5, fiberPer100: 7.0, sugarPer100: 0.5)),

        // Vegetables (cooked, per 100g)
        (["carrot"], .init(kcalPer100: 41, proteinPer100: 0.9, carbPer100: 9.6, fatPer100: 0.2, fiberPer100: 2.8, sugarPer100: 4.7)),
        (["broccoli"], .init(kcalPer100: 35, proteinPer100: 2.4, carbPer100: 7.2, fatPer100: 0.4, fiberPer100: 3.3, sugarPer100: 1.4)),
        (["green onion", "scallion", "spring onion"], .init(kcalPer100: 32, proteinPer100: 1.8, carbPer100: 7.3, fatPer100: 0.2, fiberPer100: 2.6, sugarPer100: 2.3)),
        (["cauliflower"], .init(kcalPer100: 25, proteinPer100: 1.9, carbPer100: 5.0, fatPer100: 0.3, fiberPer100: 2.0, sugarPer100: 1.9)),
        (["green bean", "asparagus", "pea"], .init(kcalPer100: 40, proteinPer100: 2.5, carbPer100: 7.5, fatPer100: 0.2, fiberPer100: 3.0, sugarPer100: 2.5)),
        (["tomato"], .init(kcalPer100: 18, proteinPer100: 0.9, carbPer100: 3.9, fatPer100: 0.2, fiberPer100: 1.2, sugarPer100: 2.6)),
        (["onion"], .init(kcalPer100: 40, proteinPer100: 1.1, carbPer100: 9.3, fatPer100: 0.1, fiberPer100: 1.7, sugarPer100: 4.2)),
        (["pepper", "capsicum"], .init(kcalPer100: 31, proteinPer100: 1.0, carbPer100: 6.0, fatPer100: 0.3, fiberPer100: 2.1, sugarPer100: 4.2)),
        (["spinach", "kale", "lettuce", "greens", "salad", "arugula"], .init(kcalPer100: 23, proteinPer100: 2.2, carbPer100: 3.6, fatPer100: 0.3, fiberPer100: 2.2, sugarPer100: 0.4)),
        (["zucchini", "squash", "courgette"], .init(kcalPer100: 17, proteinPer100: 1.2, carbPer100: 3.1, fatPer100: 0.3, fiberPer100: 1.0, sugarPer100: 2.5)),
        (["mushroom"], .init(kcalPer100: 28, proteinPer100: 2.2, carbPer100: 5.3, fatPer100: 0.5, fiberPer100: 2.2, sugarPer100: 2.4)),

        // Fruit (per 100g)
        (["lemon", "lime"], .init(kcalPer100: 29, proteinPer100: 1.1, carbPer100: 9.3, fatPer100: 0.3, fiberPer100: 2.8, sugarPer100: 2.5)),
        (["apple"], .init(kcalPer100: 52, proteinPer100: 0.3, carbPer100: 14.0, fatPer100: 0.2, fiberPer100: 2.4, sugarPer100: 10.4)),
        (["banana"], .init(kcalPer100: 89, proteinPer100: 1.1, carbPer100: 23.0, fatPer100: 0.3, fiberPer100: 2.6, sugarPer100: 12.0)),
        (["berry", "berries", "strawberry", "blueberry", "raspberry"], .init(kcalPer100: 50, proteinPer100: 0.8, carbPer100: 12.0, fatPer100: 0.3, fiberPer100: 4.0, sugarPer100: 7.0)),
        (["orange", "mandarin", "clementine"], .init(kcalPer100: 47, proteinPer100: 0.9, carbPer100: 11.8, fatPer100: 0.1, fiberPer100: 2.4, sugarPer100: 9.4)),
        (["grape"], .init(kcalPer100: 69, proteinPer100: 0.7, carbPer100: 18.0, fatPer100: 0.2, fiberPer100: 0.9, sugarPer100: 15.5)),

        // Sauces / condiments (per 100g)
        (["bbq", "barbecue"], .init(kcalPer100: 172, proteinPer100: 0.8, carbPer100: 41.0, fatPer100: 0.6, fiberPer100: 0.7, sugarPer100: 33.0)),
        (["ketchup"], .init(kcalPer100: 101, proteinPer100: 1.0, carbPer100: 27.0, fatPer100: 0.1, fiberPer100: 0.3, sugarPer100: 22.0)),
        (["tomato sauce", "marinara", "salsa"], .init(kcalPer100: 35, proteinPer100: 1.3, carbPer100: 7.0, fatPer100: 0.5, fiberPer100: 1.5, sugarPer100: 5.0)),
        (["vinaigrette", "dressing"], .init(kcalPer100: 290, proteinPer100: 0.5, carbPer100: 8.0, fatPer100: 28.0, fiberPer100: 0.1, sugarPer100: 5.0)),
        (["gravy"], .init(kcalPer100: 54, proteinPer100: 1.5, carbPer100: 5.0, fatPer100: 3.0, fiberPer100: 0.3, sugarPer100: 1.0)),
        (["orange glaze", "teriyaki glaze", "glaze", "sweet sauce", "general tso", "sticky sauce"], .init(kcalPer100: 210, proteinPer100: 3.0, carbPer100: 38.0, fatPer100: 4.5, fiberPer100: 0.2, sugarPer100: 32.0)),
        (["honey", "syrup", "jam"], .init(kcalPer100: 304, proteinPer100: 0.3, carbPer100: 82.0, fatPer100: 0.0, fiberPer100: 0.2, sugarPer100: 75.0)),

        // Nuts / seeds / garnishes (per 100g) — typical logged portions are tiny, so weights are clamped elsewhere
        (["sesame seed", "sesame seeds"], .init(kcalPer100: 573, proteinPer100: 17.0, carbPer100: 23.4, fatPer100: 49.7, fiberPer100: 11.8, sugarPer100: 0.3)),

        // Dairy (per 100g)
        (["yogurt", "yoghurt"], .init(kcalPer100: 61, proteinPer100: 3.5, carbPer100: 4.7, fatPer100: 3.3, fiberPer100: 0.0, sugarPer100: 4.7)),
        (["milk"], .init(kcalPer100: 60, proteinPer100: 3.2, carbPer100: 4.8, fatPer100: 3.3, fiberPer100: 0.0, sugarPer100: 5.0)),
        (["cheese"], .init(kcalPer100: 350, proteinPer100: 25.0, carbPer100: 1.3, fatPer100: 27.0, fiberPer100: 0.0, sugarPer100: 0.5)),

        // Proteins / fats (per 100g) — low/zero carb, used mainly for rebuilding dropped items
        (["chicken", "turkey", "poultry"], .init(kcalPer100: 165, proteinPer100: 31.0, carbPer100: 0.0, fatPer100: 3.6, fiberPer100: 0.0, sugarPer100: 0.0)),
        (["beef", "steak", "pork", "lamb"], .init(kcalPer100: 250, proteinPer100: 26.0, carbPer100: 0.0, fatPer100: 17.0, fiberPer100: 0.0, sugarPer100: 0.0)),
        (["salmon", "fish", "tuna", "cod", "shrimp"], .init(kcalPer100: 180, proteinPer100: 22.0, carbPer100: 0.0, fatPer100: 10.0, fiberPer100: 0.0, sugarPer100: 0.0)),
        (["egg"], .init(kcalPer100: 143, proteinPer100: 12.6, carbPer100: 1.1, fatPer100: 9.5, fiberPer100: 0.0, sugarPer100: 1.1)),
        (["tofu"], .init(kcalPer100: 76, proteinPer100: 8.0, carbPer100: 1.9, fatPer100: 4.8, fiberPer100: 0.3, sugarPer100: 0.6)),
        (["oil", "butter"], .init(kcalPer100: 884, proteinPer100: 0.0, carbPer100: 0.0, fatPer100: 100.0, fiberPer100: 0.0, sugarPer100: 0.0)),
    ]

    /// Generic per-100g defaults keyed by the Pass 1 category.
    private static func categoryProfile(_ category: String?) -> FoodMacroProfile {
        switch (category ?? "").lowercased() {
        case "carb": return .init(kcalPer100: 130, proteinPer100: 3.0, carbPer100: 27.0, fatPer100: 0.6, fiberPer100: 2.0, sugarPer100: 1.5)
        case "veg": return .init(kcalPer100: 35, proteinPer100: 1.8, carbPer100: 7.0, fatPer100: 0.3, fiberPer100: 2.5, sugarPer100: 3.0)
        case "fruit": return .init(kcalPer100: 60, proteinPer100: 0.8, carbPer100: 15.0, fatPer100: 0.2, fiberPer100: 2.5, sugarPer100: 10.0)
        case "sauce": return .init(kcalPer100: 90, proteinPer100: 1.0, carbPer100: 15.0, fatPer100: 2.5, fiberPer100: 0.6, sugarPer100: 10.0)
        case "dairy": return .init(kcalPer100: 120, proteinPer100: 6.0, carbPer100: 5.0, fatPer100: 8.0, fiberPer100: 0.0, sugarPer100: 4.5)
        case "fat": return .init(kcalPer100: 884, proteinPer100: 0.0, carbPer100: 0.0, fatPer100: 100.0, fiberPer100: 0.0, sugarPer100: 0.0)
        case "protein": return .init(kcalPer100: 200, proteinPer100: 27.0, carbPer100: 0.0, fatPer100: 10.0, fiberPer100: 0.0, sugarPer100: 0.0)
        default: return .init(kcalPer100: 120, proteinPer100: 5.0, carbPer100: 15.0, fatPer100: 4.0, fiberPer100: 1.5, sugarPer100: 3.0)
        }
    }

    /// Resolve the best baseline profile for a food item by name, falling back to its category.
    static func profile(forName name: String, category: String?) -> FoodMacroProfile {
        let lowered = name.lowercased()
        for entry in table where entry.keywords.contains(where: { lowered.contains($0) }) {
            return entry.profile
        }
        return categoryProfile(category)
    }

    /// Whether an item should structurally carry carbohydrate (and likely fiber/sugar) macros.
    /// Pure proteins, fats, and broths are excluded so we never inflate them.
    static func carriesCarbs(name: String, category: String?) -> Bool {
        let lowered = name.lowercased()
        let pureKeywords = ["chicken", "turkey", "poultry", "beef", "steak", "pork", "lamb",
                            "salmon", "fish", "tuna", "cod", "shrimp", "bacon", "sausage",
                            "oil", "butter", "lard", "ghee", "broth", "egg white", "water"]
        if pureKeywords.contains(where: { lowered.contains($0) }) { return false }
        switch (category ?? "").lowercased() {
        case "protein", "fat": return false
        case "carb", "veg", "fruit", "sauce", "dairy": return true
        default:
            // Unknown category: rely on the name matching a known plant/starch profile.
            let plant = ["potato", "rice", "pasta", "noodle", "bread", "bun", "tortilla", "corn",
                         "bean", "lentil", "quinoa", "oat", "carrot", "broccoli", "cauliflower",
                         "tomato", "onion", "pepper", "spinach", "kale", "lettuce", "greens",
                         "salad", "fruit", "apple", "banana", "berry", "orange", "grape",
                         "lemon", "lime", "sauce", "bbq", "ketchup", "honey", "syrup", "jam",
                         "vegetable", "fries", "wedge", "yam", "squash", "zucchini", "mushroom", "pea",
                         "scallion", "green onion", "spring onion", "sesame seed"]
            return plant.contains(where: { lowered.contains($0) })
        }
    }

    /// Default gram weight when an item was dropped before the weighing pass.
    static func defaultGrams(category: String?) -> Double {
        switch (category ?? "").lowercased() {
        case "protein": return 150
        case "carb": return 150
        case "veg": return 100
        case "fruit": return 100
        case "sauce": return 30
        case "fat": return 10
        case "dairy": return 40
        default: return 100
        }
    }
}

/// Reference weight (grams) of ONE typical unit of a discrete, countable food.
/// Anchors dimensional estimates so multi-unit foods ("4 pancakes") are weighed
/// as count × unit weight instead of one unconstrained volumetric mass.
nonisolated enum UnitReference {
    /// Keyword → grams per single unit. First keyword contained in the item name wins,
    /// so order from most-specific to most-generic.
    private static let table: [(keywords: [String], gramsPerUnit: Double)] = [
        (["chicken breast", "grilled chicken"], 174),
        (["chicken thigh"], 130),
        (["drumstick"], 62),
        (["wing"], 40),
        (["fried chicken", "chicken piece"], 120),
        (["steak", "pork chop", "chop"], 220),
        (["sausage"], 68),
        (["meatball"], 30),
        (["nugget", "tender"], 25),
        (["shrimp"], 12),
        (["bacon"], 12),
        (["pancake", "crepe"], 60),
        (["waffle"], 75),
        (["french toast"], 65),
        (["egg"], 50),
        (["toast", "bread slice", "slice of bread", "bread"], 30),
        (["burger patty", "patty", "hamburger", "cheeseburger", "burger"], 113),
        (["hash brown", "tater tot"], 70),
        (["muffin"], 110),
        (["donut", "doughnut"], 60),
        (["cookie"], 30),
        (["brownie"], 56),
        (["bagel"], 105),
        (["croissant"], 60),
        (["bun", "roll", "biscuit"], 55),
        (["taco"], 78),
        (["tortilla"], 45),
        (["banana"], 118),
        (["apple"], 182),
        (["orange", "mandarin"], 130),
        (["avocado"], 150),
        (["potato"], 173),
        (["scoop", "ice cream"], 66),
        (["lemon wedge", "lime wedge", "lemon", "lime"], 58),
    ]

    /// Grams per single unit for a discrete food, or nil when no reference exists.
    static func gramsPerUnit(forName name: String) -> Double? {
        let lowered = name.lowercased()
        for entry in table where entry.keywords.contains(where: { lowered.contains($0) }) {
            return entry.gramsPerUnit
        }
        return nil
    }
}
