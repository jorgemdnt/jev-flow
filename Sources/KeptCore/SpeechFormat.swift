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
    public static func render(_ transcript: String, shape: SpokenShape, replacements: [Replacement], dictionary: [String] = []) -> String {
        let corrected = Formatter.format(transcript)
        let named = applyDictionary(dictionary, to: corrected)
        let replaced = apply(replacements, to: named)
        if let listed = spokenList(replaced) {
            return listed
        }
        switch shape {
        case .prose, .numbered:
            return Formatter.finished(replaced)
        case .list:
            let items = listItems(in: replaced)
            guard items.count >= 2, !isCountSplit(items) else { return Formatter.finished(replaced) }
            return bullets(items)
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

    static func listItems(in text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: ", and ", with: " and ")
        return normalized
            .components(separatedBy: " and ")
            .flatMap { $0.components(separatedBy: ", ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// "list of banana pineapple" is the list. Commas in "1, 2, 3" are a count, not items.
    static func spokenList(_ text: String) -> String? {
        guard let cue = lastCue(in: text) else { return nil }
        let preface = String(text[..<cue.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = String(text[cue.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let items = tailItems(in: tail)
        guard items.count >= 2 else { return nil }
        let bullets = bullets(items)
        guard !preface.isEmpty else { return bullets }
        return Formatter.streaming(preface) + "\n" + bullets
    }

    static func isCountSplit(_ items: [String]) -> Bool {
        items.contains { isCountToken($0) }
    }

    private static func bullets(_ items: [String]) -> String {
        items.map { "• \(capitalizeItem($0))" }.joined(separator: "\n")
    }

    private static func tailItems(in tail: String) -> [String] {
        let trimmed = tail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let separated = listItems(in: trimmed).map(cleanItem).filter { !$0.isEmpty }
        if separated.count >= 2, !separated.allSatisfy(isCountToken) { return separated }
        let words = trimmed.split(whereSeparator: \.isWhitespace).map { cleanItem(String($0)) }.filter { !$0.isEmpty }
        guard words.count >= 2, !words.allSatisfy(isCountToken) else { return [] }
        return words
    }

    private static func lastCue(in text: String) -> Range<String.Index>? {
        var found: Range<String.Index>?
        var search = text.startIndex
        while let range = text.range(
            of: #"(?i)(?<![A-Za-z])list of(?![A-Za-z])"#,
            options: .regularExpression,
            range: search..<text.endIndex
        ) {
            found = range
            search = range.upperBound
        }
        return found
    }

    private static func cleanItem(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func isCountToken(_ text: String) -> Bool {
        let bare = cleanItem(text).lowercased()
        if bare.isEmpty { return false }
        if Int(bare) != nil { return true }
        return ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"].contains(bare)
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
        text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .filter(\.isLetter)
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
