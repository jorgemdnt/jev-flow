import Testing
@testable import KeptCore

private enum SimulatedFailure: Error {
    case offline
}

@Test func missingKeyUsesLocalFormattingWithoutCallingJev() async {
    var calls = 0
    let result = await JevDelivery.prepare(raw: "list of uh banana pineapple", dictionary: [], key: nil) { _, _ in
        calls += 1
        return JevJudgment(shape: .list, replacements: [], respell: [])
    }
    #expect(calls == 0)
    #expect(result.text == "List of\n• Banana\n• Pineapple")
    #expect(result.note == "No TypeSafe key. Inserted local text.")
}

@Test func aFailedJevCallInsertsTheLocalFinishedTake() async {
    let result = await JevDelivery.prepare(raw: "ship RT", dictionary: ["Artie"], key: "saved") { _, _ in
        throw SimulatedFailure.offline
    }
    #expect(result.text == "Ship Artie.")
    #expect(result.note == "Formatting failed. Inserted local text.")
}

@Test func aRejectedKeyStillInsertsTheLocalFinishedTake() async {
    let result = await JevDelivery.prepare(raw: "nao", dictionary: [], key: "revoked") { _, _ in
        throw JevFailure.rejectedKey
    }
    #expect(result.text == "Não.")
    #expect(result.note == "TypeSafe rejected the key. Inserted local text.")
}

@Test func aSuccessfulJudgmentUsesOnlyTheChosenSpanAndShape() async {
    var asked = false
    let result = await JevDelivery.prepare(raw: "buy code rabbit and milk", dictionary: [], key: "saved") { corrected, key in
        asked = corrected == "buy code rabbit and milk" && key == "saved"
        return JevJudgment(shape: .list, replacements: [Replacement(span: "code rabbit", word: "CodeRabbit")], respell: [])
    }
    #expect(asked)
    #expect(result.text == "• Buy CodeRabbit\n• Milk")
    #expect(result.note == nil)
}
