import Foundation

/// Finds a purchase date (and time, when printed) in a receipt row. Dates are read day first, UK style.
public enum DateParser {
    private static let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    public static func date(in row: String, calendar: Calendar = SpendAggregator.ukCalendar) -> Date? {
        var day: Int?
        var month: Int?
        var year: Int?

        if let g = RX.firstMatch(#"\b(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})\b"#, in: row) {
            day = g[1].flatMap { Int($0) }
            month = g[2].flatMap { Int($0) }
            year = g[3].flatMap { Int($0) }
        } else if let g = RX.firstMatch(#"\b(\d{1,2})(?:st|nd|rd|th)?\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?,?\s*(\d{2,4})\b"#, in: row) {
            day = g[1].flatMap { Int($0) }
            month = g[2].flatMap { name in months.firstIndex(of: name.lowercased()).map { $0 + 1 } }
            year = g[3].flatMap { Int($0) }
        }

        guard let d = day, let m = month, var y = year, (1...31).contains(d), (1...12).contains(m) else { return nil }
        if y < 100 { y += 2000 }

        var components = DateComponents(year: y, month: m, day: d)
        if let t = RX.firstMatch(#"\b([01]?\d|2[0-3]):([0-5]\d)\b"#, in: row) {
            components.hour = t[1].flatMap { Int($0) }
            components.minute = t[2].flatMap { Int($0) }
        }
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == d else { return nil }
        return date
    }
}
