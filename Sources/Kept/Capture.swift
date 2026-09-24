import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import KeptCore

@MainActor
@Observable
final class Session {
    var status = "Hold Right Option to talk"
    var recording = false
    var takes: [Take] = []

    @ObservationIgnored private let store: TakeStore
    @ObservationIgnored private let monitor = RightOptionMonitor()
    @ObservationIgnored private let mic = MicRecorder()
    @ObservationIgnored private var held = false
    @ObservationIgnored private var busy = false
    @ObservationIgnored private var arming = false
    @ObservationIgnored private var activeWav: URL?
    @ObservationIgnored private var activeID: UUID?

    init(store: TakeStore = TakeStore(directory: KeptPaths.takesDirectory)) {
        self.store = store
        takes = (try? store.load()) ?? []
        try? FileManager.default.createDirectory(at: KeptPaths.takesDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: KeptPaths.modelsDirectory, withIntermediateDirectories: true)
        monitor.onDown = { [weak self] in
            Task { @MainActor in self?.beginHold() }
        }
        monitor.onUp = { [weak self] in
            Task { @MainActor in self?.endHold() }
        }
        monitor.start()
        if !monitor.globalInstalled || !Self.accessibilityTrusted(prompt: true) {
            status = "Accessibility permission is required to hear Right Option"
        }
    }

    func beginHold() {
        held = true
        guard !recording, !busy else { return }
        Task { await startRecordingIfStillHeld() }
    }

    func endHold() {
        held = false
        guard recording, let wav = activeWav, let id = activeID else { return }
        let duration = mic.stop()
        recording = false
        activeWav = nil
        activeID = nil
        busy = true
        status = "Transcribing…"
        Task { await finish(id: id, wav: wav, duration: duration) }
    }

    func dismiss(_ id: UUID) {
        if let remaining = try? store.dismiss(id: id) {
            takes = remaining
            return
        }
        if let take = takes.first(where: { $0.id == id }) {
            try? FileManager.default.removeItem(atPath: take.wavPath)
        }
        takes.removeAll { $0.id == id }
    }

    private func startRecordingIfStillHeld() async {
        guard held, !recording, !busy, !arming else { return }
        arming = true
        defer { arming = false }
        guard await mic.granted() else {
            status = "Microphone permission is off"
            return
        }
        guard held, !recording, !busy else { return }
        let id = UUID()
        let wav = store.wavURL(id: id)
        do {
            try mic.start(url: wav)
        } catch {
            status = "Could not start the microphone"
            return
        }
        guard held else {
            _ = mic.stop()
            try? FileManager.default.removeItem(at: wav)
            return
        }
        activeID = id
        activeWav = wav
        recording = true
        status = "Recording…"
    }

    private func finish(id: UUID, wav: URL, duration: Double) async {
        defer {
            busy = false
            if held { Task { await startRecordingIfStillHeld() } }
        }
        let transcript: String
        do {
            status = "Transcribing…"
            let model = try await ModelStore.prepare { message in
                self.status = message
            }
            transcript = try await Task.detached {
                try WhisperProcess.transcribe(modelPath: model.path, wavPath: wav.path)
            }.value
        } catch {
            status = error.localizedDescription
            remember(id: id, wav: wav, transcript: "", duration: duration)
            return
        }
        remember(id: id, wav: wav, transcript: transcript, duration: duration)
        status = "Hold Right Option to talk"
    }

    private func remember(id: UUID, wav: URL, transcript: String, duration: Double) {
        let take = Take(id: id, wavPath: wav.path, rawTranscript: transcript, durationSeconds: duration)
        takes.insert(take, at: 0)
        try? store.save(takes)
    }

    private static func accessibilityTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

final class RightOptionMonitor {
    static let keyCode: UInt16 = 0x3D
    static let deviceFlag: UInt = 0x40

    var onDown: () -> Void = {}
    var onUp: () -> Void = {}
    private(set) var globalInstalled = false
    private var global: Any?
    private var local: Any?
    private var down = false

