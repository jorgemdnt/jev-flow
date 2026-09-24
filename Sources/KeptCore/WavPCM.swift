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

    /// Reads the fmt sample rate. A JUNK chunk before fmt is not the rate.
    public static func decode(_ data: Data) -> DecodedPCM? {
        guard data.count >= 12,
              data.prefix(4) == Data("RIFF".utf8),
              data.dropFirst(8).prefix(4) == Data("WAVE".utf8) else {
            return nil
        }
        var offset = 12
        var rate: Double = 0
        var channels = 0
        var bits = 0
        var format = 0
        var pcm: Data?
        while offset + 8 <= data.count {
            let ident = data.subdata(in: offset..<(offset + 4))
            let size = Int(readUInt32(data, offset + 4))
            let start = offset + 8
            let end = min(start + size, data.count)
            if ident == Data("fmt ".utf8), end - start >= 16 {
                format = Int(readUInt16(data, start))
                channels = Int(readUInt16(data, start + 2))
                rate = Double(readUInt32(data, start + 4))
                bits = Int(readUInt16(data, start + 14))
            } else if ident == Data("data".utf8) {
                pcm = data.subdata(in: start..<end)
            }
            let padded = size + (size & 1)
            offset = start + padded
        }
        guard format == 1, bits == 16, channels > 0, rate > 0, let pcm else { return nil }
        return DecodedPCM(sampleRate: rate, samples: floatSamples(pcm, channels: channels))
    }

    public static func floatSamples(_ pcm: Data, channels: Int = 1) -> [Float] {
        let width = max(channels, 1) * 2
        guard pcm.count >= width else { return [] }
        let frames = pcm.count / width
        var samples = [Float](repeating: 0, count: frames)
        pcm.withUnsafeBytes { raw in
            for frame in 0..<frames {
                var sum: Float = 0
                for channel in 0..<channels {
                    let value = Int16(littleEndian: raw.loadUnaligned(fromByteOffset: frame * width + channel * 2, as: Int16.self))
                    sum += Float(value) / 32768
                }
                samples[frame] = sum / Float(channels)
            }
        }
        return samples
    }

    private static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self).littleEndian }
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).littleEndian }
    }
}

public struct DecodedPCM: Equatable, Sendable {
    public let sampleRate: Double
    public let samples: [Float]

    public init(sampleRate: Double, samples: [Float]) {
        self.sampleRate = sampleRate
        self.samples = samples
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
