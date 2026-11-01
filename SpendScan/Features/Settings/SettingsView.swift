import SwiftUI
import SwiftData
import ReceiptKit

enum SettingsKeys {
    static let aiCategorisation = "aiCategorisation"
    static let learnFromCorrections = "learnFromCorrections"
    static let faceIDLock = "faceIDLock"
    static let appearance = "appearance"
}

/// Light, dark, or follow the iPhone. Every colour in Theme.swift has a light and a dark value.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Figma screen 08.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var receipts: [Receipt]
    @Query private var rules: [UserCategoryRule]

    @AppStorage(SettingsKeys.aiCategorisation) private var aiEnabled = true
    @AppStorage(SettingsKeys.learnFromCorrections) private var learnFromCorrections = true
    @AppStorage(SettingsKeys.faceIDLock) private var faceIDLock = false
    @AppStorage(SettingsKeys.appearance) private var appearance = AppAppearance.system
    @State private var confirmDeleteAll = false
    @State private var lockMessage: String?

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
                    Text("AI runs on your iPhone and works with no internet. iPhones without Apple Intelligence use built-in rules instead. You can always change a category before saving.")
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
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    LabeledContent("Currency", value: "£ GBP")
                    LabeledContent("Week starts on", value: "Monday")
                    LabeledContent("Year runs", value: "Jan to Dec")
                }

                Section {
                    NavigationLink {
                        NotionSettingsView()
                    } label: {
                        LabeledContent("Notion sync", value: NotionSync.shared.isConnected ? "On" : "Off")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Copies your receipts to Notion about once a week, when you have internet. The app works the same without it.")
                }

                Section("Privacy and data") {
                    Toggle("Lock with Face ID", isOn: faceIDBinding)
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
            .alert("Face ID lock", isPresented: lockMessageBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(lockMessage ?? "")
            }
            .confirmationDialog("Delete all receipts?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) {
                    for receipt in receipts {
                        NotionSync.receiptWillBeDeleted(receipt)
                        modelContext.delete(receipt)
                    }
                }
            } message: {
                Text("This can't be undone.")
            }
        }
    }
}

extension SettingsView {
    /// Turning the lock on asks for Face ID first, so you know it works before you rely on it.
    private var faceIDBinding: Binding<Bool> {
        Binding {
            faceIDLock
        } set: { newValue in
            guard newValue else {
                faceIDLock = false
                return
            }
            guard AppLock.isAvailable else {
                lockMessage = "Set up Face ID or a passcode in the iPhone's Settings first."
                return
            }
            Task {
                if await AppLock.authenticate(reason: "Turn on Face ID lock for SpendScan") {
                    faceIDLock = true
                } else {
                    lockMessage = "Face ID didn't confirm, so the lock is still off."
                }
            }
        }
    }

    private var lockMessageBinding: Binding<Bool> {
        Binding(get: { lockMessage != nil }, set: { if !$0 { lockMessage = nil } })
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
        // Encrypted while the iPhone is locked.
        try? Data(lines.joined(separator: "\n").utf8).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    /// Quotes a text cell. Text read from a receipt could start with = + - or @, which Excel and
    /// Numbers would run as a formula, so those cells get a leading apostrophe.
    static func quote(_ text: String) -> String {
        var safe = text
        if let first = safe.first, "=+-@\t\r".contains(first) {
            safe = "'" + safe
        }
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
