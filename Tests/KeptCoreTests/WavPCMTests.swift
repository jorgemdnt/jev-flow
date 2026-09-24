import Foundation
import Testing
@testable import KeptCore

@Test func wavHeaderIsSixteenKilohertzMonoPCM() {
    let pcm = Data(repeating: 0, count: 32_000)
    let wav = WavPCM.encode(pcm: pcm)
    #expect(wav.prefix(4) == Data("RIFF".utf8))
    #expect(wav.dropFirst(8).prefix(4) == Data("WAVE".utf8))
    #expect(wav.count == 44 + 32_000)
    #expect(WavPCM.durationSeconds(pcmByteCount: 32_000) == 1)
}
