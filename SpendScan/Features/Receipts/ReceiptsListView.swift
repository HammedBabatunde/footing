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
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(group.receipts[index]) }
                        }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text(group.total.gbp)
                        }
                    }
                }
            }
            .overlay {
                if receipts.isEmpty {
                    ContentUnavailableView("No receipts yet", systemImage: "receipt", description: Text("Scan a receipt and it will appear here."))
                }
            }
            .searchable(text: $search, prompt: "Search merchants or items")
            .navigationTitle("Receipts")
            .navigationDestination(for: Receipt.self) { ReceiptDetailView(receipt: $0) }
            .toolbar {
                Button("Add receipt", systemImage: "plus") { showAddReceipt = true }
            }
            .sheet(isPresented: $showAddReceipt) { AddReceiptSheet() }
        }
    }

    private func filterChip(_ category: SpendCategory?) -> some View {
        let selected = filter == category
        return Button {
            filter = category
        } label: {
            if let category {
                CategoryPill(category: category)
                    .overlay(Capsule().stroke(selected ? category.color : .clear, lineWidth: 1.5))
            } else {
                Text("All")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .foregroundStyle(selected ? .white : Color.textPrimary)
                    .background(selected ? Color.accentDefault : Color.bgSurfaceSecondary, in: Capsule())
            }
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

    /// Receipts grouped by month, newest first.
    private var groups: [ReceiptGroup] {
        let calendar = SpendAggregator.ukCalendar
        let grouped = Dictionary(grouping: filtered) { calendar.dateInterval(of: .month, for: $0.purchaseDate)!.start }
        return grouped.keys.sorted(by: >).map { start in
            let items = grouped[start] ?? []
            return ReceiptGroup(
                title: start.formatted(.dateTime.month(.wide).year()),
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
