import Testing
@testable import KeptCore

@Test func longSparseTakeRefusesAutoInsert() {
    let decision = InsertDecision(transcript: "A agreed", durationSeconds: 600)
    #expect(decision.autoInsert == false)
    #expect(decision.transcript == "A agreed")
    #expect(decision.durationSeconds == 600)
}

@Test func shortTakeAllowsInsert() {
    let decision = InsertDecision(transcript: "hello there", durationSeconds: 5)
    #expect(decision.autoInsert == true)
}

@Test func twentySecondsIsNotALongTake() {
    let decision = InsertDecision(transcript: "A", durationSeconds: 20)
    #expect(decision.autoInsert == true)
}

@Test func justOverTwentySecondsWithTooFewWordsRefuses() {
    let decision = InsertDecision(transcript: "one two three four five", durationSeconds: 21)
    #expect(decision.autoInsert == false)
}

@Test func oneWordPerFourSecondsStillAllows() {
    let decision = InsertDecision(transcript: "one two three four five six", durationSeconds: 24)
    #expect(decision.autoInsert == true)
}
