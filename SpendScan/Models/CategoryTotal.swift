import Foundation
import ReceiptKit

/// Money spent in one category, for charts and lists.
struct CategoryTotal: Identifiable {
    var category: SpendCategory
    var amount: Decimal
    var id: SpendCategory { category }

    var doubleValue: Double { NSDecimalNumber(decimal: amount).doubleValue }

    /// Non-zero categories, biggest first.
    static func list(_ totals: [SpendCategory: Decimal]) -> [CategoryTotal] {
        totals
            .filter { $0.value > 0 }
            .map { CategoryTotal(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}
