public enum Formatter {
    /// `err` / `er` as its own token replaces the previous word. `or`, and
    /// those letters inside another word, are left alone.
    public static func format(_ raw: String) -> String {
        let correction = /(?i)[A-Za-z0-9']+(?:[ \t]*,[ \t]*|[ \t]+)(?:err|er)(?![A-Za-z])(?:[ \t]*,[ \t]*|[ \t]+)/
        return raw.replacing(correction, with: "")
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
    /// A new take inserts one space unless the field already ends in whitespace.
    /// When the field cannot be read, a later take is still separated: the
    /// previous paste's trailing space is not proof the field kept it.
    public static func text(previous: String, next: String, field: FieldJoin = .unknown) -> String {
        guard !next.isEmpty else { return "" }
        guard needsSeparator(previous: previous, next: next, field: field) else { return next }
        return " " + next
    }

    public static func needsSeparator(previous: String, next: String, field: FieldJoin = .unknown) -> Bool {
        guard let first = next.first, !first.isWhitespace else { return false }
        switch field {
        case .separated:
            return false
        case .needsSpace:
            return true
        case .unknown:
            return !previous.isEmpty
        }
    }

    /// The text that is pasted. Always ends with one space, so the next
    /// submission does not depend on the following take remembering to join.
    public static func submission(previous: String, next: String, field: FieldJoin = .unknown) -> String {
        let joined = text(previous: previous, next: next, field: field)
        guard !joined.isEmpty else { return "" }
        if joined.last?.isWhitespace == true { return joined }
        return joined + " "
    }
}
