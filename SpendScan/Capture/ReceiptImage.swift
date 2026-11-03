import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Receipt photos are only for looking back at, so they don't need the camera's full 12 MP.
/// We keep the long side at 1600 px (still sharp enough to read every line when zoomed)
/// and save as HEIC, which is about half the size of JPEG for the same quality.
/// A typical receipt goes from 2 to 4 MB down to around 150 to 300 KB.
/// Text is still read from the full-size image before it's shrunk.
enum ReceiptImage {
    static let maxLongSide: CGFloat = 1600
    static let quality: CGFloat = 0.6
    /// Photos smaller than this were already shrunk, so we leave them alone.
    static let alreadySmall = 450_000

    /// Whether to keep the photo at all (Settings → Storage).
    static var keepPhotos: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.keepReceiptPhotos) as? Bool ?? true
    }

    /// The data to save for a newly scanned receipt, or nil when photos are switched off.
    static func dataForSaving(_ image: UIImage?) -> Data? {
        guard keepPhotos, let image else { return nil }
        return compress(image)
    }

    static func compress(_ image: UIImage) -> Data? {
        let resized = downscaled(image)
        return heic(resized) ?? resized.jpegData(compressionQuality: quality)
    }

    /// Shrinks a photo saved by an older version of the app. Returns nil if it's already small
    /// or the new copy wouldn't be smaller.
    static func shrink(_ data: Data) -> Data? {
        guard data.count > alreadySmall, let image = UIImage(data: data),
              let smaller = compress(image), smaller.count < data.count else { return nil }
        return smaller
    }

    private static func heic(_ image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyOrientation: CGImagePropertyOrientation(image.imageOrientation).rawValue,
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let size = image.size
        let longSide = max(size.width, size.height)
        guard longSide > maxLongSide else { return image }
        let factor = maxLongSide / longSide
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
