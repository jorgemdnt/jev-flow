import Foundation

public enum LayoutOutcome: Equatable, Sendable {
    case laidOut(String)
    case unchanged
    case noKey
    /// The model changed a word. The plain text is pasted instead.
    case rejected
    case failed

    /// For the log. Never the text.
    public var label: String {
        switch self {
        case .laidOut: "laid out"
        case .unchanged: "unchanged"
        case .noKey: "no key"
        case .rejected: "rejected, words changed"
        case .failed: "failed"
        }
    }
}

/// Jev decides that a take needs layout. A model lays it out. Code checks that
/// every word survived before anything is pasted, so the model can move words
/// onto lines but cannot drop a "not" or swap a rare word for a common one.
public enum Layout {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, Int)

    /// Below this many words, a take with no layout cue goes straight to the field.
    public static let minimumWords = 12

    public static let system = """
    You lay out dictated text. It came from speech recognition and is already \
    corrected. Change only its layout: line breaks, blank lines between \
    paragraphs, list markers, punctuation, and capital letters. Keep every word, \
    in the same order and with the same spelling. Do not add, remove, replace, \
    translate, or reorder words, and do not turn number words into digits. \
    Three exceptions: drop a spoken layout command such as "bullet point", \
    "new line", "new paragraph", or "next item"; turn a spoken item number such \
    as "one", "first", or "number two" into that item's list number; and drop \
    an "and" or "then" that only joins the next list item. Mark bullet items \
    with "• " and numbered items with "1. ", keeping the numbers the speaker \
    gave. Words that introduce a list stay on their own line above it. If the \
    text reads best as it is, return it unchanged. Return only the text: no \
    quotes, labels, or commentary.
    """

    public static func request(_ text: String) -> String {
        """
        <dictation>
        \(text)
        </dictation>

        Return the laid-out dictation only.
        """
    }

    /// Worth asking Jev about layout: a long take, or a short one with a cue.
    public static func mightNeed(_ text: String) -> Bool {
        let words = text.split(whereSeparator: \.isWhitespace)
        if words.count >= minimumWords { return true }
        let lowered = text.lowercased()
        if lowered.contains(/\b(list of|bullet|new line|newline|new paragraph|next item|to-?do|step one|number one)\b/) {
            return true
        }
        return lowered.contains(/\bfirst\b/) && lowered.contains(/\bsecond\b/)
    }

    public static func run(
        text: String,
        key: String?,
        endpoint: URL,
        model: String,
        userAgent: String,
        timeout: TimeInterval,
        send: Transport
    ) async -> LayoutOutcome {
        guard let key, !key.isEmpty else { return .noKey }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let body: [String: Any] = [
            "model": model,
            "reasoning_effort": "low",
            "max_tokens": max(1024, text.count * 2 + 512),
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": Self.request(text)],
            ],
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return .failed }
        request.httpBody = payload
        let data: Data
        let status: Int
        do {
            (data, status) = try await send(request)
        } catch {
            return .failed
        }
        guard (200..<300).contains(status),
              let laid = EditPrompt.text(from: data) else { return .failed }
        guard let accepted = accept(source: text, laidOut: laid) else { return .rejected }
        return accepted == text ? .unchanged : .laidOut(accepted)
    }

    /// The laid-out text, tidied, when it keeps every word of the source in
    /// order. Only layout commands, item numbers that became list numbers, and
    /// an "and" or "then" in front of a new item may go. Anything else is nil.
    public static func accept(source: String, laidOut: String) -> String? {
        let text = tidy(laidOut)
        guard !text.isEmpty else { return nil }
        return keepsWords(source: words(in: source), laidOut: lineWords(in: text)) ? text : nil
    }

    struct Word: Equatable {
        var text: String
        var startsLine = false
        var marker: Int?
    }

    private static let commands: [[String]] = [
        ["bullet", "points"], ["bullet", "point"], ["bullets"], ["bullet"],
        ["new", "paragraph"], ["new", "line"], ["newline"],
        ["next", "item"], ["next", "bullet"], ["next", "point"], ["next", "line"],
    ]

    private static let itemWords: Set<String> = ["number", "item", "step", "point"]
    private static let joiners: Set<String> = ["and", "then"]

    private static func keepsWords(source: [Word], laidOut: [Word]) -> Bool {
        var i = 0
        var j = 0
        var usedMarkers = Set<Int>()
        while i < source.count {
            if j < laidOut.count, source[i].text == laidOut[j].text {
                i += 1
                j += 1
                continue
            }
            if let (used, wrote) = joinedMatch(source, i, laidOut, j) {
                i += used
                j += wrote
                continue
            }
            let nextStartsItem = j == laidOut.count || laidOut[j].startsLine
            guard nextStartsItem else { return false }
            if let command = commands.first(where: { matches($0, in: source, at: i) }) {
                i += command.count
                continue
            }
            if let marker = j < laidOut.count ? laidOut[j].marker : nil, !usedMarkers.contains(marker) {
                if itemNumber(source[i].text) == marker {
                    usedMarkers.insert(marker)
                    i += 1
                    continue
                }
                if itemWords.contains(source[i].text), i + 1 < source.count, itemNumber(source[i + 1].text) == marker {
                    usedMarkers.insert(marker)
                    i += 2
                    continue
                }
            }
            if joiners.contains(source[i].text), j < laidOut.count {
                i += 1
                continue
            }
            return false
        }
        return j == laidOut.count
    }

    /// "todo" and "to-do", or "follow up" and "followup", are the same word.
    private static func joinedMatch(_ source: [Word], _ i: Int, _ laidOut: [Word], _ j: Int) -> (Int, Int)? {
        for used in 1...3 where i + used <= source.count {
            let spoken = source[i..<(i + used)].map(\.text).joined()
            for wrote in 1...3 where (used, wrote) != (1, 1) && j + wrote <= laidOut.count {
                let pieces = laidOut[j..<(j + wrote)]
                guard !pieces.dropFirst().contains(where: \.startsLine) else { break }
                if pieces.map(\.text).joined() == spoken { return (used, wrote) }
            }
        }
        return nil
    }

    private static func matches(_ phrase: [String], in words: [Word], at index: Int) -> Bool {
        guard index + phrase.count <= words.count else { return false }
        return phrase.indices.allSatisfy { words[index + $0].text == phrase[$0] }
    }

    private static let cardinals = [
        "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty",
    ]
    private static let ordinals = [
        "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
    ]
    private static let adverbs = ["firstly", "secondly", "thirdly", "fourthly", "fifthly"]

    static func itemNumber(_ word: String) -> Int? {
        if let value = Int(word) { return value }
        if let index = cardinals.firstIndex(of: word) { return index + 1 }
        if let index = ordinals.firstIndex(of: word) { return index + 1 }
        if let index = adverbs.firstIndex(of: word) { return index + 1 }
        return nil
    }

    static func words(in text: String) -> [Word] {
        tokens(in: text).map { Word(text: $0) }
    }

    /// A numbered line's marker is not a word. It is the item's number.
    static func lineWords(in text: String) -> [Word] {
        var result: [Word] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            var body = Substring(line)
            var marker: Int?
            if let match = line.prefixMatch(of: /\s*(?:[•◦‣▪\-*]|\(?(\d{1,3})[.)])\s+/) {
                marker = match.1.flatMap { Int($0) }
                body = line[match.range.upperBound...]
            }
            for (index, token) in tokens(in: String(body)).enumerated() {
                result.append(Word(text: token, startsLine: index == 0, marker: index == 0 ? marker : nil))
            }
        }
        return result
    }

    /// Lowercased words. Hyphens and slashes split; edge punctuation goes; an
    /// @ that starts a handle stays.
    static func tokens(in text: String) -> [String] {
        let straight = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
        return straight
            .split(whereSeparator: { $0.isWhitespace || "-–—/".contains($0) })
            .map { piece in
                var word = Substring(piece)
                while let first = word.first, !(first.isLetter || first.isNumber || first == "@") { word = word.dropFirst() }
                while let last = word.last, !(last.isLetter || last.isNumber) { word = word.dropLast() }
                return String(word)
            }
            .filter { !$0.isEmpty }
    }

    /// Bullets become "• ", line ends are trimmed, and at most one blank line
    /// separates paragraphs.
    static func tidy(_ laidOut: String) -> String {
        var text = laidOut.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count >= 2, let first = text.first, let last = text.last,
           (first == "\"" && last == "\"") || (first == "\u{201C}" && last == "\u{201D}") {
            text = String(text.dropFirst().dropLast())
        }
        text = text.replacingOccurrences(of: "**", with: "")
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var line = String(line)
            while line.last?.isWhitespace == true { line.removeLast() }
            if let match = line.prefixMatch(of: /(\s*)[-*◦‣▪]\s+/) {
                line = String(match.1) + "• " + line[match.range.upperBound...]
            }
            return line
        }
        var kept: [String] = []
        for line in lines {
            if line.isEmpty, kept.last?.isEmpty == true { continue }
            kept.append(line)
        }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
