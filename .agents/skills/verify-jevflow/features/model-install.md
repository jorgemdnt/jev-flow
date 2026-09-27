# Bundled model and install

## Sub-features

- Package release app with int8 Parakeet v3 runtime, no download at launch.
- Fallback whisper model lives in Application Support only if used.

## How to get to it (user POV)

Build and install with `scripts/package-app.sh`, then launch `~/Applications/JevFlow.app`.

## Driving it with verify-jevflow

After agreeing to replace installed app, run `swift build -c release --product Kept`, stop old instance, run `scripts/package-app.sh`, `scripts/launch.sh "$E"`, `scripts/doctor.sh`; compare installed/release hash and model dirs. Run `scripts/drive-speech.sh "$E"` for real inference.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Package script contacts Hugging Face even with full cache; 429 blocks install. Never commit model weights. New ad-hoc signature may reset TCC.
