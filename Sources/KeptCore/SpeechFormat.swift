import Foundation

public enum SpokenShape: String, Equatable, Sendable {
    case prose
    case list
    case numbered
}

public struct Replacement: Equatable, Sendable {
    public let span: String
    public let word: String

    public init(span: String, word: String) {
        self.span = span
        self.word = word
    }
}

public enum SpeechFormat {
    /// A format change is visible. Below this, leave the take as prose.
    public static let minimumConfidence = 0.7

    /// Code renders. The model only chose the shape and the spans.
    public static func render(_ transcript: String, shape: SpokenShape, replacements: [Replacement]) -> String {
        let corrected = Formatter.format(transcript)
        let replaced = apply(replacements, to: corrected)
        switch shape {
        case .prose, .numbered:
            return Formatter.finished(replaced)
        case .list:
            let items = listItems(in: replaced)
            guard items.count >= 2 else { return Formatter.finished(replaced) }
            return items.map { "• \(capitalizeItem($0))" }.joined(separator: "\n")
        }
    }

    /// Spans code is willing to replace. Jev picks among these. It cannot invent one.
    public static func candidates(in transcript: String, entries: [String]) -> [String: [String]] {
        let source = Formatter.format(transcript)
        let tokens = words(in: source)
        var found: [String: [String]] = [:]
        for entry in entries {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            var spans: [String] = []
            let limit = min(4, tokens.count)
            guard limit > 0 else { continue }
            for size in 1...limit {
                for index in 0...(tokens.count - size) {
                    let span = tokens[index..<(index + size)].joined(separator: " ")
                    guard resembles(span, trimmed) else { continue }
                    if !spans.contains(where: { $0.caseInsensitiveCompare(span) == .orderedSame }) {
                        spans.append(span)
                    }
                }
            }
            if !spans.isEmpty {
                found[trimmed] = spans
            }
        }
        return found
    }

    static func apply(_ replacements: [Replacement], to text: String) -> String {
        var result = text
        for item in replacements {
            result = replaceSpan(item.span, with: item.word, in: result)
        }
        return result
    }

    static func listItems(in text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: ", and ", with: " and ")
        return normalized
            .components(separatedBy: " and ")
            .flatMap { $0.components(separatedBy: ", ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func capitalizeItem(_ text: String) -> String {
        guard let index = text.firstIndex(where: { !$0.isWhitespace }) else { return text }
        let character = text[index]
        guard character.isLetter, character.isLowercase else { return text }
        return text.replacingCharacters(in: index...index, with: String(character).uppercased())
    }

    private static func words(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    private static func letters(_ text: String) -> String {
        text.lowercased().filter(\.isLetter)
    }

    private static func resembles(_ span: String, _ entry: String) -> Bool {
        let left = letters(span)
        let right = letters(entry)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }
        let distance = levenshtein(left, right)
        return distance <= 2 && distance < left.count && distance < right.count
    }

    private static func replaceSpan(_ span: String, with word: String, in text: String) -> String {
        let needle = span.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return text }
        var search = text.startIndex
        while let range = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: search..<text.endIndex) {
            let before = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
            let after = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
            if before && after {
                return text.replacingCharacters(in: range, with: word)
            }
            search = range.upperBound
        }
        return text
    }

    private static func levenshtein(_ left: String, _ right: String) -> Int {
        let a = Array(left)
        let b = Array(right)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var next = [i]
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                next.append(min(next[j - 1] + 1, row[j] + 1, row[j - 1] + cost))
            }
            row = next
        }
        return row[b.count]
    }
}
