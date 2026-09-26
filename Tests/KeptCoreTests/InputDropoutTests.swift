import Testing
@testable import KeptCore

private func silence(_ count: Int) -> [Int16] { [Int16](repeating: 0, count: count) }
private func speech(_ count: Int) -> [Int16] { (0..<count).map { $0 % 2 == 0 ? 2_000 : -2_000 } }
private func roomNoise(_ count: Int) -> [Int16] { (0..<count).map { $0 % 3 == 0 ? 0 : ($0 % 2 == 0 ? 12 : -9) } }

@Test func zerosWhileTheLinkComesUpAreNotADropout() {
    var dropout = InputDropout()
    dropout.feed(silence(8_000))
    #expect(!dropout.dropped)
}

@Test func startupNoiseBeforeTheLinksZerosIsNotADropout() {
    var dropout = InputDropout()
    dropout.feed(speech(60))
    dropout.feed(silence(8_000))
    #expect(!dropout.dropped)
}

@Test func speechThenPointFourSecondsOfExactZerosIsADropout() {
    var dropout = InputDropout()
    dropout.feed(speech(16_000))
    dropout.feed(silence(InputDropout.deadSamples - 1))
    #expect(!dropout.dropped)
    dropout.feed(silence(1))
    #expect(dropout.dropped)
}

@Test func aQuietRoomAfterSpeechIsNotADropout() {
    var dropout = InputDropout()
    dropout.feed(speech(16_000))
    dropout.feed(roomNoise(48_000))
    #expect(!dropout.dropped)
}

@Test func theDeadTailIsOnlyTheExactZerosAtTheEnd() {
    #expect(InputDropout.trailingZeros(speech(10) + silence(7)) == 7)
    #expect(InputDropout.trailingZeros(silence(3) + speech(4)) == 0)
    #expect(InputDropout.trailingZeros(silence(5)) == 5)
}

@Test func afterARestartTheLinkMustCarrySoundAgain() {
    var dropout = InputDropout()
    dropout.feed(speech(16_000))
    dropout.feed(silence(InputDropout.deadSamples))
    #expect(dropout.dropped)
    dropout.reset()
    dropout.feed(silence(InputDropout.deadSamples * 2))
    #expect(!dropout.dropped)
    dropout.feed(speech(InputDropout.armingSamples))
    dropout.feed(silence(InputDropout.deadSamples))
    #expect(dropout.dropped)
}
