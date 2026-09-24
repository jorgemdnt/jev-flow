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

public enum TakeJoin {
    /// A new take inserts one space when the previous insertion did not
    /// already end in whitespace. An empty previous insertion is the first take.
    public static func text(previous: String, next: String) -> String {
        guard !next.isEmpty else { return "" }
        if previous.isEmpty || previous.last?.isWhitespace == true || next.first?.isWhitespace == true {
            return next
        }
        return " " + next
    }
}
