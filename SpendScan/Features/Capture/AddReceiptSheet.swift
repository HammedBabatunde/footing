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

    /// Half-height while you pick an option, full height for reading and review (as in Figma).
    @State private var detent: PresentationDetent = .height(470)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Add a receipt")
                            .font(.title2.bold())
                            .foregroundStyle(Color.textPrimary)
                        Text("Receipts are read on your iPhone. Nothing is uploaded.")
                            .font(.footnote)
                            .foregroundStyle(Color.textSecondary)
                    }

                    VStack(spacing: Spacing.sm) {
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
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.bgPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .alert("Couldn't read that receipt", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(pipeline.errorMessage ?? "")
            }
            .navigationDestination(item: $pipeline.result) { result in
                ReviewReceiptView(result: result, onCancel: { dismiss() }) { dismiss() }
            }
        }
        .overlay {
            if pipeline.isWorking {
                ReadingReceiptView(pipeline: pipeline)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pipeline.isWorking)
        .presentationDetents([.height(470), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .presentationBackground(Color.bgPrimary)
        .interactiveDismissDisabled(pipeline.isWorking || pipeline.result != nil)
        .onChange(of: pipeline.isWorking) { _, working in
            if working { detent = .large }
        }
        .onChange(of: pipeline.result) { _, result in
            if result != nil { detent = .large }
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

    /// One option card (Figma: Add Option).
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
            Spacer(minLength: Spacing.sm)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(Spacing.lg)
        .background(Color.bgSurface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .contentShape(Rectangle())
    }
}

/// Figma screen 03: the receipt being scanned, a progress bar, and each step as it happens.
struct ReadingReceiptView: View {
    let pipeline: ScanPipeline
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { pipeline.cancel() }
                    .foregroundStyle(Color.accentDefault)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)

            Spacer(minLength: Spacing.lg)

            receiptPaper
                .padding(.bottom, Spacing.xxl)

            Text("Reading your receipt…")
                .font(.title2.bold())
                .foregroundStyle(Color.textPrimary)
            Text("Works offline. Nothing leaves your iPhone.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .padding(.top, Spacing.xs)

            ProgressView(value: pipeline.progress)
                .progressViewStyle(.linear)
                .tint(Color.accentDefault)
                .scaleEffect(x: 1, y: 1.6, anchor: .center)
                .animation(.easeInOut(duration: 0.4), value: pipeline.progress)
                .padding(.top, Spacing.xl)

            ListCard {
                step("Found the text", done: pipeline.stage > .readingText, active: pipeline.stage == .readingText,
                     activeTitle: "Finding the text")
                step(pipeline.foundSummary ?? "Finding items and the total", done: pipeline.stage > .findingItems,
                     active: pipeline.stage == .findingItems)
                step("Choosing categories with on-device AI", done: false,
                     active: pipeline.stage == .choosingCategories)
            }
            .padding(.top, Spacing.xl)

            Spacer(minLength: Spacing.xl)
            Spacer(minLength: Spacing.xl)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgPrimary.ignoresSafeArea())
        .onAppear { sweep = true }
    }

    /// A paper receipt with a green scan line moving down it.
    private var receiptPaper: some View {
        let width: CGFloat = 200, height: CGFloat = 280
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(light: 0xFFFFFA, dark: 0xF7F7F2))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            VStack(spacing: 8) {
                Capsule().fill(Color(hex: 0x9CA3AF)).frame(width: 80, height: 9)
                ForEach(Array([56, 160, 120, 144, 112, 128, 100, 160, 64, 120, 80, 56].enumerated()), id: \.offset) { _, w in
                    Capsule().fill(Color(hex: 0xD1D5DB)).frame(width: CGFloat(w), height: 5)
                }
            }
            .padding(.top, 20)

            VStack(spacing: 0) {
                LinearGradient(colors: [Color.accentDefault.opacity(0), Color.accentDefault.opacity(0.28)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 40)
                Rectangle().fill(Color.accentDefault).frame(height: 2.5)
            }
            .frame(width: width + 32)
            .offset(y: sweep && !reduceMotion ? height - 42 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: sweep)
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private func step(_ title: String, done: Bool, active: Bool, activeTitle: String? = nil) -> some View {
        HStack(spacing: Spacing.md) {
            Group {
                if done {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentDefault)
                } else if active {
                    ProgressView().controlSize(.small).tint(Color.accentDefault)
                } else {
                    Image(systemName: "circle").foregroundStyle(Color.borderDefault)
                }
            }
            .font(.title3)
            .frame(width: 24, height: 24)
            Text(active && activeTitle != nil ? activeTitle! : title)
                .font(.body)
                .foregroundStyle(done ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 14)
    }
}
