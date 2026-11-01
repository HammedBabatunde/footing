import SwiftUI
import SwiftData

@main
struct SpendScanApp: App {
    @AppStorage(SettingsKeys.appearance) private var appearance = AppAppearance.system

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .appLock()
                .preferredColorScheme(appearance.colorScheme)
        }
        // Receipts are stored on this iPhone. The only network use is the optional weekly copy to
        // Notion (see NotionSync), which you turn on yourself in Settings.
        .modelContainer(for: [Receipt.self, LineItem.self, UserCategoryRule.self])
    }
}
