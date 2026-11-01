import SwiftUI
import ReceiptKit

/// What came out of a scan, ready for the review screen.
struct ScanResult: Identifiable, Hashable {
    let id = UUID()
    var parsed: ParsedReceipt
    var engine: String
    var imageData: Data?
    var source: ReceiptSource

    static func == (lhs: ScanResult, rhs: ScanResult) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Photo or PDF → on-device OCR → parser → on-device AI categories. No step uses the internet.
@MainActor
@Observable
final class ScanPipeline {
    /// The steps shown on the "Reading your receipt" screen (Figma screen 03).
    enum Stage: Int, Comparable {
        case readingText, findingItems, choosingCategories
        static func < (a: Stage, b: Stage) -> Bool { a.rawValue < b.rawValue }
    }

    var isWorking = false
    var stage: Stage = .readingText
    /// e.g. "Found 6 items and a total of £18.49", once the receipt has been read.
    var foundSummary: String?
    var errorMessage: String?
    var result: ScanResult?
    /// Set when you tap Cancel on the reading screen, so the finished scan is thrown away.
    private var cancelled = false

    var progress: Double {
        switch stage {
        case .readingText: 0.3
        case .findingItems: 0.6
        case .choosingCategories: 0.85
        }
    }

    func cancel() {
        cancelled = true
        isWorking = false
    }

    private let parser = ReceiptParser()

    func process(images: [UIImage], source: ReceiptSource, settings: CategorisationSettings) async {
        await run(source: source, imageData: images.first?.jpegData(compressionQuality: 0.7), settings: settings) {
            var rows: [String] = []
            for image in images {
                let lines = try await TextRecognizer.lines(in: image)
                rows += self.parser.rows(from: lines)
            }
            return rows
        }
    }

    func process(pdfAt url: URL, settings: CategorisationSettings) async {
        guard let output = PDFTextExtractor.load(url) else {
            errorMessage = "That PDF couldn't be opened. It may be password-protected or larger than 25 MB."
            return
        }
        await run(source: .pdf, imageData: output.pageImages.first?.jpegData(compressionQuality: 0.7), settings: settings) {
            var rows = output.rows
            for image in output.pageImages {
                rows += self.parser.rows(from: try await TextRecognizer.lines(in: image))
            }
            return rows
        }
    }

    /// Starts an empty receipt for cash spends.
    func startManual() {
        result = ScanResult(parsed: ParsedReceipt(purchaseDate: Date()), engine: "Manual", imageData: nil, source: .manual)
    }

    private func run(source: ReceiptSource, imageData: Data?, settings: CategorisationSettings, readRows: () async throws -> [String]) async {
        isWorking = true
        cancelled = false
        stage = .readingText
        foundSummary = nil
        errorMessage = nil
        let started = Date()
        defer { isWorking = false }
        do {
            let rows = try await readRows()
            guard !cancelled else { return }
            guard !rows.isEmpty else {
                errorMessage = "No text was found. Try again with the whole receipt in view and good light."
                return
            }
            stage = .findingItems
            let parsed = parser.parse(rows: rows)
            let count = parsed.items.count
            let total = parsed.total ?? parsed.itemsTotal
            foundSummary = "Found \(count) item\(count == 1 ? "" : "s") and a total of \(total.gbp)"

            stage = .choosingCategories
            let categoriser = Categoriser(
                userRules: settings.userRules,
                aiEngines: settings.aiEnabled ? CategoryEngines.available() : []
            )
            let (categorised, engine) = await categoriser.categorise(parsed)

            // Reading is often instant. Keep the screen up long enough to see each step.
            let shown = Date().timeIntervalSince(started)
            if shown < 1.4 { try? await Task.sleep(for: .seconds(1.4 - shown)) }
            guard !cancelled else { return }
            result = ScanResult(parsed: categorised, engine: engine, imageData: imageData, source: source)
        } catch {
            guard !cancelled else { return }
            errorMessage = "The receipt couldn't be read: \(error.localizedDescription)"
        }
    }
}

struct CategorisationSettings {
    var aiEnabled: Bool
    var userRules: [CategoryRule]
}
