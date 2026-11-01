import UIKit
import Vision
import ReceiptKit

/// Reads text from a receipt photo with Apple's on-device Vision OCR. Works offline.
enum TextRecognizer {
    static func lines(in image: UIImage) async throws -> [RecognizedLine] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-GB"]
            // Item names are abbreviated ("SSKMD MLK"), so autocorrect does more harm than good.
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])

            return (request.results ?? []).compactMap { observation -> RecognizedLine? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let box = observation.boundingBox
                return RecognizedLine(
                    text: candidate.string,
                    minX: Double(box.minX),
                    maxX: Double(box.maxX),
                    midY: Double(box.midY),
                    height: Double(box.height)
                )
            }
        }.value
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
