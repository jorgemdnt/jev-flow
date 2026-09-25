import Testing
@testable import KeptCore

@Test func anOverlappingWindowDoesNotRepeatTheLastWord() {
    let line = LivePhrases(tail: "we need to ship").absorbing("ship Artie now")
    #expect(line.shown == "we need to ship Artie now")
    #expect(!line.shown.contains("shipship"))
    #expect(!line.shown.contains("ship ship"))
}

@Test func aNewWindowIsSeparatedByASpace() {
    let line = LivePhrases(tail: "we need to ship").absorbing("Artie now")
    #expect(line.shown == "we need to ship Artie now")
    #expect(line.committed == "we need to ship")
    #expect(line.tail == "Artie now")
}

@Test func aPartialWordIsReplacedNotGlued() {
    let line = LivePhrases(tail: "we need to shi").absorbing("ship Artie")
    #expect(line.shown == "we need to ship Artie")
}

@Test func threeWindowsStayOnePhrase() {
    let line = LivePhrases()
        .absorbing("we need")
        .absorbing("need to ship")
        .absorbing("ship Artie now")
    #expect(line.shown == "we need to ship Artie now")
}

@Test func aFullRereadReplacesTheLine() {
    let line = LivePhrases(tail: "we need").replacing("we need to ship Artie")
    #expect(line.shown == "we need to ship Artie")
    #expect(!line.shown.contains("we need we need"))
}
