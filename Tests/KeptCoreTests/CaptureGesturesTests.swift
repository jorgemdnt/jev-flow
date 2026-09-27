import Foundation
import Testing
@testable import KeptCore

@Test func aHoldPastesOnRelease() {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: false) == .startHold)
    #expect(gestures.optionUp(at: 900) == .finish)
    #expect(gestures.mode == .idle)
}

@Test func twoTapsLockAndAThirdTapStops() {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: false) == .startHold)
    #expect(gestures.optionUp(at: 120) == .none)
    #expect(gestures.tick(at: 200) == .none)
    #expect(gestures.optionDown(at: 300, commandDown: false) == .startLock)
    #expect(gestures.optionUp(at: 400) == .none)
    #expect(gestures.optionDown(at: 2_000, commandDown: false) == .finish)
    #expect(gestures.optionUp(at: 2_100) == .none)
    #expect(gestures.mode == .idle)
}

@Test func aSingleTapDoesNotPaste() {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: false) == .startHold)
    #expect(gestures.optionUp(at: 100) == .none)
    #expect(gestures.tick(at: 100 + CaptureGestures.gap) == .dismissTap)
    #expect(gestures.mode == .idle)
}

@Test func aLatePressAfterATapStartsAHold() {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: false) == .startHold)
    #expect(gestures.optionUp(at: 80) == .none)
    #expect(gestures.optionDown(at: 80 + CaptureGestures.gap + 1, commandDown: false) == .startHoldAfterTap)
}

@Test func rightCommandWithRightOptionEdits() {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: true) == .startEdit)
    #expect(gestures.optionUp(at: 800) == .finishEdit)
    #expect(HoldKeyCommand.rightCommandDown(flags: 0x10))
    #expect(!HoldKeyCommand.rightCommandDown(flags: 0x40))
}

@Test func aSelectionStartsAnEditWithoutCommand() {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: false, selection: true) == .startEdit)
    #expect(gestures.optionUp(at: 800) == .finishEdit)
}

@Test func silenceDoesNotPasteASecondTime() {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: false) == .startHold)
    gestures.endedWithoutKey()
    #expect(gestures.optionUp(at: 2_000) == .none)
}

@Test func editWinsOverDoubleTapAndCommandCanJoinAnActiveHold() {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: false) == .startHold)
    #expect(gestures.switchToEdit() == .switchToEdit)
    #expect(gestures.optionUp(at: 800) == .finishEdit)
    #expect(gestures.switchToEdit() == .none)

    #expect(gestures.optionDown(at: 1_000, commandDown: false) == .startHold)
    #expect(gestures.optionUp(at: 1_100) == .none)
    #expect(gestures.optionDown(at: 1_250, commandDown: true) == .startEdit)
    #expect(gestures.optionUp(at: 1_700) == .finishEdit)
    #expect(gestures.mode == .idle)
}

@Test func selectionCaptureUsesAccessibilityThenClipboardFallback() {
    #expect(EditSelection.capture(accessibility: " selected ", clipboard: "stale") == .init(text: "selected", copied: false))
    #expect(EditSelection.capture(accessibility: nil, clipboard: " copied ") == .init(text: "copied", copied: true))
    #expect(EditSelection.capture(accessibility: "", clipboard: "copied") == .init(text: "copied", copied: true))
    #expect(EditSelection.capture(accessibility: nil, clipboard: nil) == .init(text: "", copied: false))
}

@Test func armedTapCaptureIsDiscardedBeforeEditStarts() {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: false) == .startHold)
    var recording = true
    #expect(gestures.optionUp(at: 90) == .none)
    let effect = gestures.optionDown(at: 190, commandDown: true)
    let transitions = CaptureTransitions.optionDown(effect, priorCaptureActive: recording)
    #expect(transitions == [.dismissTap, .startEdit])
    var phase = "listening"
    for transition in transitions {
        switch transition {
        case .dismissTap:
            recording = false
            phase = "idle"
        case .startEdit:
            #expect(!recording)
            recording = true
            phase = "editing"
        default:
            Issue.record("unexpected transition")
        }
    }
    #expect(recording && phase == "editing")
    #expect(gestures.optionUp(at: 700) == .finishEdit)
    #expect(CaptureTransitions.optionDown(.startEdit, priorCaptureActive: false) == [.startEdit])
}

@Test @MainActor func aPendingSelectionProbeResolvesBeforeTheReleaseIsClassified() async {
    var gestures = CaptureGestures()
    #expect(gestures.optionDown(at: 0, commandDown: false) == .startHold)
    var probeFinished = false
    let pending = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(25))
        #expect(gestures.switchToEdit() == .switchToEdit)
        probeFinished = true
    }
    var effect: CaptureGestures.Effect = .none
    await CaptureTransitions.release(mode: gestures.mode, probe: pending, stillCurrent: { true }) {
        #expect(probeFinished)
        effect = gestures.optionUp(at: 700)
    }
    #expect(effect == .finishEdit)

    var ordinary = CaptureGestures()
    #expect(ordinary.optionDown(at: 0, commandDown: false) == .startHold)
    let empty = Task { @MainActor () -> Void in
        try? await Task.sleep(for: .milliseconds(25))
    }
    await CaptureTransitions.release(mode: ordinary.mode, probe: empty, stillCurrent: { true }) {
        effect = ordinary.optionUp(at: 700)
    }
    #expect(effect == .finish) // Empty probe: ordinary dictation.

    var stale = CaptureGestures()
    #expect(stale.optionDown(at: 0, commandDown: false) == .startHold)
    await CaptureTransitions.release(mode: stale.mode, probe: empty, stillCurrent: { false }) {
        effect = stale.optionUp(at: 700)
    }
    #expect(stale.mode == .holding(downAt: 0))
}

@Test func editSelectionAndResultGatePaste() {
    #expect(EditDecision.decide(selection: "  ", response: "new") == .noSelection)
    #expect(EditDecision.decide(selection: "old", response: nil) == .failed)
    #expect(EditDecision.decide(selection: "old", response: "   ") == .failed)
    #expect(EditDecision.decide(selection: "old", response: " old \n") == .unchanged)
    #expect(EditDecision.decide(selection: "old", response: " new ") == .replace("new"))
    #expect(EditDecision.matchesSelection(" old ", expected: "old"))
    #expect(!EditDecision.matchesSelection("different", expected: "old"))
    #expect(!EditDecision.matchesSelection(nil, expected: "old"))
}

@Test func anEditReplyIsTheOutputText() {
    let body = #"{"output":[{"type":"message","content":[{"type":"output_text","text":"ship it"}]}]}"#
    #expect(EditPrompt.text(from: Data(body.utf8)) == "ship it")
    #expect(EditPrompt.request(text: "RT", instruction: "say Artie").contains("say Artie"))
    let chat = #"{"choices":[{"message":{"content":"ship Artie"}}]}"#
    #expect(EditPrompt.text(from: Data(chat.utf8)) == "ship Artie")
    #expect(EditPrompt.text(from: Data(#"{"choices":[{"message":{"content":""}}]}"#.utf8)) == nil)
}
