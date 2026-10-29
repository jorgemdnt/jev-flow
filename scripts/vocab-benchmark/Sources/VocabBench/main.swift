// Replays stored takes through the dictionary word spotter the way JevFlow
// runs it, and writes one JSON line per take with the spans it would propose.
// Jev's confirmation is not part of this run.
//
//   swift run -c release VocabBench <out.jsonl> [limit]
//
// Reads the takes, the Parakeet v3 runtime and the CTC 110M spotter from
// ~/Library/Application Support/Kept. The output holds transcripts: keep it
// on this Mac.
import FluidAudio
import Foundation

struct Take: Decodable {
    let id: String
    let wavPath: String
    let rawTranscript: String
    let durationSeconds: Double
}

struct Voice: Decodable {
    let words: [String]
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: VocabBench <out.jsonl> [limit]\n".utf8))
    exit(2)
}
let support = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Kept")
let models = support.appendingPathComponent("models")
let limit = args.count > 2 ? Int(args[2]) ?? Int.max : Int.max

let asr = AsrManager(config: .default)
try await asr.loadModels(try AsrModels.loadLocal(from: models.appendingPathComponent("parakeet-tdt-0.6b-v3-coreml"), version: .v3))

let ctcDirectory = models.appendingPathComponent("parakeet-ctc-110m-coreml")
let ctc = try await CtcModels.loadDirect(from: ctcDirectory, variant: .ctc110m)
let tokenizer = try await CtcTokenizer.load(from: ctcDirectory)
let words = try JSONDecoder().decode(Voice.self, from: Data(contentsOf: support.appendingPathComponent("voice.json"))).words
let terms = words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && !$0.hasPrefix("@") }
let vocabulary = CustomVocabularyContext(terms: terms.compactMap { text in
    let ids = tokenizer.encode(text)
    return ids.isEmpty ? nil : CustomVocabularyTerm(text: text, ctcTokenIds: ids)
})
let spotter = CtcKeywordSpotter(models: ctc, blankId: ctc.vocabulary.count)
let rescorer = try await VocabularyRescorer.create(spotter: spotter, vocabulary: vocabulary, config: .default, ctcModelDirectory: ctcDirectory)
let sized = ContextBiasingConstants.rescorerConfig(forVocabSize: vocabulary.terms.count)

let takes = try JSONDecoder().decode([Take].self, from: Data(contentsOf: support.appendingPathComponent("takes/index.json")))
let outURL = URL(fileURLWithPath: args[1])
FileManager.default.createFile(atPath: outURL.path, contents: nil)
let out = try FileHandle(forWritingTo: outURL)
var done = 0
for take in takes where done < limit {
    let url = URL(fileURLWithPath: take.wavPath)
    guard FileManager.default.fileExists(atPath: url.path), !take.rawTranscript.isEmpty,
          let samples = try? AudioConverter().resampleAudioFile(url) else { continue }
    var state = TdtDecoderState.make()
    let result = try await asr.transcribe(samples, decoderState: &state, language: nil)
    guard let timings = result.tokenTimings, !timings.isEmpty else { continue }
    let started = ContinuousClock.now
    let spot = try await spotter.spotKeywordsWithLogProbs(audioSamples: samples, customVocabulary: vocabulary, minScore: nil)
    let evidence = rescorer.ctcTokenEvaluateCandidates(
        transcript: result.text, tokenTimings: timings, logProbs: spot.logProbs,
        frameDuration: spot.frameDuration, cbw: sized.cbw,
        marginSeconds: ContextBiasingConstants.defaultMarginSeconds, minSimilarity: sized.minSimilarity)
    let ms = Int((ContinuousClock.now - started) / .milliseconds(1))
    let heard = evidence.candidates.filter { $0.legacyOutcome == .applied }.map {
        ["span": $0.basePhrase, "term": $0.canonicalTerm,
         "original": Double($0.rawOriginalCTCScore ?? .nan), "vocabulary": Double($0.rawVocabularyCTCScore ?? .nan)] as [String: Any]
    }
    let row: [String: Any] = ["id": take.id, "duration": take.durationSeconds, "text": result.text, "spotterMs": ms, "heard": heard]
    out.write(try JSONSerialization.data(withJSONObject: row))
    out.write(Data("\n".utf8))
    done += 1
}
try out.close()
FileHandle.standardError.write(Data("\(done) takes, \(terms.count) terms\n".utf8))
