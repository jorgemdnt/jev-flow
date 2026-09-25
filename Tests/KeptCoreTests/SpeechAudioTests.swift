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

@Test func aReleaseWithNoDeviceBitsEndsTheHold() {
    #expect(HoldKey.event(wasDown: true, keyCode: 0, flags: 0) == .up)
    #expect(HoldKey.event(wasDown: true, keyCode: 0x3D, flags: 0) == .up)
    #expect(HoldKey.event(wasDown: false, keyCode: 0x3D, flags: 0x40) == .down)
    #expect(HoldKey.event(wasDown: true, keyCode: 0x38, flags: 0x40) == nil)
    #expect(HoldKey.event(wasDown: false, keyCode: 0, flags: 0) == nil)
}

@Test func aFlagsSampleEndsTheHoldOnlyAfterTheDeviceBitWasSeen() {
    let quiet = HoldKey.flagsRelease(wasDown: true, sawDeviceBit: false, flags: 0)
    #expect(quiet.edge == nil)
    #expect(quiet.sawDeviceBit == false)

    let seen = HoldKey.flagsRelease(wasDown: true, sawDeviceBit: false, flags: 0x40)
    #expect(seen.edge == nil)
    #expect(seen.sawDeviceBit == true)

    let released = HoldKey.flagsRelease(wasDown: true, sawDeviceBit: true, flags: 0)
    #expect(released.edge == .up)
    #expect(released.sawDeviceBit == false)

    let stillHeld = HoldKey.flagsRelease(wasDown: true, sawDeviceBit: true, flags: 0x40)
    #expect(stillHeld.edge == nil)
    #expect(stillHeld.sawDeviceBit == true)
}

@Test func aRouteChangeAbandonsAnOpenHold() {
    #expect(HoldWatch.shouldAbandon(holding: true, routeChanged: true))
    #expect(!HoldWatch.shouldAbandon(holding: false, routeChanged: true))
    #expect(!HoldWatch.shouldAbandon(holding: true, routeChanged: false))
}

@Test func aSilentTapIsAliveAndAStoppedTapIsDead() {
    #expect(!HoldWatch.tapDied(bytes: 3200, previousBytes: 1600, quietFor: .seconds(3)))
    #expect(!HoldWatch.tapDied(bytes: 0, previousBytes: 0, quietFor: .milliseconds(400)))
    #expect(HoldWatch.tapDied(bytes: 1600, previousBytes: 1600, quietFor: .milliseconds(1500)))
}

@Test func aSilentHoldEndsAndSpeechDoesNot() {
    #expect(HoldWatch.noAudio(previewEmpty: true, silent: true, quietFor: .seconds(3)))
    #expect(!HoldWatch.noAudio(previewEmpty: true, silent: false, quietFor: .seconds(5)))
    #expect(!HoldWatch.noAudio(previewEmpty: false, silent: true, quietFor: .seconds(5)))
    #expect(HoldWatch.noWords(previewEmpty: true, quietFor: .seconds(8)))
    #expect(!HoldWatch.noWords(previewEmpty: false, quietFor: .seconds(20)))
    #expect(!HoldWatch.insertAfterSilence(silentFor: .seconds(44)))
    #expect(HoldWatch.insertAfterSilence(silentFor: .seconds(45)))
    #expect(HoldWatch.escapeCancels(holding: true, keyCode: 53, keyDown: true))
    #expect(!HoldWatch.escapeCancels(holding: false, keyCode: 53, keyDown: true))
    #expect(!HoldWatch.escapeCancels(holding: true, keyCode: 0x3D, keyDown: true))
}
