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

    /// Receipts and bills are a few pages. These limits stop a huge or malformed file
    /// from using up the iPhone's memory.
    static let maxFileSize = 25 * 1024 * 1024
    static let maxPages = 10

    static func load(_ url: URL) -> Output? {
        // Read the file while we have permission, then work on the copy in memory.
        let didAccess = url.startAccessingSecurityScopedResource()
        let data: Data?
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxFileSize {
            data = nil
        } else {
            data = try? Data(contentsOf: url, options: .mappedIfSafe)
        }
        if didAccess { url.stopAccessingSecurityScopedResource() }

        guard let data, data.count <= maxFileSize,
              let document = PDFDocument(data: data),
              !document.isLocked else { return nil }
        var rows: [String] = []
        var images: [UIImage] = []

        for index in 0..<min(document.pageCount, maxPages) {
            guard let page = document.page(at: index) else { continue }
            let text = page.string ?? ""
            if text.filter(\.isLetter).count > 20 {
                rows += text.components(separatedBy: .newlines)
            } else {
                let bounds = page.bounds(for: .mediaBox)
                guard bounds.width > 0, bounds.height > 0 else { continue }
                let scale = 2000 / max(bounds.width, bounds.height)
                images.append(page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox))
            }
        }
        return Output(rows: rows, pageImages: images)
    }
}
