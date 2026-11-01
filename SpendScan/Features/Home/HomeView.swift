import SwiftUI
import SwiftData
import Charts
import ReceiptKit

/// Figma screen 01.
struct HomeView: View {
    @Binding var selection: AppTab
    @Query(sort: \Receipt.purchaseDate, order: .reverse) private var receipts: [Receipt]
    @AppStorage(SettingsKeys.userName) private var userName = ""
    @State private var showAddReceipt = false

    private let aggregator = SpendAggregator()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if receipts.isEmpty {
                        emptyState
                    } else {
                        monthCard
                        HStack(spacing: Spacing.md) {
                            StatCard(label: "This week", value: weekTotal.gbp) {
                                ChangeLabel(current: weekTotal, previous: lastWeekTotal) { pct, _ in "\(pct)% vs last week" }
                            }
                            StatCard(label: "Receipts", value: "\(monthReceiptCount)") {
                                Text("scanned this month").font(.caption.weight(.medium)).foregroundStyle(Color.textSecondary)
                            }
                        }
                        categoryCard
                        recentReceipts
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 100)
            }
            .background(Color.bgPrimary)
            // Home has no navigation bar, so cover the status bar area. Otherwise the greeting
            // scrolls up underneath the clock and battery.
            .overlay(alignment: .top) {
                Color.bgPrimary
                    .frame(height: 0)
                    .background(Color.bgPrimary.ignoresSafeArea(edges: .top))
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) { scanButton }
            .sheet(isPresented: $showAddReceipt) { AddReceiptSheet() }
            .navigationDestination(for: Receipt.self) { ReceiptDetailView(receipt: $0) }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "en_GB"))))
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
            Text(userName.isEmpty ? "Hello" : "Hello, \(userName)")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.top, Spacing.sm)
    }

    private var emptyState: some View {
        Card {
            Text("Scan your first receipt").font(.title3.bold())
            Text("Tap the green button to scan a paper receipt, pick a photo, or import a PDF. Everything stays on your iPhone.")
                .font(.callout)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var monthCard: some View {
        Card {
            Text("Spent in \(Date.now.formatted(.dateTime.month(.wide)))")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            AmountText(amount: monthTotal)
            ChangeLabel(current: monthTotal, previous: lastMonthTotal) { pct, isDown in
                "\(pct)% \(isDown ? "less" : "more") than \(lastMonthName)"
            }
        }
    }

    private var categoryCard: some View {
        Card {
            Text("Where it went").font(.title3.bold()).foregroundStyle(Color.textPrimary)
            if monthByCategory.isEmpty {
                Text("Nothing spent yet this month. Scan a receipt and it will show here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            } else {
            HStack(spacing: 20) {
                Chart(monthByCategory) { row in
                    SectorMark(angle: .value("Spent", row.doubleValue), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(row.category.color)
                }
                .chartLegend(.hidden)
                .frame(width: 122, height: 122)
                .overlay {
                    // Whole pounds in the middle of the donut, as in Figma.
                    Text(monthTotal.wholePounds)
                        .font(.headline)
                        .foregroundStyle(Color.textPrimary)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 26)
                }

                VStack(spacing: Spacing.md) {
                    ForEach(monthByCategory) { row in
                        HStack(spacing: Spacing.sm) {
                            Circle().fill(row.category.color).frame(width: 8, height: 8)
                            Text(row.category.displayName).font(.subheadline).foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(row.amount.gbp).font(.subheadline.weight(.semibold)).foregroundStyle(Color.textPrimary)
                        }
                    }
                }
            }
            }
        }
    }

    private var recentReceipts: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionTitle(title: "Recent receipts", actionTitle: "See all") { selection = .receipts }
            ListCard {
                ForEach(receipts.prefix(3)) { receipt in
                    NavigationLink(value: receipt) {
                        ReceiptRow(receipt: receipt)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scanButton: some View {
        ScanButton { showAddReceipt = true }
    }

    // MARK: Numbers

    private var entries: [SpendEntry] { receipts.flatMap(\.spendEntries) }

    private var monthTotal: Decimal {
        let month = aggregator.interval(for: .month, containing: .now)
        return receipts.filter { month.contains($0.purchaseDate) }.reduce(0) { $0 + $1.total }
    }

    private var weekTotal: Decimal {
        let week = aggregator.interval(for: .week, containing: .now)
        return receipts.filter { week.contains($0.purchaseDate) }.reduce(0) { $0 + $1.total }
    }

    private var lastWeekTotal: Decimal {
        let week = aggregator.interval(for: .week, containing: aggregator.shift(.now, by: -1, .week))
        return receipts.filter { week.contains($0.purchaseDate) }.reduce(0) { $0 + $1.total }
    }

    private var lastMonthTotal: Decimal {
        let month = aggregator.interval(for: .month, containing: aggregator.shift(.now, by: -1, .month))
        return receipts.filter { month.contains($0.purchaseDate) }.reduce(0) { $0 + $1.total }
    }

    private var lastMonthName: String {
        aggregator.shift(.now, by: -1, .month).formatted(.dateTime.month(.wide))
    }

    private var monthReceiptCount: Int {
        let month = aggregator.interval(for: .month, containing: .now)
        return receipts.filter { month.contains($0.purchaseDate) }.count
    }

    private var monthByCategory: [CategoryTotal] {
        CategoryTotal.list(aggregator.totalsByCategory(entries, in: aggregator.interval(for: .month, containing: .now)))
    }
}

#Preview {
    HomeView(selection: .constant(.home)).modelContainer(PreviewData.container)
}
