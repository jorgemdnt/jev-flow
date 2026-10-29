import Foundation
import Testing
@testable import KeptCore

@Test func aListCueStaysProseUntilJevAsksForLayout() {
    let text = SpeechFormat.render("I made a list of the things we discussed", replacements: [])
    #expect(text == "I made a list of the things we discussed.")
    #expect(!text.contains("•"))
}

@Test func aCountStaysProse() {
    let text = SpeechFormat.render("Alright so testing 1, 2, 3 please", replacements: [])
    #expect(text == "Alright so testing 1, 2, 3 please.")
}

@Test func aUniqueNamePastesTheHandle() {
    let people = ["@felipe.menezes", "@pedro.vivaldi", "@pedro.muller", "@gabriel.costa", "@gabriel.leal"]
    let text = SpeechFormat.render("ask Felipe and at Pedro Vivaldi and Pedro and Müller", replacements: [], dictionary: people)
    #expect(text.contains("@felipe.menezes"))
    #expect(text.contains("@pedro.vivaldi"))
    #expect(text.contains("@pedro.muller"))
    #expect(!text.contains("@pedro "))
    #expect(text.contains("Pedro"))
}

@Test func aHandleWhoseNameIsTheWholeHandleGetsOneAt() {
    let people = ["@felipe.menezes", "@joseph", "@pedro.vivaldi"]
    let text = SpeechFormat.render("I'm pretty sure Joseph was complaining, and Joseph agreed", replacements: [], dictionary: people)
    #expect(text.contains("sure @joseph was"))
    #expect(text.contains("and @joseph agreed"))
    #expect(!text.contains("@@"))
}

@Test func aWrittenHandleIsLeftAlone() {
    let text = SpeechFormat.render("ping @felipe.menezes about it", replacements: [], dictionary: ["@felipe.menezes"])
    #expect(text.contains("@felipe.menezes about"))
    #expect(!text.contains("@@"))
}

@Test func rtIsArtieWhenArtieIsInTheDictionary() {
    let text = SpeechFormat.render("We need to ship RT.", replacements: [], dictionary: ["Artie"])
    #expect(text == "We need to ship Artie.")
    #expect(!text.hasPrefix(" "))
    #expect(text.hasSuffix("."))
}

@Test func aThenChainAndRejectionStayProseWithAllWords() {
    let text = SpeechFormat.render("can we not ship this, that, then review it", replacements: [])
    #expect(text == "Can we not ship this, that, then review it.")
    #expect(!text.contains("•"))
}

@Test func aSpokenRejectionKeepsBothTheRejectedAndReplacementOptions() {
    let text = SpeechFormat.render("not blue, green", replacements: [])
    #expect(text == "Not blue, green.")
}

@Test func aProductTermKeepsItsSpelling() {
    let text = SpeechFormat.render("ship the post hog change and the code rabbit review", replacements: [], dictionary: ["PostHog", "CodeRabbit"])
    #expect(text.contains("PostHog"))
    #expect(text.contains("CodeRabbit"))
}

@Test func replacementSwapsOnlyTheChosenSpan() {
    let text = SpeechFormat.render(
        "ship the post hog auth change",
        replacements: [Replacement(span: "post hog", word: "PostHog")]
    )
    #expect(text.contains("PostHog"))
    #expect(text.contains("auth"))
    #expect(!text.contains("off"))
}

@Test func replacementDoesNotEatALongerWord() {
    let text = SpeechFormat.render(
        "ask the author",
        replacements: [Replacement(span: "auth", word: "Auth")]
    )
    #expect(text.contains("author"))
    #expect(!text.contains("Author"))
}

@Test func candidatesFindAMishearingAndSkipADifferentWord() {
    let found = SpeechFormat.candidates(in: "ship the post hog change", entries: ["PostHog", "auth"])
    #expect(found["PostHog"]?.contains("post hog") == true)
    #expect(found["auth"] == nil)
}
