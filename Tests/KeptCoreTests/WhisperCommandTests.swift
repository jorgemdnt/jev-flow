import Testing
@testable import KeptCore

@Test func whisperArgumentsIncludeModelPathAndAuthPrompt() {
    let model = "/Users/someone/Library/Application Support/Kept/models/ggml-large-v3-turbo.bin"
    let wav = "/Users/someone/Library/Application Support/Kept/takes/take.wav"
    let args = WhisperCommand.arguments(modelPath: model, wavPath: wav)

    #expect(argument("--model", in: args) == model)
    #expect(argument("--prompt", in: args) == "auth")
    #expect(args.contains(model))
    #expect(!args.contains { $0.contains("://") })
    #expect(!args.contains { $0.contains("for-tests-ggml-tiny") })
}

@Test func modelChoiceSkipsTheTinyTestFile() {
    #expect(WhisperCommand.modelFileName(preferredExists: true, fallbackExists: true) == "ggml-large-v3-turbo.bin")
    #expect(WhisperCommand.modelFileName(preferredExists: false, fallbackExists: true) == "ggml-medium.en.bin")
    #expect(WhisperCommand.modelFileName(preferredExists: false, fallbackExists: false) == nil)
    #expect(WhisperCommand.preferredModelFileName != "for-tests-ggml-tiny.bin")
    #expect(WhisperCommand.executablePath == "/opt/homebrew/bin/whisper-cli")
}

private func argument(_ name: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: name), args.index(after: index) < args.endIndex else { return nil }
    return args[args.index(after: index)]
}
