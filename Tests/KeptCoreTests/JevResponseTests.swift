import Foundation
import Testing
@testable import KeptCore

@Test func jevCannotReplaceAnInventedSpanEvenAtFullConfidence() throws {
    let answer = Data(#"{"answers":{"shape":{"choice":"prose","confidence":1},"word_0":{"choice":"off","confidence":1}}}"#.utf8)
    let judged = try JevResponse.parse(
        answer, candidates: ["word_0": (entry: "auth", spans: ["auth"])], respell: [:]
    )
    #expect(judged.replacements.isEmpty)
    #expect(SpeechFormat.render("ship auth", shape: judged.shape, replacements: judged.replacements) == "Ship auth.")
}

@Test func jevAcceptsOnlyAConfidentCandidateAndKeepsNoneAsNoChange() throws {
    let answer = Data(#"{"answers":{"shape":{"choice":"list","confidence":0.8},"word_0":{"choice":"post hog","confidence":0.8},"word_1":{"choice":"none","confidence":1},"word_2":{"choice":"code rabbit","confidence":0.6}}}"#.utf8)
    let judged = try JevResponse.parse(answer, candidates: [
        "word_0": (entry: "PostHog", spans: ["post hog"]),
        "word_1": (entry: "Artie", spans: ["RT"]),
        "word_2": (entry: "CodeRabbit", spans: ["code rabbit"]),
    ], respell: [:])
    #expect(judged.shape == .list)
    #expect(judged.replacements == [Replacement(span: "post hog", word: "PostHog")])
}

@Test func malformedJevReplyCannotReplaceTheLocalTake() {
    #expect(throws: JevResponse.Failure.self) {
        _ = try JevResponse.parse(Data(#"{"answers":{}}"#.utf8), candidates: [:], respell: [:])
    }
}
