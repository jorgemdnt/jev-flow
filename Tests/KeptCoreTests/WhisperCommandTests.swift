import Testing
@testable import KeptCore

@Test func defaultRecognizerIsParakeetV3NotWhisperTurbo() {
    #expect(SpeechRoute.engine(for: "auto") == .parakeetV3)
    #expect(SpeechRoute.engine(for: "en") == .parakeetV3)
    #expect(SpeechRoute.engine(for: "pt") == .parakeetV3)
    #expect(SpeechRoute.engine(for: "es") == .parakeetV3)
    #expect(SpeechRoute.engine(for: "fr") == .parakeetV3)
    #expect(SpeechRoute.engine(for: "de") == .parakeetV3)
    #expect(SpeechRoute.engine(for: "ru") == .parakeetV3)
    #expect(SpeechRoute.parakeetCodes.count == 25)
    #expect(SpeechRoute.parakeetModelFolder == "parakeet-tdt-0.6b-v3-coreml")
    #expect(!SpeechRoute.parakeetModelFolder.contains("eou"))
    #expect(!SpeechRoute.parakeetModelFolder.contains("-v2"))
    #expect(WhisperCommand.preferredModelFileName != SpeechRoute.parakeetModelFolder)
}

@Test func languagesOutsideParakeetFallBackToWhisperWithoutDroppingTheTail() {
    for code in ["ar", "hi", "ja", "zh", "ko"] {
        #expect(SpeechRoute.engine(for: code) == .whisperCLI)
    }
    let args = WhisperCommand.arguments(modelPath: "/m", wavPath: "/t.wav", language: "ar")
    #expect(!args.contains("--no-timestamps"))
    #expect(!args.contains("--detect-language"))
    #expect(argument("--language", in: args) == "ar")
    #expect(argument("--prompt", in: args) == "auth")
    #expect(args.contains("--output-txt"))
    #expect(WhisperCommand.executablePath == "/opt/homebrew/bin/whisper-cli")
    #expect(!args.contains { $0.contains("://") })
    #expect(!args.contains { $0.contains("for-tests-ggml-tiny") })
}

@Test func whisperFallbackSkipsTheTinyTestFileAndPassesThePinnedLanguage() {
    #expect(WhisperCommand.modelFileName(preferredExists: true, fallbackExists: true) == "ggml-large-v3-turbo.bin")
    #expect(WhisperCommand.modelFileName(preferredExists: false, fallbackExists: true) == "ggml-medium.en.bin")
    #expect(WhisperCommand.modelFileName(preferredExists: false, fallbackExists: false) == nil)
    #expect(WhisperCommand.preferredModelFileName != "for-tests-ggml-tiny.bin")
    let model = "/Users/someone/Library/Application Support/Kept/models/ggml-large-v3-turbo.bin"
    let wav = "/Users/someone/Library/Application Support/Kept/takes/take.wav"
    let args = WhisperCommand.arguments(modelPath: model, wavPath: wav, language: "hi")
    #expect(argument("--model", in: args) == model)
    #expect(argument("--language", in: args) == "hi")
    #expect(argument("--prompt", in: args) == "auth")
    #expect(SpeechRoute.engine(for: "hi") == .whisperCLI)
}

@Test func parakeetWordTimingsKeepTheTailAndDoNotSendOnANewline() {
    let text = SpeechTranscript.text(
        timedWords: [
            "But it doesn't put spaces in between the phrases, like after I stop holding my ALT, I write the right option",
            "Say I stop holding it and then I start holding it again, it puts the two phrases together",
        ],
        rawText: "dropped"
    )
    #expect(text.contains("I write the right option"))
    #expect(text.contains("it puts the two phrases together"))
    #expect(!text.contains("\n"))
    #expect(!text.contains("dropped"))
    #expect(text == "But it doesn't put spaces in between the phrases, like after I stop holding my ALT, I write the right option Say I stop holding it and then I start holding it again, it puts the two phrases together")
}

@Test func transcriptJoinsANewlineInsideATimedWord() {
    let text = SpeechTranscript.text(timedWords: ["keep the tail\nof the take"], rawText: "")
    #expect(text == "keep the tail of the take")
    #expect(!text.contains("\n"))
}

@Test func emptyTimingsFallBackToJoinedRawText() {
    let file = """
    But it doesn't put spaces in between the phrases, like after I stop holding my ALT, I write the right option
    Say I stop holding it and then I start holding it again, it puts the two phrases together
    """
    let text = SpeechTranscript.text(timedWords: [], rawText: file)
    #expect(text.contains("it puts the two phrases together"))
    #expect(!text.contains("\n"))
    #expect(WhisperCommand.transcriptText(fileContents: file) == text)
}

private func argument(_ name: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: name), args.index(after: index) < args.endIndex else { return nil }
    return args[args.index(after: index)]
}
