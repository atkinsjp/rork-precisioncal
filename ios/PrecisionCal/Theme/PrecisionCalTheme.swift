import SwiftUI

enum PrecisionCalTheme {
    // MARK: - Warm Sanctuary palette
    static let bgTop = Color(red: 0xF9 / 255, green: 0xF7 / 255, blue: 0xF2 / 255)     // #F9F7F2
    static let bgBottom = Color(red: 0xEA / 255, green: 0xDF / 255, blue: 0xD3 / 255)  // #EADFD3

    // Primary action color
    static let terracotta = Color(red: 0xD6 / 255, green: 0x7D / 255, blue: 0x5B / 255) // #D67D5B
    static let terracottaDeep = Color(red: 0xB5 / 255, green: 0x5E / 255, blue: 0x40 / 255)

    // Sage accent (calm, sanctuary)
    static let sage = Color(red: 0x6F / 255, green: 0x8E / 255, blue: 0x6C / 255)
    static let sageLight = Color(red: 0xA8 / 255, green: 0xBF / 255, blue: 0x9D / 255)

    // Text on light cream
    static let textPrimary = Color(red: 0x2A / 255, green: 0x21 / 255, blue: 0x1B / 255)    // deep walnut
    static let textSecondary = Color(red: 0x6B / 255, green: 0x5C / 255, blue: 0x4F / 255)  // warm taupe
    static let textTertiary = Color(red: 0x9A / 255, green: 0x8B / 255, blue: 0x7C / 255)   // soft taupe

    // Glass / parchment
    static let cardFill = Color.white.opacity(0.55)
    static let glassStroke = Color(red: 0xC4 / 255, green: 0xB3 / 255, blue: 0xA0 / 255).opacity(0.55)
    static let parchment = Color(red: 0xFB / 255, green: 0xF7 / 255, blue: 0xEE / 255)

    // Macros — warm, earthy
    static let proteinColor = terracotta
    static let carbColor = Color(red: 0xC2 / 255, green: 0xA9 / 255, blue: 0x7E / 255)   // golden tan
    static let fatColor = Color(red: 0xE4 / 255, green: 0xBC / 255, blue: 0x76 / 255)    // honey
    static let hydrationColor = Color(red: 0x7A / 255, green: 0xA8 / 255, blue: 0xB8 / 255) // muted teal

    // Backwards-compat aliases (now warm)
    static let deepSea = bgTop
    static let chalkyMint = sage
    static let mint = sage
    static let pearl = Color.white.opacity(0.55)
}
