import Foundation

/// Small wrapper around NSRegularExpression so parsing code stays readable.
enum RX {
    /// Returns the capture groups of the first match (index 0 is the whole match), or nil.
    static func firstMatch(_ pattern: String, in text: String, caseInsensitive: Bool = true) -> [String?]? {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let r = match.range(at: index)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    static func matches(_ pattern: String, _ text: String, caseInsensitive: Bool = true) -> Bool {
        firstMatch(pattern, in: text, caseInsensitive: caseInsensitive) != nil
    }

    static func replace(_ pattern: String, in text: String, with template: String, caseInsensitive: Bool = true) -> String {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
}
