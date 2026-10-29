import Foundation

public struct Replacement: Equatable, Sendable {
    public let span: String
    public let word: String

    public init(span: String, word: String) {
        self.span = span
        self.word = word
    }
}

public enum SpeechFormat {
    /// A Jev answer must be at least this sure before code acts on it.
    public static let minimumConfidence = 0.7

    /// Local prose: hesitations, corrections, numbers, dictionary words and the
    /// spans Jev chose. Layout is not decided here.
    public static func render(_ transcript: String, replacements: [Replacement], dictionary: [String] = []) -> String {
        let corrected = Formatter.format(transcript)
        let named = applyDictionary(dictionary, to: corrected)
        return Formatter.finished(apply(replacements, to: named))
    }

    static func apply(_ replacements: [Replacement], to text: String) -> String {
        var result = text
        for item in replacements {
            result = replaceSpan(item.span, with: item.word, in: result)
        }
        return result
    }

    /// A dictionary word replaces a span with the same letters. An @handle also
    /// replaces its unique first name or surname. Pedro and Gabriel need the surname.
    static func applyDictionary(_ entries: [String], to text: String) -> String {
        let tokens = words(in: text)
        guard !tokens.isEmpty else { return text }
        var planned: [(String, String)] = []
        let handles = entries.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.hasPrefix("@") }
        var owners: [String: [String]] = [:]
        for handle in handles {
            let parts = handle.dropFirst().split(separator: ".").map { letters(String($0)) }.filter { !$0.isEmpty }
            for part in parts {
                owners[part, default: []].append(handle)
            }
            if let span = matchingSpan(in: tokens, letters: letters(handle)) {
                planned.append((span, handle))
            }
        }
        for (part, handles) in owners where handles.count == 1 {
            if let span = matchingSpan(in: tokens, letters: part, maxTokens: 1) {
                planned.append((span, handles[0]))
            }
        }
        for entry in entries where !entry.hasPrefix("@") {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = letters(trimmed)
            if let span = matchingSpan(in: tokens, letters: key) {
                planned.append((span, trimmed))
            }
            for alias in spokenAliases[key] ?? [] {
                guard let span = matchingSpan(in: tokens, letters: letters(alias), maxTokens: 2) else { continue }
                planned.append((span, trimmed))
            }
        }
        var result = text
        for (span, word) in planned.sorted(by: { $0.0.count > $1.0.count }) {
            result = replaceEverySpan(span, with: word, in: result)
        }
        return result.replacingOccurrences(of: "(?i)\\bat\\s+@", with: "@", options: .regularExpression)
    }

    private static let spokenAliases: [String: [String]] = [
        "artie": ["rt", "arty", "r t"],
    ]

    private static func matchingSpan(in tokens: [String], letters key: String, maxTokens: Int = 4) -> String? {
        guard !key.isEmpty else { return nil }
        let limit = min(maxTokens, tokens.count)
        guard limit > 0 else { return nil }
        for size in stride(from: limit, through: 1, by: -1) {
            for index in 0...(tokens.count - size) {
                let span = tokens[index..<(index + size)].joined(separator: " ")
                if letters(span) == key { return span }
            }
        }
        return nil
    }

    private static func words(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func letters(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .filter(\.isLetter)
    }

    /// The span stands alone somewhere in the text.
    static func contains(_ span: String, in text: String) -> Bool {
        spanRange(span, in: text, from: text.startIndex) != nil
    }

    private static func replaceSpan(_ span: String, with word: String, in text: String) -> String {
        guard let range = spanRange(span, in: text, from: text.startIndex) else { return text }
        return text.replacingCharacters(in: range, with: word)
    }

    /// Replaces each standalone occurrence once. The search resumes after the
    /// inserted word, so "joseph" inside a pasted "@joseph" is not matched again.
    static func replaceEverySpan(_ span: String, with word: String, in text: String) -> String {
        var result = text
        var search = result.startIndex
        while let range = spanRange(span, in: result, from: search) {
            let offset = result.distance(from: result.startIndex, to: range.lowerBound) + word.count
            result.replaceSubrange(range, with: word)
            search = result.index(result.startIndex, offsetBy: offset)
        }
        return result
    }

    /// A span is a whole word: no letter next to it, and not the tail of an
    /// @handle or a dotted name that is already written out.
    private static func spanRange(_ span: String, in text: String, from start: String.Index) -> Range<String.Index>? {
        let needle = span.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        var search = start
        while search < text.endIndex,
              let range = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive], range: search..<text.endIndex) {
            let before = range.lowerBound == text.startIndex || !isWordJoin(text[text.index(before: range.lowerBound)])
            let after = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
                && !(text[range.upperBound] == "." && text.index(after: range.upperBound) < text.endIndex && text[text.index(after: range.upperBound)].isLetter)
            if before && after { return range }
            search = range.upperBound
        }
        return nil
    }

    private static func isWordJoin(_ character: Character) -> Bool {
        character.isLetter || character == "@" || character == "."
    }
}
