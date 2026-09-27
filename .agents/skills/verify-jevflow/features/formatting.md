# Format without rewriting words

## Sub-features

- Jev chooses prose/list/numbered and dictionary span; code applies it.
- Preserve numbered start, negation, uncommon words, `um`; remove standalone `uh`; correct known accents and misspellings, spoken numbers and `ship PR`.

## How to get to it (user POV)

Dictate a list, numbered sequence, and a sentence with `not`, `uh`, `nao`, and `ship we are five thousand forty-nine`.

## Driving it with verify-jevflow

Run `swift test` (FormatterTests, CleanupTests, SpeechFormatTests, SpokenNumberTests, JevResponseTests, RespellTests). Human compares raw take with inserted sentence: no lost negation, renumbering, unintended expansion or wrong alias.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Jev is a format/span judgment, not a rewrite. Live Jev needs TypeSafe key/network; tests isolate it. `um` can be Portuguese.
