# Dictionary

## Sub-features

- Add a written spelling or unique @handle; remove a saved entry.
- Replacement applies only to selected span and cannot re-match the handle output.

## How to get to it (user POV)

Click menu-bar icon → Dictionary… or Open JevFlow → Dictionary; use `New dictionary word`, `Add`, then `Remove <word>`.

## Driving it with verify-jevflow

Run `scripts/test-ui-snapshots.sh "$E/ui"`, inspect `dictionary-light.png`; run `swift test` (CleanupTests, RespellTests, JevResponseTests). Human adds a disposable word, checks list and `voice.json` persists after reopen, uses it in a take, then removes only that word.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Shared first names require surname (Pedro Vivaldi, Costa). Do not invent an alias. Fixture words are not saved dictionary.
