import Foundation
import SwiftData

/// A single line on the user's shopping list. Items can originate from the
/// scanned pantry (linked via `barcode`) or be added as a custom entry.
///
/// Workflow:
/// - User adds items to the list (often from their pantry).
/// - While shopping, they tap each item they could NOT purchase to mark
///   `keepOnList = true` (out of stock, wrong store, etc.).
/// - On "Shopping Complete", every item with `keepOnList == false` is
///   removed (assumed purchased) and items with `keepOnList == true`
///   carry over to the next trip with the flag reset.
@Model
final class ShoppingItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var brand: String
    /// Source pantry barcode if added from a scanned product. Empty for custom items.
    var barcode: String
    var quantity: Int
    /// User flagged this as "couldn't purchase — keep on next list".
    var keepOnList: Bool
    var addedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        barcode: String = "",
        quantity: Int = 1,
        keepOnList: Bool = false,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.quantity = quantity
        self.keepOnList = keepOnList
        self.addedAt = addedAt
    }
}
