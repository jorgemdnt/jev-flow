import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import KeptCore

enum LivePhase: Equatable {
    case idle
    case listening
    case transcribing
    case cleaning
}

@MainActor
@Observable
final class Session {
    var status = "Hold Right Option to talk"
    var recording = false
    var takes: [Take] = []
    var lastInsertedText = ""
    var livePhase: LivePhase = .idle
    var livePreview = ""
    var microphoneName = ""
    let voice = VoiceStore()

    static let insertNeedsAccessibility = "Accessibility permission is required to insert. Text kept."
    static let keptNotPasted = "Kept this take and did not paste it."
    static let caretMarkUnavailable = "Caret mark unavailable."

    @ObservationIgnored private let store: TakeStore
    @ObservationIgnored private let monitor = RightOptionMonitor()
    @ObservationIgnored private let mic = MicRecorder()
    @ObservationIgnored private let whisper = WhisperSerial()
    @ObservationIgnored private let caret = CaretMark()
    @ObservationIgnored private var held = false
    @ObservationIgnored private var busy = false
    @ObservationIgnored private var arming = false
    @ObservationIgnored private var activeWav: URL?
    @ObservationIgnored private var activeID: UUID?
    @ObservationIgnored private var anchor = ""
    @ObservationIgnored private var partial: FieldPartial?
    @ObservationIgnored private var partialTask: Task<Void, Never>?
    @ObservationIgnored private var finishTask: Task<Void, Never>?
    var caretNote = ""

    init(store: TakeStore = TakeStore(directory: KeptPaths.takesDirectory)) {
        self.store = store
        takes = (try? store.load()) ?? []
        lastInsertedText = Self.readLastInserted() ?? takes.compactMap(\.insertedText).first ?? ""
        try? FileManager.default.createDirectory(at: KeptPaths.takesDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: KeptPaths.modelsDirectory, withIntermediateDirectories: true)
        monitor.onDown = { [weak self] in
            Task { @MainActor in self?.beginHold() }
        }
        monitor.onUp = { [weak self] in
            Task { @MainActor in self?.endHold() }
        }
        monitor.start()
        caret.onNote = { [weak self] note in
            self?.caretNote = note
        }
        if !monitor.globalInstalled || !Self.accessibilityTrusted(prompt: true) {
            status = "Accessibility permission is required to hear Right Option"
        }
    }

