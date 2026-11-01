import Foundation

public enum SpendPeriod: String, CaseIterable, Sendable, Identifiable {
    case week, month, quarter, year
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// One amount of spending on a date, in one category.
public struct SpendEntry: Sendable, Equatable {
    public var date: Date
    public var amount: Decimal
    public var category: SpendCategory

    public init(date: Date, amount: Decimal, category: SpendCategory) {
        self.date = date
        self.amount = amount
        self.category = category
    }
}

public struct SpendBucket: Sendable, Equatable, Identifiable {
    public var start: Date
    public var end: Date
    public var total: Decimal
    public var id: Date { start }
}

/// Sums spending by week, month, quarter and year. Weeks start on Monday (UK).
public struct SpendAggregator: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = SpendAggregator.ukCalendar) {
        self.calendar = calendar
    }

    public static var ukCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        calendar.minimumDaysInFirstWeek = 4
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }

    /// The week, month, quarter or year that contains `date`.
    public func interval(for period: SpendPeriod, containing date: Date) -> DateInterval {
        switch period {
        case .week: return calendar.dateInterval(of: .weekOfYear, for: date)!
        case .month: return calendar.dateInterval(of: .month, for: date)!
        case .year: return calendar.dateInterval(of: .year, for: date)!
        case .quarter:
            // Calendar's .quarter support is unreliable, so work it out from the month.
            let month = calendar.component(.month, from: date)
            let year = calendar.component(.year, from: date)
            let firstMonth = ((month - 1) / 3) * 3 + 1
            let start = calendar.date(from: DateComponents(year: year, month: firstMonth, day: 1))!
            let end = calendar.date(byAdding: .month, value: 3, to: start)!
            return DateInterval(start: start, end: end)
        }
    }

    /// Moves `date` forward (positive) or back (negative) by whole periods.
    public func shift(_ date: Date, by count: Int, _ period: SpendPeriod) -> Date {
        switch period {
        case .week: calendar.date(byAdding: .weekOfYear, value: count, to: date)!
        case .month: calendar.date(byAdding: .month, value: count, to: date)!
        case .quarter: calendar.date(byAdding: .month, value: count * 3, to: date)!
        case .year: calendar.date(byAdding: .year, value: count, to: date)!
        }
    }

    public func total(_ entries: [SpendEntry], in interval: DateInterval) -> Decimal {
        entries.filter { contains(interval, $0.date) }.reduce(0) { $0 + $1.amount }
    }

    public func totalsByCategory(_ entries: [SpendEntry], in interval: DateInterval) -> [SpendCategory: Decimal] {
        var totals: [SpendCategory: Decimal] = [:]
        for entry in entries where contains(interval, entry.date) {
            totals[entry.category, default: 0] += entry.amount
        }
        return totals
    }

    /// Chart bars for a period: days of a week, weeks of a month, months of a quarter or year.
    public func buckets(_ entries: [SpendEntry], for period: SpendPeriod, containing date: Date) -> [SpendBucket] {
        let range = interval(for: period, containing: date)
        var result: [SpendBucket] = []
        var start = range.start
        while start < range.end {
            let next: Date
            switch period {
            case .week: next = calendar.date(byAdding: .day, value: 1, to: start)!
            case .month: next = min(calendar.dateInterval(of: .weekOfYear, for: start)!.end, range.end)
            case .quarter, .year: next = calendar.date(byAdding: .month, value: 1, to: start)!
            }
            let bucket = DateInterval(start: start, end: next)
            result.append(SpendBucket(start: start, end: next, total: total(entries, in: bucket)))
            start = next
        }
        return result
    }

    /// DateInterval.contains includes the end date; periods here are half-open.
    private func contains(_ interval: DateInterval, _ date: Date) -> Bool {
        date >= interval.start && date < interval.end
    }
}
