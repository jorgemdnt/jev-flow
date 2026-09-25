import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import KeptCore

enum LivePhase: Equatable {
    case idle
    case listening
    case locked
    case editing
    case notice
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
    var liveCommitted = ""
    var liveTail = ""
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
    @ObservationIgnored private var partialTask: Task<Void, Never>?
    @ObservationIgnored private var finishTask: Task<Void, Never>?
    @ObservationIgnored private var watchTask: Task<Void, Never>?
    @ObservationIgnored private var holdGeneration = 0
    @ObservationIgnored private var previousFinish: Task<Void, Never>?
    @ObservationIgnored private var gestures = CaptureGestures()
    @ObservationIgnored private var armTask: Task<Void, Never>?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?
    @ObservationIgnored private var editing = false
    @ObservationIgnored private var locked = false
    @ObservationIgnored private var editSelection = ""
    @ObservationIgnored private var lastInsertLocation: Int?
    @ObservationIgnored private var lastInsertLength = 0
    var caretNote = ""
    var editSubject = ""
    var editKind = ""
    var noticeTitle = ""
    var noticeBody = ""

    init(store: TakeStore = TakeStore(directory: KeptPaths.takesDirectory)) {
        self.store = store
        takes = (try? store.load()) ?? []
        lastInsertedText = Self.readLastInserted() ?? takes.compactMap(\.insertedText).first ?? ""
        try? FileManager.default.createDirectory(at: KeptPaths.takesDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: KeptPaths.modelsDirectory, withIntermediateDirectories: true)
        monitor.onDown = { [weak self] commandDown in
            let at = Session.milliseconds()
            Task { @MainActor in self?.optionDown(commandDown, at: at) }
        }
        monitor.onUp = { [weak self] in
            let at = Session.milliseconds()
            Task { @MainActor in self?.optionUp(at: at) }
        }
        monitor.onCancel = { [weak self] in
            Task { @MainActor in self?.cancelHold() }
        }
        monitor.start()
        InputDevices.startWatching { [weak self] in
            Task { @MainActor in
                MicStore.shared.refresh()
                self?.noteRouteChange()
            }
        }
        Task { await ParakeetEngine.shared.warmup() }
        mic.warm()
        caret.onNote = { [weak self] note in
            self?.caretNote = note
        }
        if !monitor.globalInstalled || !Self.accessibilityTrusted(prompt: true) {
            status = "Accessibility permission is required to hear Right Option"
        }
    }