    func beginHold() {
        held = true
        guard !recording else { return }
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
        let streaming = partialTask
        partialTask = nil
        let captured = partial
        partial = nil
        let base = anchor
        finishTask = Task {
            await streaming?.value
            await self.finish(id: id, wav: wav, duration: duration, partial: captured, anchor: base)
        }
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

    var canInsert: Bool {
        Self.accessibilityTrusted(prompt: false)
    }

    var lastRawTranscript: String {
        takes.first?.rawTranscript ?? ""
    }

    func refusesAutoInsert(_ take: Take) -> Bool {
        !InsertDecision(transcript: take.rawTranscript, durationSeconds: take.durationSeconds).autoInsert
    }

    func keptText(_ take: Take) -> String {
        Formatter.finished(take.rawTranscript)
    }

    func insertRaw(_ id: UUID) {
        Task { await insertManually(id: id, formatted: false) }
    }

    func insertKept(_ id: UUID) {
        Task { await insertManually(id: id, formatted: true) }
    }

    func insertAgain(_ id: UUID) {
        Task { await insertStored(id: id) }
    }

    private func startRecordingIfStillHeld() async {
        guard held, !recording, !arming else { return }
        arming = true
        defer { arming = false }
        guard await mic.granted() else {
            status = "Microphone permission is off"
            return
        }
        guard held, !recording else { return }
        let id = UUID()
        let wav = store.wavURL(id: id)
        do {
            try mic.start(url: wav)
            microphoneName = mic.deviceName
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
        anchor = lastInsertedText
        recording = true
        livePhase = .listening
        livePreview = ""
        status = "Recording…"
        caret.show()
        let previousFinish = finishTask
        partialTask = Task {
            await previousFinish?.value
            guard await MainActor.run(body: { self.recording && self.activeID == id }) else { return }
            await MainActor.run { self.anchor = self.lastInsertedText }
            await self.streamPartials(id: id)
        }
    }

    private func streamPartials(id: UUID) async {
        var lastBytes = 0
        while recording, activeID == id {
            guard let snap = mic.snapshot() else {
                try? await Task.sleep(for: .milliseconds(200))
                continue
            }
            if snap.bytes < 16_000 || snap.bytes < lastBytes + 16_000 {
                try? FileManager.default.removeItem(at: snap.url)
                try? await Task.sleep(for: .milliseconds(200))
                continue
            }
            lastBytes = snap.bytes
            let raw: String
            do {
                raw = try await transcribe(snap.url)
            } catch {
                try? FileManager.default.removeItem(at: snap.url)
                try? await Task.sleep(for: .milliseconds(300))
                continue
            }
            try? FileManager.default.removeItem(at: snap.url)
            guard recording, activeID == id else { return }
            let text = Formatter.streaming(raw)
            guard !text.isEmpty else { continue }
            livePreview = text
        }
    }

    private func finish(id: UUID, wav: URL, duration: Double, partial captured: FieldPartial?, anchor: String) async {
        defer {
            busy = false
            if !recording {
                caret.hide()
                livePhase = .idle
                livePreview = ""
            }
            if held { Task { await startRecordingIfStillHeld() } }
        }
        let transcript: String
        do {
            if !recording {
                status = "Transcribing…"
                livePhase = .transcribing
            }
            transcript = try await transcribe(wav)
        } catch {
            if !recording { status = error.localizedDescription }
            remember(id: id, wav: wav, transcript: "", duration: duration)
            return
        }
        remember(id: id, wav: wav, transcript: transcript, duration: duration)
        let decision = InsertDecision(transcript: transcript, durationSeconds: duration)
        let outcome: CleanupOutcome
        if decision.autoInsert {
            if !recording {
                status = "Formatting…"
                livePhase = .cleaning
            }
            outcome = await JevFormat.prepare(raw: transcript, dictionary: voice.words)
        } else {
            outcome = .local("", note: "")
        }
        let message = deliver(
            id: id,
            raw: transcript,
            duration: duration,
            partial: captured,
            anchor: anchor,
            prepared: outcome.text,
            cleanupNote: outcome.note
        )
        if !recording { status = message }
    }

    private func transcribe(_ wav: URL) async throws -> String {
        let code = LanguageStore.currentCode()
        if SpeechRoute.engine(for: code) == .parakeetV3 {
            if !ParakeetEngine.isCached {
                if recording {
                    if livePreview.isEmpty { livePreview = "Downloading Parakeet…" }
                } else {
                    status = "Downloading Parakeet…"
                }
            }
            return try await ParakeetEngine.shared.transcribe(wavPath: wav.path, languageCode: code)
        }
        let model = try await ModelStore.prepare { message in
            if !self.recording {
                self.status = message
            }
        }
        return try await whisper.transcribe(modelPath: model.path, wavPath: wav.path)
    }

    private func deliver(
        id: UUID,
        raw: String,
        duration: Double,
        partial captured: FieldPartial?,
        anchor: String,
        prepared: String,
        cleanupNote: String?
    ) -> String {
        let decision = InsertDecision(transcript: raw, durationSeconds: duration)
        guard decision.autoInsert else {
            if let captured { _ = removePartial(captured) }
            return Self.keptNotPasted
        }
        let text = TakeJoin.submission(previous: anchor, next: prepared)
        guard !text.isEmpty else {
            if let captured { _ = removePartial(captured) }
            return "Hold Right Option to talk"
        }
        let idle = (cleanupNote?.isEmpty == false) ? cleanupNote! : "Hold Right Option to talk"
        if let captured {
            guard let updated = replace(captured, with: text) else {
                return "Could not replace the partial. Text kept."
            }
            recordInserted(id: id, text: updated.text)
            return idle
        }
        switch place(text) {
        case .placed(let placed):
            recordInserted(id: id, text: placed.text)
            return idle
        case .accessibilityMissing:
            return Self.insertNeedsAccessibility
        case .wouldReplaceSelection:
            return "Could not insert without replacing a selection. Text kept."
        case .failed:
            return "Could not insert. Text kept."
        }
    }

    private func publish(_ text: String) {
        if let partial {
            guard text != partial.text else { return }
            guard let updated = replace(partial, with: text) else {
                status = "Could not replace the partial. Text kept."
                return
            }
            self.partial = updated
            return
        }
        switch FocusedField.caretForInsert() {
        case .location(let location):
            switch FocusedAppPaste.paste(text) {
            case .pasted:
                partial = FieldPartial(location: location, text: text)
            case .accessibilityMissing:
                status = Self.insertNeedsAccessibility
            case .failed:
                status = "Could not insert. Text kept."
            }
        case .selectionCouldNotCollapse:
            status = "Could not insert without replacing a selection. Text kept."
        case .unavailable:
            return
        }
    }

    private func place(_ text: String) -> PlaceResult {
        switch FocusedField.caretForInsert() {
        case .location(let location):
            switch FocusedAppPaste.paste(text) {
            case .pasted:
                return .placed(FieldPartial(location: location, text: text))
            case .accessibilityMissing:
                return .accessibilityMissing
            case .failed:
                return .failed
            }
        case .selectionCouldNotCollapse:
            return .wouldReplaceSelection
        case .unavailable:
            switch FocusedAppPaste.paste(text) {
            case .pasted:
                return .placed(FieldPartial(location: -1, text: text))
            case .accessibilityMissing:
                return .accessibilityMissing
            case .failed:
                return .failed
            }
        }
    }

    private func replace(_ partial: FieldPartial, with text: String) -> FieldPartial? {
        guard partial.location >= 0 else { return nil }
        let length = (partial.text as NSString).length
        guard FocusedField.select(location: partial.location, length: length) else { return nil }
        guard FocusedField.selectedText() == partial.text else { return nil }
        switch FocusedAppPaste.paste(text) {
        case .pasted:
            return FieldPartial(location: partial.location, text: text)
        default:
            return nil
        }
    }

    private func removePartial(_ partial: FieldPartial) -> Bool {
        guard partial.location >= 0 else { return false }
        let length = (partial.text as NSString).length
        guard FocusedField.select(location: partial.location, length: length) else { return false }
        guard FocusedField.selectedText() == partial.text else { return false }
        return FocusedField.deleteSelection()
    }

    private func insertManually(id: UUID, formatted: Bool) async {
        guard let take = takes.first(where: { $0.id == id }) else { return }
        guard Self.accessibilityTrusted(prompt: true) else {
            status = Self.insertNeedsAccessibility
            return
        }
        try? await Task.sleep(for: .milliseconds(80))
        await FocusedAppPaste.focusForeignAppIfNeeded()
        let text: String
        let note: String?
        if formatted {
            status = "Formatting…"
            let outcome = await JevFormat.prepare(raw: take.rawTranscript, dictionary: voice.words)
            text = outcome.text
            note = outcome.note
        } else {
            text = take.rawTranscript
            note = nil
        }
        let inserting = TakeJoin.submission(previous: lastInsertedText, next: text)
        guard !inserting.isEmpty else {
            status = "Could not insert. Text kept."
            return
        }
        switch FocusedAppPaste.paste(inserting) {
        case .pasted:
            recordInserted(id: id, text: inserting)
            status = (note?.isEmpty == false) ? note! : "Hold Right Option to talk"
        case .accessibilityMissing:
            status = Self.insertNeedsAccessibility
        case .failed:
            status = "Could not insert. Text kept."
        }
    }

    private func insertStored(id: UUID) async {
        guard let take = takes.first(where: { $0.id == id }) else { return }
        let stored = take.insertedText ?? Formatter.finished(take.rawTranscript)
        let text = stored.last?.isWhitespace == true ? stored : stored + " "
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard Self.accessibilityTrusted(prompt: true) else {
            status = Self.insertNeedsAccessibility
            return
        }
        await FocusedAppPaste.focusForeignAppIfNeeded()
        switch FocusedAppPaste.paste(text) {
        case .pasted:
            lastInsertedText = text
            let url = KeptPaths.applicationSupport.appendingPathComponent("last-inserted.txt")
            try? text.write(to: url, atomically: true, encoding: .utf8)
            status = "Hold Right Option to talk"
        case .accessibilityMissing:
            status = Self.insertNeedsAccessibility
        case .failed:
            status = "Could not insert. Text kept."
        }
    }

    private func recordInserted(id: UUID, text: String) {
        if let index = takes.firstIndex(where: { $0.id == id }) {
            var take = takes[index]
            take.insertedText = text
            takes[index] = take
            try? store.save(takes)
        }
        lastInsertedText = text
        let url = KeptPaths.applicationSupport.appendingPathComponent("last-inserted.txt")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func readLastInserted() -> String? {
        let url = KeptPaths.applicationSupport.appendingPathComponent("last-inserted.txt")
        guard let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty else { return nil }
        return text
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

private struct FieldPartial: Equatable {
    var location: Int
    var text: String
}

private enum PlaceResult {
    case placed(FieldPartial)
    case accessibilityMissing
    case wouldReplaceSelection
    case failed
}

private actor WhisperSerial {
    func transcribe(modelPath: String, wavPath: String) async throws -> String {
        try await Task.detached {
            try WhisperProcess.transcribe(modelPath: modelPath, wavPath: wavPath)
        }.value
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

final class MicRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var pcm = Data()
    private var engine: AVAudioEngine?
    private var destination: URL?
    private var converter: AVAudioConverter?
    private(set) var deviceName = ""

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
        let engine = AVAudioEngine()
        deviceName = InputDevices.apply(uid: MicStore.savedUID(), to: engine)
        let input = engine.inputNode
        let hardware = input.outputFormat(forBus: 0)
        guard hardware.sampleRate > 0, hardware.channelCount > 0 else { throw RecorderError.failed }
        guard let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: hardware, to: target) else {
            throw RecorderError.failed
        }
        lock.lock()
        pcm.removeAll(keepingCapacity: true)
        lock.unlock()
        self.converter = converter
        self.destination = url
        input.installTap(onBus: 0, bufferSize: 4096, format: hardware) { [weak self] buffer, _ in
            self?.append(buffer)
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    func stop() -> Double {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        converter = nil
        let duration = writeKeptFile()
        return duration
    }

    func snapshot() -> (url: URL, bytes: Int)? {
        lock.lock()
        let data = pcm
        let folder = destination?.deletingLastPathComponent()
        lock.unlock()
        guard data.count >= 2, let folder else { return nil }
        let url = folder.appendingPathComponent(".\(UUID().uuidString).partial.wav")
        do {
            try WavPCM.encode(pcm: data).write(to: url)
            return (url, data.count)
        } catch {
            return nil
        }
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let target = converter.outputFormat
        let ratio = target.sampleRate / max(buffer.format.sampleRate, 1)
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var error: NSError?
        let feed = PCMFeed(buffer)
        converter.convert(to: output, error: &error) { _, status in
            guard let buffer = feed.take() else {
                status.pointee = .noDataNow
                return nil
            }
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let samples = output.int16ChannelData else { return }
        let count = Int(output.frameLength) * 2
        guard count > 0 else { return }
        let chunk = Data(bytes: samples[0], count: count)
        lock.lock()
        pcm.append(chunk)
        lock.unlock()
    }

    private func writeKeptFile() -> Double {
        lock.lock()
        let data = pcm
        let url = destination
        lock.unlock()
        guard let url else { return 0 }
        try? WavPCM.encode(pcm: data).write(to: url)
        return WavPCM.durationSeconds(pcmByteCount: data.count)
    }
}

private enum RecorderError: Error {
    case failed
}

private final class PCMFeed: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private let lock = NSLock()
    private var pending = true

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func take() -> AVAudioPCMBuffer? {
        lock.lock()
        defer { lock.unlock() }
        guard pending else { return nil }
        pending = false
        return buffer
    }
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
        process.arguments = WhisperCommand.arguments(
            modelPath: modelPath,
            wavPath: wavPath,
            language: LanguageStore.currentCode()
        )
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
        return WhisperCommand.transcriptText(fileContents: raw)
    }
}

private struct WhisperFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
