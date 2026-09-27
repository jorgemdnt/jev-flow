# Double-tap lock

## Sub-features

- Two short Right Option taps lock the microphone on.
- A later tap stops and pastes; cancellation and silence rules also apply.

## How to get to it (user POV)

With no selection or Right Command, tap Right Option twice, speak hands-free, then tap once.

## Driving it with verify-jevflow

Use `Tests/KeptCoreTests/CaptureGesturesTests.swift` and `locked-light.png`/`locked-dark.png`. Human observes locked card and status `Tap Right Option to stop`; later tap yields one saved take and one insertion.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Second tap within gesture gap is lock, not a second paste. Selected field is Edit. Synthetic posted keys are not trusted proof.
