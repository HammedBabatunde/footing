import Foundation
import SwiftData
import ReceiptKit

/// Column names in the Notion database. Change them here and in Notion together.
enum NotionSchema {
    static let merchant = "Merchant"
    static let date = "Date"
    static let total = "Total"
    static let category = "Category"
    static let itemCategories = "Item categories"
    static let items = "Items"
    static let itemCount = "Item count"
    static let vat = "VAT"
    static let payment = "Payment"
    static let source = "Source"
    static let categorisedBy = "Categorised by"
    static let receiptID = "Receipt ID"

    static var categoryOptions: [[String: String]] {
        SpendCategory.allCases.map { ["name": $0.displayName, "color": color(for: $0)] }
    }

    private static func color(for category: SpendCategory) -> String {
        switch category {
        case .food: "orange"
        case .utilities: "blue"
        case .health: "red"
        case .transport: "purple"
        case .other: "gray"
        }
    }
}

/// Small builders for Notion's JSON shapes.
enum NotionValue {
    /// Notion caps each piece of text at 2,000 characters.
    static func text(_ content: String) -> [String: Any] {
        ["type": "text", "text": ["content": String(content.prefix(2000))]]
    }

    static func richText(_ content: String) -> [String: Any] {
        ["rich_text": [text(content)]]
    }

    static func paragraph(_ content: String) -> [String: Any] {
        ["object": "block", "type": "paragraph", "paragraph": richText(content)]
    }

    static func heading(_ content: String) -> [String: Any] {
        ["object": "block", "type": "heading_3", "heading_3": richText(content)]
    }

    static func tableRow(_ cells: [String]) -> [String: Any] {
        let cellValues: [[[String: Any]]] = cells.map { [text($0)] }
        return ["type": "table_row", "table_row": ["cells": cellValues]]
    }

    static func number(_ value: Decimal) -> [String: Any] {
        ["number": NSDecimalNumber(decimal: value)]
    }
}

/// Copies receipts to a Notion database about once a week, whenever the iPhone is online.
/// The app never needs Notion to work: scanning, AI categories and analytics stay on the iPhone.
/// Sync only sends data to Notion; it never downloads or changes anything in the app.
@MainActor
@Observable
final class NotionSync {
    static let shared = NotionSync()

    enum Status: Equatable {
        case idle
        case syncing
        case synced(Int)
        case failed(String)
    }

    static let syncInterval: TimeInterval = 7 * 24 * 60 * 60

    private enum Keys {
        static let token = "notionToken"                 // Keychain
        static let databaseID = "notionDatabaseID"       // UserDefaults
        static let lastSync = "notionLastSync"
        static let autoSync = "notionAutoSync"
        static let pendingArchive = "notionPendingArchive"
    }

    private let defaults = UserDefaults.standard

    var status: Status = .idle
    private(set) var lastSync: Date?
    private(set) var databaseID: String?
    private(set) var hasToken: Bool

    var autoSync: Bool {
        didSet { defaults.set(autoSync, forKey: Keys.autoSync) }
    }

    var isConnected: Bool { hasToken && databaseID != nil }

    var nextSyncDue: Date? {
        guard isConnected, autoSync else { return nil }
        return (lastSync ?? .distantPast).addingTimeInterval(Self.syncInterval)
    }

    private init() {
        let stored = UserDefaults.standard
        lastSync = stored.object(forKey: Keys.lastSync) as? Date
        databaseID = stored.string(forKey: Keys.databaseID)
        hasToken = KeychainStore.get(Keys.token) != nil
        autoSync = stored.object(forKey: Keys.autoSync) as? Bool ?? true
    }

    // MARK: - Setup

    /// Checks the secret, creates the "SpendScan receipts" database in the given page, and saves both.
    func connect(secret: String, pageLink: String) async throws {
        let secret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty else { throw NotionError.badToken }
        guard let pageID = NotionLink.pageID(from: pageLink) else {
            throw NotionError.server(0, "That doesn't look like a Notion page link.")
        }
        let client = NotionClient(token: secret)
        try await client.checkToken()
        let newDatabaseID = try await client.createReceiptsDatabase(inPage: pageID)

        KeychainStore.set(secret, for: Keys.token)
        defaults.set(newDatabaseID, forKey: Keys.databaseID)
        hasToken = true
        databaseID = newDatabaseID
        lastSync = nil
        defaults.removeObject(forKey: Keys.lastSync)
        status = .idle
    }

