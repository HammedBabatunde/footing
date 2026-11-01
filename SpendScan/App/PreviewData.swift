import Foundation
import SwiftData
import ReceiptKit

/// Sample receipts matching the Figma designs, for SwiftUI previews and the debug button in Settings.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Receipt.self, LineItem.self, UserCategoryRule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        insertSamples(into: container.mainContext)
        return container
    }()

    static func insertSamples(into context: ModelContext) {
        let calendar = SpendAggregator.ukCalendar
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: .now)! }

        // Amounts are strings so pence are exact (Decimal from a Double literal can be off by a fraction).
        let samples: [(String, Int, SpendCategory, ReceiptSource, [(String, String, SpendCategory)])] = [
            ("Tesco Express", 0, .food, .camera, [
                ("Semi-skimmed milk 2L", "1.65", .food), ("Hovis Seed Sensations", "1.85", .food),
                ("Paracetamol 16 caplets", "0.75", .health), ("Fairy washing-up liquid", "1.50", .other),
                ("Chicken breast fillets 650g", "5.25", .food), ("Basmati rice 4kg", "7.49", .food)
            ]),
            ("Octopus Energy", 1, .utilities, .pdf, [("Electricity and gas, October", "84.00", .utilities)]),
            ("TfL", 2, .transport, .photo, [("Contactless journeys", "8.10", .transport)]),
            ("Boots", 4, .health, .camera, [("Vitamin D 90 tablets", "6.00", .health), ("Plasters 40 pack", "2.50", .health), ("Ibuprofen 16 tablets", "3.80", .health)]),
            ("Sainsbury's", 7, .food, .camera, [("Weekly shop", "46.72", .food)]),
            ("Thames Water", 9, .utilities, .pdf, [("Water bill", "38.50", .utilities)]),
            ("Trainline", 12, .transport, .pdf, [("London to Manchester return", "27.40", .transport)])
        ]

        for (merchant, days, category, source, items) in samples {
            let total = items.reduce(Decimal.zero) { $0 + (Decimal(string: $1.1) ?? 0) }
            let receipt = Receipt(merchantName: merchant, purchaseDate: daysAgo(days), total: total, category: category, source: source)
            receipt.categorisedBy = "Built-in rules"
            context.insert(receipt)
            for (index, item) in items.enumerated() {
                let line = LineItem(name: item.0, quantity: 1, lineTotal: Decimal(string: item.1) ?? 0, isDiscount: false, category: item.2, position: index)
                line.receipt = receipt
                context.insert(line)
            }
        }
    }
}
