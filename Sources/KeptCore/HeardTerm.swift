import Foundation

/// A dictionary term the audio supports at a transcript span. The CTC word
/// spotter proposes it from sound; Jev confirms it from context. Code never
/// swaps a span on the spotter's word alone: on stored takes the spotter was
/// right 17 times and wrong 28, mostly on Portuguese ("posso" → PostHog) and
/// common English ("library" → Linear).
public struct HeardTerm: Codable, Equatable, Sendable {
    public let span: String
    public let term: String

    public init(span: String, term: String) {
        self.span = span
        self.term = term
    }

    /// Terms the spotter listens for. A person is matched by exact first name
    /// to their @handle instead: as spotter terms, names replaced "browser"
    /// with Rober and "request" with Reus.
    public static func spotterTerms(_ dictionary: [String]) -> [String] {
        dictionary
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("@") }
    }

    /// Spans to ask Jev about, grouped by term. A span already spelled like
    /// its term is left to the dictionary rule, and a span missing from the
    /// text Jev sees cannot be replaced, so neither is asked.
    public static func questions(_ heard: [HeardTerm], in corrected: String) -> [String: [String]] {
        var grouped: [String: [String]] = [:]
        for item in heard {
            let span = item.span.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !span.isEmpty, !item.term.hasPrefix("@"),
                  SpeechFormat.letters(span) != SpeechFormat.letters(item.term),
                  SpeechFormat.contains(span, in: corrected) else { continue }
            let spans = grouped[item.term, default: []]
            guard !spans.contains(where: { $0.caseInsensitiveCompare(span) == .orderedSame }) else { continue }
            grouped[item.term] = spans + [span]
        }
        return grouped
    }
}
