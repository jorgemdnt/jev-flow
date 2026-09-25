import Foundation

public enum TypeSafeEnv {
    public static func key(in text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let row = line.trimmingCharacters(in: .whitespaces)
            guard !row.hasPrefix("#") else { continue }
            guard row.hasPrefix("TYPESAFE_API_KEY=") else { continue }
            var value = String(row.dropFirst("TYPESAFE_API_KEY=".count))
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }
}
