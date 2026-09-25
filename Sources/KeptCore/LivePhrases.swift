import Foundation

/// The live card. A window may repeat the end of the line, or arrive as only
/// the new words. Either way the next window does not glue onto the previous
/// one, and a word already shown is not shown again.
public struct LivePhrases: Equatable, Sendable {
    public var committed: String
    public var tail: String

    public init(committed: String = "", tail: String = "") {
        self.committed = committed
        self.tail = tail
    }

    public var shown: String {
        [committed, tail].filter { !$0.isEmpty }.joined(separator: " ")
    }

    public var committedWordCount: Int {
        Self.words(committed).count
    }

    /// The window is the new audio, possibly overlapping the end of the line.
    public func absorbing(_ window: String) -> LivePhrases {
        let incoming = Self.words(window)
        guard !incoming.isEmpty else { return self }
        let current = Self.words(shown)
        let overlap = Self.overlapCount(current: current, incoming: incoming)
        let stable = current.dropLast(overlap)
        return LivePhrases(
            committed: stable.joined(separator: " "),
            tail: incoming.joined(separator: " ")
        )
    }

    /// A recognizer that re-reads the whole buffer. The latest text replaces
    /// the line. It is not appended.
    public func replacing(_ full: String) -> LivePhrases {
        LivePhrases(tail: Self.words(full).joined(separator: " "))
    }

    /// Split a formatted line on the committed word count. Formatting may
    /// drop a filler, so the count is a ceiling, not a second source of words.
    public func split(formatted: String) -> (committed: String, tail: String) {
        let words = Self.words(formatted)
        let count = min(committedWordCount, words.count)
        return (
            words.prefix(count).joined(separator: " "),
            words.dropFirst(count).joined(separator: " ")
        )
    }

    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init).filter { !$0.isEmpty }
    }

    /// How many words at the end of `current` the new window is repeating.
    /// A shorter word may be the start of the revised word (`shi` / `ship`).
    static func overlapCount(current: [String], incoming: [String]) -> Int {
        guard !current.isEmpty, !incoming.isEmpty else { return 0 }
        let max = min(current.count, incoming.count)
        var best = 0
        for length in 1...max {
            let suffix = current.suffix(length)
            let prefix = incoming.prefix(length)
            if zip(suffix, prefix).allSatisfy({ sameWord($0, $1) }) {
                best = length
            }
        }
        return best
    }

    private static func sameWord(_ left: String, _ right: String) -> Bool {
        let a = letters(left)
        let b = letters(right)
        guard !a.isEmpty, !b.isEmpty else { return false }
        if a == b { return true }
        let short = a.count < b.count ? a : b
        let long = a.count < b.count ? b : a
        guard short.count >= 2, long.hasPrefix(short), long.count - short.count <= 4 else { return false }
        return true
    }

    private static func letters(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .filter(\.isLetter)
    }
}
