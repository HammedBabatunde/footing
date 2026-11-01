import SwiftUI
import SwiftData
import Charts
import ReceiptKit

/// Figma screen 01.
struct HomeView: View {
    @Query(sort: \Receipt.purchaseDate, order: .reverse) private var receipts: [Receipt]
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
                            StatCard(label: "This week", value: weekTotal.gbp)
                            StatCard(label: "Receipts", value: "\(monthReceiptCount)", detail: "this month")
                        }
                        categoryCard
                        recentReceipts
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, 100)
            }
            .background(Color.bgPrimary)
            .overlay(alignment: .bottomTrailing) { scanButton }
            .sheet(isPresented: $showAddReceipt) { AddReceiptSheet() }
            .navigationDestination(for: Receipt.self) { ReceiptDetailView(receipt: $0) }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
            Text("Hello").font(.largeTitle.bold())
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
        }
    }

    private var categoryCard: some View {
        Card {
            Text("Where it went").font(.title3.bold())
            HStack(spacing: 20) {
                Chart(monthByCategory) { row in
                    SectorMark(angle: .value("Spent", row.doubleValue), innerRadius: .ratio(0.68), angularInset: 1.5)
                        .foregroundStyle(row.category.color)
                }
                .frame(width: 120, height: 120)

                VStack(spacing: Spacing.sm) {
                    ForEach(monthByCategory) { row in
                        HStack(spacing: Spacing.sm) {
                            Circle().fill(row.category.color).frame(width: 8, height: 8)
                            Text(row.category.displayName).font(.subheadline)
                            Spacer()
                            Text(row.amount.gbp).font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
    }

    private var recentReceipts: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Recent receipts").font(.title3.bold())
            VStack(spacing: 0) {
                ForEach(receipts.prefix(3)) { receipt in
                    NavigationLink(value: receipt) {
                        ReceiptRow(receipt: receipt).padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    if receipt.id != receipts.prefix(3).last?.id { Divider() }
                }
            }
            .background(Color.bgSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
    }

    private var scanButton: some View {
        Button { showAddReceipt = true } label: {
            Image(systemName: "viewfinder")
                .font(.title.weight(.semibold))
                .foregroundStyle(Color.textOnAccent)
                .frame(width: 64, height: 64)
                .background(Color.accentDefault, in: Circle())
                .shadow(color: Color.accentDefault.opacity(0.35), radius: 12, y: 6)
        }
        .padding(Spacing.lg)
        .accessibilityLabel("Scan receipt")
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

    private var monthReceiptCount: Int {
        let month = aggregator.interval(for: .month, containing: .now)
        return receipts.filter { month.contains($0.purchaseDate) }.count
    }

    private var monthByCategory: [CategoryTotal] {
        CategoryTotal.list(aggregator.totalsByCategory(entries, in: aggregator.interval(for: .month, containing: .now)))
    }
}

#Preview {
    HomeView().modelContainer(PreviewData.container)
}
