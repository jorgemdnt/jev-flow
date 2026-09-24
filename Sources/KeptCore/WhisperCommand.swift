import Foundation

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
    ///
    /// Timestamps stay on. `--no-timestamps` decodes the window in one pass
    /// and stops early. On a 23.8s take that dropped the tail
    /// ("it puts the two phrases together").
    public static func arguments(modelPath: String, wavPath: String) -> [String] {
        [
            "--model", modelPath,
            "--file", wavPath,
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
