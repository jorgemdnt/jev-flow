<p align="center">
  <img src="docs/logo.png" width="128" alt="JevFlow">
</p>

# JevFlow

Hold Right Option. Speak. Let go. The words land in the focused field.

Speech stays on this Mac. [whisper.cpp](https://github.com/ggml-org/whisper.cpp) transcribes locally. There is no account, no billing, and no cloud speech API.

On release, [Jev](https://typesafe.ai) chooses the shape (prose, a list, or numbered) and which dictionary word you meant. The app keeps every word you said. If that call fails, the local transcript is inserted. A TypeSafe key is optional. Save it in Settings, or set `TYPESAFE_API_KEY`. It is not stored in this repo.

## Build

macOS 15. Swift Command Line Tools. No Xcode.app.

```sh
brew install whisper-cpp
scripts/link-testing-module.sh && swift test
scripts/package-app.sh
```

That installs `~/Applications/JevFlow.app`. The speech model and past takes live in `~/Library/Application Support/Kept`. Microphone and Accessibility are required to insert.

The menu-bar icon is the Option key.

## License

[MIT](LICENSE). The Option, book, clock, and settings marks are [Lucide](https://lucide.dev), ISC. See [NOTICE](NOTICE).
