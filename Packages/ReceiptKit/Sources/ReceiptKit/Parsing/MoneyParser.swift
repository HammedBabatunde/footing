import Foundation

/// Reads GBP amounts as printed on UK receipts.
public enum MoneyParser {
    private static let amountPattern = #"\(?-?\s*£?\s*(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{2}\s*\)?-?"#

    /// Parses "£1.50", "1.50", "-0.50", "0.50-", "(0.50)" and "1,234.56".
    public static func parse(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard let match = RX.firstMatch("^" + amountPattern + "$", in: trimmed)?.first, let raw = match else { return nil }
        let isNegative = raw.contains("-") || raw.contains("(")
        let digits = raw.filter { $0.isNumber || $0 == "." }
        guard let value = Decimal(string: digits, locale: Locale(identifier: "en_GB")) else { return nil }
        return isNegative ? -value : value
    }

    /// Splits a receipt row such as "MILK 2L   £1.65 A" into ("MILK 2L", 1.65).
    /// A trailing VAT code (one or two capital letters or "*") after the amount is ignored.
    public static func splitTrailingAmount(_ row: String) -> (label: String, amount: Decimal)? {
        let pattern = #"^(.*?)[\s:]*("# + amountPattern + #")(?:\s+[A-Z*]{1,2})?\s*$"#
        guard let groups = RX.firstMatch(pattern, in: row, caseInsensitive: false),
              groups.count >= 3,
              let amountText = groups[2],
              let amount = parse(amountText) else { return nil }
        let label = (groups[1] ?? "").trimmingCharacters(in: .whitespaces)
        return (label, amount)
    }
}
