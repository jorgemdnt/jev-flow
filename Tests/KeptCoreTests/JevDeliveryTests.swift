import Testing
@testable import KeptCore

private enum SimulatedFailure: Error {
    case offline
}

private let longTake = "so for the release we need to update the changelog and bump the version and tag the build"

private func noLayout(_ text: String) async -> LayoutOutcome {
    Issue.record("layout was not expected")
    return .failed
}

@Test func aShortPlainTakeSkipsJevEntirely() async {
    var calls = 0
    let result = await JevDelivery.prepare(raw: "sounds good to me", dictionary: [], key: "saved", judge: { _, _ in
        calls += 1
        return JevJudgment(layout: true, replacements: [], respell: [])
    }, layout: noLayout)
    #expect(calls == 0)
    #expect(result.text == "Sounds good to me.")
    #expect(result.note == nil)
}

@Test func missingKeyUsesLocalFormattingWithoutCallingJev() async {
    var calls = 0
    let result = await JevDelivery.prepare(raw: "list of uh banana pineapple", dictionary: [], key: nil, judge: { _, _ in
        calls += 1
        return JevJudgment(layout: true, replacements: [], respell: [])
    }, layout: noLayout)
    #expect(calls == 0)
    #expect(result.text == "List of banana pineapple.")
    #expect(result.note == "No TypeSafe key. Inserted local text.")
}

@Test func aFailedJevCallInsertsTheLocalFinishedTake() async {
    let result = await JevDelivery.prepare(raw: longTake + " and ship RT", dictionary: ["Artie"], key: "saved", judge: { _, _ in
        throw SimulatedFailure.offline
    }, layout: noLayout)
    #expect(result.text.hasSuffix("ship Artie."))
    #expect(result.note == "Formatting failed. Inserted local text.")
}

@Test func aRejectedKeyStillInsertsTheLocalFinishedTake() async {
    let result = await JevDelivery.prepare(raw: "nao " + longTake, dictionary: [], key: "revoked", judge: { _, _ in
        throw JevFailure.rejectedKey
    }, layout: noLayout)
    #expect(result.text.hasPrefix("Não so"))
    #expect(result.note == "TypeSafe rejected the key. Inserted local text.")
}

@Test func aPlainJudgmentPastesProseWithTheChosenSpanAndNoLayoutCall() async {
    var asked = false
    let heard = [HeardTerm(span: "coat rabbit", term: "CodeRabbit")]
    let result = await JevDelivery.prepare(raw: "buy coat rabbit and milk", dictionary: ["CodeRabbit"], heard: heard, key: "saved", judge: { corrected, key in
        asked = corrected == "buy coat rabbit and milk" && key == "saved"
        return JevJudgment(layout: false, replacements: [Replacement(span: "coat rabbit", word: "CodeRabbit")], respell: [])
    }, layout: noLayout)
    #expect(asked)
    #expect(result.text == "Buy CodeRabbit and milk.")
    #expect(result.note == nil)
}

@Test func aLayoutJudgmentSendsTheCorrectedProseAndPastesTheLayout() async {
    var sent = ""
    let result = await JevDelivery.prepare(raw: "list of uh banana pineapple", dictionary: [], key: "saved", judge: { _, _ in
        JevJudgment(layout: true, replacements: [], respell: [])
    }, layout: { prose in
        sent = prose
        return .laidOut("List of:\n• Banana\n• Pineapple")
    })
    #expect(sent == "List of banana pineapple.")
    #expect(result.text == "List of:\n• Banana\n• Pineapple")
    #expect(result.note == nil)
}

@Test(arguments: [
    (LayoutOutcome.rejected, "Layout changed words. Inserted text without layout."),
    (.failed, "Layout failed. Inserted text without layout."),
    (.noKey, "No OpenCode key. Inserted text without layout."),
])
func aLayoutThatDoesNotLandPastesTheProse(_ outcome: LayoutOutcome, _ note: String) async {
    let result = await JevDelivery.prepare(raw: "list of uh banana pineapple", dictionary: [], key: "saved", judge: { _, _ in
        JevJudgment(layout: true, replacements: [], respell: [])
    }, layout: { _ in outcome })
    #expect(result.text == "List of banana pineapple.")
    #expect(result.note == note)
}
