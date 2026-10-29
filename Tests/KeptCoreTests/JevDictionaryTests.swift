import Foundation
import Testing
@testable import Kept
@testable import KeptCore

@Test func aMisheardProductNameIsAskedAboutAsAMishearingAndReplaced() async throws {
    nonisolated(unsafe) var asked: [String: Any] = [:]
    let outcome = await JevFormat.prepare(raw: "the new Jabflow. Let's see", dictionary: ["JevFlow"], key: "test-key") { request in
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

@Test func aSpanCandidateLeavesTheSentencePunctuationOutside() {
    let found = SpeechFormat.candidates(in: "testing JevFlow, then Jabflow.", entries: ["JevFlow"])
    #expect(found["JevFlow"] == ["JevFlow", "Jabflow"])
}
