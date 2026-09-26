import Foundation

/// A Bluetooth headset can drop its voice link in the middle of a hold. The
/// engine keeps running and the tap keeps delivering buffers of exact zeros,
/// so the take keeps growing with no words in it. A live microphone never
/// holds every sample at exactly zero for this long once it has carried sound.
/// The zeros while the link comes up are not a dropout, even after a few
/// samples of startup noise: the link must first carry 0.1 s of sound.
public struct InputDropout: Equatable, Sendable {
    /// 0.4 s at 16 kHz.
    public static let deadSamples = 6_400
    /// A sample this loud is sound, not the link's noise floor.
    public static let signalLevel: Int16 = 100
    /// 0.1 s of sound. Startup noise before the link's zeros is a few milliseconds.
    public static let armingSamples = 1_600

    public private(set) var loudSamples = 0
    public private(set) var zeroRun = 0

    public init() {}

    public var heardSignal: Bool {
        loudSamples >= Self.armingSamples
    }

    public var dropped: Bool {
        heardSignal && zeroRun >= Self.deadSamples
    }

    /// Exact zeros at the end of a recording. On a dropout they are dead air, not speech.
    public static func trailingZeros<C: BidirectionalCollection>(_ samples: C) -> Int where C.Element == Int16 {
        var count = 0
        for sample in samples.reversed() {
            guard sample == 0 else { break }
            count += 1
        }
        return count
    }

    public mutating func feed<S: Sequence>(_ samples: S) where S.Element == Int16 {
        for sample in samples {
            if sample == 0 {
                zeroRun += 1
                continue
            }
            zeroRun = 0
            if sample >= Self.signalLevel || sample <= -Self.signalLevel {
                loudSamples += 1
            }
        }
    }

    /// After the input restarts, the link comes up through zeros again.
    public mutating func reset() {
        self = InputDropout()
    }
}
