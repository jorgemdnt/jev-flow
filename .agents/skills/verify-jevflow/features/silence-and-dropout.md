# Silence and input dropout

## Sub-features

- 45 seconds of silence finishes and inserts an audio-bearing hold/lock.
- Input tap death retains captured audio; AirPods exact-zero dropout cuts dead tail and restarts.

## How to get to it (user POV)

Hold Right Option or lock it, speak, then remain silent.

## Driving it with verify-jevflow

Run `swift test --filter InputDropoutTests` and `swift test --filter CaptureGesturesTests`. Human waits after words for card to dismiss; confirm WAV/index and one insertion. Review `log show --predicate 'subsystem == "local.kept.app"' --info --last 10m` for dropout/restart or silence finish.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

45s is a live timer, not a unit-test wall-clock wait. If input device route changes, cancel instead (separate feature).