    func start() {
        guard global == nil, local == nil else { return }
        global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        globalInstalled = global != nil
        local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    /// keyCode 0x3D is Right Option. Device flag 0x40 is NX_DEVICERALTKEYMASK.
    /// NSEvent sometimes strips that bit; the key that changed plus .option still tells press from release.
    private func handle(_ event: NSEvent) {
        guard event.keyCode == Self.keyCode else { return }
        let raw = event.modifierFlags.rawValue
        let deviceBits = raw & 0x0000_207F
        let pressed = deviceBits != 0
            ? (raw & Self.deviceFlag) != 0
            : event.modifierFlags.contains(.option)
        guard pressed != down else { return }
        down = pressed
        if pressed { onDown() } else { onUp() }
    }
}

@MainActor
final class MicRecorder {
    private var recorder: AVAudioRecorder?

    func granted() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    func start(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else { throw RecorderError.failed }
        self.recorder = recorder
    }

    func stop() -> Double {
        let duration = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil
        return duration
    }
}

private enum RecorderError: Error {
    case failed
}

enum ModelStore {
    private static let minimumBytes: Int64 = 1_000_000_000
    private static let preferredURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
    private static let fallbackURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin"

    static func prepare(status: @escaping @MainActor (String) -> Void) async throws -> URL {
        try FileManager.default.createDirectory(at: KeptPaths.modelsDirectory, withIntermediateDirectories: true)
        if let existing = resolved() { return existing }
        await MainActor.run { status("Downloading ggml-large-v3-turbo…") }
        if await download(preferredURL, named: WhisperCommand.preferredModelFileName), let existing = resolved() {
            return existing
        }
        await MainActor.run { status("Downloading ggml-medium.en…") }
        if await download(fallbackURL, named: WhisperCommand.fallbackModelFileName), let existing = resolved() {
            return existing
        }
        throw ModelError.missing
    }

    private static func resolved() -> URL? {
        let directory = KeptPaths.modelsDirectory
        let preferred = directory.appendingPathComponent(WhisperCommand.preferredModelFileName)
        let fallback = directory.appendingPathComponent(WhisperCommand.fallbackModelFileName)
        guard let name = WhisperCommand.modelFileName(preferredExists: usable(preferred), fallbackExists: usable(fallback)) else {
            return nil
        }
        return directory.appendingPathComponent(name)
    }

    private static func usable(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        return size >= minimumBytes
    }

    private static func download(_ url: String, named name: String) async -> Bool {
        let destination = KeptPaths.modelsDirectory.appendingPathComponent(name)
        let partial = destination.appendingPathExtension("partial")
        return await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = ["-L", "--fail", "--retry", "3", "-C", "-", "-o", partial.path, url]
            let sink = FileHandle(forWritingAtPath: "/dev/null")
            process.standardOutput = sink
            process.standardError = sink
            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return false }
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: partial, to: destination)
                let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.int64Value ?? 0
                return size >= minimumBytes
            } catch {
                return false
            }
        }.value
    }
}

private enum ModelError: LocalizedError {
    case missing

    var errorDescription: String? {
        "No dictation model in ~/Library/Application Support/Kept/models"
    }
}

enum WhisperProcess {
    static func transcribe(modelPath: String, wavPath: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: WhisperCommand.executablePath)
        process.arguments = WhisperCommand.arguments(modelPath: modelPath, wavPath: wavPath)
        let errors = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        let errData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errData, encoding: .utf8)?
                .split(whereSeparator: \.isNewline)
                .last
                .map(String.init) ?? "whisper-cli failed (\(process.terminationStatus))"
            throw WhisperFailure(message: message)
        }
        let txt = WhisperCommand.transcriptURL(wavPath: wavPath)
        let raw = (try? String(contentsOf: txt, encoding: .utf8)) ?? ""
        try? FileManager.default.removeItem(at: txt)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct WhisperFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
