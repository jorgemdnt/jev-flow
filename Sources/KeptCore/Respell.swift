import Foundation

/// Sound-alike words the recognizer confuses. On AirPods, "ship" often
/// arrives as "shift" or "shoot". Code finds each such word and writes both
/// readings of its sentence. Jev picks the sentence the speaker meant. Code
/// swaps only that word.
public enum Respell {
    public struct Candidate: Equatable, Sendable {
        /// Index into the transcript's whitespace-separated words.
        public var index: Int
        public var heard: String
        public var meant: String
        public var asHeard: String
        public var asMeant: String
    }

    /// Heard word to the word it is often a mishearing of.
    public static let soundAlikes: [String: String] = [
        "shift": "ship",
        "shifted": "shipped",
        "shoot": "ship",
    ]

    /// Replacing a word the recognizer heard is riskier than choosing a
    /// shape. Measured on stored takes: true cases scored 0.91 to 0.98,
    /// false ones at most 0.71.
    public static let minimumConfidence = 0.85

    public static func candidates(in transcript: String) -> [Candidate] {
        let words = transcript.split(whereSeparator: \.isWhitespace).map(String.init)
        var found: [Candidate] = []
        for (index, word) in words.enumerated() {
            let bare = word.lowercased().filter(\.isLetter)
            guard let meant = soundAlikes[bare] else { continue }
            let sentence = sentenceBounds(around: index, in: words)
            let heardSentence = words[sentence].joined(separator: " ")
            var swapped = words
            swapped[index] = swap(word, to: meant)
            found.append(Candidate(
                index: index,
                heard: bare,
                meant: meant,
                asHeard: heardSentence,
                asMeant: swapped[sentence].joined(separator: " ")
            ))
        }
        return found
    }

    /// Swaps the chosen words and keeps every other word as it was.
    public static func apply(_ chosen: [Candidate], to transcript: String) -> String {
        guard !chosen.isEmpty else { return transcript }
        var words = transcript.split(whereSeparator: \.isWhitespace).map(String.init)
        for candidate in chosen where words.indices.contains(candidate.index) {
            words[candidate.index] = swap(words[candidate.index], to: candidate.meant)
        }
        return words.joined(separator: " ")
    }

    /// Keeps leading and trailing punctuation and a leading capital.
    static func swap(_ word: String, to meant: String) -> String {
        let leading = word.prefix(while: { !$0.isLetter })
        let rest = word.dropFirst(leading.count)
        let core = rest.prefix(while: \.isLetter)
        let trailing = rest.dropFirst(core.count)
        let capital = core.first?.isUppercase == true
        let replacement = capital ? meant.prefix(1).uppercased() + meant.dropFirst() : meant
        return String(leading) + replacement + String(trailing)
    }

    private static func sentenceBounds(around index: Int, in words: [String]) -> Range<Int> {
        func ends(_ word: String) -> Bool {
            guard let last = word.last else { return false }
            return last == "." || last == "?" || last == "!"
        }
        var start = index
        while start > 0, !ends(words[start - 1]) { start -= 1 }
        var end = index
        while end < words.count - 1, !ends(words[end]) { end += 1 }
        return start..<(end + 1)
    }
}
