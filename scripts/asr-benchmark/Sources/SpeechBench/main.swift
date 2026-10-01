import AVFoundation
import FluidAudio
import Foundation

struct Take: Decodable {
    let id: String
    let wavPath: String
    let language: String
    let durationSeconds: Double
}

func seconds(_ elapsed: Duration) -> Double {
    Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
}

func emit(_ row: [String: Any], to handle: FileHandle) throws {
    let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
    try handle.write(contentsOf: data + Data([10]))
}

func samples(at path: String) throws -> [Float] {
    let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
    guard file.processingFormat.sampleRate == 16_000,
          file.processingFormat.channelCount == 1,
          let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
        throw NSError(domain: "SpeechBench", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected stored 16 kHz mono WAV"])
    }
    try file.read(into: buffer)
    guard let channel = buffer.floatChannelData?[0] else { throw NSError(domain: "SpeechBench", code: 2) }
    return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
}

@main
struct SpeechBench {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 5 else {
            print("Usage: SpeechBench <v3-dir> <phonon-dir> <takes-json> <output-jsonl>")
            exit(2)
        }
        let takes = try JSONDecoder().decode([Take].self, from: Data(contentsOf: URL(fileURLWithPath: args[3])))
        FileManager.default.createFile(atPath: args[4], contents: nil, attributes: [.posixPermissions: 0o600])
        let output = try FileHandle(forWritingTo: URL(fileURLWithPath: args[4]))
        defer { try? output.close() }
        var managers: [AsrManager] = []
        for (name, path, version) in [("v3", args[1], AsrModelVersion.v3), ("phonon2", args[2], AsrModelVersion.phonon2)] {
            print("Loading \(name)")
            let started = ContinuousClock.now
            let models = try AsrModels.loadLocal(from: URL(fileURLWithPath: path), version: version)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            let elapsed = seconds(ContinuousClock.now - started)
            try emit(["kind": "load", "model": name, "seconds": elapsed], to: output)
            print("Loaded \(name) in \(elapsed)s")
            managers.append(manager)
        }
        let names = ["v3", "phonon2"]
        let firstAudio = try samples(at: takes[1].wavPath)
        for manager in managers {
            var state = TdtDecoderState.make()
            _ = try await manager.transcribe(firstAudio, decoderState: &state, language: Language(rawValue: "en"))
        }
        for repetition in 0..<3 {
            for (takeIndex, take) in takes.enumerated() {
                let audio = try samples(at: take.wavPath)
                let order = (repetition + takeIndex) % 2 == 0 ? [0, 1] : [1, 0]
                for modelIndex in order {
                    var state = TdtDecoderState.make()
                    let started = ContinuousClock.now
                    let result = try await managers[modelIndex].transcribe(audio, decoderState: &state, language: Language(rawValue: take.language))
                    let elapsed = seconds(ContinuousClock.now - started)
                    let words = buildWordTimings(from: result.tokenTimings ?? []).sorted { $0.startTime < $1.startTime }
                    let text = words.isEmpty ? result.text : words.map(\.word).joined(separator: " ")
                    try emit([
                        "kind": "take", "id": take.id, "language": take.language,
                        "model": names[modelIndex], "repetition": repetition,
                        "audioSeconds": Double(audio.count) / 16_000, "seconds": elapsed,
                        "text": text, "rawText": result.text,
                        "words": words.map { ["word": $0.word, "start": $0.startTime, "end": $0.endTime] },
                    ], to: output)
                    print("\(names[modelIndex]) \(take.id.prefix(8)) run \(repetition + 1): \(String(format: "%.3f", elapsed))s, \(words.count) timed words")
                }
            }
        }
    }
}
