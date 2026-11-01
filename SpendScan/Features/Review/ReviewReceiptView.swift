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

            if result.source != .manual && !editedItems && !itemsMatch {
                Section {
                    Label("The items add up to \(itemsTotal.gbp), but the total says \(total.gbp). Please check the prices.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Color.statusWarning)
                }
            }

            Section("Details") {
                TextField("Merchant", text: $merchant)
                DatePicker("Date", selection: $date)
                Picker("Category", selection: $category) {
                    ForEach(SpendCategory.allCases) { Text($0.displayName).tag($0) }
                }
                LabeledContent("Total") {
                    PriceField(title: "Total", value: $total)
                }
            }

            Section {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            TextField("Item", text: $item.name)
                            PriceField(title: "Price", value: $item.lineTotal, keyboard: .numbersAndPunctuation)
                                .frame(width: 100)
                        }
                        HStack {
                            Button(role: .destructive) {
                                items.removeAll { $0.id == item.id }
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(.footnote)
                            }
                            .buttonStyle(.borderless)
                            .tint(Color.statusNegative)
                            .accessibilityLabel("Remove \(item.name)")

                            Picker("Category", selection: $item.category) {
                                ForEach(SpendCategory.allCases) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .font(.footnote)
                        }
                    }
                }
                // Swipe left on an item to delete it, or tap Remove.
                .onDelete { items.remove(atOffsets: $0) }

                Button("Add item", systemImage: "plus") {
                    items.append(EditableItem(name: "", lineTotal: 0, category: category))
                }
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
                Button("Save", action: save).disabled(merchant.isEmpty)
            }
        }
    }

    private var itemsTotal: Decimal { items.reduce(0) { $0 + $1.lineTotal } }
    private var itemsMatch: Bool { items.isEmpty || itemsTotal == total }

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
