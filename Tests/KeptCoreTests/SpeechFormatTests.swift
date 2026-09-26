import Foundation
import Testing
@testable import KeptCore

@Test func aListCueDoesNotBulletTheCountBeforeIt() {
    let heard = "Alright so testing 1, 2, 3 Let's make a list of uh banana pineapple"
    let text = SpeechFormat.render(heard, shape: .list, replacements: [])
    #expect(text == """
    Alright so testing 1, 2, 3 Let's make a list of
    • Banana
    • Pineapple
    """)
    #expect(!text.contains("uh"))
    #expect(!text.contains("• 2"))
    #expect(text.contains("Alright"))
}

@Test func theSameListIsFormattedWithoutJev() {
    let text = SpeechFormat.render(
        "Okay so testing one two three let's make a list of uh banana pineapple",
        shape: .prose,
        replacements: []
    )
    #expect(text.contains("Okay"))
    #expect(text.contains("one two three"))
    #expect(text.contains("• Banana"))
    #expect(text.contains("• Pineapple"))
    #expect(!text.contains("uh"))
}

@Test func aCountIsNotAList() {
    let text = SpeechFormat.render("Alright so testing 1, 2, 3 please", shape: .list, replacements: [])
    #expect(!text.contains("•"))
    #expect(text.contains("1, 2, 3"))
}

@Test func aUniqueNamePastesTheHandle() {
    let people = ["@felipe.menezes", "@pedro.vivaldi", "@pedro.muller", "@gabriel.costa", "@gabriel.leal"]
    let text = SpeechFormat.render("ask Felipe and at Pedro Vivaldi and Pedro and Müller", shape: .prose, replacements: [], dictionary: people)
    #expect(text.contains("@felipe.menezes"))
    #expect(text.contains("@pedro.vivaldi"))
    #expect(text.contains("@pedro.muller"))
    #expect(!text.contains("@pedro "))
    #expect(text.contains("Pedro"))
}

@Test func aHandleWhoseNameIsTheWholeHandleGetsOneAt() {
    let people = ["@felipe.menezes", "@joseph", "@pedro.vivaldi"]
    let text = SpeechFormat.render("I'm pretty sure Joseph was complaining, and Joseph agreed", shape: .prose, replacements: [], dictionary: people)
    #expect(text.contains("sure @joseph was"))
    #expect(text.contains("and @joseph agreed"))
    #expect(!text.contains("@@"))
}

@Test func aWrittenHandleIsLeftAlone() {
    let text = SpeechFormat.render("ping @felipe.menezes about it", shape: .prose, replacements: [], dictionary: ["@felipe.menezes"])
    #expect(text.contains("@felipe.menezes about"))
    #expect(!text.contains("@@"))
}

@Test func rtIsArtieWhenArtieIsInTheDictionary() {
    let text = SpeechFormat.render("We need to ship RT.", shape: .prose, replacements: [], dictionary: ["Artie"])
    #expect(text == "We need to ship Artie.")
    #expect(!text.hasPrefix(" "))
    #expect(text.hasSuffix("."))
}

@Test func aProductTermKeepsItsSpelling() {
    let text = SpeechFormat.render("ship the post hog change and the code rabbit review", shape: .prose, replacements: [], dictionary: ["PostHog", "CodeRabbit"])
    #expect(text.contains("PostHog"))
    #expect(text.contains("CodeRabbit"))
}

@Test func listShapeKeepsEveryWord() {
    let text = SpeechFormat.render(
        "buy milk and eggs and I would never not want bread",
        shape: .list,
        replacements: []
    )
    #expect(text.contains("• Buy milk"))
    #expect(text.contains("never"))
    #expect(text.contains("not"))
    #expect(text.contains("bread"))
}

@Test func numberedShapeIsNotTurnedIntoBullets() {
    let text = SpeechFormat.render("5. alpha and 6. beta", shape: .numbered, replacements: [])
    #expect(!text.contains("•"))
    #expect(text.contains("5."))
    #expect(text.contains("6."))
}

@Test func replacementSwapsOnlyTheChosenSpan() {
    let text = SpeechFormat.render(
        "ship the post hog auth change",
        shape: .prose,
        replacements: [Replacement(span: "post hog", word: "PostHog")]
    )
    #expect(text.contains("PostHog"))
    #expect(text.contains("auth"))
    #expect(!text.contains("off"))
}

@Test func replacementDoesNotEatALongerWord() {
    let text = SpeechFormat.render(
        "ask the author",
        shape: .prose,
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
