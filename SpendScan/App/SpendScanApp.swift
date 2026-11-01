import SwiftUI
import SwiftData

@main
struct SpendScanApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        // Everything is stored on this iPhone only. There is no cloud sync and no network code.
        .modelContainer(for: [Receipt.self, LineItem.self, UserCategoryRule.self])
    }
}
