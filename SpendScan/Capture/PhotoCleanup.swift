import Foundation
import SwiftData

/// How long receipt photos are kept (Settings → Storage).
/// Only the picture is removed; the receipt, its items and totals always stay.
enum PhotoRetention: Int, CaseIterable, Identifiable {
    case forever = 0
    case days90 = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .forever: "Keep forever"
        case .days90: "Delete after 90 days"
        }
    }

    /// Photos of receipts saved before this date are removed. Nil means keep them all.
    func cutoff(from now: Date = Date()) -> Date? {
        guard rawValue > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: -rawValue, to: now)
    }

    static var current: PhotoRetention {
        PhotoRetention(rawValue: UserDefaults.standard.integer(forKey: SettingsKeys.photoRetentionDays)) ?? .forever
    }
}

enum PhotoCleanup {
    /// Removes photos from receipts saved more than the chosen number of days ago.
    /// Age counts from when the receipt was added to the app, not the date printed on it,
    /// so an old receipt you scan today still keeps its photo for the full 90 days.
    /// Runs on this iPhone with no internet. Returns how many photos it removed.
    @discardableResult
    static func run(context: ModelContext, retention: PhotoRetention = .current, now: Date = Date()) -> Int {
        guard let cutoff = retention.cutoff(from: now) else { return 0 }
        let descriptor = FetchDescriptor<Receipt>(predicate: #Predicate { $0.createdAt < cutoff })
        guard let old = try? context.fetch(descriptor) else { return 0 }
        var removed = 0
        for receipt in old where receipt.imageData != nil {
            receipt.imageData = nil
            removed += 1
        }
        if removed > 0 { try? context.save() }
        return removed
    }
}
