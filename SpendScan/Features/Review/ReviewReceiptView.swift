import SwiftUI
import SwiftData
import ReceiptKit

/// Figma screen 04: check what was read, fix anything, then save.
/// On its own it saves the receipt. Inside "Review receipts" (several scanned at once) it edits
/// that one receipt and goes back to the list, where they are all saved together.
struct ReviewReceiptView: View {
    enum Mode: Equatable {
        case single
        /// Receipt `number` of `count`, edited from the multiple receipts screen.
        case batch(number: Int, count: Int)
    }

    @Binding var draft: ReceiptDraft
    var mode: Mode = .single
    var onCancel: () -> Void
    var onSave: () -> Void

    @State private var showOriginal = false

    var body: some View {
        List {
            if let data = draft.imageData, let image = UIImage(data: data) {
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
                    TextField("Shop name", text: $draft.merchant)
                        .multilineTextAlignment(.trailing)
                }
                field("Date") {
                    DatePicker("Date", selection: $draft.date)
                        .labelsHidden()
                }
                field("Category") {
                    CategoryMenu(selection: $draft.category)
                }
                if let payment = draft.paymentMethod {
                    field("Paid with") { Text(payment).lineLimit(1) }
                }
                field("Total") {
                    PriceField(title: "0.00", value: $draft.total)
                        .fontWeight(.bold)
                }
            } footer: {
                if draft.engine != "Manual" {
                    Label {
                        Text("Categories picked by \(draft.engine == "Built-in rules" ? "built-in rules" : "on-device AI"). Tap any category to change it.")
                    } icon: {
                        Image(systemName: "sparkles").foregroundStyle(Color.accentDefault)
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                }
            }

            Section {
                ForEach($draft.items) { $item in
                    itemRow($item)
                        .themedRow()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                draft.items.removeAll { $0.id == item.id }
                            }
                        }
                        .contextMenu {
                            Button("Remove item", systemImage: "trash", role: .destructive) {
                                draft.items.removeAll { $0.id == item.id }
                            }
                        }
                }
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Items (\(draft.items.count))")
                        .font(.title3.bold())
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Button("Add item", systemImage: "plus") {
                        draft.items.append(EditableItem(name: "", lineTotal: 0, category: draft.category))
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentDefault)
                    .buttonStyle(.borderless)
                }
                .textCase(nil)
            } footer: {
                VStack(spacing: Spacing.sm) {
                    totalCheck
                    if !draft.items.isEmpty {
                        Text("Swipe left on an item to remove it.")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.sm)
            }

            Section {
                Button(action: onSave) {
                    Text(isBatch ? "Done" : "Save receipt")
                        .font(.headline)
                        .foregroundStyle(Color.textOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.accentDefault, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(draft.merchant.isEmpty)
                .opacity(draft.merchant.isEmpty ? 0.5 : 1)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Spacing.lg)
        .themedList()
        // When you change a price, add or remove an item, the total follows the items.
        // You can still type a different total afterwards.
        .onChange(of: draft.items.map(\.lineTotal)) { _, _ in
            draft.total = draft.itemsTotal
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!isBatch)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if !isBatch {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isBatch ? "Done" : "Save", action: onSave)
                    .fontWeight(.semibold)
                    .disabled(draft.merchant.isEmpty)
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
        if draft.items.isEmpty {
            EmptyView()
        } else if draft.itemsMatch {
            Label("Items add up to \(draft.itemsTotal.gbp), matching the receipt total", systemImage: "checkmark")
                .font(.caption)
                .foregroundStyle(Color.accentDefault)
        } else {
            HStack(spacing: Spacing.sm) {
                Text("Items add up to \(draft.itemsTotal.gbp).")
                    .foregroundStyle(Color.textSecondary)
                Button("Use this total") { draft.total = draft.itemsTotal }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentDefault)
                    .buttonStyle(.borderless)
            }
            .font(.caption)
        }
    }

    private var isBatch: Bool { mode != .single }

    private var title: String {
        switch mode {
        case .single: "Review receipt"
        case .batch(let number, let count): "Receipt \(number) of \(count)"
        }
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
