import Foundation

/// One line of text found on a receipt image, in Vision's normalised coordinates
/// (0...1, origin at the bottom left).
public struct RecognizedLine: Sendable, Equatable {
    public var text: String
    public var minX: Double
    public var maxX: Double
    public var midY: Double
    public var height: Double

    public init(text: String, minX: Double, maxX: Double, midY: Double, height: Double) {
        self.text = text
        self.minX = minX
        self.maxX = maxX
        self.midY = midY
        self.height = height
    }
}

public struct ParsedLineItem: Sendable, Equatable {
    public var name: String
    public var quantity: Int
    /// Price for the whole line (quantity × unit price). Negative for discounts.
    public var lineTotal: Decimal
    public var isDiscount: Bool
    public var category: SpendCategory?

    public init(name: String, quantity: Int = 1, lineTotal: Decimal, isDiscount: Bool = false, category: SpendCategory? = nil) {
        self.name = name
        self.quantity = quantity
        self.lineTotal = lineTotal
        self.isDiscount = isDiscount
        self.category = category
    }

    public var unitPrice: Decimal {
        quantity > 0 ? lineTotal / Decimal(quantity) : lineTotal
    }
}

public struct ParsedReceipt: Sendable, Equatable {
    public var merchantName: String?
    public var purchaseDate: Date?
    public var items: [ParsedLineItem]
    public var subtotal: Decimal?
    public var vat: Decimal?
    public var total: Decimal?
    public var paymentMethod: String?
    public var category: SpendCategory?
    /// The text rows the parser worked from, top to bottom.
    public var rawRows: [String]

    public init(merchantName: String? = nil, purchaseDate: Date? = nil, items: [ParsedLineItem] = [], subtotal: Decimal? = nil, vat: Decimal? = nil, total: Decimal? = nil, paymentMethod: String? = nil, category: SpendCategory? = nil, rawRows: [String] = []) {
        self.merchantName = merchantName
        self.purchaseDate = purchaseDate
        self.items = items
        self.subtotal = subtotal
        self.vat = vat
        self.total = total
        self.paymentMethod = paymentMethod
        self.category = category
        self.rawRows = rawRows
    }

    /// Sum of all line totals, discounts included.
    public var itemsTotal: Decimal {
        items.reduce(Decimal.zero) { $0 + $1.lineTotal }
    }

    /// True when the items add up to the printed total (to the penny).
    public var itemsMatchTotal: Bool {
        guard let total else { return false }
        return itemsTotal == total
    }
}
