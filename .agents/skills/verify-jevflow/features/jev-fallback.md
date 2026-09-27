# Jev formatting and local fallback

## Sub-features

- Saved TypeSafe key enables final shape/span choice; absent/failing call inserts local finished text.
- Partials never call Jev.

## How to get to it (user POV)

Dictate a list with working saved key; test unavailable format service only in a disposable session.

## Driving it with verify-jevflow

Run `swift test --filter JevDeliveryTests`, `swift test --filter JevResponseTests` and `swift test --filter SpeechFormatTests`. Human compares raw/inserted text, TypeSafe health tag and recent `log show --predicate 'subsystem == "local.kept.app"' --info` status; fallback should still insert local finished text.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Do not delete/revoke the real key to simulate failure. Tests are not proof of live API success. Never archive a key.
