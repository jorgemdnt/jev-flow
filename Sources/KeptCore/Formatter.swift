public enum Formatter {
    /// `err` / `er` as its own token replaces the previous word. `or`, and
    /// those letters inside another word, are left alone.
    public static func format(_ raw: String) -> String {
        let correction = /(?i)[A-Za-z0-9']+(?:[ \t]*,[ \t]*|[ \t]+)(?:err|er)(?![A-Za-z])(?:[ \t]*,[ \t]*|[ \t]+)/
        return raw.replacing(correction, with: "")
    }
}
