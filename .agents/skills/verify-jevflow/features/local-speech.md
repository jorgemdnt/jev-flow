# Local Parakeet transcription

## Sub-features

- Bundled v3 batch recognition with timestamped words joined by spaces.
- Resampling and short-buffer rejection; no cloud speech.

## How to get to it (user POV)

Hold Right Option and speak in an editable field; release to transcribe. For an automated recognizer-only path use the installed executable with a WAV.

## Driving it with verify-jevflow

Run `.agents/skills/verify-jevflow/scripts/drive-speech.sh "$E"`; inspect audible `spoken.wav`, nonempty `transcription.txt`, and exit code. `Tests/KeptCoreTests/SpeechAudioTests.swift` and `WavPCMTests.swift` test input gates. Human hold: compare spoken phrase with target field and saved take.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

The CLI `--transcribe` uses Auto and does not format, save a take or paste. Debug executable without bundle weights fails. Synthesized voice is real audio, not microphone capture.
