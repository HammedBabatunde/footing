import SwiftUI
import SwiftData
import ReceiptKit

/// Figma screen 05.
struct ReceiptsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.purchaseDate, order: .reverse) private var receipts: [Receipt]
    @State private var search = ""
    @State private var filter: SpendCategory?
    @State private var showAddReceipt = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            filterChip(nil)
                            ForEach(SpendCategory.allCases) { filterChip($0) }
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                ForEach(groups) { group in
                    Section {
                        ForEach(group.receipts) { receipt in
                            NavigationLink(value: receipt) { ReceiptRow(receipt: receipt) }
                                .themedRow()
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                let receipt = group.receipts[index]
                                NotionSync.receiptWillBeDeleted(receipt)
                                modelContext.delete(receipt)
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text(group.total.gbp)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                        .textCase(nil)
                    }
                }
            }
            .overlay {
                if receipts.isEmpty {
                    ContentUnavailableView("No receipts yet", systemImage: "receipt", description: Text("Scan a receipt and it will appear here."))
                }
            }
            .themedList()
            .contentMargins(.bottom, 96, for: .scrollContent)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search merchants or items")
            .navigationTitle("Receipts")
            .navigationDestination(for: Receipt.self) { ReceiptDetailView(receipt: $0) }
            .overlay(alignment: .bottomTrailing) {
                ScanButton { showAddReceipt = true }
            }
            .sheet(isPresented: $showAddReceipt) { AddReceiptSheet() }
        }
    }

    /// Figma: Filter Chip. "All" is solid green when selected; categories are tinted pills,
    /// filled with their colour when selected.
    private func filterChip(_ category: SpendCategory?) -> some View {
        let selected = filter == category
        let color = category?.color ?? Color.accentDefault
        return Button {
            filter = category
        } label: {
            HStack(spacing: 6) {
                if category != nil {
                    Circle().fill(selected ? Color.textOnAccent : color).frame(width: 8, height: 8)
                }
                Text(category?.displayName ?? "All")
                    .font(.footnote.weight(.medium))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? Color.textOnAccent : (category == nil ? Color.textPrimary : color))
            .background(selected ? color : (category?.tint ?? Color.bgSurfaceSecondary), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var filtered: [Receipt] {
        receipts.filter { receipt in
            let matchesFilter = filter == nil || receipt.category == filter || receipt.items.contains { $0.category == filter }
            let matchesSearch = search.isEmpty
                || receipt.merchantName.localizedCaseInsensitiveContains(search)
                || receipt.items.contains { $0.name.localizedCaseInsensitiveContains(search) }
            return matchesFilter && matchesSearch
        }
    }

    /// Receipts grouped by week (Monday to Sunday), newest first: "This week", "Last week", "Week of 12 Oct".
    private var groups: [ReceiptGroup] {
        let calendar = SpendAggregator.ukCalendar
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek)!
        let grouped = Dictionary(grouping: filtered) { calendar.dateInterval(of: .weekOfYear, for: $0.purchaseDate)!.start }
        return grouped.keys.sorted(by: >).map { start in
            let items = grouped[start] ?? []
            let title: String
            switch start {
            case thisWeek: title = "This week"
            case lastWeek: title = "Last week"
            default:
                let sameYear = calendar.isDate(start, equalTo: .now, toGranularity: .year)
                title = "Week of " + start.formatted(sameYear ? .dateTime.day().month(.abbreviated) : .dateTime.day().month(.abbreviated).year())
            }
            return ReceiptGroup(
                title: title,
                total: items.reduce(Decimal.zero) { $0 + $1.total },
                receipts: items
            )
        }
    }
}

struct ReceiptGroup: Identifiable {
    var title: String
    var total: Decimal
    var receipts: [Receipt]
    var id: String { title }
}
