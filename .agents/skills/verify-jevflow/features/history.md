# History

## Sub-features

- Empty and populated views show takes/duration.
- Insert, Insert raw, Insert again, Dismiss are different actions.

## How to get to it (user POV)

Click menu-bar icon → Open JevFlow → History; use visible button on a disposable take.

## Driving it with verify-jevflow

Run `scripts/test-ui-snapshots.sh "$E/ui"`, inspect `history-light.png` and `history-empty-light.png`; run `swift test --filter TakeStoreTests`. Human makes/reopens take, uses Insert again or Insert raw and sees target field change; Dismiss removes only that take WAV/sidecar/index entry.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Snapshot takes are fixtures, not saved history. Never dismiss someone else's speech. Refused sparse take offers Insert raw.
