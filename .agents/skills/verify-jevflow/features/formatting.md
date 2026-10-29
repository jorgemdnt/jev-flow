# Format without rewriting words

## Sub-features

- Jev judges whether a take needs layout and confirms each dictionary span the word spotter heard in the audio; code applies spans. Short takes with nothing to judge skip Jev.
- A take that needs layout goes to DeepSeek V4.1 Flash (OpenCode key); `Layout.accept` pastes it only when every word survives in order (layout commands, item numbers and an and/then before a new item may go). Otherwise the prose is pasted.
- Preserve numbered start, negation, uncommon words, `um`; remove standalone `uh`; correct known accents and misspellings, spoken numbers and `ship PR`.

## How to get to it (user POV)

Dictate a list (`list of banana pineapple`, `bullet point … bullet point …`), steps (`first … second …`), a two-paragraph message with `new paragraph`, a long plain sentence, and a sentence with `not`, `uh`, `nao`, and `ship we are five thousand forty-nine`.

## Driving it with verify-jevflow

Run `swift test` (FormatterTests, CleanupTests, SpeechFormatTests, LayoutTests, SpokenNumberTests, JevResponseTests, JevDeliveryTests, RespellTests). Live: `log show --predicate 'subsystem == "local.kept.app" AND category == "format"' --info --last 10m` shows `layout true/false` from Jev and `layout laid out/unchanged/rejected/failed in N ms`. Human compares raw take with inserted sentence: no lost negation, renumbering, unintended expansion or wrong alias.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Jev is a layout/span judgment, not a rewrite; the layout model is checked word by word. Layout needs a working OpenCode key (Settings) as well as TypeSafe. Live Jev needs TypeSafe key/network; tests isolate it. `um` can be Portuguese.
