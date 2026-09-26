import Testing
@testable import KeptCore

@Test func aSoundAlikeOffersBothReadingsOfItsSentence() {
    let found = Respell.candidates(in: "Hey, can you review my PR? We need to shoot RT.")
    #expect(found.count == 1)
    #expect(found[0].index == 9)
    #expect(found[0].asHeard == "We need to shoot RT.")
    #expect(found[0].asMeant == "We need to ship RT.")
}

@Test func applySwapsOnlyTheChosenWord() {
    let text = "Shift the release, then shift my meeting."
    let found = Respell.candidates(in: text)
    #expect(found.count == 2)
    #expect(Respell.apply([found[0]], to: text) == "Ship the release, then shift my meeting.")
}

@Test func swapKeepsPunctuationAndCapital() {
    #expect(Respell.swap("Shoot,", to: "ship") == "Ship,")
    #expect(Respell.swap("shifted.", to: "shipped") == "shipped.")
}

@Test func aTakeWithNoSoundAlikeAsksNothing() {
    #expect(Respell.candidates(in: "We need to ship Artie today.").isEmpty)
}
