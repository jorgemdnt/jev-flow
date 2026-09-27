import Foundation

public struct JevJudgment {
    public let shape: SpokenShape
    public let replacements: [Replacement]
    public let respell: [Respell.Candidate]

    public init(shape: SpokenShape, replacements: [Replacement], respell: [Respell.Candidate]) {
        self.shape = shape
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

/// The network only judges shape and candidate words; a failed judgment does
/// not discard a take. Keep this boundary shared by live and manual insert.
public enum JevDelivery {
    public static func prepare(
        raw: String,
        dictionary: [String],
        key: String?,
        judge: (String, String) async throws -> JevJudgment
    ) async -> JevResult {
        let local = SpeechFormat.render(raw, shape: .prose, replacements: [], dictionary: dictionary)
        let corrected = Formatter.format(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !corrected.isEmpty else { return JevResult(text: local, note: "") }
        guard let key else { return JevResult(text: local, note: "No TypeSafe key. Inserted local text.") }
        do {
            let judgment = try await judge(corrected, key)
            let respelled = Respell.apply(judgment.respell, to: raw)
            let text = SpeechFormat.render(respelled, shape: judgment.shape, replacements: judgment.replacements, dictionary: dictionary)
            guard !text.isEmpty else { return JevResult(text: local, note: "Formatting failed. Inserted local text.") }
            return JevResult(text: text, note: nil)
        } catch JevFailure.rejectedKey {
            return JevResult(text: local, note: "TypeSafe rejected the key. Inserted local text.")
        } catch {
            return JevResult(text: local, note: "Formatting failed. Inserted local text.")
        }
    }
}
