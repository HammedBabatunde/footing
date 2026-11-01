import Foundation
import SwiftData
import ReceiptKit

@Model
final class LineItem {
    var name: String = ""
    var quantity: Int = 1
    /// Price for the whole line. Negative for discounts.
    var lineTotal: Decimal = 0
    var isDiscount: Bool = false
    var categoryRaw: String = SpendCategory.other.rawValue
    /// Order on the receipt.
    var position: Int = 0
    var receipt: Receipt?

    init(name: String, quantity: Int, lineTotal: Decimal, isDiscount: Bool, category: SpendCategory, position: Int) {
        self.name = name
        self.quantity = quantity
        self.lineTotal = lineTotal
        self.isDiscount = isDiscount
        self.categoryRaw = category.rawValue
        self.position = position
    }

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var unitPrice: Decimal {
        quantity > 0 ? lineTotal / Decimal(quantity) : lineTotal
    }
}
