import Foundation

/// A category chosen for a whole receipt and for each of its items (same order as `ParsedReceipt.items`).
public struct CategoryAssignment: Sendable, Equatable {
    public var receipt: SpendCategory
    public var items: [SpendCategory]

    public init(receipt: SpendCategory, items: [SpendCategory]) {
        self.receipt = receipt
        self.items = items
    }
}

/// Anything that can suggest categories: the on-device language model, a Core ML classifier, or rules.
/// Every engine must work offline.
public protocol CategoryEngine: Sendable {
    var name: String { get }
    /// Returns nil when the engine is not available on this device.
    func categorise(_ receipt: ParsedReceipt) async throws -> CategoryAssignment?
}

/// A keyword (or merchant name) that always maps to a category. User corrections are saved as rules.
public struct CategoryRule: Sendable, Equatable, Codable {
    public var keyword: String
    public var category: SpendCategory

    public init(keyword: String, category: SpendCategory) {
        self.keyword = keyword
        self.category = category
    }

    func matches(_ text: String) -> Bool {
        let needle = MerchantDirectory.normalise(keyword)
        return !needle.isEmpty && MerchantDirectory.normalise(text).contains(needle)
    }
}

/// Built-in keyword rules for common UK receipt items.
public struct KeywordEngine: CategoryEngine {
    public let name = "Built-in rules"
    public var merchants: MerchantDirectory
    public var keywords: [CategoryRule]

    public init(merchants: MerchantDirectory = MerchantDirectory(), keywords: [CategoryRule] = KeywordEngine.ukDefaults) {
        self.merchants = merchants
        self.keywords = keywords
    }

    public func categorise(_ receipt: ParsedReceipt) async throws -> CategoryAssignment? {
        let merchantCategory = receipt.merchantName.flatMap { merchants.match($0)?.category }
        let items = receipt.items.map { item in
            keywords.first { $0.matches(item.name) }?.category ?? merchantCategory ?? .other
        }
        return CategoryAssignment(receipt: merchantCategory ?? Categoriser.mostSpent(receipt.items, items) ?? .other, items: items)
    }

    public static let ukDefaults: [CategoryRule] = {
        let groups: [(SpendCategory, [String])] = [
            (.health, ["paracetamol", "ibuprofen", "vitamin", "plaster", "prescription", "antiseptic", "cough", "allergy", "pharmacy", "lemsip", "nurofen", "calpol"]),
            (.transport, ["petrol", "diesel", "unleaded", "train ticket", "bus fare", "oyster", "railcard", "parking", "taxi"]),
            (.utilities, ["electricity", "gas supply", "standing charge", "water rates", "broadband", "council tax", "sim only", "phone bill"]),
            (.other, ["washing up", "washing-up", "bin bags", "detergent", "toilet roll", "batteries", "carrier bag", "bag for life"]),
            (.food, ["milk", "bread", "chicken", "rice", "banana", "egg", "cheese", "apple", "beef", "pasta", "yoghurt", "yogurt", "juice", "coffee", "tea", "sandwich", "meal deal", "butter", "tomato", "potato", "onion", "fish", "lamb", "yam", "plantain"])
        ]
        return groups.flatMap { category, words in words.map { CategoryRule(keyword: $0, category: category) } }
    }()
}

/// Picks categories for a parsed receipt, fully on the device.
///
/// Order of priority for each item:
/// 1. Your own rules (saved when you correct a category).
/// 2. The first AI engine that is available (Apple Intelligence, then the bundled Core ML model).
/// 3. Built-in keyword and merchant rules.
public struct Categoriser: Sendable {
    public var userRules: [CategoryRule]
    public var aiEngines: [any CategoryEngine]
    public var fallback: KeywordEngine

    public init(userRules: [CategoryRule] = [], aiEngines: [any CategoryEngine] = [], fallback: KeywordEngine = KeywordEngine()) {
        self.userRules = userRules
        self.aiEngines = aiEngines
        self.fallback = fallback
    }

    /// Returns the receipt with `category` set on it and on every item, plus the name of the engine used.
    public func categorise(_ receipt: ParsedReceipt) async -> (receipt: ParsedReceipt, engine: String) {
        var ai: CategoryAssignment?
        var engineName = fallback.name
        for engine in aiEngines {
            if let result = try? await engine.categorise(receipt), result.items.count == receipt.items.count {
                ai = result
                engineName = engine.name
                break
            }
        }
        let rules = (try? await fallback.categorise(receipt)) ?? CategoryAssignment(receipt: .other, items: receipt.items.map { _ in .other })

        var output = receipt
        for index in output.items.indices {
            let name = output.items[index].name
            output.items[index].category = userRules.first { $0.matches(name) }?.category
                ?? ai?.items[index]
                ?? rules.items[index]
        }

        let merchantRule = receipt.merchantName.flatMap { merchant in userRules.first { $0.matches(merchant) }?.category }
        let knownMerchant = receipt.merchantName.flatMap { fallback.merchants.match($0)?.category }
        output.category = merchantRule ?? knownMerchant ?? ai?.receipt ?? rules.receipt
        return (output, engineName)
    }

    /// The category with the most money spent on it.
    static func mostSpent(_ items: [ParsedLineItem], _ categories: [SpendCategory]) -> SpendCategory? {
        var totals: [SpendCategory: Decimal] = [:]
        for (item, category) in zip(items, categories) where !item.isDiscount {
            totals[category, default: 0] += item.lineTotal
        }
        return totals.max { $0.value < $1.value }?.key
    }
}
