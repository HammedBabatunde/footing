import Foundation
import SwiftData
import ReceiptKit

enum ReceiptSource: String, Codable, CaseIterable {
    case camera, photo, pdf, manual
}

@Model
final class Receipt {
    var id: UUID = UUID()
    var merchantName: String = ""
    var purchaseDate: Date = Date()
    /// Always GBP. Stored as Decimal so pence never drift.
    var total: Decimal = 0
    var vat: Decimal?
    var paymentMethod: String?
    var categoryRaw: String = SpendCategory.other.rawValue
    var sourceRaw: String = ReceiptSource.manual.rawValue
    /// Which engine picked the categories, e.g. "Apple Intelligence" or "Built-in rules".
    var categorisedBy: String?
    @Attribute(.externalStorage) var imageData: Data?
    var rawText: String = ""
    var createdAt: Date = Date()
    /// Set once this receipt has been copied to Notion. Nil means it still needs syncing.
    var notionPageID: String?
    var notionSyncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \LineItem.receipt)
    var items: [LineItem] = []

    init(merchantName: String, purchaseDate: Date, total: Decimal, category: SpendCategory, source: ReceiptSource) {
        self.merchantName = merchantName
        self.purchaseDate = purchaseDate
        self.total = total
        self.categoryRaw = category.rawValue
        self.sourceRaw = source.rawValue
    }

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var source: ReceiptSource {
        ReceiptSource(rawValue: sourceRaw) ?? .manual
    }

    var sortedItems: [LineItem] {
        items.sorted { $0.position < $1.position }
    }
}

extension Receipt {
    /// Spending split by category for analytics. Item amounts go to each item's category.
    /// Any gap between the items and the total (a receipt-wide discount or rounding) goes to the
    /// receipt's main category, so category totals always add up to the receipt total.
    var spendEntries: [SpendEntry] {
        var entries = items.map { SpendEntry(date: purchaseDate, amount: $0.lineTotal, category: $0.category) }
        let gap = total - items.reduce(Decimal.zero) { $0 + $1.lineTotal }
        if gap != 0 {
            entries.append(SpendEntry(date: purchaseDate, amount: gap, category: category))
        }
        return entries
    }
}
