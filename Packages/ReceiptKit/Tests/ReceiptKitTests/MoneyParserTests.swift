import Foundation
import Testing
@testable import ReceiptKit

@Suite("Money parsing")
struct MoneyParserTests {
    @Test(arguments: [
        ("1.50", Decimal(string: "1.50")!),
        ("£1.50", Decimal(string: "1.50")!),
        ("-0.50", Decimal(string: "-0.50")!),
        ("0.50-", Decimal(string: "-0.50")!),
        ("(0.50)", Decimal(string: "-0.50")!),
        ("£1,234.56", Decimal(string: "1234.56")!)
    ])
    func parsesAmounts(text: String, expected: Decimal) {
        #expect(MoneyParser.parse(text) == expected)
    }

    @Test func rejectsTextWithoutPence() {
        #expect(MoneyParser.parse("2041") == nil)
        #expect(MoneyParser.parse("MILK") == nil)
    }

    @Test func splitsLabelAndTrailingAmountIgnoringVATCode() throws {
        let split = try #require(MoneyParser.splitTrailingAmount("SEMI SKIMMED MILK 2L  1.65 A"))
        #expect(split.label == "SEMI SKIMMED MILK 2L")
        #expect(split.amount == Decimal(string: "1.65")!)
    }

    @Test func keepsQuantityTextInLabel() throws {
        let split = try #require(MoneyParser.splitTrailingAmount("2 x £1.50  £3.00"))
        #expect(split.label == "2 x £1.50")
        #expect(split.amount == Decimal(string: "3.00")!)
    }
}

@Suite("Date parsing")
struct DateParserTests {
    let calendar = SpendAggregator.ukCalendar

    @Test func readsDayFirstNumericDates() throws {
        let date = try #require(DateParser.date(in: "31/10/26 18:42"))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(parts.year == 2026 && parts.month == 10 && parts.day == 31)
        #expect(parts.hour == 18 && parts.minute == 42)
    }

    @Test func readsWrittenMonths() throws {
        let date = try #require(DateParser.date(in: "Date: 5 Nov 2026"))
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        #expect(parts.year == 2026 && parts.month == 11 && parts.day == 5)
    }

    @Test func rejectsImpossibleDates() {
        #expect(DateParser.date(in: "31/02/2026") == nil)
    }
}
