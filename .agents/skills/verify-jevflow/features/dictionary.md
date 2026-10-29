# Dictionary

## Sub-features

- Add a written spelling or unique @handle; remove a saved entry.
- Replacement applies only to selected span and cannot re-match the handle output.
- Non-@ entries are word-spotter terms: the bundled Parakeet CTC 110M proposes spans whose audio sounds like a term (`heard`), Jev confirms, code swaps. No spelling-distance matching. @handles match by exact first name/surname only.

## How to get to it (user POV)

Click menu-bar icon → Dictionary… or Open JevFlow → Dictionary; use `New dictionary word`, `Add`, then `Remove <word>`.

## Driving it with verify-jevflow

Run `scripts/test-ui-snapshots.sh "$E/ui"`, inspect `dictionary-light.png`; run `swift test` (CleanupTests, RespellTests, JevResponseTests, HeardTermTests, JevDictionaryTests). Networked, on a stored take: `~/Applications/JevFlow.app/Contents/MacOS/Kept --format <take.wav>` prints `raw`, `heard <span> -> <term>`, the note and the final text without pasting (it sends that take to Jev, and to OpenCode if layout is needed). Live log: `spotter heard N of M terms in X ms` in category `format`. Human adds a disposable word, checks list and `voice.json` persists after reopen, uses it in a take, then removes only that word.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Shared first names require surname (Pedro Vivaldi, Costa). Do not invent an alias. Fixture words are not saved dictionary. The spotter is English-only; on its own it proposed "posso" → PostHog and "library" → Linear, so a spotter proposal without Jev's confirmation is never pasted. `scripts/vocab-benchmark` replays stored takes through the spotter to re-measure after tuning.
