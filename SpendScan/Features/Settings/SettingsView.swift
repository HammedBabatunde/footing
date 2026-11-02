import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ReceiptKit

enum SettingsKeys {
    static let aiCategorisation = "aiCategorisation"
    static let learnFromCorrections = "learnFromCorrections"
    static let faceIDLock = "faceIDLock"
    static let appearance = "appearance"
    static let userName = "userName"
    static let keepReceiptPhotos = "keepReceiptPhotos"
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
    @AppStorage(SettingsKeys.userName) private var userName = ""
    @State private var confirmDeleteAll = false
    @State private var lockMessage: String?
    @AppStorage("lastBackupAt") private var lastBackupAt: Double = 0
    @State private var backupDocument: BackupDocument?
    @State private var showBackupExporter = false
    @State private var showRestoreImporter = false
    @State private var backupMessage: String?
    @AppStorage(SettingsKeys.keepReceiptPhotos) private var keepPhotos = true
    @State private var shrinking = false
    @State private var confirmRemovePhotos = false
    @State private var storageMessage: String?
    @State private var photoBytes = 0
    @State private var photoCount = 0

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
                            Image(systemName: "sparkles")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.accentDefault)
                                .frame(width: 30, height: 30)
                                .background(Color.accentSubtle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    LabeledContent("Your name") {
                        TextField("For the Home greeting", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .textContentType(.givenName)
                    }
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
                    Button("Back up to a file") { makeBackup() }
                    Button("Restore from a backup") { showRestoreImporter = true }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Deleting the app deletes its receipts. Back up to a file in Files or iCloud Drive to keep a copy you can restore, with no internet needed. \(lastBackupText) Notion sync also copies receipts about once a week when you're online.")
                }

                Section {
                    LabeledContent("Receipt photos", value: photosSizeText)
                    Toggle("Keep receipt photos", isOn: $keepPhotos)
                    Button {
                        Task { await shrinkPhotos() }
                    } label: {
                        HStack {
                            Text(shrinking ? "Shrinking photos…" : "Shrink saved photos")
                            if shrinking { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(shrinking || photoBytes == 0)
                    Button("Remove all receipt photos", role: .destructive) { confirmRemovePhotos = true }
                        .disabled(shrinking || photoBytes == 0)
                } header: {
                    Text("Storage")
                } footer: {
                    Text("New photos are saved smaller automatically. Shrink saved photos to make older ones smaller too; they stay easy to read. With Keep receipt photos off, only the items and totals are saved.")
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
            .themedList()
            .navigationTitle("Settings")
            .alert("Face ID lock", isPresented: lockMessageBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(lockMessage ?? "")
            }
            .fileExporter(isPresented: $showBackupExporter, document: backupDocument, contentType: .json,
                          defaultFilename: Backup.suggestedFilename) { outcome in
                switch outcome {
                case .success:
                    lastBackupAt = Date().timeIntervalSince1970
                    backupMessage = "Backup saved. Keep it somewhere outside the app, like iCloud Drive or your Mac."
                case .failure(let error):
                    backupMessage = "Couldn't save the backup. \(error.localizedDescription)"
                }
                backupDocument = nil
            }
            .fileImporter(isPresented: $showRestoreImporter, allowedContentTypes: [.json]) { outcome in
                restoreBackup(outcome)
            }
            .alert("Backup", isPresented: backupMessageBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupMessage ?? "")
            }
            .confirmationDialog("Remove all receipt photos?", isPresented: $confirmRemovePhotos, titleVisibility: .visible) {
                Button("Remove photos", role: .destructive) { removeAllPhotos() }
            } message: {
                Text("Your receipts, items and totals stay. Only the pictures are deleted, and this can't be undone.")
            }
            .onAppear { measurePhotos() }
            .onChange(of: receipts.count) { _, _ in measurePhotos() }
            .alert("Storage", isPresented: storageMessageBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(storageMessage ?? "")
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
    /// Adds up photo sizes. Done once when Settings opens and after changes,
    /// because reading every photo on each redraw would be slow.
    private func measurePhotos() {
        var bytes = 0
        var count = 0
        for receipt in receipts {
            if let size = receipt.imageData?.count {
                bytes += size
                count += 1
            }
        }
        photoBytes = bytes
        photoCount = count
    }

    private var photosSizeText: String {
        guard photoCount > 0 else { return "None" }
        return "\(photoCount) · \(Int64(photoBytes).formatted(.byteCount(style: .file)))"
    }

    private var storageMessageBinding: Binding<Bool> {
        Binding(get: { storageMessage != nil }, set: { if !$0 { storageMessage = nil } })
    }

    /// Re-saves older full-size photos at the smaller size, one at a time off the main thread.
    private func shrinkPhotos() async {
        shrinking = true
        defer { shrinking = false }
        let before = photoBytes
        for receipt in receipts {
            guard let data = receipt.imageData else { continue }
            let smaller = await Task.detached(priority: .userInitiated) { ReceiptImage.shrink(data) }.value
            if let smaller { receipt.imageData = smaller }
        }
        try? modelContext.save()
        measurePhotos()
        let saved = max(before - photoBytes, 0)
        storageMessage = saved > 0
            ? "Done. Freed \(Int64(saved).formatted(.byteCount(style: .file)))."
            : "Your photos are already small."
    }

    private func removeAllPhotos() {
        let before = photoBytes
        for receipt in receipts { receipt.imageData = nil }
        try? modelContext.save()
        measurePhotos()
        storageMessage = "Removed photos and freed \(Int64(before).formatted(.byteCount(style: .file)))."
    }

    private var lastBackupText: String {
        guard lastBackupAt > 0 else { return "You haven't made a backup yet." }
        let date = Date(timeIntervalSince1970: lastBackupAt)
        return "Last backup: \(date.formatted(date: .abbreviated, time: .shortened))."
    }

    private var backupMessageBinding: Binding<Bool> {
        Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })
    }

    private func makeBackup() {
        do {
            backupDocument = BackupDocument(data: try Backup.make(context: modelContext))
            showBackupExporter = true
        } catch {
            backupMessage = "Couldn't make the backup. \(error.localizedDescription)"
        }
    }

    private func restoreBackup(_ outcome: Result<URL, Error>) {
        do {
            let url = try outcome.get()
            let canAccess = url.startAccessingSecurityScopedResource()
            defer { if canAccess { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let result = try Backup.restore(data, into: modelContext)
            switch (result.added, result.skipped) {
            case (0, 0): backupMessage = "That backup has no receipts in it."
            case (0, _): backupMessage = "All \(result.skipped) receipts in that backup are already in the app."
            case (_, 0): backupMessage = "Restored \(result.added) receipts."
            default: backupMessage = "Restored \(result.added) receipts. \(result.skipped) were already in the app."
            }
        } catch {
            backupMessage = error.localizedDescription
        }
    }

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
