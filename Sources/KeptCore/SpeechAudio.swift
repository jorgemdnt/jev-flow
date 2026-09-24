import Foundation

public enum SpeechGate: Error, Equatable {
    case tooShort
}

/// Audio the recognizer is allowed to see. 16 kHz mono, at least 300 ms.
public enum SpeechAudio {
    public static let sampleRate: Double = 16_000
    public static let minimumDuration: Double = 0.3
    public static var minimumSamples: Int { Int(sampleRate * minimumDuration) }

    /// Linear resample to 16 kHz. Empty when the rate is unusable.
    public static func resample(_ samples: [Float], from inputRate: Double, to outputRate: Double = sampleRate) -> [Float] {
        guard inputRate > 0, outputRate > 0, !samples.isEmpty else { return [] }
        if abs(inputRate - outputRate) < 0.5 { return samples }
        let outCount = Int((Double(samples.count) * outputRate / inputRate).rounded())
        guard outCount > 0 else { return [] }
        var output = [Float](repeating: 0, count: outCount)
        let step = inputRate / outputRate
        let last = samples.count - 1
        for index in 0..<outCount {
            let position = Double(index) * step
            let left = min(Int(position), last)
            let right = min(left + 1, last)
            let fraction = Float(position - Double(left))
            let a = samples[left]
            output[index] = a + (samples[right] - a) * fraction
        }
        return output
    }

    /// Nil means do not call the recognizer. A short tap is not a failed take.
    public static func prepare(samples: [Float], sampleRate: Double) -> [Float]? {
        let resampled = resample(samples, from: sampleRate, to: Self.sampleRate)
        guard resampled.count >= minimumSamples else { return nil }
        return resampled
    }

    public static func accepts(durationSeconds: Double) -> Bool {
        durationSeconds >= minimumDuration
    }

    public static func int16Data(_ samples: [Float]) -> Data {
        var data = Data(count: samples.count * 2)
        data.withUnsafeMutableBytes { raw in
            guard let bytes = raw.baseAddress else { return }
            for (index, sample) in samples.enumerated() {
                let scaled = min(32767, max(-32768, sample * 32767))
                var value = Int16(scaled.rounded()).littleEndian
                memcpy(bytes.advanced(by: index * 2), &value, 2)
            }
        }
        return data
    }

    /// The menu must not show a buffer rejection as a failed take.
    public static func isBufferRejection(_ message: String) -> Bool {
        message.contains("Invalid audio data") && message.contains("300ms")
    }

    public static func isBufferRejection(_ error: Error) -> Bool {
        if error is SpeechGate { return true }
        return isBufferRejection(error.localizedDescription)
    }

    public static func menuStatus(recognizerMessage: String, idle: String) -> String {
        isBufferRejection(recognizerMessage) ? idle : recognizerMessage
    }
}

public enum HoldKey {
    public enum Edge: Equatable, Sendable {
        case down
        case up
    }

    /// Physical key state. A release is an edge even when the key-up event was missed.
    public static func edge(wasDown: Bool, physicalDown: Bool) -> Edge? {
        if physicalDown == wasDown { return nil }
        return physicalDown ? .down : .up
    }

    /// A flagsChanged event. A release with no device bits left is still a release.
    /// Right Option's key state stays false while held, so this does not read key state.
    public static func event(wasDown: Bool, keyCode: UInt16, flags: UInt64) -> Edge? {
        if keyCode != rightOptionKey && !wasDown { return nil }
        return edge(wasDown: wasDown, physicalDown: rightOptionDown(flags: flags))
    }

    /// A flags-state sample. This never starts a hold. It ends one only after a
    /// sample in this hold already contained the right-option device bit.
    /// A reading that never had that bit is not a release.
    public static func flagsRelease(wasDown: Bool, sawDeviceBit: Bool, flags: UInt64) -> (edge: Edge?, sawDeviceBit: Bool) {
        let deviceDown = (flags & rightOptionDeviceBit) != 0
        let seen = sawDeviceBit || deviceDown
        if wasDown && seen && !deviceDown {
            return (.up, false)
        }
        return (nil, seen)
    }

    public static let rightOptionKey: UInt16 = 0x3D
    public static let rightOptionDeviceBit: UInt64 = 0x40
    public static let deviceModifierBits: UInt64 = 0x0000_207F
    public static let optionBit: UInt64 = 0x0008_0000

    public static func rightOptionDown(flags: UInt64) -> Bool {
        let devices = flags & deviceModifierBits
        if devices != 0 {
            return (flags & rightOptionDeviceBit) != 0
        }
        return (flags & optionBit) != 0
    }
}
