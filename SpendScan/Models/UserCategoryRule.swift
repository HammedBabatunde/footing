import Foundation
import SwiftData
import ReceiptKit

/// A category you chose by hand. Saved when you change a category on the review screen,
/// so the same merchant or item gets the right category next time.
@Model
final class UserCategoryRule {
    var keyword: String = ""
    var categoryRaw: String = SpendCategory.other.rawValue
    var createdAt: Date = Date()

    init(keyword: String, category: SpendCategory) {
        self.keyword = keyword
        self.categoryRaw = category.rawValue
    }

    var rule: CategoryRule {
        CategoryRule(keyword: keyword, category: SpendCategory(rawValue: categoryRaw) ?? .other)
    }
}
