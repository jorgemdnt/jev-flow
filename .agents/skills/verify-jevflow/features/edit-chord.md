# Edit selected text

## Sub-features

- Selection + Right Option, Right Command then Right Option, or Right Option then Right Command starts Edit.
- Missing selection, changed selection, unchanged/failed response all refuse paste with notice.
- Electron AX failure falls back to Command-C with clipboard restore.

## How to get to it (user POV)

Select text in a disposable field and speak change during each chord order. Repeat with no selection, modify selection during processing and in an Electron field.

## Driving it with verify-jevflow

Run `swift test --filter CaptureGesturesTests` and `swift test --filter PasteActionsTests`; inspect `edit-light.png` and `notice-light.png`. Optional `--probe-edit` calls real OpenCode with a fixed sample but does not paste. Human confirms only selection changes, instruction is not pasted, clipboard restored, no model call on no selection (logs), stale selection refused.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

OpenCode key required. Electron can return AX -25212 so copy fallback isn't failure. Model probe/unit test cannot prove live AX, mic or paste.
