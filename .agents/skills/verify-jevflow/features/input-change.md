# Microphone changes mid-hold

## Sub-features

- Default input route change abandons active take.
- Input dropout recovery is distinct from route change.

## How to get to it (user POV)

Start a hold, then switch macOS system default input or change selected device in Settings.

## Driving it with verify-jevflow

Run `swift test --filter CaptureGesturesTests` and inspect `Sources/Kept/InputDevices.swift`. Human verifies `Microphone changed. Hold again.`, no paste, hidden card, no retained take; compare index and field.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Device switching can disturb other sessions. Recorder's own aggregate is not a real route change.
