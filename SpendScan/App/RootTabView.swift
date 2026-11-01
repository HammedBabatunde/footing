import SwiftUI

enum AppTab: Hashable {
    case home, receipts, analytics, settings
}

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView(selection: $selection)
            }
            Tab("Receipts", systemImage: "list.bullet.rectangle.portrait", value: AppTab.receipts) {
                ReceiptsListView()
            }
            Tab("Analytics", systemImage: "chart.bar", value: AppTab.analytics) {
                AnalyticsView()
            }
            Tab("Settings", systemImage: "slider.horizontal.3", value: AppTab.settings) {
                SettingsView()
            }
        }
        // Selected tab, toggles, links and buttons all use the app green (Figma: color/accent/default).
        .tint(Color.accentDefault)
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Weekly Notion copy: runs when the app opens, if a week has passed and there's internet.
            if phase == .active {
                Task { await NotionSync.shared.syncIfDue(context: modelContext) }
            }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewData.container)
}
