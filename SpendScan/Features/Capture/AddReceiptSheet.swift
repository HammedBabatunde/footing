import SwiftUI
import SwiftData
import PhotosUI
import ReceiptKit

/// Figma screens 02 (Add receipt) and 03 (Reading receipt).
struct AddReceiptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var userRules: [UserCategoryRule]
    @AppStorage(SettingsKeys.aiCategorisation) private var aiEnabled = true

    @State private var pipeline = ScanPipeline()
    @State private var photoItem: PhotosPickerItem?
    @State private var showScanner = false
    @State private var showPDFImporter = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showScanner = true } label: {
                        option("Scan with camera", "Best for paper receipts", "camera")
                    }
                    .disabled(!DocumentScannerView.isSupported)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        option("Choose from Photos", "Use a photo you already took", "photo")
                    }

                    Button { showPDFImporter = true } label: {
                        option("Import a PDF", "E-receipts and bills from Files or Mail", "doc.text")
                    }

                    Button { pipeline.startManual() } label: {
                        option("Add manually", "For cash spends without a receipt", "pencil")
                    }
                } footer: {
                    Text("Receipts are read on your iPhone. Nothing is uploaded, and no internet is needed.")
                }
            }
            .navigationTitle("Add a receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .overlay {
                if pipeline.isWorking { ReadingReceiptView() }
            }
            .alert("Couldn't read that receipt", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(pipeline.errorMessage ?? "")
            }
            .navigationDestination(item: $pipeline.result) { result in
                ReviewReceiptView(result: result) { dismiss() }
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView { images in
                showScanner = false
                Task { await pipeline.process(images: images, source: .camera, settings: settings) }
            } onCancel: {
                showScanner = false
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf]) { outcome in
            if case .success(let url) = outcome {
                Task { await pipeline.process(pdfAt: url, settings: settings) }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await pipeline.process(images: [image], source: .photo, settings: settings)
                }
                photoItem = nil
            }
        }
    }

    private var settings: CategorisationSettings {
        CategorisationSettings(aiEnabled: aiEnabled, userRules: userRules.map(\.rule))
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { pipeline.errorMessage != nil }, set: { if !$0 { pipeline.errorMessage = nil } })
    }

    private func option(_ title: String, _ subtitle: String, _ symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentDefault)
                .frame(width: 44, height: 44)
                .background(Color.accentSubtle, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(Color.textPrimary)
                Text(subtitle).font(.footnote).foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Figma screen 03.
struct ReadingReceiptView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ProgressView().controlSize(.large)
            Text("Reading your receipt…").font(.title2.bold())
            Text("Works offline. Nothing leaves your iPhone.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
