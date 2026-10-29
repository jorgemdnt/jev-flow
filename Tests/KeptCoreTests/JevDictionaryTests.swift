import Foundation
import Testing
@testable import Kept
@testable import KeptCore

@Test func aHeardTermIsAskedAboutAsAMishearingAndReplacedKeepingThePeriod() async throws {
    nonisolated(unsafe) var asked: [String: Any] = [:]
    let heard = [HeardTerm(span: "Jabflow", term: "JevFlow")]
    let outcome = await JevFormat.prepare(raw: "the new Jabflow. Let's see", dictionary: ["JevFlow"], heard: heard, key: "test-key") { request in
        let body = try #require(request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        asked = try #require(body["questions"] as? [String: Any])
        let answer = #"{"answers":{"layout":{"choice":"plain","confidence":1,"probabilities":{"plain":1,"layout":0}},"word_0":{"choice":"Jabflow","confidence":0.92,"probabilities":{"none":0.04,"Jabflow":0.96}}}}"#
        return (Data(answer.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    let word = try #require(asked["word_0"] as? [String: Any])
    #expect((word["instructions"] as? String)?.contains("mishears") == true)
    #expect((word["criteria"] as? [String: String])?.keys.sorted() == ["Jabflow", "none"])
    #expect(outcome == .model("The new JevFlow. Let's see."))
}

@Test func aSoundAlikeWordTheSpotterDidNotHearIsNeverAsked() async {
    nonisolated(unsafe) var calls = 0
    let outcome = await JevFormat.prepare(raw: "hey can you check that", dictionary: ["Jev", "@juan", "@ethan", "auth"], key: "test-key") { request in
        calls += 1
        return (Data(), HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
    }
    #expect(calls == 0)
    #expect(outcome == .model("Hey can you check that."))
}

@Test func jevTurningDownAHeardTermKeepsTheWordsAsHeard() async {
    let heard = [HeardTerm(span: "posso", term: "PostHog")]
    let outcome = await JevFormat.prepare(raw: "eu posso fazer isso amanhã", dictionary: ["PostHog"], heard: heard, key: "test-key") { request in
        let answer = #"{"answers":{"layout":{"choice":"plain","confidence":1,"probabilities":{"plain":1,"layout":0}},"word_0":{"choice":"none","confidence":0.84,"probabilities":{"none":0.92,"posso":0.08}}}}"#
        return (Data(answer.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    #expect(outcome == .model("Eu posso fazer isso amanhã."))
}
