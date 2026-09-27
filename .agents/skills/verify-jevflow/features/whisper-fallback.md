# Non-European whisper fallback

## Sub-features

- Pinned ja/zh/ko/ar/hi use Homebrew whisper-cli and a stored fallback model.
- Timestamped output is flattened without dropping tail.

## How to get to it (user POV)

In Settings pin Japanese/Chinese/Korean/Arabic/Hindi, then dictate in a disposable field.

## Driving it with verify-jevflow

Run `swift test --filter WhisperCommandTests` for `--language` and transcript join. Human with `/opt/homebrew/bin/whisper-cli` and a real fallback model under Application Support checks a real take and language; inspect saved text/logs, then restore prior language.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Never use Homebrew's tiny test model for actual dictation. `--no-timestamps` drops tails. Do not change the user's pin without restoring it.
