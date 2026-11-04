import SwiftUI
import SwiftData
import ReceiptKit

/// Figma screen 09: several receipts scanned at once. Each one is a card; tap it to check and
/// edit it section by section, then save them all together.
struct MultipleReceiptsView: View {
    @Binding var drafts: [ReceiptDraft]
    var notice: String?
    var onCancel: () -> Void
    var onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.learnFromCorrections) private var learnFromCorrections = true
    @State private var editing: ReceiptDraft.ID?
    @State private var confirmCancel = false

    var body: some View {
        List {
            Section {
                summary
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, draft in
                    Button { editing = draft.id } label: {
                        card(draft, number: index + 1)
                    }
                    .buttonStyle(.plain)
                    .themedRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Remove", systemImage: "trash", role: .destructive) { remove(draft.id) }
                    }
                    .contextMenu {
                        Button("Remove receipt", systemImage: "trash", role: .destructive) { remove(draft.id) }
                    }
                }
            } header: {
                Text("Receipts")
                    .font(.title3.bold())
                    .foregroundStyle(Color.textPrimary)
                    .textCase(nil)
            } footer: {
                Text("Tap a receipt to check it. Swipe left to remove one you don't want.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Spacing.lg)
        .themedList()
        .safeAreaInset(edge: .bottom) { saveBar }
        .navigationTitle("Review receipts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { confirmCancel = true }
            }
        }
        .confirmationDialog("Discard these receipts?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Discard \(drafts.count) receipts", role: .destructive, action: onCancel)
        } message: {
            Text("They haven't been saved yet.")
        }
        .navigationDestination(item: $editing) { id in
            if let index = drafts.firstIndex(where: { $0.id == id }) {
                ReviewReceiptView(
                    draft: $drafts[index],
                    mode: .batch(number: index + 1, count: drafts.count),
                    onCancel: { editing = nil },
                    onSave: { editing = nil }
                )
            }
        }
        .onChange(of: drafts.isEmpty) { _, empty in
            if empty { onCancel() }
        }
    }

    // MARK: Pieces

    /// Figma: summary card. How many receipts, their total, and how many need a look.
    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(drafts.count) receipts found")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            AmountText(amount: grandTotal, size: 34)
            Group {
                if needsCheck == 0 {
                    Label("All look right. Check any you like, then save.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentDefault)
                } else {
                    Label("\(needsCheck) need\(needsCheck == 1 ? "s" : "") a quick check", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.statusWarning)
                }
            }
            .font(.caption.weight(.medium))
            if let notice {
                Text(notice).font(.caption).foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.bgSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    /// Figma: Receipt Draft Card. Photo, shop, date and items, total, and whether it needs a look.
    private func card(_ draft: ReceiptDraft, number: Int) -> some View {
        HStack(spacing: Spacing.md) {
            thumbnail(draft)
            VStack(alignment: .leading, spacing: 3) {
                Text(draft.merchant.isEmpty ? "Shop name missing" : draft.merchant)
                    .font(.headline)
                    .foregroundStyle(draft.merchant.isEmpty ? Color.textSecondary : Color.textPrimary)
                    .lineLimit(1)
                Text(details(draft))
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                status(draft)
            }
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 6) {
                Text(draft.total.gbp).font(.headline).foregroundStyle(Color.textPrimary)
                CategoryPill(category: draft.category)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Receipt \(number). Opens it to check and edit.")
    }

    @ViewBuilder
    private func thumbnail(_ draft: ReceiptDraft) -> some View {
        if let data = draft.imageData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            CategoryIcon(category: draft.category, size: 44)
        }
    }

    private func status(_ draft: ReceiptDraft) -> some View {
        let ok = draft.looksRight
        return HStack(spacing: 4) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
            Text(ok ? "Looks right" : (draft.merchant.isEmpty ? "Add the shop name" : "Check the total"))
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(ok ? Color.accentDefault : Color.statusWarning)
    }

    private var saveBar: some View {
        Button(action: saveAll) {
            Text("Save all \(drafts.count) receipts")
                .font(.headline)
                .foregroundStyle(Color.textOnAccent)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.accentDefault, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(Color.bgPrimary)
    }

    // MARK: Actions and numbers

    private func remove(_ id: ReceiptDraft.ID) {
        drafts.removeAll { $0.id == id }
    }

    private func saveAll() {
        for draft in drafts {
            draft.save(into: modelContext, learn: learnFromCorrections)
        }
        onSaved()
    }

    private var grandTotal: Decimal { drafts.reduce(0) { $0 + $1.total } }
    private var needsCheck: Int { drafts.filter { !$0.looksRight }.count }

    private func details(_ draft: ReceiptDraft) -> String {
        let day = draft.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "en_GB")))
        let count = draft.items.count
        return count > 0 ? "\(day) · \(count) item\(count == 1 ? "" : "s")" : day
    }
}
