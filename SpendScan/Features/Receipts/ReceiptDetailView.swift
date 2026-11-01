import SwiftUI
import SwiftData
import ReceiptKit

/// Figma screen 06.
struct ReceiptDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let receipt: Receipt
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 6) {
                    CategoryIcon(category: receipt.category, size: 56)
                    Text(receipt.merchantName).font(.title2.bold())
                    Text(receipt.purchaseDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote)
                        .foregroundStyle(Color.textSecondary)
                    AmountText(amount: receipt.total)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if !receipt.items.isEmpty {
                Section("Items") {
                    ForEach(receipt.sortedItems) { item in
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).lineLimit(1)
                                Text("\(item.quantity) × \(item.unitPrice.gbp)")
                                    .font(.footnote)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            CategoryPill(category: item.category)
                            Text(item.lineTotal.gbp)
                        }
                    }
                }
            }

            Section {
                if let vat = receipt.vat { LabeledContent("VAT included", value: vat.gbp) }
                if let method = receipt.paymentMethod { LabeledContent("Paid with", value: method) }
                if let engine = receipt.categorisedBy { LabeledContent("Categorised by", value: engine) }
                LabeledContent("Total") { Text(receipt.total.gbp).bold() }
            }

            if let data = receipt.imageData, let image = UIImage(data: data) {
                Section("Original receipt") {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            }

            Section {
                Button("Delete receipt", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this receipt?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(receipt)
                dismiss()
            }
        }
    }
}
