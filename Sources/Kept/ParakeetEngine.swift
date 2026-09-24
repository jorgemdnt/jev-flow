import FluidAudio
import Foundation
import KeptCore

/// Local Parakeet TDT 0.6B v3. Batch only. Not the English-only EOU model.
actor ParakeetEngine {
    static let shared = ParakeetEngine()

    private var manager: AsrManager?
    private var loading: Task<AsrManager, Error>?

    static var bundleDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent(SpeechRoute.parakeetModelFolder, isDirectory: true)
    }

    func warmup() async {
        _ = try? await ready()
    }

    func transcribe(wavPath: String, languageCode: String) async throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: wavPath))
        guard let decoded = WavPCM.decode(data),
              let samples = SpeechAudio.prepare(samples: decoded.samples, sampleRate: decoded.sampleRate) else {
            throw SpeechGate.tooShort
        }
        return try await transcribe(samples: samples, languageCode: languageCode)
    }

    /// `samples` are already 16 kHz. A shorter buffer is not sent to the model.
    func transcribe(samples: [Float], languageCode: String) async throws -> String {
        guard samples.count >= SpeechAudio.minimumSamples else { throw SpeechGate.tooShort }
        let manager = try await ready()
        var state = TdtDecoderState.make()
        let result = try await manager.transcribe(
            samples,
            decoderState: &state,
            language: Self.hint(languageCode)
        )
        let words = buildWordTimings(from: result.tokenTimings ?? [])
            .sorted { $0.startTime < $1.startTime }
            .map(\.word)
        return SpeechTranscript.text(timedWords: words, rawText: result.text)
    }

    private func ready() async throws -> AsrManager {
        if let manager { return manager }
        if let loading { return try await loading.value }
        let task = Task { try await Self.load() }
        loading = task
        do {
            let loaded = try await task.value
            manager = loaded
            loading = nil
            return loaded
        } catch {
            loading = nil
            throw error
        }
    }

    private static func load() async throws -> AsrManager {
        guard let directory = bundleDirectory else {
            throw ParakeetFailure.missingFromApp
        }
        let models = try AsrModels.loadLocal(from: directory, version: .v3)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        return manager
    }

    /// `auto` lets v3 detect among the 25. A pinned code is a script hint.
    private static func hint(_ code: String) -> Language? {
        guard code != SpokenLanguage.auto.code else { return nil }
        return Language(rawValue: code)
    }
}

private enum ParakeetFailure: LocalizedError {
    case missingFromApp

    var errorDescription: String? {
        "Parakeet is missing from the app."
    }
}
