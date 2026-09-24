import Foundation
import Testing
@testable import KeptCore

@Test func resampleHalvesAThirtyTwoKilohertzRun() {
    let input: [Float] = [0, 0, 1, 1, 0, 0, 1, 1]
    let output = SpeechAudio.resample(input, from: 32_000)
    #expect(output == [0, 1, 0, 1])
}

@Test func sixteenKilohertzAtThreeHundredMillisecondsIsSent() {
    let samples = [Float](repeating: -0.25, count: 4_800)
    let prepared = SpeechAudio.prepare(samples: samples, sampleRate: 16_000)
    #expect(prepared?.count == 4_800)
    #expect(prepared?.first == -0.25)
    #expect(prepared?.last == -0.25)
}

@Test func oneSampleUnderThreeHundredMillisecondsIsNotSent() {
    let samples = [Float](repeating: 0.1, count: 4_799)
    #expect(SpeechAudio.prepare(samples: samples, sampleRate: 16_000) == nil)
}

@Test func fortyEightKilohertzOneHundredMillisecondsIsNotSent() {
    // 4800 samples is 300 ms only if someone forgets to resample from 48 kHz.
    let samples = [Float](repeating: 0.2, count: 4_800)
    #expect(SpeechAudio.prepare(samples: samples, sampleRate: 48_000) == nil)
}

@Test func fortyEightKilohertzThreeHundredMillisecondsBecomesSixteenKilohertz() {
    let samples = [Float](repeating: 0.5, count: 14_400)
    let prepared = SpeechAudio.prepare(samples: samples, sampleRate: 48_000)
    #expect(prepared?.count == 4_800)
    #expect(prepared?.first == 0.5)
    #expect(prepared?.last == 0.5)
}

@Test func aHeaderOnlyWavIsNotSent() {
    let decoded = WavPCM.decode(WavPCM.encode(pcm: Data()))
    #expect(decoded?.sampleRate == 16_000)
    #expect(decoded?.samples.isEmpty == true)
    #expect(SpeechAudio.prepare(samples: decoded?.samples ?? [1], sampleRate: decoded?.sampleRate ?? 16_000) == nil)
}

@Test func wavAtFortyEightKilohertzIsReadAtThatRate() {
    var pcm = Data()
    var sample = Int16(8192).littleEndian
    for _ in 0..<14_400 {
        pcm.append(contentsOf: withUnsafeBytes(of: &sample) { Array($0) })
    }
    let decoded = WavPCM.decode(WavPCM.encode(pcm: pcm, sampleRate: 48_000))
    #expect(decoded?.sampleRate == 48_000)
    #expect(decoded?.samples.count == 14_400)
    let prepared = SpeechAudio.prepare(samples: decoded?.samples ?? [], sampleRate: decoded?.sampleRate ?? 0)
    #expect(prepared?.count == 4_800)
}

@Test func bufferRejectionIsNotAFailedTake() {
    let idle = "Hold Right Option to talk"
    let shown = SpeechAudio.menuStatus(
        recognizerMessage: "Invalid audio data provided. Must be at least 300ms of 16kHz audio.",
        idle: idle
    )
    #expect(shown == idle)
}

@Test func aMissingModelStillShows() {
    let shown = SpeechAudio.menuStatus(
        recognizerMessage: "Parakeet is missing from the app.",
        idle: "Hold Right Option to talk"
    )
    #expect(shown == "Parakeet is missing from the app.")
}

@Test func aFalseKeyStateDoesNotEndAHoldItNeverSaw() {
    #expect(HoldKey.release(wasDown: true, sawPhysicalDown: false, physicalDown: false) == false)
    #expect(HoldKey.release(wasDown: true, sawPhysicalDown: true, physicalDown: false) == true)
    #expect(HoldKey.release(wasDown: true, sawPhysicalDown: true, physicalDown: true) == false)
}
