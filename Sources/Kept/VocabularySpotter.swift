import FluidAudio
import Foundation
import KeptCore

/// Listens for dictionary terms in the audio with the Parakeet CTC 110M word
/// spotter (FluidAudio vocabulary boosting). It reports spans where the audio
/// sounds more like a term than like the transcript's words. It never edits
/// the transcript: Jev confirms each proposal from context, and code swaps
/// only what Jev confirmed.
actor VocabularySpotter {
    static let shared = VocabularySpotter()

    static var bundleDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent(SpeechRoute.ctcModelFolder, isDirectory: true)
    }

    private struct Loaded: Sendable {
        let models: CtcModels
        let tokenizer: CtcTokenizer
        let directory: URL
    }

    private struct Prepared: Sendable {
        let terms: [String]
        let vocabulary: CustomVocabularyContext
        let spotter: CtcKeywordSpotter
        let rescorer: VocabularyRescorer
    }

    private var loading: Task<Loaded, Error>?
    private var prepared: Prepared?

    /// Loads the spotter and builds the rescorer for the saved dictionary, so
    /// the first take after launch does not pay for either.
    func warmup(dictionary: [String]) async {
        let terms = HeardTerm.spotterTerms(dictionary)
        if terms.isEmpty {
            _ = try? await load()
        } else {
            _ = try? await prepare(terms)
        }
    }

    /// Terms the audio supports in this take. Empty on any failure: a missing
    /// spotter must never cost the take.
    func heard(samples: [Float], transcript: String, tokenTimings: [TokenTiming], dictionary: [String]) async -> [HeardTerm] {
        let terms = HeardTerm.spotterTerms(dictionary)
        guard !terms.isEmpty, !tokenTimings.isEmpty, !samples.isEmpty else { return [] }
        let started = ContinuousClock.now
        do {
            let set = try await prepare(terms)
            let spot = try await set.spotter.spotKeywordsWithLogProbs(
                audioSamples: samples, customVocabulary: set.vocabulary, minScore: nil)
            guard !spot.logProbs.isEmpty else { return [] }
            let sized = ContextBiasingConstants.rescorerConfig(forVocabSize: set.vocabulary.terms.count)
            let evidence = set.rescorer.ctcTokenEvaluateCandidates(
                transcript: transcript, tokenTimings: tokenTimings, logProbs: spot.logProbs,
                frameDuration: spot.frameDuration, cbw: sized.cbw,
                marginSeconds: ContextBiasingConstants.defaultMarginSeconds,
                minSimilarity: sized.minSimilarity)
            var found: [HeardTerm] = []
            // `applied` is what FluidAudio itself would have written after
            // overlap arbitration: one proposal per stretch of audio.
            for candidate in evidence.candidates where candidate.legacyOutcome == .applied {
                let span = Self.span(of: candidate, in: evidence.baseText)
                let item = HeardTerm(span: span, term: candidate.canonicalTerm)
                if !span.isEmpty, !found.contains(item) { found.append(item) }
            }
            let ms = Int((ContinuousClock.now - started) / .milliseconds(1))
            KeptLog.format.notice("spotter heard \(found.count) of \(terms.count) terms in \(ms) ms")
            return found
        } catch {
            KeptLog.format.error("spotter unavailable: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    private func load() async throws -> Loaded {
        if let loading { return try await loading.value }
        guard let directory = Self.bundleDirectory,
              FileManager.default.fileExists(atPath: directory.appendingPathComponent("tokenizer.json").path) else {
            throw SpotterFailure.missingFromApp
        }
        let task = Task {
            Loaded(
                models: try await CtcModels.loadDirect(from: directory, variant: .ctc110m),
                tokenizer: try await CtcTokenizer.load(from: directory),
                directory: directory
            )
        }
        loading = task
        do {
            return try await task.value
        } catch {
            loading = nil
            throw error
        }
    }

    /// The rescorer is built for one term list. A dictionary edit rebuilds it.
    private func prepare(_ terms: [String]) async throws -> Prepared {
        if let prepared, prepared.terms == terms { return prepared }
        let loaded = try await load()
        let tokenized = terms.compactMap { text -> CustomVocabularyTerm? in
            let ids = loaded.tokenizer.encode(text)
            return ids.isEmpty ? nil : CustomVocabularyTerm(text: text, ctcTokenIds: ids)
        }
        let vocabulary = CustomVocabularyContext(terms: tokenized)
        let spotter = CtcKeywordSpotter(models: loaded.models, blankId: loaded.models.vocabulary.count)
        let rescorer = try await VocabularyRescorer.create(
            spotter: spotter, vocabulary: vocabulary, config: .default, ctcModelDirectory: loaded.directory)
        let made = Prepared(terms: terms, vocabulary: vocabulary, spotter: spotter, rescorer: rescorer)
        prepared = made
        return made
    }

    /// The exact transcript text when FluidAudio could align it, without the
    /// sentence's punctuation, so a replacement keeps the period.
    private static func span(of candidate: VocabularyRescorer.CandidateEvidence, in base: String) -> String {
        var text = candidate.basePhrase
        if let range = candidate.baseTextUTF8Range {
            let bytes = Array(base.utf8)
            if range.lowerBound >= 0, range.upperBound <= bytes.count {
                text = String(decoding: bytes[range], as: UTF8.self)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters.subtracting(CharacterSet(charactersIn: "@"))))
    }
}

private enum SpotterFailure: LocalizedError {
    case missingFromApp

    var errorDescription: String? {
        "The dictionary word spotter is missing from the app."
    }
}
