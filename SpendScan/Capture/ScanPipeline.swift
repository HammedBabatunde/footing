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
    /// Receipts read and ready to check. One for a normal scan, several when you scan
    /// several receipts at once.
    var drafts: [ReceiptDraft] = []
    /// True once there is something to review, which opens the review screen.
    var reviewing = false
    /// "Receipt 2 of 3" while reading several.
    var receiptNumber = 1
    var receiptCount = 1
    /// e.g. "1 page couldn't be read and was skipped."
    var notice: String?
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

    /// Reads scanned pages or photos. `separate` = each image is its own receipt;
    /// otherwise all of them are pages of one long receipt.
    func process(images: [UIImage], source: ReceiptSource, separate: Bool, settings: CategorisationSettings) async {
        let groups: [[UIImage]] = separate ? images.map { [$0] } : [images]
        let jobs = groups.map { pages in
            Job(imageData: ReceiptImage.dataForSaving(pages.first)) {
                var rows: [String] = []
                for page in pages {
                    rows += self.parser.rows(from: try await TextRecognizer.lines(in: page))
                }
                return rows
            }
        }
        await run(jobs, source: source, settings: settings)
    }

    func process(pdfAt url: URL, settings: CategorisationSettings) async {
        guard let output = PDFTextExtractor.load(url) else {
            errorMessage = "That PDF couldn't be opened. It may be password-protected or larger than 25 MB."
            return
        }
        let job = Job(imageData: ReceiptImage.dataForSaving(output.pageImages.first)) {
            var rows = output.rows
            for image in output.pageImages {
                rows += self.parser.rows(from: try await TextRecognizer.lines(in: image))
            }
            return rows
        }
        await run([job], source: .pdf, settings: settings)
    }

    /// Starts an empty receipt for cash spends.
    func startManual() {
        let result = ScanResult(parsed: ParsedReceipt(purchaseDate: Date()), engine: "Manual", imageData: nil, source: .manual)
        drafts = [ReceiptDraft(result)]
        reviewing = true
    }

    private struct Job {
        var imageData: Data?
        var readRows: () async throws -> [String]
    }

    private func run(_ jobs: [Job], source: ReceiptSource, settings: CategorisationSettings) async {
        isWorking = true
        cancelled = false
        errorMessage = nil
        notice = nil
        receiptCount = jobs.count
        let started = Date()
        defer { isWorking = false }

        let categoriser = Categoriser(
            userRules: settings.userRules,
            aiEngines: settings.aiEnabled ? CategoryEngines.available() : []
        )
        var results: [ReceiptDraft] = []
        var skipped = 0

        for (index, job) in jobs.enumerated() {
            guard !cancelled else { return }
            receiptNumber = index + 1
            stage = .readingText
            foundSummary = nil
            do {
                let rows = try await job.readRows()
                guard !cancelled else { return }
                guard !rows.isEmpty else {
                    skipped += 1
                    continue
                }
                stage = .findingItems
                let parsed = parser.parse(rows: rows)
                let count = parsed.items.count
                let total = parsed.total ?? parsed.itemsTotal
                foundSummary = "Found \(count) item\(count == 1 ? "" : "s") and a total of \(total.gbp)"

                stage = .choosingCategories
                let (categorised, engine) = await categoriser.categorise(parsed)
                results.append(ReceiptDraft(ScanResult(parsed: categorised, engine: engine, imageData: job.imageData, source: source)))
            } catch {
                skipped += 1
            }
        }

        // Reading is often instant. Keep the screen up long enough to see each step.
        let shown = Date().timeIntervalSince(started)
        if shown < 1.4 { try? await Task.sleep(for: .seconds(1.4 - shown)) }
        guard !cancelled else { return }

        if results.isEmpty {
            errorMessage = "No text was found. Try again with the whole receipt in view and good light."
            return
        }
        if skipped > 0 {
            notice = skipped == 1 ? "1 page couldn't be read and was skipped." : "\(skipped) pages couldn't be read and were skipped."
        }
        drafts = results
        reviewing = true
    }
}

struct CategorisationSettings {
    var aiEnabled: Bool
    var userRules: [CategoryRule]
}
