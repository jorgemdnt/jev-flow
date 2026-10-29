<p align="center">
  <img src="docs/logo.png" width="128" alt="JevFlow">
</p>

# JevFlow

Hold Right Option and speak. When you let go, your words land in the field you have focused.

## How it works

Your speech stays on this Mac. [NVIDIA Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3), through [FluidAudio](https://github.com/FluidInference/FluidAudio), transcribes Auto, English, Portuguese, and the other supported European languages locally. A pinned language outside that set uses [whisper.cpp](https://github.com/ggml-org/whisper.cpp). You don't need a speech account, nothing is billed for speech recognition, and no cloud speech API is involved.

Phonon-2 was tested on this Mac's saved takes and did not win. English stays on v3, as does Auto; no English-only language detector or second model is added. See the [benchmark and routing decision](docs/phonon-2-benchmark.md).

When you release the key, a short take with nothing to correct pastes straight away. For the rest, [Jev](https://typesafe.ai) decides whether the text needs layout (a list, steps, or paragraphs) and which dictionary word you meant. Only a take that needs layout goes to DeepSeek V4.1 Flash on OpenCode, using the same key as edit mode. JevFlow pastes that layout only if every word you said is still there, in order. If any call fails, JevFlow inserts the local text instead.

## TypeSafe key

You don't need a TypeSafe key to use JevFlow. If you have one, save it in Settings or set `TYPESAFE_API_KEY`. The key is never stored in this repo.

## Build

You need macOS 15 and the Swift Command Line Tools. You don't need Xcode.app.

```sh
brew install whisper-cpp
scripts/link-testing-module.sh && swift test
scripts/package-app.sh
```

`scripts/package-app.sh` installs `~/Applications/JevFlow.app` with the Parakeet runtime inside the bundle; launch does not download it. Its build-time cache and your past takes live in `~/Library/Application Support/Kept`. Homebrew whisper-cpp is only needed for the pinned-language fallback. JevFlow needs Microphone and Accessibility permissions before it can insert text.

The menu-bar icon is the Option key.

## License

JevFlow is released under the [MIT](LICENSE) license. The Option, book, clock, and settings marks come from [Lucide](https://lucide.dev) and are under the ISC license. See [NOTICE](NOTICE).

The bundled Parakeet TDT 0.6B v3 weights are created by [NVIDIA](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) and distributed under [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/legalcode.en). [FluidInference](https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml) provides the quantized CoreML conversion; [FluidAudio](https://github.com/FluidInference/FluidAudio) is Apache-2.0. JevFlow does not train or modify the weights. [Speech-model attribution](Resources/SpeechModelAttribution.txt) is also included in the app's Resources.
