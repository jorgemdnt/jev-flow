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
    #expect(paste.calls == ["Yellow."])
    #expect(delivery == .pasted("Yellow."))
    #expect(!paste.calls[0].contains("orange"))
    #expect(!paste.calls[0].contains("or yellow"))
}

@Test func newTakeInsertsASpaceWhenThePreviousInsertionDoesNotEndInWhitespace() {
    let paste = PasteFunction()
    let delivery = InsertPipeline.afterTake(
        raw: "but it doesn't",
        durationSeconds: 3,
        previousInsertion: "works.",
        paste: paste.paste
    )
    #expect(paste.calls == [" But it doesn't."])
    #expect(delivery == .pasted(" But it doesn't."))
}

@Test func newTakeDoesNotAddASpaceWhenThePreviousInsertionAlreadyEndsInWhitespace() {
    let paste = PasteFunction()
    let delivery = InsertPipeline.afterTake(
        raw: "but",
        durationSeconds: 1,
        previousInsertion: "works. ",
        paste: paste.paste
    )
    #expect(paste.calls == ["But."])
    #expect(delivery == .pasted("But."))
}
