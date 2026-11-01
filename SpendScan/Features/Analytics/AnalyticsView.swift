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
                    .onChange(of: period) { _, _ in anchor = .now }

                    stepper

                    Card {
                        Text("Total spent").font(.subheadline).foregroundStyle(Color.textSecondary)
                        AmountText(amount: total)
                        ChangeLabel(current: total, previous: previousTotal) { pct, isDown in
                            "\(pct)% \(isDown ? "less" : "more") than \(previousTitle) (\(previousTotal.gbp))"
                        }
                    }

                    chartCard
                    categoryCard
                    if !topMerchants.isEmpty { merchantsCard }
                }
                .padding(Spacing.lg)
            }
            .background(Color.bgPrimary)
            .navigationTitle("Analytics")
        }
    }

    // MARK: Cards

    /// Figma: "Spend by week". The biggest bar is solid green with its amount above it.
    private var chartCard: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Spend by \(bucketName)").font(.headline).foregroundStyle(Color.textPrimary)
                Spacer()
                if !buckets.isEmpty {
                    Text("Avg \(average.gbp) / \(bucketName)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Chart(buckets) { bucket in
                let isTop = bucket.id == topBucket?.id && bucket.total > 0
                BarMark(
                    x: .value("When", label(for: bucket)),
                    y: .value("Spent", NSDecimalNumber(decimal: bucket.total).doubleValue),
                    width: .ratio(0.62)
                )
                .foregroundStyle(isTop ? Color.accentDefault : Color.accentSubtle)
                .cornerRadius(6)
                .annotation(position: .top, spacing: 4) {
                    if isTop {
                        Text(bucket.total.gbp)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Color.borderDefault)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(Decimal(amount).wholePounds).font(.caption2).foregroundStyle(Color.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.caption2).foregroundStyle(Color.textSecondary)
                }
            }
            .frame(height: 190)

            if let top = topBucket, top.total > 0 {
                Text("Highest \(bucketName): \(rangeText(top)).")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    /// Figma: "By category". Icon, name, amount, a coloured bar and the share.
    private var categoryCard: some View {
        Card {
            Text("By category").font(.headline).foregroundStyle(Color.textPrimary)
            if byCategory.isEmpty {
                Text("No spending in this period.").foregroundStyle(Color.textSecondary)
            }
            ForEach(byCategory) { row in
                HStack(alignment: .top, spacing: Spacing.md) {
                    CategoryIcon(category: row.category, size: 36)
                    VStack(spacing: 4) {
                        HStack {
                            Text(row.category.displayName).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(row.amount.gbp).font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color.textPrimary)
                        HStack(spacing: Spacing.sm) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.bgSurfaceSecondary)
                                    Capsule().fill(row.category.color).frame(width: geo.size.width * share(of: row))
                                }
                            }
                            .frame(height: 6)
                            Text("\(Int((share(of: row) * 100).rounded()))%")
                                .font(.caption2)
                                .foregroundStyle(Color.textSecondary)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    /// Figma: "Top merchants".
    private var merchantsCard: some View {
        Card {
            Text("Top merchants").font(.headline).foregroundStyle(Color.textPrimary)
            ForEach(Array(topMerchants.enumerated()), id: \.element.name) { index, merchant in
                if index > 0 { Divider().overlay(Color.borderDefault) }
                HStack(spacing: Spacing.md) {
                    Text("\(index + 1)").font(.body).foregroundStyle(Color.textSecondary).frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(merchant.name).foregroundStyle(Color.textPrimary).lineLimit(1)
                        Text("\(merchant.count) receipt\(merchant.count == 1 ? "" : "s")")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Text(merchant.total.gbp).font(.headline).foregroundStyle(Color.textPrimary)
                }
            }
        }
    }

    private var stepper: some View {
        HStack {
            Button { anchor = aggregator.shift(anchor, by: -1, period) } label: {
                Image(systemName: "chevron.left").font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary).frame(width: 36, height: 36).background(Color.bgSurfaceSecondary, in: Circle())
            }
            Spacer()
            Text(periodTitle).font(.headline).foregroundStyle(Color.textPrimary)
            Spacer()
            Button { anchor = aggregator.shift(anchor, by: 1, period) } label: {
                Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary).frame(width: 36, height: 36).background(Color.bgSurfaceSecondary, in: Circle())
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

    private var bucketName: String {
        switch period {
        case .week: "day"
        case .month: "week"
        case .quarter, .year: "month"
        }
    }

    private var topBucket: SpendBucket? { buckets.max { $0.total < $1.total } }

    private var average: Decimal {
        buckets.isEmpty ? 0 : buckets.reduce(Decimal.zero) { $0 + $1.total } / Decimal(buckets.count)
    }

    private static let uk = Locale(identifier: "en_GB")

    /// Bar labels: "Mon" for a week, "5 Oct" for weeks in a month, "Oct" for months.
    private func label(for bucket: SpendBucket) -> String {
        switch period {
        case .week: bucket.start.formatted(.dateTime.weekday(.abbreviated).locale(Self.uk))
        case .month: bucket.start.formatted(.dateTime.day().month(.abbreviated).locale(Self.uk))
        case .quarter, .year: bucket.start.formatted(.dateTime.month(.abbreviated).locale(Self.uk))
        }
    }

    /// "5 to 11 October", "Tuesday 3 June" or "March".
    private func rangeText(_ bucket: SpendBucket) -> String {
        switch period {
        case .week:
            return bucket.start.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Self.uk))
        case .month:
            let last = aggregator.calendar.date(byAdding: .day, value: -1, to: bucket.end) ?? bucket.end
            return "\(bucket.start.formatted(.dateTime.day().locale(Self.uk))) to \(last.formatted(.dateTime.day().month(.wide).locale(Self.uk)))"
        case .quarter, .year:
            return bucket.start.formatted(.dateTime.month(.wide).locale(Self.uk))
        }
    }

    private var previousTitle: String {
        let previous = aggregator.interval(for: period, containing: aggregator.shift(anchor, by: -1, period)).start
        switch period {
        case .week: return "the week before"
        case .month: return previous.formatted(.dateTime.month(.wide).locale(Self.uk))
        case .quarter:
            let quarter = (aggregator.calendar.component(.month, from: previous) - 1) / 3 + 1
            return "Q\(quarter)"
        case .year: return previous.formatted(.dateTime.year())
        }
    }

    private struct MerchantTotal {
        var name: String
        var count: Int
        var total: Decimal
    }

    private var topMerchants: [MerchantTotal] {
        let inRange = receipts.filter { range.contains($0.purchaseDate) && !$0.merchantName.isEmpty }
        let grouped = Dictionary(grouping: inRange) { $0.merchantName }
        return grouped
            .map { MerchantTotal(name: $0.key, count: $0.value.count, total: $0.value.reduce(0) { $0 + $1.total }) }
            .sorted { $0.total > $1.total }
            .prefix(3)
            .map { $0 }
    }

    private func share(of row: CategoryTotal) -> Double {
        let all = NSDecimalNumber(decimal: total).doubleValue
        return all > 0 ? min(row.doubleValue / all, 1) : 0
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
