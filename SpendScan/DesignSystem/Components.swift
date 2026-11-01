import SwiftUI
import ReceiptKit

/// Tinted square icon for a category (Figma: Category Icon).
struct CategoryIcon: View {
    let category: SpendCategory
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.tint, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .accessibilityLabel(category.displayName)
    }
}

/// Small category label (Figma: Category Pill).
struct CategoryPill: View {
    let category: SpendCategory

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(category.color).frame(width: 8, height: 8)
            Text(category.displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(category.color)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(category.tint, in: Capsule())
    }
}

/// A category pill you can tap to pick another category.
struct CategoryMenu: View {
    @Binding var selection: SpendCategory
    /// Smaller pill without the arrows, for item rows (Figma: Category Pill).
    var compact = false

    var body: some View {
        Menu {
            Picker("Category", selection: $selection) {
                ForEach(SpendCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.symbolName).tag(category)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(selection.color).frame(width: 8, height: 8)
                Text(selection.displayName)
                    .font(compact ? .caption.weight(.medium) : .footnote.weight(.medium))
                if !compact {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
            }
            .foregroundStyle(selection.color)
            .padding(.horizontal, compact ? 10 : Spacing.md)
            .padding(.vertical, compact ? 4 : 6)
            .background(selection.tint, in: Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Category: \(selection.displayName)")
    }
}

/// Large money figure: small £, big pounds, grey pence (Figma: Amount).
struct AmountText: View {
    let amount: Decimal
    var size: CGFloat = 40

    var body: some View {
        let text = amount.gbp // "£1,284.60" or "-£3.00"
        let isNegative = text.hasPrefix("-")
        let digits = text.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "£", with: "")
        let parts = digits.split(separator: ".", maxSplits: 1)
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(isNegative ? "-£" : "£")
                .font(.system(size: size * 0.55, weight: .bold))
            Text(String(parts.first ?? ""))
                .font(.system(size: size, weight: .bold))
            if parts.count > 1 {
                Text("." + parts[1])
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .foregroundStyle(Color.textPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Summary tile (Figma: Stat Card).
struct StatCard<Detail: View>: View {
    let label: String
    let value: String
    @ViewBuilder var detail: Detail

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(.footnote).foregroundStyle(Color.textSecondary)
            Text(value).font(.title2.bold()).foregroundStyle(Color.textPrimary)
            detail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(Color.bgSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

/// One receipt in a list (Figma: Receipt Row).
struct ReceiptRow: View {
    let receipt: Receipt

    var body: some View {
        HStack(spacing: Spacing.md) {
            CategoryIcon(category: receipt.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.merchantName).font(.headline).lineLimit(1)
                Text(details).font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(1)
            }
            Spacer(minLength: Spacing.sm)
            Text(receipt.total.gbp).font(.headline)
        }
        .foregroundStyle(Color.textPrimary)
        .padding(.vertical, 4)
    }

    /// "Today · 6 items", "Fri 30 Oct · PDF bill", "Thu 29 Oct · Contactless"
    private var details: String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(receipt.purchaseDate) {
            day = "Today"
        } else if calendar.isDateInYesterday(receipt.purchaseDate) {
            day = "Yesterday"
        } else {
            day = receipt.purchaseDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "en_GB")))
        }
        let count = receipt.items.count
        let extra: String?
        if receipt.source == .pdf {
            extra = "PDF bill"
        } else if count > 0 {
            extra = "\(count) item\(count == 1 ? "" : "s")"
        } else {
            extra = receipt.paymentMethod
        }
        return [day, extra].compactMap { $0 }.joined(separator: " · ")
    }
}

/// White rounded card used across screens.
struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(Color.bgSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

// MARK: - Shared pieces from the Figma Components page

/// The scan icon from Figma: four corners with a line across the middle.
struct ScanGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let arm = w * 0.28
        let r = w * 0.08
        var p = Path()
        // Top left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))
        // Top right
        p.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))
        // Bottom right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))
        // Bottom left
        p.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))
        // Middle line
        p.move(to: CGPoint(x: rect.minX + w * 0.22, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - w * 0.22, y: rect.midY))
        return p
    }
}

/// Round green Scan button that floats above the tab bar (Figma: Scan Button).
struct ScanButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ScanGlyph()
                .stroke(Color.textOnAccent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .frame(width: 24, height: 24)
                .frame(width: 64, height: 64)
                .background(Color.accentDefault, in: Circle())
                .shadow(color: Color.accentDefault.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.trailing, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        .accessibilityLabel("Scan a receipt")
    }
}

/// "▼ 6% less than September" in green, or "▲ 12% vs last week" in red.
struct ChangeLabel: View {
    let current: Decimal
    let previous: Decimal
    /// Builds the words after the arrow, e.g. { pct, isDown in "\(pct)% less than September" }.
    let text: (Int, Bool) -> String

    var body: some View {
        if previous > 0 {
            let change = NSDecimalNumber(decimal: (current - previous) / previous * 100).doubleValue
            let isDown = change <= 0
            HStack(spacing: 4) {
                Image(systemName: isDown ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill")
                    .font(.system(size: 9))
                Text(text(Int(abs(change).rounded()), isDown))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(isDown ? Color.accentDefault : Color.statusNegative)
        }
    }
}

/// Section title with an optional green action on the right ("Recent receipts · See all").
struct SectionTitle: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold()).foregroundStyle(Color.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline)
                    .foregroundStyle(Color.accentDefault)
                    .buttonStyle(.plain)
            }
        }
    }
}

/// A row of a white card: grey label on the left, value on the right (Figma: Detail Row).
struct DetailRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(label).foregroundStyle(Color.textSecondary)
            Spacer(minLength: Spacing.sm)
            value.foregroundStyle(Color.textPrimary)
        }
        .font(.body)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 13)
    }
}

/// White rounded card holding rows with dividers between them (Figma: List Card).
struct ListCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { rows in
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    row
                    if index < rows.count - 1 {
                        Divider().overlay(Color.borderDefault).padding(.leading, Spacing.lg)
                    }
                }
            }
        }
        .background(Color.bgSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }
}

extension View {
    /// Lists and forms use the app's own background and card colours in light and dark mode.
    func themedList() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
    }

    /// Card background for a row in a themed list.
    func themedRow() -> some View {
        listRowBackground(Color.bgSurface)
    }
}
