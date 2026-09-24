import Testing
@testable import KeptCore

private final class PasteFunction {
    private(set) var calls: [String] = []

    func paste(_ text: String) {
        calls.append(text)
    }
}

@Test func sixHundredSecondTwoWordTranscriptCannotReachPaste() {
    let paste = PasteFunction()
    let delivery = InsertPipeline.afterTake(raw: "A agreed", durationSeconds: 600, paste: paste.paste)
    #expect(paste.calls.isEmpty)
    #expect(delivery == .refused(raw: "A agreed", durationSeconds: 600))
}

@Test func allowedTakeReachesPasteWithFormattedText() {
    let paste = PasteFunction()
    let delivery = InsertPipeline.afterTake(raw: "orange, err, yellow", durationSeconds: 2, paste: paste.paste)
    #expect(paste.calls == ["yellow"])
    #expect(delivery == .pasted("yellow"))
}
