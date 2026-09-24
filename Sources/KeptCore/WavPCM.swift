import Foundation

public enum WavPCM {
    public static func encode(pcm: Data, sampleRate: UInt32 = 16_000) -> Data {
        var data = Data()
        data.reserveCapacity(44 + pcm.count)
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        data.appendLE(UInt32(36 + pcm.count))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(UInt16(1))
        data.appendLE(sampleRate)
        data.appendLE(sampleRate * 2)
        data.appendLE(UInt16(2))
        data.appendLE(UInt16(16))
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        data.appendLE(UInt32(pcm.count))
        data.append(pcm)
        return data
    }

    public static func durationSeconds(pcmByteCount: Int, sampleRate: Double = 16_000) -> Double {
        guard sampleRate > 0, pcmByteCount > 0 else { return 0 }
        return Double(pcmByteCount) / 2 / sampleRate
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
