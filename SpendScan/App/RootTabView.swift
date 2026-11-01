import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Receipts", systemImage: "receipt") {
                ReceiptsListView()
            }
            Tab("Analytics", systemImage: "chart.bar") {
                AnalyticsView()
            }
            Tab("Settings", systemImage: "slider.horizontal.3") {
                SettingsView()
            }
        }
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
