# Short tap and startup release

## Sub-features

- Under 300 ms audio is rejected quietly.
- One tap may arm the second-tap lock briefly, then dismiss.

## How to get to it (user POV)

Tap Right Option once without speech; release while microphone is still starting.

## Driving it with verify-jevflow

Run `swift test --filter SpeechAudioTests` and `swift test --filter CaptureGesturesTests`. Human confirms no new take/index change, no paste, and disappearing card/status; review recent capture logs if needed.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

A short tap need not produce a WAV. Do not call `Invalid audio data provided` a successful user outcome.
