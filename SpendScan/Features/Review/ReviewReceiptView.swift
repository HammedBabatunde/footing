import SwiftUI
import SwiftData
import ReceiptKit

/// Figma screen 04: check what was read, fix anything, then save.
struct ReviewReceiptView: View {
    let result: ScanResult
    var onCancel: () -> Void
    var onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.learnFromCorrections) private var learnFromCorrections = true

    @State private var merchant: String
    @State private var date: Date
    @State private var total: Decimal
    @State private var category: SpendCategory
    @State private var items: [EditableItem]
    @State private var showOriginal = false

    init(result: ScanResult, onCancel: @escaping () -> Void, onSaved: @escaping () -> Void) {
        self.result = result
        self.onCancel = onCancel
        self.onSaved = onSaved
        let parsed = result.parsed
        _merchant = State(initialValue: parsed.merchantName ?? "")
        _date = State(initialValue: parsed.purchaseDate ?? Date())
        _total = State(initialValue: parsed.total ?? parsed.itemsTotal)
        _category = State(initialValue: parsed.category ?? .other)
        _items = State(initialValue: parsed.items.map(EditableItem.init))
    }

    var body: some View {
        List {
            if let data = result.imageData, let image = UIImage(data: data) {
                Section {
                    Button { showOriginal = true } label: {
                        HStack(spacing: Spacing.md) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Original receipt").font(.headline).foregroundStyle(Color.textPrimary)
                                Text("Tap to view full size").font(.footnote).foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.textSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .themedRow()
                }
                .fullScreenCover(isPresented: $showOriginal) {
                    OriginalReceiptView(image: image)
                }
            }

            Section {
                field("Merchant") {
                    TextField("Shop name", text: $merchant)
                        .multilineTextAlignment(.trailing)
                }
                field("Date") {
                    DatePicker("Date", selection: $date)
                        .labelsHidden()
                }
                field("Category") {
                    CategoryMenu(selection: $category)
                }
                if let payment = result.parsed.paymentMethod {
                    field("Paid with") { Text(payment).lineLimit(1) }
                }
                field("Total") {
                    PriceField(title: "0.00", value: $total)
                        .fontWeight(.bold)
                }
            } footer: {
                if result.engine != "Manual" {
                    Label {
                        Text("Categories picked by \(result.engine == "Built-in rules" ? "built-in rules" : "on-device AI"). Tap any category to change it.")
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(Color.accentDefault)
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                }
            }

            Section {
                ForEach($items) { $item in
                    itemRow($item)
                        .themedRow()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                items.removeAll { $0.id == item.id }
                            }
                        }
                        .contextMenu {
                            Button("Remove item", systemImage: "trash", role: .destructive) {
                                items.removeAll { $0.id == item.id }
                            }
                        }
                }
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Items (\(items.count))")
                        .font(.title3.bold())
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Button("Add item", systemImage: "plus") {
                        items.append(EditableItem(name: "", lineTotal: 0, category: category))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentDefault)
                    .buttonStyle(.borderless)
                }
                .textCase(nil)
            } footer: {
                VStack(spacing: Spacing.sm) {
                    totalCheck
                    if !items.isEmpty {
                        Text("Swipe left on an item to remove it.")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.sm)
            }

            Section {
                Button(action: save) {
                    Text("Save receipt")
                        .font(.headline)
                        .foregroundStyle(Color.textOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.accentDefault, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(merchant.isEmpty)
                .opacity(merchant.isEmpty ? 0.5 : 1)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Spacing.lg)
        .themedList()
        // When you change a price, add or remove an item, the total follows the items.
        // You can still type a different total afterwards.
        .onChange(of: items.map(\.lineTotal)) { _, _ in
            total = itemsTotal
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Review receipt")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(merchant.isEmpty)
            }
        }
    }

    /// A Details row: grey label on the left, the editable value on the right.
    private func field<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: Spacing.md) {
            Text(label).foregroundStyle(Color.textSecondary)
            Spacer(minLength: Spacing.sm)
            value().foregroundStyle(Color.textPrimary)
        }
        .themedRow()
    }

    /// Figma: Line Item Row. Name and "1 × £1.65" on the left, category pill and price on the right.
    private func itemRow(_ item: Binding<EditableItem>) -> some View {
        HStack(spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                TextField("Item name", text: item.name)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                Text("\(item.wrappedValue.quantity) × \(item.wrappedValue.unitPrice.gbp)")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer(minLength: Spacing.xs)
            CategoryMenu(selection: item.category, compact: true)
            PriceField(title: "0.00", value: item.lineTotal, keyboard: .numbersAndPunctuation)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.vertical, 2)
    }

    /// Green tick when the items match the total; otherwise a quiet note with a fix.
    @ViewBuilder
    private var totalCheck: some View {
        if items.isEmpty {
            EmptyView()
        } else if itemsMatch {
            Label("Items add up to \(itemsTotal.gbp), matching the receipt total", systemImage: "checkmark")
                .font(.caption)
                .foregroundStyle(Color.accentDefault)
        } else {
            HStack(spacing: Spacing.sm) {
                Text("Items add up to \(itemsTotal.gbp).")
                    .foregroundStyle(Color.textSecondary)
                Button("Use this total") { total = itemsTotal }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentDefault)
                    .buttonStyle(.borderless)
            }
            .font(.caption)
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

/// The receipt photo, full screen, pinch to zoom.
struct OriginalReceiptView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width * zoom)
                    .gesture(MagnifyGesture().onChanged { zoom = min(max($0.magnification, 1), 4) })
            }
            .background(Color.bgPrimary)
            .navigationTitle("Original receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
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

    var unitPrice: Decimal {
        quantity > 0 ? lineTotal / Decimal(quantity) : lineTotal
    }

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
