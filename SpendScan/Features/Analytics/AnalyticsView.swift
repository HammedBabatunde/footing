import SwiftUI
import SwiftData
import Charts
import ReceiptKit

/// Figma screen 07: spend by week, month, quarter or year, and by category.
struct AnalyticsView: View {
    @Query private var receipts: [Receipt]
    @State private var period: SpendPeriod = .month
    @State private var anchor = Date.now

    private let aggregator = SpendAggregator()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Picker("Period", selection: $period) {
                        ForEach(SpendPeriod.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    stepper

                    Card {
                        Text("Total spent").font(.subheadline).foregroundStyle(Color.textSecondary)
                        AmountText(amount: total)
                        if previousTotal > 0 {
                            Text(changeText)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(total <= previousTotal ? Color.accentDefault : Color.statusNegative)
                        }
                    }

                    Card {
                        Text("Spend over time").font(.headline)
                        Chart(buckets) { bucket in
                            BarMark(
                                x: .value("Period", bucket.start, unit: barUnit),
                                y: .value("Spent", NSDecimalNumber(decimal: bucket.total).doubleValue)
                            )
                            .foregroundStyle(Color.accentDefault)
                            .cornerRadius(6)
                        }
                        .chartYAxis { AxisMarks(format: FloatingPointFormatStyle<Double>.Currency(code: "GBP").precision(.fractionLength(0))) }
                        .frame(height: 180)
                    }

                    Card {
                        Text("By category").font(.headline)
                        if byCategory.isEmpty {
                            Text("No spending in this period.").foregroundStyle(Color.textSecondary)
                        }
                        ForEach(byCategory) { row in
                            HStack(spacing: Spacing.md) {
                                CategoryIcon(category: row.category)
                                VStack(spacing: 6) {
                                    HStack {
                                        Text(row.category.displayName).font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(row.amount.gbp).font(.subheadline.weight(.semibold))
                                    }
                                    ProgressView(value: share(of: row))
                                        .tint(row.category.color)
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Analytics")
        }
    }

    private var stepper: some View {
        HStack {
            Button { anchor = aggregator.shift(anchor, by: -1, period) } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 36).background(Color.bgSurfaceSecondary, in: Circle())
            }
            Spacer()
            Text(periodTitle).font(.headline)
            Spacer()
            Button { anchor = aggregator.shift(anchor, by: 1, period) } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 36).background(Color.bgSurfaceSecondary, in: Circle())
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Numbers

    private var entries: [SpendEntry] { receipts.flatMap(\.spendEntries) }
    private var range: DateInterval { aggregator.interval(for: period, containing: anchor) }
    private var total: Decimal { aggregator.total(entries, in: range) }
    private var previousTotal: Decimal {
        aggregator.total(entries, in: aggregator.interval(for: period, containing: aggregator.shift(anchor, by: -1, period)))
    }
    private var buckets: [SpendBucket] { aggregator.buckets(entries, for: period, containing: anchor) }
    private var byCategory: [CategoryTotal] { CategoryTotal.list(aggregator.totalsByCategory(entries, in: range)) }

    private var barUnit: Calendar.Component {
        switch period {
        case .week: .day
        case .month: .weekOfYear
        case .quarter, .year: .month
        }
    }

    private func share(of row: CategoryTotal) -> Double {
        let all = NSDecimalNumber(decimal: total).doubleValue
        return all > 0 ? min(row.doubleValue / all, 1) : 0
    }

    private var changeText: String {
        let change = NSDecimalNumber(decimal: (total - previousTotal) / previousTotal * 100).doubleValue
        let rounded = Int(abs(change).rounded())
        return change <= 0 ? "▼ \(rounded)% less than the previous \(period.rawValue)" : "▲ \(rounded)% more than the previous \(period.rawValue)"
    }

    private var periodTitle: String {
        let start = range.start
        switch period {
        case .week: return "Week of \(start.formatted(.dateTime.day().month(.abbreviated)))"
        case .month: return start.formatted(.dateTime.month(.wide).year())
        case .quarter:
            let quarter = (aggregator.calendar.component(.month, from: start) - 1) / 3 + 1
            return "Q\(quarter) \(start.formatted(.dateTime.year()))"
        case .year: return start.formatted(.dateTime.year())
        }
    }
}

#Preview {
    AnalyticsView().modelContainer(PreviewData.container)
}
