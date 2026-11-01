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
    var isWorking = false
    var errorMessage: String?
    var result: ScanResult?

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
            errorMessage = "That PDF couldn't be opened."
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
        errorMessage = nil
        defer { isWorking = false }
        do {
            let rows = try await readRows()
            guard !rows.isEmpty else {
                errorMessage = "No text was found. Try again with the whole receipt in view and good light."
                return
            }
            let parsed = parser.parse(rows: rows)
            let categoriser = Categoriser(
                userRules: settings.userRules,
                aiEngines: settings.aiEnabled ? CategoryEngines.available() : []
            )
            let (categorised, engine) = await categoriser.categorise(parsed)
            result = ScanResult(parsed: categorised, engine: engine, imageData: imageData, source: source)
        } catch {
            errorMessage = "The receipt couldn't be read: \(error.localizedDescription)"
        }
    }
}

struct CategorisationSettings {
    var aiEnabled: Bool
    var userRules: [CategoryRule]
}
