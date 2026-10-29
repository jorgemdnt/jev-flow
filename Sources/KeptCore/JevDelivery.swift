import Foundation

public struct JevJudgment {
    /// Jev thinks a reader wants line breaks: a list, steps, or paragraphs.
    public let layout: Bool
    public let replacements: [Replacement]
    public let respell: [Respell.Candidate]

    public init(layout: Bool, replacements: [Replacement], respell: [Respell.Candidate]) {
        self.layout = layout
        self.replacements = replacements
        self.respell = respell
    }
}

public enum JevFailure: Error {
    case rejectedKey
}

public struct JevResult {
    public let text: String
    public let note: String?
}

/// Jev judges layout and candidate words; it never writes text. Most takes
/// paste as local prose. Only a take Jev says needs layout goes to the layout
/// model, and its answer is pasted only when every word survived. A failed
/// call never discards a take. Keep this boundary shared by live and manual insert.
public enum JevDelivery {
    public static func prepare(
        raw: String,
        dictionary: [String],
        heard: [HeardTerm] = [],
        key: String?,
        judge: (String, String) async throws -> JevJudgment,
        layout: (String) async -> LayoutOutcome
    ) async -> JevResult {
        let local = SpeechFormat.render(raw, replacements: [], dictionary: dictionary)
        let corrected = Formatter.format(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !corrected.isEmpty else { return JevResult(text: local, note: "") }
        guard worthAsking(raw: raw, corrected: corrected, heard: heard) else {
            return JevResult(text: local, note: nil)
        }
        guard let key else { return JevResult(text: local, note: "No TypeSafe key. Inserted local text.") }
        let judgment: JevJudgment
        do {
            judgment = try await judge(corrected, key)
        } catch JevFailure.rejectedKey {
            return JevResult(text: local, note: "TypeSafe rejected the key. Inserted local text.")
        } catch {
            return JevResult(text: local, note: "Formatting failed. Inserted local text.")
        }
        let respelled = Respell.apply(judgment.respell, to: raw)
        let prose = SpeechFormat.render(respelled, replacements: judgment.replacements, dictionary: dictionary)
        guard !prose.isEmpty else { return JevResult(text: local, note: "Formatting failed. Inserted local text.") }
        guard judgment.layout else { return JevResult(text: prose, note: nil) }
        switch await layout(prose) {
        case .laidOut(let text):
            return JevResult(text: text, note: nil)
        case .unchanged:
            return JevResult(text: prose, note: nil)
        case .noKey:
            return JevResult(text: prose, note: "No OpenCode key. Inserted text without layout.")
        case .rejected:
            return JevResult(text: prose, note: "Layout changed words. Inserted text without layout.")
        case .failed:
            return JevResult(text: prose, note: "Layout failed. Inserted text without layout.")
        }
    }

    /// A short take with no heard term, sound-alike, or layout cue has
    /// nothing for Jev to judge. It pastes without a network call.
    public static func worthAsking(raw: String, corrected: String, heard: [HeardTerm]) -> Bool {
        Layout.mightNeed(corrected)
            || !HeardTerm.questions(heard, in: corrected).isEmpty
            || !Respell.candidates(in: raw).isEmpty
    }
}
