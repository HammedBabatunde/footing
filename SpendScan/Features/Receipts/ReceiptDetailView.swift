import SwiftUI
import SwiftData
import ReceiptKit

/// Figma screen 06.
struct ReceiptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let receipt: Receipt
    @State private var confirmDelete = false
    @State private var showOriginal = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header
                if split.count > 0 { splitCard }
                if !receipt.items.isEmpty { itemsSection }
                summaryCard
                if receipt.imageData != nil { originalRow }

                Button("Delete receipt", role: .destructive) { confirmDelete = true }
                    .font(.body)
                    .foregroundStyle(Color.statusNegative)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Color.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showOriginal) {
            if let data = receipt.imageData, let image = UIImage(data: data) {
                OriginalReceiptView(image: image)
            }
        }
        .confirmationDialog("Delete this receipt?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                NotionSync.receiptWillBeDeleted(receipt)
                modelContext.delete(receipt)
                dismiss()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            CategoryIcon(category: receipt.category, size: 56)
                .padding(.bottom, Spacing.xs)
            Text(receipt.merchantName)
                .font(.title2.bold())
                .foregroundStyle(Color.textPrimary)
            Text(receipt.purchaseDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "en_GB"))))
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
            AmountText(amount: receipt.total)
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    /// Figma: "Split by category": one bar in category colours, with a legend.
    private var splitCard: some View {
        Card {
            Text("Split by category").font(.headline).foregroundStyle(Color.textPrimary)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(split) { row in
                        Capsule()
                            .fill(row.category.color)
                            .frame(width: max(4, (geo.size.width - CGFloat(split.count - 1) * 2) * share(row)))
                    }
                }
            }
            .frame(height: 10)
            HStack(spacing: Spacing.md) {
                ForEach(split) { row in
                    HStack(spacing: 4) {
                        Circle().fill(row.category.color).frame(width: 7, height: 7)
                        Text("\(row.category.displayName) \(row.amount.gbp)")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Items").font(.title3.bold()).foregroundStyle(Color.textPrimary)
            ListCard {
                ForEach(receipt.sortedItems) { item in
                    HStack(spacing: Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).lineLimit(1).foregroundStyle(Color.textPrimary)
                            Text("\(item.quantity) × \(item.unitPrice.gbp)")
                                .font(.footnote)
                                .foregroundStyle(Color.textSecondary)
                        }
                        Spacer(minLength: Spacing.xs)
                        CategoryPill(category: item.category)
                        Text(item.lineTotal.gbp)
                            .foregroundStyle(Color.textPrimary)
                            .frame(minWidth: 56, alignment: .trailing)
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                }
            }
        }
    }

    private var summaryCard: some View {
        ListCard {
            if let vat = receipt.vat {
                DetailRow(label: "VAT included") { Text(vat.gbp) }
            }
            if let method = receipt.paymentMethod {
                DetailRow(label: "Paid with") { Text(method).lineLimit(1) }
            }
            if let engine = receipt.categorisedBy {
                DetailRow(label: "Categorised by") { Text(engine).lineLimit(1) }
            }
            DetailRow(label: "Total") { Text(receipt.total.gbp).bold() }
        }
    }

    private var originalRow: some View {
        Button { showOriginal = true } label: {
            HStack(spacing: Spacing.md) {
                if let data = receipt.imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                Text("View original receipt").foregroundStyle(Color.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
            }
            .padding(Spacing.md)
            .background(Color.bgSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Numbers

    private var split: [CategoryTotal] {
        var totals: [SpendCategory: Decimal] = [:]
        for entry in receipt.spendEntries { totals[entry.category, default: 0] += entry.amount }
        return CategoryTotal.list(totals)
    }

    private func share(_ row: CategoryTotal) -> CGFloat {
        let all = split.reduce(0) { $0 + $1.doubleValue }
        return all > 0 ? CGFloat(row.doubleValue / all) : 0
    }
}
