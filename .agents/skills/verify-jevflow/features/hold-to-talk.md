# Hold to talk

## Sub-features

- Right Option press starts mic/listening; release after a hold finalizes once.
- Partial card stays local; final uses v3 batch then Jev.

## How to get to it (user POV)

Focus an empty field in another app, hold Right Option, speak, release.

## Driving it with verify-jevflow

Run `swift test --filter CaptureGesturesTests` and `swift test --filter SpeechAudioTests` for transitions/gate. Run `scripts/test-ui-snapshots.sh "$E/ui"` for `listening-light.png`. Human must observe live card, release, resulting field text and a new take in `takes/index.json`; capture before and after.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Neither `--transcribe` nor `Session.beginHold()` proves the hold. Selection or Right Command routes to Edit. Release while mic starts hides the card.
