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

@Test func anEditReplyIsTheOutputText() {
    let body = #"{"output":[{"type":"message","content":[{"type":"output_text","text":"ship it"}]}]}"#
    #expect(EditPrompt.text(from: Data(body.utf8)) == "ship it")
    #expect(EditPrompt.request(text: "RT", instruction: "say Artie").contains("say Artie"))
    let chat = #"{"choices":[{"message":{"content":"ship Artie"}}]}"#
    #expect(EditPrompt.text(from: Data(chat.utf8)) == "ship Artie")
    #expect(EditPrompt.text(from: Data(#"{"choices":[{"message":{"content":""}}]}"#.utf8)) == nil)
}
