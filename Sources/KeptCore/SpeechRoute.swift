import Foundation

/// Which recognizer runs for a pinned language.
///
/// Auto and NVIDIA Parakeet TDT 0.6B v3's 25 European languages use FluidAudio.
/// A pinned language outside that set uses whisper-cli. v3 romanizes Japanese,
/// Korean, and Chinese, and it does not support Arabic or Hindi.
public enum SpeechEngine: String, Equatable, Sendable {
    case parakeetV3
    case whisperCLI
}

public enum SpeechRoute {
    /// CoreML bundle folder. Weights are NVIDIA `parakeet-tdt-0.6b-v3`, CC-BY-4.0.
    public static let parakeetModelFolder = "parakeet-tdt-0.6b-v3-coreml"

    /// Model card: https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3
    public static let parakeetCodes: Set<String> = [
        "bg", "hr", "cs", "da", "nl", "en", "et", "fi", "fr", "de", "el",
        "hu", "it", "lv", "lt", "mt", "pl", "pt", "ro", "sk", "sl", "es",
        "sv", "ru", "uk",
    ]

    public static func engine(for languageCode: String) -> SpeechEngine {
        if languageCode == SpokenLanguage.auto.code || parakeetCodes.contains(languageCode) {
            return .parakeetV3
        }
        return .whisperCLI
    }
}

public enum SpeechTranscript {
    /// Timed words, in order. A newline is a segment break, not a chat send.
    /// When timings are empty, the raw text is joined the same way so the tail
    /// is not dropped on the floor.
    public static func text(timedWords: [String], rawText: String) -> String {
        let fromWords = joined(timedWords)
        if !fromWords.isEmpty { return fromWords }
        return joined([rawText])
    }

    public static func joined(_ pieces: [String]) -> String {
        pieces
            .flatMap { piece in
                piece.split(whereSeparator: \.isNewline).map {
                    String($0).trimmingCharacters(in: .whitespaces)
                }
            }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
