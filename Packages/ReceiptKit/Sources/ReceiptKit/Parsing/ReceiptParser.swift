import Foundation

/// Turns the text found on a receipt into merchant, date, items and totals.
///
/// The parser is deliberately simple and rule-based so it works offline and is easy to test.
/// Add a test fixture for every real receipt it gets wrong, then fix the rule.
public struct ReceiptParser: Sendable {
    public var merchants: MerchantDirectory

    public init(merchants: MerchantDirectory = MerchantDirectory()) {
        self.merchants = merchants
    }

    // MARK: - Rows

    /// Groups recognised text into visual rows, top to bottom, left to right.
    /// Receipts often print the item name on the left and the price on the right as separate text boxes.
    public func rows(from lines: [RecognizedLine]) -> [String] {
        let sorted = lines.sorted { $0.midY > $1.midY }
        var rows: [[RecognizedLine]] = []
        for line in sorted {
            if let last = rows.last, belongs(line, to: last) {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.map { row in
            row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: "  ")
        }
    }

    /// A line joins a row when it sits at the same height and doesn't overlap any text already in
    /// the row. Two boxes that overlap side to side can't be on the same printed line, so a slightly
    /// tilted photo no longer merges two items (and loses one price).
    private func belongs(_ line: RecognizedLine, to row: [RecognizedLine]) -> Bool {
        let rowMidY = row.map(\.midY).reduce(0, +) / Double(row.count)
        let rowHeight = row.map(\.height).max() ?? line.height
        guard abs(rowMidY - line.midY) < max(rowHeight, line.height) * 0.5 else { return false }
        return !row.contains { $0.minX < line.maxX && line.minX < $0.maxX }
    }

    public func parse(lines: [RecognizedLine]) -> ParsedReceipt {
        parse(rows: rows(from: lines))
    }

    // MARK: - Parsing

    public func parse(text: String) -> ParsedReceipt {
        parse(rows: text.components(separatedBy: .newlines))
    }

    public func parse(rows input: [String]) -> ParsedReceipt {
        let rows = input
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var receipt = ParsedReceipt(rawRows: rows)
        receipt.merchantName = findMerchant(in: rows)

        var reachedTotal = false
        var pendingName: String?

        for row in rows {
            let lower = row.lowercased()

            if receipt.purchaseDate == nil, let date = DateParser.date(in: row) {
                receipt.purchaseDate = date
                continue
            }
            if receipt.paymentMethod == nil, let method = paymentMethod(in: lower) {
                receipt.paymentMethod = method
            }

            guard let split = MoneyParser.splitTrailingAmount(row) else {
                // A row with words but no price may be an item name whose price is on the next row.
                if !reachedTotal, letterCount(row) >= 3 { pendingName = row }
                continue
            }
            let (label, amount) = (split.label, split.amount)

            if isSubtotal(lower) {
                receipt.subtotal = amount
            } else if isTotal(lower) {
                if receipt.total == nil { receipt.total = amount }
                reachedTotal = true
            } else if RX.matches(#"\bvat\b"#, lower) {
                if receipt.vat == nil { receipt.vat = amount }
            } else if !reachedTotal, !isNonItem(lower) {
                if let item = makeItem(label: label, amount: amount, pendingName: pendingName) {
                    receipt.items.append(item)
                }
                pendingName = nil
            }
        }
        return receipt
    }

    // MARK: - Helpers

    private func findMerchant(in rows: [String]) -> String? {
        for row in rows.prefix(6) {
            if let entry = merchants.match(row) { return entry.name }
        }
        return rows.first { letterCount($0) >= 3 && MoneyParser.splitTrailingAmount($0) == nil }
    }

    private func makeItem(label: String, amount: Decimal, pendingName: String?) -> ParsedLineItem? {
        // Aldi, Lidl and others print a product code before the name: "335782 Water Still Spring".
        var name = RX.replace(#"^\d{4,}\s+"#, in: label, with: "")
        // Lidl and others sometimes print the code after the name: "Speciality Blonde Be 0083184".
        name = RX.replace(#"\s+\d{5,}$"#, in: name, with: "")
        var quantity = 1

        // "2 x £1.50" or "2 @ 1.50" printed on its own row under the item name.
        if let g = RX.firstMatch(#"^(\d+)\s*[x@]\s*£?\d+\.\d{2}$"#, in: label), let q = g[1].flatMap({ Int($0) }) {
            quantity = q
            name = pendingName ?? label
        } else if let g = RX.firstMatch(#"^(.*?)\s+(\d+)\s*[x@]\s*£?\d+\.\d{2}$"#, in: label),
                  let base = g[1], let q = g[2].flatMap({ Int($0) }) {
            // "BANANAS 3 x 0.20" on one row.
            name = base
            quantity = q
        } else if let g = RX.firstMatch(#"^(\d+)\s*[x@]?\s+(.+)$"#, in: label),
                  let q = g[1].flatMap({ Int($0) }), q < 50, let base = g[2], letterCount(base) >= 2 {
            // "2 MILK 2L" with the quantity first.
            name = base
            quantity = q
        }

        guard letterCount(name) >= 2 else { return nil }

        let lower = name.lowercased()
        let isDiscount = amount < 0 || ["saving", "discount", "clubcard price", "nectar price", "promo", "offer", "% off"].contains { lower.contains($0) }
        let lineTotal = isDiscount && amount > 0 ? -amount : amount
        return ParsedLineItem(name: tidy(name), quantity: quantity, lineTotal: lineTotal, isDiscount: isDiscount)
    }

    private func isSubtotal(_ lower: String) -> Bool {
        lower.contains("subtotal") || lower.contains("sub-total") || lower.contains("sub total")
            // Aldi prints "Goods" for the sum of the items before any discounts.
            || RX.matches(#"^goods\b"#, lower)
    }

    private func isTotal(_ lower: String) -> Bool {
        if lower.contains("saving") || lower.contains("items") { return false }
        return RX.matches(#"^(grand\s+)?total\b|\btotal\s+(to\s+pay|due)\b|^balance(\s+due|\s+to\s+pay)?\b|^amount\s+due\b|^to\s+pay\b"#, lower)
            || lower.hasPrefix("total")
    }

    private func isNonItem(_ lower: String) -> Bool {
        let words = ["change", "cash", "card payment", "debit", "credit", "visa", "mastercard", "amex", "contactless", "tendered", "paid", "auth code", "tel:", "telephone", "vat no", "www.", "apple pay", "google pay", "balance"]
        return words.contains { lower.contains($0) }
    }

    private func paymentMethod(in lower: String) -> String? {
        if lower.contains("contactless") { return "Contactless" }
        if lower.contains("apple pay") { return "Apple Pay" }
        if lower.contains("visa") { return "Visa" }
        if lower.contains("mastercard") { return "Mastercard" }
        if lower.contains("amex") { return "American Express" }
        if RX.matches(#"^cash\b"#, lower) { return "Cash" }
        return nil
    }

    private func letterCount(_ text: String) -> Int {
        text.filter(\.isLetter).count
    }

    /// "SEMI SKIMMED MILK 2L" → "Semi Skimmed Milk 2L"
    private func tidy(_ name: String) -> String {
        let collapsed = name.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        guard collapsed == collapsed.uppercased() else { return collapsed }
        return collapsed.split(separator: " ").map { word in
            word.contains(where: \.isNumber) ? String(word) : String(word.prefix(1)) + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}
