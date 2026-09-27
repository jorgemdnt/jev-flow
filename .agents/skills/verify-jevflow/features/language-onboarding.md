# Language picker and routing

## Sub-features

- First launch asks spoken language, default Auto; Settings can change it.
- Auto/European languages use Parakeet; unsupported pinned languages use whisper-cli with explicit `--language`.

## How to get to it (user POV)

On a fresh macOS account open JevFlow; choose language and Continue. On an existing account use Settings → Dictation → Language.

## Driving it with verify-jevflow

Run `scripts/test-ui-snapshots.sh "$E/ui"`, inspect `onboarding-light.png`; run `swift test` (WhisperCommandTests and SpeechRoute tests). Human replays first launch only on disposable OS account and checks `language.txt` persists. Do not delete the personal saved language.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Snapshot is fixture drawing, not actual first-launch persistence. There is no isolated app-profile override; don't reset the user's personal store.
