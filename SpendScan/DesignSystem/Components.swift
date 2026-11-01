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

/// Large money figure with smaller pence (Figma: Amount).
struct AmountText: View {
    let amount: Decimal

    var body: some View {
        let text = amount.gbp // "£1,284.60"
        let parts = text.split(separator: ".", maxSplits: 1)
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(String(parts.first ?? ""))
                .font(.system(size: 40, weight: .bold, design: .rounded))
            if parts.count > 1 {
                Text("." + parts[1])
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .foregroundStyle(Color.textPrimary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Summary tile (Figma: Stat Card).
struct StatCard: View {
    let label: String
    let value: String
    var detail: String?
    var detailColor: Color = .textSecondary

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(.footnote).foregroundStyle(Color.textSecondary)
            Text(value).font(.title2.bold()).foregroundStyle(Color.textPrimary)
            if let detail {
                Text(detail).font(.caption.weight(.medium)).foregroundStyle(detailColor)
            }
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

    private var details: String {
        let date = receipt.purchaseDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let count = receipt.items.count
        return count > 0 ? "\(date) · \(count) item\(count == 1 ? "" : "s")" : date
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
