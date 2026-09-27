# Listening, locked, Edit and notice cards

## Sub-features

- Listening names mic, shows growing transcript with dim latest window.
- Edit separates selected text/instruction; notice explains error.
- Card grows vertically to cap and shows tail, never takes focus.

## How to get to it (user POV)

Hold or double-tap Right Option for Listening/Locked; use edit chord for Edit; no selection for notice.

## Driving it with verify-jevflow

Run `scripts/test-ui-snapshots.sh "$E/ui"` and inspect `listening`, `locked`, `long-speech`, `edit`, `notice` light/dark PNGs; inspect dimensions via `sips`. Human observes growing card under icon while original field retains focus and text tail remains visible.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Fixtures do not prove panel positioning, nonactivation or live redraw. `NSHostingView.sizingOptions = []` prevents runaway min-height.
