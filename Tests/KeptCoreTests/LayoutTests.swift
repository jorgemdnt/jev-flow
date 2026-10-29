import Foundation
import Testing
@testable import KeptCore

@Test func aListKeepsItsLeadInAndEveryItem() {
    let source = "Okay so testing one two three let's make a list of banana pineapple."
    let laid = "Okay, so testing one two three. Let's make a list of:\n- banana\n- pineapple"
    #expect(Layout.accept(source: source, laidOut: laid) == "Okay, so testing one two three. Let's make a list of:\n• banana\n• pineapple")
}

@Test func spokenItemNumbersBecomeListNumbersAndJoinersCanGo() {
    let source = "For the release we need to first update the changelog second bump the version third tag the build and then announce it in slack."
    let laid = """
    For the release we need to:
    1. Update the changelog
    2. Bump the version
    3. Tag the build
    4. Announce it in Slack
    """
    #expect(Layout.accept(source: source, laidOut: laid) == laid)
}

@Test func layoutCommandsCanGoOnlyWhereALineBreaks() {
    let source = "Bullet point update the docs bullet point ping @felipe.menezes bullet point merge the PR."
    let laid = "• Update the docs\n• Ping @felipe.menezes\n• Merge the PR."
    #expect(Layout.accept(source: source, laidOut: laid) == laid)
    #expect(Layout.accept(source: "We shipped the new line of products.", laidOut: "We shipped the of products.") == nil)
}

@Test func aNewParagraphCommandBecomesABlankLine() {
    let source = "Hey Walid, thanks for the update. New paragraph. I looked at the numbers."
    let laid = "Hey Walid, thanks for the update.\n\n\n\nI looked at the numbers."
    #expect(Layout.accept(source: source, laidOut: laid) == "Hey Walid, thanks for the update.\n\nI looked at the numbers.")
}

@Test func spokenListNumbersAreKept() {
    let source = "5. alpha and 6. beta."
    #expect(Layout.accept(source: source, laidOut: "5. Alpha\n6. Beta") == "5. Alpha\n6. Beta")
    #expect(Layout.accept(source: source, laidOut: "1. Alpha\n2. Beta") == nil)
}

@Test(arguments: [
    ("I would never not want bread and milk.", "• I would want bread\n• Milk"),
    ("Ship the auth change and the docs.", "• Ship the off change\n• The docs"),
    ("I need two apples and pears.", "I need apples:\n• Pears"),
    ("Buy milk or eggs.", "• Buy milk\n• Eggs"),
    ("Buy milk and eggs.", "Here is the list:\n• Buy milk\n• Eggs"),
    ("Buy milk and eggs.", "• Buy eggs\n• Milk"),
])
func aLayoutThatChangesWordsIsRejected(_ source: String, _ laid: String) {
    #expect(Layout.accept(source: source, laidOut: laid) == nil)
}

@Test func punctuationCaseAndHyphensAreLayout() {
    let source = "todo follow up with Gabriel's team re the q3 plan"
    let laid = "To-do:\n• Follow-up with Gabriel’s team re: the Q3 plan"
    #expect(Layout.accept(source: source, laidOut: laid) != nil)
}

@Test func shortPlainTakesDoNotAskAboutLayout() {
    #expect(!Layout.mightNeed("Sounds good to me."))
    #expect(Layout.mightNeed("list of banana pineapple"))
    #expect(Layout.mightNeed("first milk second eggs"))
    #expect(Layout.mightNeed("so for the release we need to update the changelog and bump the version"))
}

@Test func theLayoutCallSendsTheProseAndChecksTheAnswer() async {
    let answer = #"{"choices":[{"finish_reason":"stop","message":{"content":"List of:\n- Banana\n- Pineapple"}}]}"#
    let outcome = await Layout.run(
        text: "List of banana pineapple.", key: "k", endpoint: URL(string: "https://example.invalid")!,
        model: "m", userAgent: "u", timeout: 5
    ) { request in
        let body = try #require(request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.last?["content"]?.contains("List of banana pineapple.") == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer k")
        return (Data(answer.utf8), 200)
    }
    #expect(outcome == .laidOut("List of:\n• Banana\n• Pineapple"))
}

@Test func aLayoutCallThatChangesAWordOrFailsNeverReturnsText() async {
    let changed = #"{"choices":[{"finish_reason":"stop","message":{"content":"• Banana\n• Apple"}}]}"#
    let rejected = await Layout.run(text: "List of banana pineapple.", key: "k", endpoint: URL(string: "https://example.invalid")!, model: "m", userAgent: "u", timeout: 5) { _ in
        (Data(changed.utf8), 200)
    }
    #expect(rejected == .rejected)
    let unauthorized = await Layout.run(text: "x", key: "k", endpoint: URL(string: "https://example.invalid")!, model: "m", userAgent: "u", timeout: 5) { _ in
        (Data(), 401)
    }
    #expect(unauthorized == .failed)
    let noKey = await Layout.run(text: "x", key: nil, endpoint: URL(string: "https://example.invalid")!, model: "m", userAgent: "u", timeout: 5) { _ in
        Issue.record("no request without a key")
        return (Data(), 200)
    }
    #expect(noKey == .noKey)
}
