import Foundation
import SwiftData
import ReceiptKit

/// A scanned receipt being checked before it is saved. One per receipt, so several
/// scanned at once can each be edited on their own and then saved together.
struct ReceiptDraft: Identifiable, Hashable {
    let id = UUID()
    var merchant: String
    var date: Date
    var total: Decimal
    var category: SpendCategory
    var items: [EditableItem]
    var paymentMethod: String?
    var vat: Decimal?
    var rawText: String
    var imageData: Data?
    var source: ReceiptSource
    /// Which engine picked the categories, e.g. "Apple Intelligence".
    var engine: String
    /// The category the AI or rules picked for the whole receipt, to spot your corrections.
    var suggestedCategory: SpendCategory?

    init(_ result: ScanResult) {
        let parsed = result.parsed
        merchant = parsed.merchantName ?? ""
        date = parsed.purchaseDate ?? Date()
        total = parsed.total ?? parsed.itemsTotal
        category = parsed.category ?? .other
        items = parsed.items.map(EditableItem.init)
        paymentMethod = parsed.paymentMethod
        vat = parsed.vat
        rawText = parsed.rawRows.joined(separator: "\n")
        imageData = result.imageData
        source = result.source
        engine = result.engine
        suggestedCategory = parsed.category
    }

    var itemsTotal: Decimal { items.reduce(0) { $0 + $1.lineTotal } }
    var itemsMatch: Bool { items.isEmpty || itemsTotal == total }

    /// Ready to save without a second look: it has a shop name and the items add up.
    var looksRight: Bool { !merchant.isEmpty && itemsMatch }

    static func == (a: ReceiptDraft, b: ReceiptDraft) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// Saves it as a receipt. With `learn` on, every category you changed becomes a rule,
    /// so the same shop or item is right automatically next time.
    func save(into context: ModelContext, learn: Bool) {
        let receipt = Receipt(merchantName: merchant.isEmpty ? "Receipt" : merchant, purchaseDate: date, total: total, category: category, source: source)
        receipt.imageData = imageData
        receipt.rawText = rawText
        receipt.vat = vat
        receipt.paymentMethod = paymentMethod
        receipt.categorisedBy = engine
        context.insert(receipt)

        for (index, item) in items.enumerated() where !item.name.isEmpty {
            let lineItem = LineItem(name: item.name, quantity: item.quantity, lineTotal: item.lineTotal, isDiscount: item.isDiscount, category: item.category, position: index)
            lineItem.receipt = receipt
            context.insert(lineItem)
        }

        if learn {
            for item in items where item.category != item.suggestedCategory && !item.name.isEmpty {
                context.insert(UserCategoryRule(keyword: item.name, category: item.category))
            }
            if category != suggestedCategory, !merchant.isEmpty {
                context.insert(UserCategoryRule(keyword: merchant, category: category))
            }
        }
    }
}
