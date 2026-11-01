import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import ReceiptKit

/// A full copy of your receipts and category choices in one JSON file.
/// It's saved wherever you pick (Files, iCloud Drive, AirDrop to your Mac), so it survives
/// deleting the app. Making and restoring a backup needs no internet.
struct BackupFile: Codable {
    static let currentVersion = 1

    var version: Int = BackupFile.currentVersion
    var app = "SpendScan"
    var createdAt = Date()
    var receipts: [BackupReceipt]
    var rules: [BackupRule]
}

struct BackupReceipt: Codable {
    var id: UUID
    var merchantName: String
    var purchaseDate: Date
    var total: Decimal
    var vat: Decimal?
    var paymentMethod: String?
    var category: String
    var source: String
    var categorisedBy: String?
    var rawText: String
    var createdAt: Date
    /// The receipt photo, if there is one.
    var imageData: Data?
    var items: [BackupItem]
}

struct BackupItem: Codable {
    var name: String
    var quantity: Int
    var lineTotal: Decimal
    var isDiscount: Bool
    var category: String
    var position: Int
}

struct BackupRule: Codable {
    var keyword: String
    var category: String
    var createdAt: Date
}

enum BackupError: LocalizedError {
    case notABackup
    case tooNew

    var errorDescription: String? {
        switch self {
        case .notABackup: "That file isn't a SpendScan backup."
        case .tooNew: "That backup was made by a newer version of SpendScan. Update the app, then try again."
        }
    }
}

enum Backup {
    struct RestoreResult {
        var added: Int
        var skipped: Int
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static var suggestedFilename: String {
        "SpendScan backup \(Date().formatted(.iso8601.year().month().day()))"
    }

    /// Builds the backup file from everything in the app.
    static func make(context: ModelContext) throws -> Data {
        let receipts = try context.fetch(FetchDescriptor<Receipt>(sortBy: [SortDescriptor(\.purchaseDate)]))
        let rules = try context.fetch(FetchDescriptor<UserCategoryRule>())
        let file = BackupFile(
            receipts: receipts.map { receipt in
                BackupReceipt(
                    id: receipt.id,
                    merchantName: receipt.merchantName,
                    purchaseDate: receipt.purchaseDate,
                    total: receipt.total,
                    vat: receipt.vat,
                    paymentMethod: receipt.paymentMethod,
                    category: receipt.categoryRaw,
                    source: receipt.sourceRaw,
                    categorisedBy: receipt.categorisedBy,
                    rawText: receipt.rawText,
                    createdAt: receipt.createdAt,
                    imageData: receipt.imageData,
                    items: receipt.sortedItems.map {
                        BackupItem(name: $0.name, quantity: $0.quantity, lineTotal: $0.lineTotal,
                                   isDiscount: $0.isDiscount, category: $0.categoryRaw, position: $0.position)
                    }
                )
            },
            rules: rules.map { BackupRule(keyword: $0.keyword, category: $0.categoryRaw, createdAt: $0.createdAt) }
        )
        return try encoder.encode(file)
    }

    /// Adds the receipts from a backup. Receipts already in the app (same id) are left alone,
    /// so restoring the same file twice never makes duplicates.
    static func restore(_ data: Data, into context: ModelContext) throws -> RestoreResult {
        let file: BackupFile
        do {
            file = try decoder.decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.notABackup
        }
        guard file.app == "SpendScan" else { throw BackupError.notABackup }
        guard file.version <= BackupFile.currentVersion else { throw BackupError.tooNew }

        let existingIDs = Set(try context.fetch(FetchDescriptor<Receipt>()).map(\.id))
        var added = 0
        var skipped = 0
        for saved in file.receipts {
            if existingIDs.contains(saved.id) {
                skipped += 1
                continue
            }
            let receipt = Receipt(
                merchantName: saved.merchantName,
                purchaseDate: saved.purchaseDate,
                total: pence(saved.total),
                category: SpendCategory(rawValue: saved.category) ?? .other,
                source: ReceiptSource(rawValue: saved.source) ?? .manual
            )
            receipt.id = saved.id
            receipt.vat = saved.vat.map(pence)
            receipt.paymentMethod = saved.paymentMethod
            receipt.categorisedBy = saved.categorisedBy
            receipt.rawText = saved.rawText
            receipt.createdAt = saved.createdAt
            receipt.imageData = saved.imageData
            context.insert(receipt)
            for item in saved.items {
                let lineItem = LineItem(
                    name: item.name,
                    quantity: item.quantity,
                    lineTotal: pence(item.lineTotal),
                    isDiscount: item.isDiscount,
                    category: SpendCategory(rawValue: item.category) ?? .other,
                    position: item.position
                )
                lineItem.receipt = receipt
                context.insert(lineItem)
            }
            added += 1
        }

        let existingKeywords = Set(try context.fetch(FetchDescriptor<UserCategoryRule>()).map { $0.keyword.lowercased() })
        for rule in file.rules where !existingKeywords.contains(rule.keyword.lowercased()) {
            let newRule = UserCategoryRule(keyword: rule.keyword, category: SpendCategory(rawValue: rule.category) ?? .other)
            newRule.createdAt = rule.createdAt
            context.insert(newRule)
        }

        try context.save()
        return RestoreResult(added: added, skipped: skipped)
    }

    /// Rounds to whole pence, in case reading the file turned 1.10 into 1.0999999.
    private static func pence(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 2, .plain)
        return output
    }
}

/// Lets the system "Save to Files" sheet write the backup.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
