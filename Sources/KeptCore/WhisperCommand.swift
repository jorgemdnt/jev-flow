import Foundation

/// whisper-cli is the fallback for a pinned language Parakeet v3 does not
/// support. Auto and the 25 European languages do not use this path.
public enum WhisperCommand {
    public static let executablePath = "/opt/homebrew/bin/whisper-cli"
    /// Seed word the recognizer hears before any formatter runs.
    public static let initialPrompt = "auth"
    public static let preferredModelFileName = "ggml-large-v3-turbo.bin"
    public static let fallbackModelFileName = "ggml-medium.en.bin"

    /// Homebrew's tiny file is a test fixture. Never select it for dictation.
    public static func modelFileName(preferredExists: Bool, fallbackExists: Bool) -> String? {
        if preferredExists { return preferredModelFileName }
        if fallbackExists { return fallbackModelFileName }
        return nil
    }

    /// `-p` is processors. The initial prompt is `--prompt`.
    /// The spoken language is `--language`. `auto` detects it. Omitting the
    /// flag makes whisper-cli assume English.
    ///
    /// Timestamps stay on. `--no-timestamps` decodes the window in one pass
    /// and stops early. On a 23.8s take that dropped the tail
    /// ("it puts the two phrases together").
    public static func arguments(modelPath: String, wavPath: String, language: String = SpokenLanguage.auto.code) -> [String] {
        [
            "--model", modelPath,
            "--file", wavPath,
            "--language", language,
            "--prompt", initialPrompt,
            "--no-prints",
            "--output-txt",
            "--output-file", transcriptBase(wavPath: wavPath),
        ]
    }

    /// The txt file breaks segments with newlines. Join them so the tail is
    /// kept and a chat field does not send on the segment break.
    public static func transcriptText(fileContents: String) -> String {
        fileContents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func transcriptURL(wavPath: String) -> URL {
        URL(fileURLWithPath: transcriptBase(wavPath: wavPath) + ".txt")
    }

    private static func transcriptBase(wavPath: String) -> String {
        URL(fileURLWithPath: wavPath).deletingPathExtension().path
    }
}

public struct SpokenLanguage: Equatable, Sendable, Hashable {
    public let code: String
    public let name: String

    public static let auto = SpokenLanguage(code: "auto", name: "Auto")

    public static let choices: [SpokenLanguage] = [
        .auto,
        SpokenLanguage(code: "en", name: "English"),
        SpokenLanguage(code: "pt", name: "Portuguese"),
        SpokenLanguage(code: "es", name: "Spanish"),
        SpokenLanguage(code: "fr", name: "French"),
        SpokenLanguage(code: "de", name: "German"),
        SpokenLanguage(code: "it", name: "Italian"),
        SpokenLanguage(code: "nl", name: "Dutch"),
        SpokenLanguage(code: "ja", name: "Japanese"),
        SpokenLanguage(code: "zh", name: "Chinese"),
        SpokenLanguage(code: "ko", name: "Korean"),
        SpokenLanguage(code: "ru", name: "Russian"),
        SpokenLanguage(code: "ar", name: "Arabic"),
        SpokenLanguage(code: "hi", name: "Hindi"),
    ]

    public static func matching(_ code: String) -> SpokenLanguage {
        choices.first { $0.code == code } ?? .auto
    }
}
