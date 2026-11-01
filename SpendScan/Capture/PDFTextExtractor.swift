import PDFKit
import UIKit

/// Gets text out of a PDF receipt or bill.
/// Digital PDFs (e-receipts, energy bills) already contain text, so it is read directly.
/// Scanned PDFs are turned into page images for Vision OCR.
enum PDFTextExtractor {
    struct Output {
        var rows: [String]
        var pageImages: [UIImage]
    }

    static func load(_ url: URL) -> Output? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let document = PDFDocument(url: url) else { return nil }
        var rows: [String] = []
        var images: [UIImage] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let text = page.string ?? ""
            if text.filter(\.isLetter).count > 20 {
                rows += text.components(separatedBy: .newlines)
            } else {
                let bounds = page.bounds(for: .mediaBox)
                let scale = 2000 / max(bounds.width, bounds.height)
                images.append(page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox))
            }
        }
        return Output(rows: rows, pageImages: images)
    }
}
