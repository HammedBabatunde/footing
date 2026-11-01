import Foundation
import ReceiptKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The on-device AI engines, best first. None of them use the internet.
enum CategoryEngines {
    static func available() -> [any CategoryEngine] {
        var engines: [any CategoryEngine] = []
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelsEngine.isAvailable {
            engines.append(FoundationModelsEngine())
        }
        #endif
        engines.append(CoreMLEngine())
        return engines
    }

    /// Shown in Settings → AI engine.
    static var activeEngineName: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelsEngine.isAvailable {
            return "Apple Intelligence"
        }
        #endif
        return CoreMLEngine.isAvailable ? "Built-in model" : "Built-in rules"
    }
}

#if canImport(FoundationModels)
/// Uses the language model behind Apple Intelligence, running on the iPhone (iOS 26+,
/// iPhone 15 Pro or newer with Apple Intelligence turned on). Guided generation means the
/// model can only answer with one of our categories.
@available(iOS 26.0, *)
struct FoundationModelsEngine: CategoryEngine {
    let name = "Apple Intelligence"

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    @Generable
    enum Choice {
        case food, utilities, health, transport, other
    }

    @Generable
    struct Answer {
        @Guide(description: "The category that best describes the whole receipt")
        var receipt: Choice
        @Guide(description: "Exactly one category per item, in the same order as the numbered item list")
        var items: [Choice]
    }

    func categorise(_ receipt: ParsedReceipt) async throws -> CategoryAssignment? {
        guard Self.isAvailable, !receipt.items.isEmpty else { return nil }

        let session = LanguageModelSession(instructions: """
            You sort UK shop receipts into spending categories.
            food: groceries, drinks, takeaways, restaurants and cafes.
            utilities: energy, water, broadband, phone, council tax.
            health: medicine, pharmacy, toiletries for health, opticians, dentists.
            transport: trains, buses, the Tube, taxis, fuel, parking.
            other: anything else, such as household cleaning, clothes or gifts.
            """)

        let itemList = receipt.items.enumerated()
            .map { "\($0.offset + 1). \($0.element.name)" }
            .joined(separator: "\n")
        let prompt = "Shop: \(receipt.merchantName ?? "Unknown")\nItems:\n\(itemList)"

        let response = try await session.respond(to: prompt, generating: Answer.self)
        let answer = response.content
        guard answer.items.count == receipt.items.count else { return nil }
        return CategoryAssignment(receipt: answer.receipt.category, items: answer.items.map(\.category))
    }
}

@available(iOS 26.0, *)
extension FoundationModelsEngine.Choice {
    var category: SpendCategory {
        switch self {
        case .food: .food
        case .utilities: .utilities
        case .health: .health
        case .transport: .transport
        case .other: .other
        }
    }
}
#endif

/// For iPhones without Apple Intelligence: a small Core ML text classifier bundled with the app.
///
/// To add it: train a Text Classifier in Create ML on item names labelled food / utilities / health /
/// transport / other, export `CategoryClassifier.mlmodel`, drop it into the Resources folder, and
/// fill in `categorise` with `NLModel(contentsOf:)`. Until then this engine returns nil and the
/// built-in keyword rules are used.
struct CoreMLEngine: CategoryEngine {
    let name = "Built-in model"

    static var isAvailable: Bool {
        Bundle.main.url(forResource: "CategoryClassifier", withExtension: "mlmodelc") != nil
    }

    func categorise(_ receipt: ParsedReceipt) async throws -> CategoryAssignment? {
        guard Self.isAvailable else { return nil }
        return nil // TODO: load the model with NLModel and classify each item name.
    }
}
