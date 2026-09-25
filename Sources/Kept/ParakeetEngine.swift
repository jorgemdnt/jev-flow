import AVFoundation
import FluidAudio
import Foundation
import KeptCore

/// Local Parakeet TDT 0.6B v3. The live card streams that same model.
/// The pasted transcript is still a v3 batch, not the English-only EOU model.
actor ParakeetEngine {
    static let shared = ParakeetEngine()

    private var manager: AsrManager?
    private var loadedModels: AsrModels?
    private var loading: Task<AsrModels, Error>?
    private var live: SlidingWindowAsrManager?
    private var liveTask: Task<Void, Never>?
    private var liveGeneration = 0

    static var bundleDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent(SpeechRoute.parakeetModelFolder, isDirectory: true)
    }

    func warmup() async {
        _ = try? await models()
        _ = try? await ready()
    }

    /// Opens a low-latency v3 stream. Each yield is the text so far.
    /// Call `endLive()` on release. The paste still uses `transcribe`.
    func beginLive(languageCode: String) async throws -> AsyncStream<String> {
        let generation = liveGeneration
        let models = try await models()
        guard generation == liveGeneration else { throw CancellationError() }
        let config = SlidingWindowAsrConfig(
            chunkSeconds: 0.5,
            hypothesisChunkSeconds: 0.5,
            leftContextSeconds: 1.0,
            rightContextSeconds: 0,
            minContextForConfirmation: 8,
            confirmationThreshold: 0.8,
            language: Self.hint(languageCode)
        )
        let stream = SlidingWindowAsrManager(config: config)
        try await stream.loadModels(models)
        guard generation == liveGeneration else {
            await stream.cancel()
            throw CancellationError()
        }
        let updates = await stream.transcriptionUpdates
        try await stream.startStreaming(source: .microphone)
        guard generation == liveGeneration else {
            await stream.cancel()
            throw CancellationError()
        }
        live = stream
        let (output, continuation) = AsyncStream<String>.makeStream()
        liveTask = Task {
            for await update in updates {
                let text = Self.windowText(update)
                if !text.isEmpty { continuation.yield(text) }
            }
            continuation.finish()
        }
        return output
    }

    func pushLive(_ samples: [Float]) async {
        guard let live, let buffer = Self.buffer(samples) else { return }
        await live.streamAudio(buffer)
    }

    func endLive() async {
        liveGeneration &+= 1
        let stream = live
        live = nil
        liveTask?.cancel()
        liveTask = nil
        await stream?.cancel()
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
        let models = try await models()
        let loaded = AsrManager(config: .default)
        try await loaded.loadModels(models)
        manager = loaded
        return loaded
    }

    private func models() async throws -> AsrModels {
        if let loadedModels { return loadedModels }
        if let loading { return try await loading.value }
        let task = Task { try Self.loadModels() }
        loading = task
        do {
            let loaded = try await task.value
            loadedModels = loaded
            loading = nil
            return loaded
        } catch {
            loading = nil
            throw error
        }
    }

    private static func loadModels() throws -> AsrModels {
        guard let directory = bundleDirectory else {
            throw ParakeetFailure.missingFromApp
        }
        return try AsrModels.loadLocal(from: directory, version: .v3)
    }

    /// The words in this window, joined. The card assembles windows. The
    /// accumulated transcript glues the next window onto the previous one.
    private static func windowText(_ update: SlidingWindowTranscriptionUpdate) -> String {
        let words = buildWordTimings(from: update.tokenTimings).map(\.word).filter { !$0.isEmpty }
        if !words.isEmpty { return words.joined(separator: " ") }
        return update.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: SpeechAudio.sampleRate,
                channels: 1,
                interleaved: false
              ),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return nil }
        samples.withUnsafeBufferPointer { source in
            guard let address = source.baseAddress else { return }
            channel.update(from: address, count: samples.count)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        return buffer
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
