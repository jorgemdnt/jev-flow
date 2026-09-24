import Foundation
import Testing
@testable import KeptCore

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
