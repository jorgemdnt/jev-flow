import Foundation
import Testing
@testable import KeptCore

@Test func peopleAreNotSpotterTerms() {
    #expect(HeardTerm.spotterTerms(["@juan", " JevFlow ", "", "PostHog", "@felipe.menezes"]) == ["JevFlow", "PostHog"])
}

@Test func onlyMisheardSpansInTheTextAreAskedGroupedByTerm() {
    let heard = [
        HeardTerm(span: "Jabflow", term: "JevFlow"),
        HeardTerm(span: "jabflow", term: "JevFlow"),
        HeardTerm(span: "Jeff O", term: "JevFlow"),
        HeardTerm(span: "post hog", term: "PostHog"),
        HeardTerm(span: "Wally", term: "@walid"),
        HeardTerm(span: "astro", term: "Astra"),
    ]
    let asked = HeardTerm.questions(heard, in: "Jabflow and Jeff O, then post hog.")
    #expect(asked == ["JevFlow": ["Jabflow", "Jeff O"]])
}

@Test func aTakeWithoutHeardTermsDecodesAndHeardTermsRoundTrip() throws {
    let old = Data(#"[{"id":"7F1B0E2A-0000-4000-8000-000000000001","wavPath":"/x.wav","rawTranscript":"hi","durationSeconds":1}]"#.utf8)
    let takes = try JSONDecoder().decode([Take].self, from: old)
    #expect(takes.first?.heardTerms == nil)
    var take = try #require(takes.first)
    take.heardTerms = [HeardTerm(span: "Jabflow", term: "JevFlow")]
    let again = try JSONDecoder().decode(Take.self, from: JSONEncoder().encode(take))
    #expect(again.heardTerms == take.heardTerms)
}