    private static func milliseconds() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }

    private func optionDown(_ commandDown: Bool, at ms: Int) {
        armTask?.cancel()
        let selected = FocusedField.selectedText()?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let effect = gestures.optionDown(at: ms, commandDown: commandDown, selection: selected)
        apply(effect)
    }

    private func optionUp(at ms: Int) {
        let effect = gestures.optionUp(at: ms)
        apply(effect)
        if case .armed = gestures.mode {
            let upAt = ms
            armTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(CaptureGestures.gap))
                await MainActor.run {
                    guard let self else { return }
                    self.apply(self.gestures.tick(at: upAt + CaptureGestures.gap))
                }
            }
        }
    }

    private func apply(_ effect: CaptureGestures.Effect) {
        switch effect {
        case .none:
            break
        case .startHold:
            editing = false
            locked = false
            beginHold()
        case .startHoldAfterTap:
            dismissTap()
            editing = false
            locked = false
            beginHold()
        case .startLock:
            locked = true
            livePhase = .locked
            status = "Tap Right Option to stop"
        case .startEdit:
            guard OpenCodeKey.load() != nil else {
                gestures = CaptureGestures()
                showNotice("No OpenCode key", "Save one in Settings.")
                return
            }
            guard let selected = FocusedField.selectedText()?.trimmingCharacters(in: .whitespacesAndNewlines), !selected.isEmpty else {
                gestures = CaptureGestures()
                showNotice("Select text", "Select the text you want to change first.")
                return
            }
            editSelection = selected
            editSubject = selected
            editKind = "Selection"
            editing = true
            locked = false
            beginHold()
            livePhase = .editing
        case .finish:
            locked = false
            endHold()
        case .dismissTap:
            dismissTap()
        case .finishEdit:
            editing = false
            locked = false
            endEdit()
        }
    }

    private func dismissTap() {
        armTask?.cancel()
        holdGeneration += 1
        watchTask?.cancel()
        watchTask = nil
        held = false
        partialTask?.cancel()
        partialTask = nil
        _ = mic.stop()
        if let wav = activeWav {
            try? FileManager.default.removeItem(at: wav)
        }
        activeWav = nil
        activeID = nil
        recording = false
        arming = false
        locked = false
        editing = false
        clearListening()
    }

    private func showNotice(_ title: String, _ body: String) {
        busy = false
        recording = false
        held = false
        livePhase = .notice
        noticeTitle = title
        noticeBody = body
        liveCommitted = ""
        liveTail = ""
        livePreview = ""
        status = title
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, self.livePhase == .notice else { return }
            self.clearListening()
            self.status = self.idleStatus()
        }
    }

    func beginHold() {
        held = true
        guard !recording else { return }
        holdGeneration += 1
        let generation = holdGeneration
        _ = InputDevices.consumeRouteChange()
        livePhase = editing ? .editing : .listening
        clearLiveText()
        status = editing ? "Say the change" : "Recording…"
        watchTask?.cancel()
        watchTask = Task { await self.watchHold(generation) }
        Task { await startRecordingIfStillHeld(generation) }
    }

    func endHold() {
        if editing {
            editing = false
            endEdit()
            return
        }
        watchTask?.cancel()
        watchTask = nil
        held = false
        Task { await ParakeetEngine.shared.endLive() }
        guard recording, let wav = activeWav, let id = activeID else {
            clearListening()
            return
        }
        let duration = mic.stop()
        recording = false
        activeWav = nil
        activeID = nil
        let streaming = partialTask
        partialTask = nil
        streaming?.cancel()
        guard SpeechAudio.accepts(durationSeconds: duration) else {
            quietDismiss(wav)
            return
        }
        busy = true
        status = "Transcribing…"
        livePhase = .transcribing
        let prior = previousFinish
        finishTask = Task {
            await streaming?.value
            await prior?.value
            await self.finish(id: id, wav: wav, duration: duration, anchor: self.lastInsertedText)
        }
    }

    private func endEdit() {
        watchTask?.cancel()
        watchTask = nil
        held = false
        let selected = editSelection
        guard recording, let wav = activeWav, !selected.isEmpty else {
            showNotice("No instruction", "Say what to change, then release.")
            return
        }
        let duration = mic.stop()
        recording = false
        activeWav = nil
        activeID = nil
        partialTask?.cancel()
        partialTask = nil
        guard SpeechAudio.accepts(durationSeconds: duration) else {
            try? FileManager.default.removeItem(at: wav)
            showNotice("No instruction", "Say what to change, then release.")
            return
        }
        busy = true
        status = "Editing…"
        livePhase = .transcribing
        finishTask = Task {
            let instruction: String
            do {
                instruction = try await self.transcribe(wav)
            } catch {
                try? FileManager.default.removeItem(at: wav)
                self.showNotice("Didn't catch that", "Try the change again.")
                return
            }
            try? FileManager.default.removeItem(at: wav)
            guard let edited = await OpenCodeClient.edit(text: selected, instruction: instruction), !edited.isEmpty else {
                self.showNotice(
                    OpenCodeKey.load() == nil ? "No OpenCode key" : "Edit failed",
                    OpenCodeKey.load() == nil ? "Save one in Settings." : "The model did not return a change."
                )
                return
            }
            await self.replaceEdited(edited, previous: selected)
        }
    }

    private func replaceEdited(_ edited: String, previous: String) async {
        let replacement = edited.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replacement.isEmpty else {
            showNotice("Edit failed", "The model did not return a change.")
            return
        }
        await FocusedAppPaste.focusForeignAppIfNeeded()
        let selected = FocusedField.selectedText()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard selected == previous else {
            showNotice("Selection changed", "Select that text again.")
            return
        }
        switch FocusedAppPaste.paste(replacement) {
        case .pasted:
            lastInsertedText = replacement
            lastInsertLocation = nil
            lastInsertLength = 0
            let url = KeptPaths.applicationSupport.appendingPathComponent("last-inserted.txt")
            try? replacement.write(to: url, atomically: true, encoding: .utf8)
            busy = false
            clearListening()
            status = idleStatus()
        case .accessibilityMissing:
            showNotice("Can't insert", Self.insertNeedsAccessibility)
        case .failed:
            showNotice("Didn't paste", "The edit was not inserted.")
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

    func cancelHold() {
        if livePhase == .notice {
            noticeTask?.cancel()
            clearListening()
            status = idleStatus()
            return
        }
        guard held || recording || arming || livePhase == .listening || livePhase == .locked || livePhase == .editing else { return }
        abandon("Hold cancelled.")
    }

    private func noteRouteChange() {
        guard HoldWatch.shouldAbandon(holding: held || recording || arming || livePhase == .listening || livePhase == .locked || livePhase == .editing, routeChanged: true) else {
            return
        }
        abandon("Microphone changed. Hold again.")
    }

    private func abandon(_ message: String) {
        gestures = CaptureGestures()
        locked = false
        editing = false
        armTask?.cancel()
        holdGeneration += 1
        watchTask?.cancel()
        watchTask = nil
        held = false
        monitor.forceUp()
        Task { await ParakeetEngine.shared.endLive() }
        partialTask?.cancel()
        partialTask = nil
        _ = mic.stop()
        if let wav = activeWav {
            try? FileManager.default.removeItem(at: wav)
        }
        activeWav = nil
        activeID = nil
        recording = false
        arming = false
        clearListening()
        status = message
    }

    private func watchHold(_ generation: Int) async {
        var lastBytes = 0
        var quietSince = ContinuousClock.now
        var silentSince = ContinuousClock.now
        var sawRecording = false
        while !Task.isCancelled, generation == holdGeneration {
            try? await Task.sleep(for: .milliseconds(300))
            guard generation == holdGeneration else { return }
            let now = ContinuousClock.now
            if InputDevices.consumeRouteChange() {
                abandon("Microphone changed. Hold again.")
                return
            }
            guard recording else { continue }
            if !sawRecording {
                sawRecording = true
                lastBytes = mic.byteCount()
                quietSince = now
                silentSince = now
                continue
            }
            let bytes = mic.byteCount()
            if bytes != lastBytes {
                lastBytes = bytes
                quietSince = now
            } else if HoldWatch.tapDied(bytes: bytes, previousBytes: lastBytes, quietFor: now - quietSince) {
                if bytes > 0 {
                    finishFromSilence()
                } else {
                    abandon("Microphone stopped.")
                }
                return
            }
            if !mic.recentlySilent() {
                silentSince = now
            }
            if HoldWatch.insertAfterSilence(silentFor: now - silentSince) {
                finishFromSilence()
                return
            }
        }
    }

    /// Silence ends the take and inserts it. It does not throw the audio away.
    private func finishFromSilence() {
        gestures.endedWithoutKey()
        endHold()
    }

    private func startRecordingIfStillHeld(_ generation: Int) async {
        guard held, generation == holdGeneration, !recording, !arming else {
            if generation == holdGeneration, !held { clearListening() }
            return
        }
        arming = true
        defer { arming = false }
        guard await mic.granted() else {
            status = "Microphone permission is off"
            clearListening()
            return
        }
        guard held, generation == holdGeneration, !recording else {
            if generation == holdGeneration, !held { clearListening() }
            return
        }
        let id = UUID()
        let wav = store.wavURL(id: id)
        do {
            try mic.start(url: wav)
            _ = InputDevices.consumeRouteChange()
            microphoneName = mic.deviceName
            await Task.yield()
            guard held, generation == holdGeneration else {
                _ = mic.stop()
                try? FileManager.default.removeItem(at: wav)
                clearListening()
                return
            }
        } catch {
            if generation == holdGeneration {
                status = "Could not start the microphone"
                clearListening()
            }
            return
        }
        guard held, generation == holdGeneration else {
            _ = mic.stop()
            try? FileManager.default.removeItem(at: wav)
            clearListening()
            return
        }
        activeID = id
        activeWav = wav
        recording = true
        if locked {
            livePhase = .locked
        } else if editing {
            livePhase = .editing
        } else {
            livePhase = .listening
        }
        clearLiveText()
        status = locked ? "Tap Right Option to stop" : (editing ? "Say the change" : "Recording…")
        caret.show()
        previousFinish = finishTask
        partialTask = Task {
            await self.streamPartials(id: id)
        }
    }

    /// The card reads the audio so far. The sliding window does not gate it:
    /// that window was leaving the card on … while the hold stayed up.
    private func streamPartials(id: UUID) async {
        await streamBatchPartials(id: id)
    }

    /// Whisper, and a v3 stream that failed to open. Re-reads the audio so far.
    private func streamBatchPartials(id: UUID) async {
        var sent = 0
        while recording, activeID == id, !Task.isCancelled {
            let pcm = mic.copyPCM()
            let floor = SpeechAudio.minimumSamples * 2
            let needed = sent == 0 ? floor : sent + 8_000
            guard pcm.count >= needed else {
                try? await Task.sleep(for: .milliseconds(40))
                continue
            }
            let snapshot = pcm
            do {
                let raw = try await transcribePCM(snapshot, sampleRate: SpeechAudio.sampleRate)
                guard recording, activeID == id, !Task.isCancelled else { return }
                showLive(LivePhrases().replacing(raw))
                sent = snapshot.count
                await Task.yield()
            } catch {
                guard recording, activeID == id, !Task.isCancelled else { return }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func finish(id: UUID, wav: URL, duration: Double, anchor: String) async {
        defer {
            busy = false
            if !recording {
                caret.hide()
                livePhase = .idle
                clearLiveText()
            }
            if held && monitor.isDown {
                holdGeneration += 1
                let generation = holdGeneration
                watchTask = Task { await self.watchHold(generation) }
                Task { await startRecordingIfStillHeld(generation) }
            } else if !monitor.isDown {
                held = false
            }
        }
        let transcript: String
        do {
            if !recording {
                status = "Transcribing…"
                livePhase = .transcribing
            }
            transcript = try await transcribe(wav)
        } catch {
            if SpeechAudio.isBufferRejection(error) {
                try? FileManager.default.removeItem(at: wav)
                if !recording { status = idleStatus() }
                return
            }
            if !recording {
                status = SpeechAudio.menuStatus(recognizerMessage: error.localizedDescription, idle: idleStatus())
            }
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
            anchor: anchor,
            prepared: outcome.text,
            cleanupNote: outcome.note
        )
        if !recording { status = message }
    }

    private func transcribe(_ wav: URL) async throws -> String {
        let data = try Data(contentsOf: wav)
        guard let decoded = WavPCM.decode(data) else { throw SpeechGate.tooShort }
        return try await transcribeSamples(decoded.samples, sampleRate: decoded.sampleRate)
    }

    private func transcribePCM(_ pcm: Data, sampleRate: Double) async throws -> String {
        try await transcribeSamples(WavPCM.floatSamples(pcm), sampleRate: sampleRate)
    }

    /// Resamples to 16 kHz and refuses a clip under 300 ms before either recognizer.
    private func transcribeSamples(_ samples: [Float], sampleRate: Double) async throws -> String {
        guard let prepared = SpeechAudio.prepare(samples: samples, sampleRate: sampleRate) else {
            throw SpeechGate.tooShort
        }
        let code = LanguageStore.currentCode()
        if SpeechRoute.engine(for: code) == .parakeetV3 {
            return try await ParakeetEngine.shared.transcribe(samples: prepared, languageCode: code)
        }
        let model = try await ModelStore.prepare { message in
            if !self.recording {
                self.status = message
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try WavPCM.encode(pcm: SpeechAudio.int16Data(prepared)).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try await whisper.transcribe(modelPath: model.path, wavPath: url.path)
    }

    private func deliver(
        id: UUID,
        raw: String,
        duration: Double,
        anchor: String,
        prepared: String,
        cleanupNote: String?
    ) -> String {
        let decision = InsertDecision(transcript: raw, durationSeconds: duration)
        guard decision.autoInsert else {
            return Self.keptNotPasted
        }
        let field = FocusedField.joinEdge()
        let text = TakeJoin.submission(previous: anchor, next: prepared, field: field)
        guard !text.isEmpty else {
            return idleStatus()
        }
        let idle = (cleanupNote?.isEmpty == false) ? cleanupNote! : idleStatus()
        switch place(text, typeSeparator: TakeJoin.needsSeparator(previous: anchor, next: prepared, field: field)) {
        case .placed(let placed):
            recordInserted(id: id, text: placed)
            return idle
        case .accessibilityMissing:
            return Self.insertNeedsAccessibility
        case .wouldReplaceSelection:
            return "Could not insert without replacing a selection. Text kept."
        case .failed:
            return "Could not insert. Text kept."
        }
    }

    private func place(_ text: String, typeSeparator: Bool = false) -> PlaceResult {
        let body = Self.pasteBody(text)
        switch FocusedField.caretForInsert() {
        case .selectionCouldNotCollapse:
            return .wouldReplaceSelection
        case .location(let at):
            let start = typeSeparator ? at + 1 : at
            if typeSeparator { _ = FocusedAppPaste.typeSpace() }
            switch FocusedAppPaste.paste(body) {
            case .pasted:
                Self.scheduleTrailingSpace(for: text)
                lastInsertLocation = start
                lastInsertLength = text.count
                return .placed(text)
            case .accessibilityMissing:
                return .accessibilityMissing
            case .failed:
                return .failed
            }
        case .unavailable:
            if let selected = FocusedField.selectedText()?.trimmingCharacters(in: .whitespacesAndNewlines), !selected.isEmpty {
                return .wouldReplaceSelection
            }
            if typeSeparator { _ = FocusedAppPaste.typeSpace() }
            switch FocusedAppPaste.paste(body) {
            case .pasted:
                Self.scheduleTrailingSpace(for: text)
                lastInsertLocation = nil
                return .placed(text)
            case .accessibilityMissing:
                return .accessibilityMissing
            case .failed:
                return .failed
            }
        }
    }

    /// The field trims a trailing space out of a paste. Type it after the paste lands.
    private static func pasteBody(_ text: String) -> String {
        text.hasSuffix(" ") ? String(text.dropLast()) : text
    }

    private static func scheduleTrailingSpace(for text: String) {
        guard text.hasSuffix(" ") else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            _ = FocusedAppPaste.typeSpace()
        }
    }

    private func showLive(_ phrases: LivePhrases) {
        let formatted = Formatter.streaming(phrases.shown)
        guard !formatted.isEmpty else { return }
        let split = phrases.split(formatted: formatted)
        liveCommitted = split.committed
        liveTail = split.tail
        livePreview = [split.committed, split.tail].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func clearLiveText() {
        livePreview = ""
        liveCommitted = ""
        liveTail = ""
    }

    private func clearListening() {
        guard !recording else { return }
        caret.hide()
        livePhase = .idle
        noticeTitle = ""
        noticeBody = ""
        editSubject = ""
        editKind = ""
        clearLiveText()
        if status == "Recording…" { status = idleStatus() }
    }

    private func quietDismiss(_ wav: URL) {
        try? FileManager.default.removeItem(at: wav)
        if !recording {
            caret.hide()
            livePhase = .idle
            clearLiveText()
        }
        busy = false
        if !recording { status = idleStatus() }
    }

    private func idleStatus() -> String {
        if !monitor.globalInstalled || !Self.accessibilityTrusted(prompt: false) {
            return "Accessibility permission is required to hear Right Option"
        }
        return "Hold Right Option to talk"
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
        let field = FocusedField.joinEdge()
        let inserting = TakeJoin.submission(previous: lastInsertedText, next: text, field: field)
        guard !inserting.isEmpty else {
            status = "Could not insert. Text kept."
            return
        }
        let payload = inserting
        if TakeJoin.needsSeparator(previous: lastInsertedText, next: text, field: field) {
            _ = FocusedAppPaste.typeSpace()
        }
        switch FocusedAppPaste.paste(payload) {
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

private enum PlaceResult {
    case placed(String)
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

    var onDown: (Bool) -> Void = { _ in }
    var onUp: () -> Void = {}
    var onCancel: () -> Void = {}
    private(set) var globalInstalled = false
    private(set) var isDown = false
    private var global: Any?
    private var local: Any?
    private var keyGlobal: Any?
    private var keyLocal: Any?
    private var timer: Timer?
    private var down = false
    private var sawDeviceBit = false

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
        let keys: NSEvent.EventTypeMask = [.keyDown, .keyUp]
        keyGlobal = NSEvent.addGlobalMonitorForEvents(matching: keys) { [weak self] event in
            self?.handle(event)
        }
        keyLocal = NSEvent.addLocalMonitorForEvents(matching: keys) { [weak self] event in
            self?.handle(event)
            return event
        }
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// keyCode 0x3D is Right Option. A key-up ends the hold even when flagsChanged never arrives.
    private func handle(_ event: NSEvent) {
        if event.keyCode == Self.keyCode {
            if event.type == .keyUp {
                finish()
                return
            }
            if event.type == .keyDown {
                begin(commandDown: HoldKeyCommand.rightCommandDown(flags: UInt64(event.modifierFlags.rawValue)))
                return
            }
        }
        if event.type == .keyDown, event.keyCode == HoldWatch.escapeKey {
            forceUp()
            onCancel()
            return
        }
        guard event.type == .flagsChanged else { return }
        let flags = UInt64(event.modifierFlags.rawValue)
        guard let edge = HoldKey.event(wasDown: down, keyCode: event.keyCode, flags: flags) else { return }
        if edge == .down {
            begin(commandDown: HoldKeyCommand.rightCommandDown(flags: flags))
        } else {
            finish()
        }
    }

    /// Ends the hold once flags state has shown the device bit and then lost it.
    /// A reading that never had the bit is ignored. Key state is not read.
    private func poll() {
        let flags = UInt64(CGEventSource.flagsState(.hidSystemState).rawValue)
        let decision = HoldKey.flagsRelease(wasDown: down, sawDeviceBit: sawDeviceBit, flags: flags)
        sawDeviceBit = decision.sawDeviceBit
        if decision.edge == .up {
            finish()
        }
    }

    private func begin(commandDown: Bool) {
        guard !down else { return }
        down = true
        isDown = true
        onDown(commandDown)
    }

    func forceUp() {
        down = false
        isDown = false
        sawDeviceBit = false
    }

    private func finish() {
        guard down else { return }
        down = false
        isDown = false
        sawDeviceBit = false
        onUp()
    }
}

final class MicRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var pcm = Data()
    private var engine: AVAudioEngine?
    private var appliedUID: String?
    private var tapInstalled = false
    private var destination: URL?
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

    func warm() {
        _ = try? prepare(uid: MicStore.savedUID())
        _ = engine?.inputNode
    }

    func start(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let uid = MicStore.savedUID()
        let engine = try prepare(uid: uid)
        let input = engine.inputNode
        if tapInstalled {
            input.removeTap(onBus: 0)
            tapInstalled = false
        }
        let hardware = input.outputFormat(forBus: 0)
        guard hardware.sampleRate > 0, hardware.channelCount > 0 else { throw RecorderError.failed }
        lock.lock()
        pcm.removeAll(keepingCapacity: true)
        lock.unlock()
        self.destination = url
        input.installTap(onBus: 0, bufferSize: 4096, format: hardware) { [weak self] buffer, _ in
            self?.append(buffer)
        }
        tapInstalled = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            engine.stop()
            self.engine = nil
            appliedUID = nil
            throw error
        }
        self.engine = engine
    }

    /// One engine for every hold. A new engine opens the speaker, then the mic.
    private func prepare(uid: String) throws -> AVAudioEngine {
        if let engine, appliedUID == uid {
            if engine.isRunning { engine.stop() }
            return engine
        }
        if let engine {
            if tapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            engine.stop()
        }
        let engine = AVAudioEngine()
        deviceName = InputDevices.apply(uid: uid, to: engine)
        appliedUID = uid
        self.engine = engine
        return engine
    }

    func stop() -> Double {
        if tapInstalled {
            engine?.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine?.stop()
        return writeKeptFile()
    }

    func byteCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return pcm.count
    }

    /// True when the latest slice has no speech. A live tap of silence is not a dead tap.
    func recentlySilent() -> Bool {
        lock.lock()
        let data = pcm
        lock.unlock()
        guard data.count >= 2 else { return true }
        let start = data.count - min(data.count, 6_400)
        let aligned = start - (start % 2)
        var peak = 0
        data.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for sample in samples[(aligned / 2)...] {
                peak = max(peak, abs(Int(sample)))
            }
        }
        return peak < 300
    }

    func copyPCM() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return pcm
    }

    private func append(_ buffer: AVAudioPCMBuffer) {
        let chunk = Self.sixteenKilohertzInt16(buffer)
        guard !chunk.isEmpty else { return }
        lock.lock()
        pcm.append(chunk)
        lock.unlock()
    }

    /// Each buffer is converted from its own samples. A reused converter drops audio.
    private static func sixteenKilohertzInt16(_ buffer: AVAudioPCMBuffer) -> Data {
        guard buffer.format.sampleRate > 0, let mono = monoFloat(buffer), !mono.isEmpty else { return Data() }
        return SpeechAudio.int16Data(SpeechAudio.resample(mono, from: buffer.format.sampleRate))
    }

    private static func monoFloat(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return nil }
        let channels = Int(buffer.format.channelCount)
        guard channels > 0 else { return nil }
        if let data = buffer.floatChannelData {
            if channels == 1 {
                return Array(UnsafeBufferPointer(start: data[0], count: frames))
            }
            var mono = [Float](repeating: 0, count: frames)
            for frame in 0..<frames {
                var sum: Float = 0
                for channel in 0..<channels {
                    sum += data[channel][frame]
                }
                mono[frame] = sum / Float(channels)
            }
            return mono
        }
        guard let data = buffer.int16ChannelData else { return nil }
        let stride = buffer.format.isInterleaved ? channels : 1
        var mono = [Float](repeating: 0, count: frames)
        for frame in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels {
                let sample = buffer.format.isInterleaved ? data[0][frame * stride + channel] : data[channel][frame]
                sum += Float(sample) / 32768
            }
            mono[frame] = sum / Float(channels)
        }
        return mono
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
