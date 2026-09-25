import Foundation

/// Spoken numbers become digits. A count such as one two three stays words.
public enum SpokenNumber {
    public static func apply(_ text: String) -> String {
        acronyms(in: digits(in: text))
    }

    static func digits(in text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let tokens = line.split(whereSeparator: \.isWhitespace).map { Token(String($0)) }
            var index = 0
            var out: [String] = []
            while index < tokens.count {
                if let phrase = phrase(in: tokens, from: index) {
                    out.append(tokens[phrase.start].leading + String(phrase.value) + tokens[phrase.last].trailing)
                    index = phrase.next
                } else {
                    out.append(tokens[index].raw)
                    index += 1
                }
            }
            return out.joined(separator: " ")
        }.joined(separator: "\n")
    }

    private static func acronyms(in text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            var tokens = line.split(whereSeparator: \.isWhitespace).map { Token(String($0)) }
            var index = 0
            while index < tokens.count {
                if let replaced = pullRequest(in: tokens, at: index) {
                    tokens.replaceSubrange(index..<(index + replaced.drop), with: [Token(replaced.word)])
                    index += 1
                    continue
                }
                index += 1
            }
            var words = tokens.map(\.raw)
            for index in words.indices where Token(words[index]).bare == "shoot" {
                let next = words.index(after: index)
                guard next < words.endIndex, Token(words[next]).bare == "pr" else { continue }
                let token = Token(words[index])
                words[index] = token.leading + "ship" + token.trailing
            }
            return words.joined(separator: " ")
        }
        return lines.joined(separator: "\n")
    }

    private static func pullRequest(in tokens: [Token], at index: Int) -> (drop: Int, word: String)? {
        let forms = ["we are", "pee are", "p r"]
        for form in forms {
            let parts = form.split(separator: " ").map(String.init)
            guard index + parts.count < tokens.count else { continue }
            let heard = (0..<parts.count).allSatisfy { tokens[index + $0].bare == parts[$0] }
            guard heard else { continue }
            let number = index + parts.count
            guard tokens[number].bare.wholeMatch(of: /\d+/) != nil else { continue }
            if form == "we are" {
                guard index > 0, cues.contains(tokens[index - 1].bare) else { continue }
                let after = number + 1
                if after < tokens.count, units.contains(tokens[after].bare) { continue }
            }
            let leading = tokens[index].leading
            return (parts.count, leading + "PR")
        }
        return nil
    }

    private static let cues: Set<String> = ["ship", "shoot", "merge", "open", "review", "file", "close", "push", "pull"]
    private static let units: Set<String> = ["people", "percent", "dollars", "minutes", "hours", "years", "times", "bucks", "meters", "miles", "pounds", "days", "weeks", "months"]

    private struct Phrase {
        var start: Int
        var last: Int
        var next: Int
        var value: Int
    }

    private static func phrase(in tokens: [Token], from start: Int) -> Phrase? {
        guard piece(tokens[start]) != nil || isArticle(tokens, at: start) else { return nil }
        var index = start
        var seenMagnitude = false
        var seenCompound = false
        var current = 0
        var total = 0
        var last = start
        var started = false

        while index < tokens.count {
            if tokens[index].bare == "and" {
                guard seenMagnitude, index + 1 < tokens.count, piece(tokens[index + 1]) != nil else { break }
                index += 1
                continue
            }
            if !started, isArticle(tokens, at: index) {
                current = 1
                started = true
                last = index
                index += 1
                continue
            }
            guard let part = piece(tokens[index]) else { break }
            switch part {
            case .small(let value, let compound):
                if !seenMagnitude, started, !continues(current: current, with: value) { break }
                if compound || continues(current: current, with: value) { seenCompound = true }
                current += value
            case .hundred:
                seenMagnitude = true
                current = max(current, 1) * 100
            case .magnitude(let scale):
                seenMagnitude = true
                total += max(current, 1) * scale
                current = 0
            }
            started = true
            last = index
            index += 1
            if !tokens[last].trailing.isEmpty { break }
        }
        let value = total + current
        guard started, seenMagnitude || seenCompound else { return nil }
        return Phrase(start: start, last: last, next: last + 1, value: value)
    }

    private static func continues(current: Int, with value: Int) -> Bool {
        let tens = current % 100
        return tens >= 20 && tens % 10 == 0 && value < 10
    }

    private static func isArticle(_ tokens: [Token], at index: Int) -> Bool {
        let bare = tokens[index].bare
        guard bare == "a" || bare == "an", index + 1 < tokens.count else { return false }
        switch tokens[index + 1].bare {
        case "hundred", "thousand", "million", "billion": return true
        default: return false
        }
    }

    private enum Piece {
        case small(Int, compound: Bool)
        case hundred
        case magnitude(Int)
    }

    private static func piece(_ token: Token) -> Piece? {
        let parts = token.bare.split(separator: "-").map(String.init)
        guard !parts.isEmpty, parts.allSatisfy({ values[$0] != nil || scales[$0] != nil }) else { return nil }
        if parts.count == 1, let scale = scales[parts[0]] {
            return scale == 100 ? .hundred : .magnitude(scale)
        }
        var total = 0
        for part in parts {
            guard let value = values[part] else { return nil }
            total += value
        }
        return .small(total, compound: parts.count > 1)
    }

    private static let values: [String: Int] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
        "twenty": 20, "thirty": 30, "forty": 40, "fifty": 50,
        "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90,
    ]

    private static let scales: [String: Int] = [
        "hundred": 100, "thousand": 1_000, "million": 1_000_000, "billion": 1_000_000_000,
    ]

    private struct Token {
        var raw: String
        var bare: String
        var leading: String
        var trailing: String

        init(_ raw: String) {
            self.raw = raw
            var start = raw.startIndex
            var end = raw.endIndex
            while start < end, raw[start].isPunctuation, raw[start] != "-" {
                start = raw.index(after: start)
            }
            while end > start, raw[raw.index(before: end)].isPunctuation, raw[raw.index(before: end)] != "-" {
                end = raw.index(before: end)
            }
            leading = String(raw[..<start])
            trailing = String(raw[end...])
            bare = String(raw[start..<end]).lowercased()
        }
    }
}
