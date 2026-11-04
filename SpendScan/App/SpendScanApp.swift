import SwiftUI
import SwiftData

@main
struct SpendScanApp: App {
    @AppStorage(SettingsKeys.appearance) private var appearance = AppAppearance.system
    /// Shown once each time the app starts, not when it comes back from the background.
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    // No scroll bars anywhere in the app; lists and pages still scroll.
                    .scrollIndicators(.hidden)
                    .appLock()
                    .dismissesKeyboardOnTap()
                if showSplash {
                    SplashView { showSplash = false }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .preferredColorScheme(appearance.colorScheme)
        }
        // Receipts are stored on this iPhone. The only network use is the optional weekly copy to
        // Notion (see NotionSync), which you turn on yourself in Settings.
        .modelContainer(for: [Receipt.self, LineItem.self, UserCategoryRule.self])
    }
}
