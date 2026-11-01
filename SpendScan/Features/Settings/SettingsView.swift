import SwiftUI
import SwiftData
import ReceiptKit

enum SettingsKeys {
    static let aiCategorisation = "aiCategorisation"
    static let learnFromCorrections = "learnFromCorrections"
    static let faceIDLock = "faceIDLock"
}

/// Figma screen 08.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var receipts: [Receipt]
    @Query private var rules: [UserCategoryRule]

    @AppStorage(SettingsKeys.aiCategorisation) private var aiEnabled = true
    @AppStorage(SettingsKeys.learnFromCorrections) private var learnFromCorrections = true
    @AppStorage(SettingsKeys.faceIDLock) private var faceIDLock = false
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $aiEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Categorise with AI")
                                Text("Sorts every receipt and item for you").font(.footnote).foregroundStyle(Color.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "sparkles").foregroundStyle(Color.accentDefault)
                        }
                    }
                    LabeledContent("AI engine", value: CategoryEngines.activeEngineName)
                    Toggle("Learn from my corrections", isOn: $learnFromCorrections)
                } header: {
                    Text("AI categorisation")
                } footer: {
                    Text("Everything runs on your iPhone and works with no internet. iPhones without Apple Intelligence use built-in rules instead. You can always change a category before saving.")
                }

                Section("Categories") {
                    ForEach(SpendCategory.allCases) { category in
                        HStack(spacing: Spacing.md) {
                            CategoryIcon(category: category, size: 30)
                            Text(category.displayName)
                            Spacer()
                            let count = rules.filter { $0.categoryRaw == category.rawValue }.count
                            if count > 0 {
                                Text("\(count) rule\(count == 1 ? "" : "s")").foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                }

                Section("Preferences") {
                    LabeledContent("Currency", value: "£ GBP")
                    LabeledContent("Week starts on", value: "Monday")
                    LabeledContent("Year runs", value: "Jan to Dec")
                }

                Section("Privacy and data") {
                    Toggle("Lock with Face ID", isOn: $faceIDLock) // TODO: enforce with LocalAuthentication in phase 5.
                    ShareLink(item: CSVExport.file(for: receipts), preview: SharePreview("Spending export")) {
                        Text("Export spending (CSV)")
                    }
                    Button("Delete all receipts", role: .destructive) { confirmDeleteAll = true }
                }

                #if DEBUG
                Section("Developer") {
                    Button("Add sample receipts") { PreviewData.insertSamples(into: modelContext) }
                }
                #endif

                Section {
                    Text("SpendScan 1.0").frame(maxWidth: .infinity).foregroundStyle(Color.textSecondary)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all receipts?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) {
                    for receipt in receipts { modelContext.delete(receipt) }
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}

/// Builds a CSV file of all line items, saved locally and handed to the share sheet.
enum CSVExport {
    static func file(for receipts: [Receipt]) -> URL {
        var lines = ["Date,Merchant,Item,Quantity,Amount (GBP),Category,Receipt total (GBP)"]
        let dateFormat = Date.ISO8601FormatStyle().year().month().day()
        for receipt in receipts.sorted(by: { $0.purchaseDate < $1.purchaseDate }) {
            let date = receipt.purchaseDate.formatted(dateFormat)
            let items = receipt.sortedItems
            if items.isEmpty {
                lines.append([date, quote(receipt.merchantName), "", "", "\(receipt.total)", receipt.category.displayName, "\(receipt.total)"].joined(separator: ","))
            }
            for item in items {
                lines.append([date, quote(receipt.merchantName), quote(item.name), "\(item.quantity)", "\(item.lineTotal)", item.category.displayName, "\(receipt.total)"].joined(separator: ","))
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("spending.csv")
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func quote(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
