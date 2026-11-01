import SwiftUI
import SwiftData

/// Settings → Notion sync. Connect once, then receipts copy to Notion about once a week.
struct NotionSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var receipts: [Receipt]

    @State private var secret = ""
    @State private var pageLink = ""
    @State private var isConnecting = false
    @State private var connectError: String?
    @State private var confirmDisconnect = false

    private var sync: NotionSync { NotionSync.shared }

    var body: some View {
        Form {
            if sync.isConnected {
                connectedSections
            } else {
                setupSections
            }
        }
        .themedList()
        .navigationTitle("Notion sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Connected

    @ViewBuilder
    private var connectedSections: some View {
        Section {
            Toggle("Sync every week", isOn: Binding(get: { sync.autoSync }, set: { sync.autoSync = $0 }))
            LabeledContent("Last synced", value: sync.lastSync.map { $0.formatted(.relative(presentation: .named)) } ?? "Not yet")
            if let due = sync.nextSyncDue {
                LabeledContent("Next sync", value: due <= Date() ? "Next time you open the app online" : due.formatted(date: .abbreviated, time: .omitted))
            }
            LabeledContent("Waiting to sync", value: "\(receipts.filter { $0.notionPageID == nil }.count) receipts")
        } footer: {
            Text("SpendScan syncs when you open it, if a week has passed and you have internet. If you're offline, it tries again next time.")
        }

        Section {
            Button {
                Task { await sync.sync(context: modelContext) }
            } label: {
                HStack {
                    Text("Sync now")
                    Spacer()
                    if sync.status == .syncing { ProgressView() }
                }
            }
            .disabled(sync.status == .syncing)

            switch sync.status {
            case .synced(let count):
                Label(count == 0 ? "Notion is up to date." : "Sent \(count) receipt\(count == 1 ? "" : "s") to Notion.", systemImage: "checkmark.circle")
                    .foregroundStyle(Color.accentDefault)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            default:
                EmptyView()
            }
        }

        Section {
            Button("Disconnect Notion", role: .destructive) { confirmDisconnect = true }
        } footer: {
            Text("Your Notion secret is kept in the iPhone's Keychain and only sent to api.notion.com. Disconnecting deletes it from this iPhone. Receipts already in Notion stay there.")
        }
        .confirmationDialog("Disconnect Notion?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) { sync.disconnect(context: modelContext) }
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupSections: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                step(1, "On notion.so/profile/integrations, create an internal integration called SpendScan. Copy its secret.")
                step(2, "In Notion, make a page for your spending. Tap ••• → Connections and add SpendScan.")
                step(3, "Copy that page's link (••• → Copy link) and paste both below.")
            }
            .padding(.vertical, 4)
            Button("Open Notion integrations") {
                if let url = URL(string: "https://www.notion.so/profile/integrations") { openURL(url) }
            }
        } header: {
            Text("Set up once")
        }

        Section {
            SecureField("Integration secret", text: $secret)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            TextField("Notion page link", text: $pageLink)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button {
                connect()
            } label: {
                HStack {
                    Text("Connect")
                    Spacer()
                    if isConnecting { ProgressView() }
                }
            }
            .disabled(secret.isEmpty || pageLink.isEmpty || isConnecting)
        } footer: {
            if let connectError {
                Text(connectError).foregroundStyle(.orange)
            } else {
                Text("SpendScan creates a \"SpendScan receipts\" database in that page and copies every receipt there.")
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text("\(number).").foregroundStyle(Color.textSecondary)
            Text(text).font(.subheadline)
        }
    }

    private func connect() {
        isConnecting = true
        connectError = nil
        Task {
            do {
                try await sync.connect(secret: secret, pageLink: pageLink)
                secret = ""
                pageLink = ""
                await sync.sync(context: modelContext)
            } catch {
                connectError = error.localizedDescription
            }
            isConnecting = false
        }
    }
}
