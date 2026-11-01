import Foundation

/// Common UK merchants and the category their receipts usually belong to.
/// Matching ignores case, spaces and punctuation, so "TESCO STORES 2041" matches "Tesco".
public struct MerchantDirectory: Sendable {
    public struct Entry: Sendable, Equatable {
        public var name: String
        public var aliases: [String]
        public var category: SpendCategory

        public init(name: String, aliases: [String] = [], category: SpendCategory) {
            self.name = name
            self.aliases = aliases
            self.category = category
        }
    }

    public var entries: [Entry]

    public init(entries: [Entry] = MerchantDirectory.ukDefaults) {
        self.entries = entries
    }

    /// Finds the merchant whose name or alias appears in `text`.
    public func match(_ text: String) -> Entry? {
        let haystack = Self.normalise(text)
        guard !haystack.isEmpty else { return nil }
        return entries.first { entry in
            ([entry.name] + entry.aliases).contains { haystack.contains(Self.normalise($0)) }
        }
    }

    static func normalise(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    public static let ukDefaults: [Entry] = [
        Entry(name: "Tesco", category: .food),
        Entry(name: "Sainsbury's", aliases: ["Sainsburys"], category: .food),
        Entry(name: "Asda", category: .food),
        Entry(name: "Aldi", category: .food),
        Entry(name: "Lidl", category: .food),
        Entry(name: "Morrisons", category: .food),
        Entry(name: "Waitrose", category: .food),
        Entry(name: "Co-op", aliases: ["Coop", "Co-operative"], category: .food),
        Entry(name: "Iceland", category: .food),
        Entry(name: "M&S", aliases: ["Marks & Spencer", "Marks and Spencer"], category: .food),
        Entry(name: "Greggs", category: .food),
        Entry(name: "Pret", aliases: ["Pret A Manger"], category: .food),
        Entry(name: "Boots", category: .health),
        Entry(name: "Superdrug", category: .health),
        Entry(name: "Lloydspharmacy", aliases: ["Lloyds Pharmacy"], category: .health),
        Entry(name: "TfL", aliases: ["Transport for London"], category: .transport),
        Entry(name: "Trainline", category: .transport),
        Entry(name: "National Rail", category: .transport),
        Entry(name: "Uber", category: .transport),
        Entry(name: "Shell", category: .transport),
        Entry(name: "BP", category: .transport),
        Entry(name: "Esso", category: .transport),
        Entry(name: "British Gas", category: .utilities),
        Entry(name: "Octopus Energy", aliases: ["Octopus"], category: .utilities),
        Entry(name: "EDF", category: .utilities),
        Entry(name: "E.ON", aliases: ["EON Next"], category: .utilities),
        Entry(name: "OVO", category: .utilities),
        Entry(name: "Thames Water", category: .utilities),
        Entry(name: "BT", aliases: ["British Telecom"], category: .utilities),
        Entry(name: "Virgin Media", category: .utilities),
        Entry(name: "Vodafone", category: .utilities),
        Entry(name: "EE", category: .utilities),
        Entry(name: "Three", category: .utilities),
        Entry(name: "Council Tax", category: .utilities)
    ]
}
