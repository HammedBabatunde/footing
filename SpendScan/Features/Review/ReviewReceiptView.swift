import SwiftUI
import SwiftData
import ReceiptKit

/// Figma screen 04: check what was read, fix anything, then save.
struct ReviewReceiptView: View {
    let result: ScanResult
    var onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.learnFromCorrections) private var learnFromCorrections = true

    @State private var merchant: String
    @State private var date: Date
    @State private var total: Decimal
    @State private var category: SpendCategory
    @State private var items: [EditableItem]
    /// Once you change the items, the total follows them and the mismatch warning goes away.
    @State private var editedItems = false

    init(result: ScanResult, onSaved: @escaping () -> Void) {
        self.result = result
        self.onSaved = onSaved
        let parsed = result.parsed
        _merchant = State(initialValue: parsed.merchantName ?? "")
        _date = State(initialValue: parsed.purchaseDate ?? Date())
        _total = State(initialValue: parsed.total ?? parsed.itemsTotal)
        _category = State(initialValue: parsed.category ?? .other)
        _items = State(initialValue: parsed.items.map(EditableItem.init))
    }

    var body: some View {
        Form {
            if let data = result.imageData, let image = UIImage(data: data) {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                LabeledContent("Shop") {
                    TextField("Name", text: $merchant)
                        .multilineTextAlignment(.trailing)
                }
                DatePicker("Date", selection: $date)
                LabeledContent("Category") {
                    CategoryMenu(selection: $category)
                }
                LabeledContent("Total") {
                    PriceField(title: "Total", value: $total)
                        .fontWeight(.semibold)
                }
            } header: {
                Text("Details")
            } footer: {
                if showsMismatch {
                    // A quiet note, not a warning: often a discount or a line the scan missed.
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text("Items add up to \(itemsTotal.gbp).")
                        Button("Use this total") { total = itemsTotal }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.borderless)
                            .tint(Color.accentDefault)
                    }
                }
            }

            Section {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                            TextField("Item name", text: $item.name)
                            PriceField(title: "0.00", value: $item.lineTotal, keyboard: .numbersAndPunctuation)
                        }
                        HStack {
                            CategoryMenu(selection: $item.category)
                            Spacer()
                            Button {
                                items.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.statusNegative)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove \(item.name)")
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                    // Keep every divider lined up with the text.
                    .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                }
                // Swipe left on an item to delete it, or tap the bin.
                .onDelete { items.remove(atOffsets: $0) }

                Button("Add item", systemImage: "plus") {
                    items.append(EditableItem(name: "", lineTotal: 0, category: category))
                }
                .tint(Color.accentDefault)
            } header: {
                Text("Items (\(items.count))")
            } footer: {
                if result.engine != "Manual" {
                    Label("Categories picked on your iPhone by \(result.engine). Tap any category to change it.", systemImage: "sparkles")
                }
            }
        }
        // When you change a price, add or remove an item, the total follows the items.
        // You can still type a different total afterwards.
        .onChange(of: items.map(\.lineTotal)) { _, _ in
            editedItems = true
            total = itemsTotal
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Review receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(merchant.isEmpty)
            }
        }
    }

    private var itemsTotal: Decimal { items.reduce(0) { $0 + $1.lineTotal } }
    private var itemsMatch: Bool { items.isEmpty || itemsTotal == total }
    private var showsMismatch: Bool { result.source != .manual && !editedItems && !itemsMatch }

    private func save() {
        let receipt = Receipt(merchantName: merchant, purchaseDate: date, total: total, category: category, source: result.source)
        receipt.imageData = result.imageData
        receipt.rawText = result.parsed.rawRows.joined(separator: "\n")
        receipt.vat = result.parsed.vat
        receipt.paymentMethod = result.parsed.paymentMethod
        receipt.categorisedBy = result.engine
        modelContext.insert(receipt)

        for (index, item) in items.enumerated() where !item.name.isEmpty {
            let lineItem = LineItem(name: item.name, quantity: item.quantity, lineTotal: item.lineTotal, isDiscount: item.isDiscount, category: item.category, position: index)
            lineItem.receipt = receipt
            modelContext.insert(lineItem)
        }

        if learnFromCorrections {
            // Every category you changed becomes a rule, so next time it is right automatically.
            for item in items where item.category != item.suggestedCategory && !item.name.isEmpty {
                modelContext.insert(UserCategoryRule(keyword: item.name, category: item.category))
            }
            if category != result.parsed.category, !merchant.isEmpty {
                modelContext.insert(UserCategoryRule(keyword: merchant, category: category))
            }
        }
        onSaved()
    }
}

struct EditableItem: Identifiable {
    let id = UUID()
    var name: String
    var quantity: Int = 1
    var lineTotal: Decimal
    var isDiscount: Bool = false
    var category: SpendCategory
    /// What the AI or rules picked, to spot your corrections.
    var suggestedCategory: SpendCategory?

    init(name: String, lineTotal: Decimal, category: SpendCategory) {
        self.name = name
        self.lineTotal = lineTotal
        self.category = category
    }

    init(_ item: ParsedLineItem) {
        name = item.name
        quantity = item.quantity
        lineTotal = item.lineTotal
        isDiscount = item.isDiscount
        category = item.category ?? .other
        suggestedCategory = item.category
    }
}
