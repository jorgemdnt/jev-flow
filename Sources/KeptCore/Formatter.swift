public enum Formatter {
    /// `err` / `er` as its own token replaces the previous word. `or`, and
    /// those letters inside another word, are left alone.
    public static func format(_ raw: String) -> String {
        let spoken = dropFillers(raw)
        let correction = /(?i)[A-Za-z0-9']+(?:[ \t]*,[ \t]*|[ \t]+)(?:err|er)(?![A-Za-z])(?:[ \t]*,[ \t]*|[ \t]+)/
        return correctSpellings(SpokenNumber.apply(spoken.replacing(correction, with: "")))
    }

    /// A standalone `uh` is a hesitation, not a word. `um` stays: in Portuguese it is "a" or "one".
    static func dropFillers(_ raw: String) -> String {
        raw.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.split(whereSeparator: \.isWhitespace).map(String.init).filter { !isFiller($0) }.joined(separator: " ")
        }.joined(separator: "\n")
    }

    private static func isFiller(_ token: String) -> Bool {
        let bare = token.trimmingCharacters(in: .punctuationCharacters).lowercased()
        return bare.wholeMatch(of: /uh+/) != nil
    }

    static func correctSpellings(_ raw: String) -> String {
        let fixes = [
            "nao": "não", "voce": "você", "tambem": "também", "entao": "então",
            "amanha": "amanhã", "manha": "manhã", "documentacao": "documentação",
            "sloness": "slowness", "successfuly": "successfully", "imediatelly": "immediately",
            "inneficiencies": "inefficiencies", "inneficiency": "inefficiency", "meawhile": "meanwhile",
            "th": "the",
        ]
        return raw.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.split(whereSeparator: \.isWhitespace).map { token in
                let word = String(token)
                let bare = word.trimmingCharacters(in: .punctuationCharacters)
                guard let fixed = fixes[bare.lowercased()] else { return word }
                let replaced = bare.first?.isUppercase == true ? fixed.prefix(1).uppercased() + fixed.dropFirst() : fixed
                return word.replacingOccurrences(of: bare, with: replaced)
            }.joined(separator: " ")
        }.joined(separator: "\n")
    }

    /// In-progress text. Capitalize the start. Do not add a period yet.
    public static func streaming(_ raw: String) -> String {
        let trimmed = format(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return capitalizingStart(trimmed)
    }

    /// A finished take. Capitalize the start and end with a period when the
    /// take has no terminal punctuation. Does not renumber, drop guard words,
    /// or rewrite `auth`.
    public static func finished(_ raw: String) -> String {
        let trimmed = format(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let started = capitalizingStart(trimmed)
        guard !hasTerminalPunctuation(started) else { return started }
        return started + "."
    }

    private static func capitalizingStart(_ text: String) -> String {
        guard let index = text.firstIndex(where: { !$0.isWhitespace }) else { return text }
        let character = text[index]
        guard character.isLetter, character.isLowercase else { return text }
        return text.replacingCharacters(in: index...index, with: String(character).uppercased())
    }

    private static func hasTerminalPunctuation(_ text: String) -> Bool {
        guard let last = text.last(where: { !$0.isWhitespace }) else { return false }
        return ".!?…".contains(last)
    }
}

/// What is actually before the caret. A remembered trailing space is not this.
public enum FieldJoin: Equatable, Sendable {
    /// Caret is at the start, or the character before it is whitespace.
    case separated
    /// The character before the caret is not whitespace. The field dropped the space.
    case needsSpace
    /// The focused field could not be read.
    case unknown
}

public enum TakeJoin {
    /// The paste never starts with a space. It ends with one. A missing gap
    /// before the caret is typed, not pasted. An unread field does not get a
    /// leading space.
    public static func text(previous: String, next: String, field: FieldJoin = .unknown) -> String {
        guard !next.isEmpty else { return "" }
        return next
    }

    public static func needsSeparator(previous: String, next: String, field: FieldJoin = .unknown) -> Bool {
        guard let first = next.first, !first.isWhitespace else { return false }
        return field == .needsSpace
    }

    /// The text that is pasted. Ends with one space. Does not start with one.
    public static func submission(previous: String, next: String, field: FieldJoin = .unknown) -> String {
        let body = next.drop(while: \.isWhitespace)
        guard !body.isEmpty else { return "" }
        if body.last?.isWhitespace == true { return String(body) }
        return body + " "
    }
}
