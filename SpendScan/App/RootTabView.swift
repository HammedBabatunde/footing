import SwiftUI

struct RootTabView: View {
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
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewData.container)
}