    /// Forgets the secret and database. Receipts already in Notion stay there.
    func disconnect(context: ModelContext) {
        KeychainStore.delete(Keys.token)
        defaults.removeObject(forKey: Keys.databaseID)
        defaults.removeObject(forKey: Keys.lastSync)
        defaults.removeObject(forKey: Keys.pendingArchive)
        hasToken = false
        databaseID = nil
        lastSync = nil
        status = .idle
        // So that connecting a new database later copies every receipt again.
        if let synced = try? context.fetch(FetchDescriptor<Receipt>(predicate: #Predicate { $0.notionPageID != nil })) {
            for receipt in synced {
                receipt.notionPageID = nil
                receipt.notionSyncedAt = nil
            }
            try? context.save()
        }
    }

    // MARK: - Syncing

    /// Called whenever the app opens. Syncs if it has been a week or more since the last sync.
    func syncIfDue(context: ModelContext) async {
        guard let due = nextSyncDue, due <= Date() else { return }
        await sync(context: context)
    }

    /// Remembers a deleted receipt so its Notion page is moved to the trash at the next sync.
    static func receiptWillBeDeleted(_ receipt: Receipt) {
        guard let pageID = receipt.notionPageID else { return }
        var pending = UserDefaults.standard.stringArray(forKey: Keys.pendingArchive) ?? []
        pending.append(pageID)
        UserDefaults.standard.set(pending, forKey: Keys.pendingArchive)
    }

    func pendingCount(context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<Receipt>(predicate: #Predicate { $0.notionPageID == nil }))) ?? 0
    }

    func sync(context: ModelContext) async {
        guard status != .syncing,
              let databaseID,
              let token = KeychainStore.get(Keys.token) else { return }
        status = .syncing
        let client = NotionClient(token: token)

        do {
            // 1. Deleted receipts: move their pages to Notion's trash.
            var pending = defaults.stringArray(forKey: Keys.pendingArchive) ?? []
            while let pageID = pending.first {
                do {
                    try await client.archivePage(pageID)
                } catch NotionError.noAccess {
                    // Already gone in Notion. Nothing to do.
                }
                pending.removeFirst()
                defaults.set(pending, forKey: Keys.pendingArchive)
                try await Task.sleep(for: .milliseconds(350))
            }

            // 2. New receipts: add a page for each.
            let descriptor = FetchDescriptor<Receipt>(
                predicate: #Predicate { $0.notionPageID == nil },
                sortBy: [SortDescriptor(\.purchaseDate)]
            )
            let unsynced = try context.fetch(descriptor)
            var count = 0
            for receipt in unsynced {
                let pageID = try await client.createPage(
                    databaseID: databaseID,
                    properties: properties(for: receipt),
                    children: blocks(for: receipt)
                )
                receipt.notionPageID = pageID
                receipt.notionSyncedAt = Date()
                try context.save()
                count += 1
                try await Task.sleep(for: .milliseconds(350))
            }

            lastSync = Date()
            defaults.set(lastSync, forKey: Keys.lastSync)
            status = .synced(count)
        } catch NotionError.offline {
            // Try again next time the app opens. Not an error worth showing.
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Receipt → Notion

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func properties(for receipt: Receipt) -> [String: Any] {
        let items = receipt.sortedItems
        let itemSummary = items
            .map { "\($0.name)\($0.quantity > 1 ? " ×\($0.quantity)" : ""): \($0.lineTotal.gbp) (\($0.category.displayName))" }
            .joined(separator: "\n")
        var itemCategoryNames: [String] = []
        for category in items.map(\.category) where !itemCategoryNames.contains(category.displayName) {
            itemCategoryNames.append(category.displayName)
        }

        var properties: [String: Any] = [
            NotionSchema.merchant: ["title": [NotionValue.text(receipt.merchantName.isEmpty ? "Receipt" : receipt.merchantName)]],
            NotionSchema.date: ["date": ["start": Self.dayFormatter.string(from: receipt.purchaseDate)]],
            NotionSchema.total: NotionValue.number(receipt.total),
            NotionSchema.category: ["select": ["name": receipt.category.displayName]],
            NotionSchema.itemCategories: ["multi_select": itemCategoryNames.map { ["name": $0] }],
            NotionSchema.items: NotionValue.richText(itemSummary),
            NotionSchema.itemCount: ["number": items.count],
            NotionSchema.source: ["select": ["name": receipt.source.rawValue.capitalized]],
            NotionSchema.categorisedBy: NotionValue.richText(receipt.categorisedBy ?? ""),
            NotionSchema.receiptID: NotionValue.richText(receipt.id.uuidString),
        ]
        if let vat = receipt.vat {
            properties[NotionSchema.vat] = NotionValue.number(vat)
        }
        if let payment = receipt.paymentMethod {
            properties[NotionSchema.payment] = NotionValue.richText(payment)
        }
        return properties
    }

    /// The page body: a table of items, then the raw text read from the receipt.
    private func blocks(for receipt: Receipt) -> [[String: Any]] {
        var blocks: [[String: Any]] = [NotionValue.heading("Items")]
        let items = receipt.sortedItems
        if items.isEmpty {
            blocks.append(NotionValue.paragraph("No items were read from this receipt."))
        } else {
            // Notion allows up to 100 rows in one request, including the header.
            var rows = [NotionValue.tableRow(["Item", "Qty", "Price", "Category"])]
            for item in items.prefix(99) {
                rows.append(NotionValue.tableRow([item.name, "\(item.quantity)", item.lineTotal.gbp, item.category.displayName]))
            }
            let table: [String: Any] = ["table_width": 4, "has_column_header": true, "has_row_header": false, "children": rows]
            blocks.append(["object": "block", "type": "table", "table": table])
            if items.count > 99 {
                blocks.append(NotionValue.paragraph("\(items.count - 99) more items are in the app."))
            }
        }

        let raw = receipt.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            blocks.append(NotionValue.heading("Text read from the receipt"))
            var remaining = Substring(raw)
            while !remaining.isEmpty && blocks.count < 20 {
                blocks.append(NotionValue.paragraph(String(remaining.prefix(2000))))
                remaining = remaining.dropFirst(2000)
            }
        }
        return blocks
    }
}
