import Testing
@testable import KeptCore

@Test func formatterAcceptsATranscript() {
    let formatted = Formatter.format("")
    #expect(formatted.isEmpty)
}

@Test func numberedListKeepsSpokenStart() {
    let formatted = Formatter.format("5. alpha\n6. beta")
    #expect(formatted.contains("5. alpha"))
    #expect(formatted.contains("6. beta"))
    #expect(!formatted.contains("1. alpha"))
}

@Test func formatterDoesNotRewriteAuthToOff() {
    let formatted = Formatter.format("auth")
    #expect(formatted.contains("auth"))
    #expect(formatted != "off")
}

@Test func spokenSelfCorrectionReplacesThePreviousWord() {
    let formatted = Formatter.format("I want the color to be orange, err, yellow")
    #expect(formatted == "I want the color to be yellow")
    #expect(!formatted.contains("or yellow"))
}

@Test func spokenErIsAlsoACorrectionMark() {
    let formatted = Formatter.format("I want the color to be orange, er, yellow")
    #expect(formatted == "I want the color to be yellow")
    #expect(!formatted.contains("or yellow"))
}

@Test(arguments: ["never", "not", "haven't", "hadn't", "before"])
func formatterKeepsGuardWord(_ word: String) {
    let formatted = Formatter.format("I'd prefer to \(word) merge this")
    #expect(formatted.contains(word))
}

@Test func formatterKeepsLike() {
    let formatted = Formatter.format("I like this approach")
    #expect(formatted.contains("like"))
}

@Test func formatterKeepsPissing() {
    let formatted = Formatter.format("this is pissing me off")
    #expect(formatted.contains("pissing"))
}

@Test func errDropsAGuardWordOnlyWhenThatWordWasCorrected() {
    let formatted = Formatter.format("I'd prefer to never, err, always merge this")
    #expect(formatted == "I'd prefer to always merge this")
    #expect(!formatted.contains("never"))
}

@Test func correctionDoesNotRenumberAList() {
    let formatted = Formatter.format("5. alpha, err, beta\n6. gamma")
    #expect(formatted.contains("5. beta"))
    #expect(formatted.contains("6. gamma"))
    #expect(!formatted.contains("1. alpha"))
}

@Test func correctionMarkMustBeItsOwnToken() {
    #expect(Formatter.format("an error") == "an error")
    #expect(Formatter.format("ask her") == "ask her")
    #expect(Formatter.format("orange or yellow") == "orange or yellow")
}

@Test func finishedTakeCapitalizesAndEndsWithAPeriod() {
    #expect(Formatter.finished("okay, it seems like it works") == "Okay, it seems like it works.")
}

@Test func finishedTakeKeepsTerminalPunctuation() {
    #expect(Formatter.finished("Okay, it seems like it works.") == "Okay, it seems like it works.")
    #expect(Formatter.finished("does it work?") == "Does it work?")
}

@Test func finishedTakeDoesNotRenumberOrDropGuardWords() {
    let text = Formatter.finished("5. alpha\n6. beta I'd prefer to never not haven't hadn't before like auth")
    #expect(text.contains("5. alpha"))
    #expect(text.contains("6. beta"))
    #expect(!text.contains("1. alpha"))
    #expect(text.contains("never"))
    #expect(text.contains("not"))
    #expect(text.contains("haven't"))
    #expect(text.contains("hadn't"))
    #expect(text.contains("before"))
    #expect(text.contains("like"))
    #expect(text.contains("auth"))
    #expect(text != "off")
}

@Test func finishedTakeDoesNotTurnErrIntoOr() {
    let text = Formatter.finished("I want the color to be orange, err, yellow")
    #expect(text == "I want the color to be yellow.")
    #expect(!text.contains("or yellow"))
}

@Test func streamingPartialDoesNotForceAPeriod() {
    #expect(Formatter.streaming("it puts the phrases together") == "It puts the phrases together")
}
