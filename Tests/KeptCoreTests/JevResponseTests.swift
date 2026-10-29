import Foundation
import Testing
@testable import KeptCore

@Test func jevCannotReplaceAnInventedSpanEvenAtFullConfidence() throws {
    let answer = Data(#"{"answers":{"layout":{"choice":"plain","confidence":1,"probabilities":{"plain":1,"layout":0}},"word_0":{"choice":"off","confidence":1}}}"#.utf8)
    let judged = try JevResponse.parse(
        answer, candidates: ["word_0": (entry: "auth", spans: ["auth"])], respell: [:]
    )
    #expect(judged.replacements.isEmpty)
    #expect(SpeechFormat.render("ship auth", replacements: judged.replacements) == "Ship auth.")
}

@Test func jevAcceptsOnlyAConfidentCandidateAndKeepsNoneAsNoChange() throws {
    let answer = Data(#"{"answers":{"layout":{"choice":"layout","confidence":0.26,"probabilities":{"plain":0.37,"layout":0.63}},"word_0":{"choice":"post hog","confidence":0.8},"word_1":{"choice":"none","confidence":1},"word_2":{"choice":"code rabbit","confidence":0.6}}}"#.utf8)
    let judged = try JevResponse.parse(answer, candidates: [
        "word_0": (entry: "PostHog", spans: ["post hog"]),
        "word_1": (entry: "Artie", spans: ["RT"]),
        "word_2": (entry: "CodeRabbit", spans: ["code rabbit"]),
    ], respell: [:])
    #expect(judged.layout)
    #expect(judged.replacements == [Replacement(span: "post hog", word: "PostHog")])
}

@Test func malformedJevReplyCannotReplaceTheLocalTake() {
    #expect(throws: JevResponse.Failure.self) {
        _ = try JevResponse.parse(Data(#"{"answers":{}}"#.utf8), candidates: [:], respell: [:])
    }
}

@Test func layoutNeedsTheLargerShareNotTheConfidenceBar() throws {
    let plain = Data(#"{"answers":{"layout":{"choice":"plain","confidence":0.36,"probabilities":{"plain":0.68,"layout":0.32}}}}"#.utf8)
    #expect(try !JevResponse.parse(plain, candidates: [:], respell: [:]).layout)
    let missing = Data(#"{"answers":{"word_0":{"choice":"none","confidence":1}}}"#.utf8)
    #expect(try !JevResponse.parse(missing, candidates: [:], respell: [:]).layout)
}
