import Foundation
import Testing
@testable import ReceiptKit

@Suite("Spend analytics")
struct SpendAggregatorTests {
    let aggregator = SpendAggregator()
    var calendar: Calendar { aggregator.calendar }

    func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    @Test func weeksStartOnMonday() {
        let week = aggregator.interval(for: .week, containing: day(2026, 10, 31)) // a Saturday
        #expect(calendar.component(.weekday, from: week.start) == 2)
        #expect(calendar.component(.day, from: week.start) == 26)
    }

    @Test func quartersAreCalendarQuarters() {
        let q = aggregator.interval(for: .quarter, containing: day(2026, 11, 1))
        #expect(calendar.component(.month, from: q.start) == 10)
        #expect(calendar.component(.month, from: q.end) == 1)
    }

    @Test func totalsByPeriodAndCategory() {
        let entries = [
            SpendEntry(date: day(2026, 10, 31), amount: Decimal(string: "18.49")!, category: .food),
            SpendEntry(date: day(2026, 10, 30), amount: 84, category: .utilities),
            SpendEntry(date: day(2026, 9, 30), amount: 10, category: .food)
        ]
        let october = aggregator.interval(for: .month, containing: day(2026, 10, 15))
        #expect(aggregator.total(entries, in: october) == Decimal(string: "102.49")!)
        #expect(aggregator.totalsByCategory(entries, in: october)[.food] == Decimal(string: "18.49")!)
    }

    @Test func monthBucketsAreWeeksClippedToTheMonth() {
        let buckets = aggregator.buckets([], for: .month, containing: day(2026, 10, 15))
        #expect(buckets.count == 5)
        #expect(calendar.component(.day, from: buckets[0].start) == 1)
    }
}
