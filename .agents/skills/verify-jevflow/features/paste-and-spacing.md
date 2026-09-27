# Insertion and spacing

## Sub-features

- Save/restore pasteboard, Command-V accepted text, type one trailing space.
- Type leading gap only if caret predecessor is non-whitespace; never dictate over selection.

## How to get to it (user POV)

Dictate twice into a field, including one that trims trailing pasted whitespace; try a selection (routes to Edit).

## Driving it with verify-jevflow

Run `swift test --filter PasteActionsTests` and `swift test --filter InsertPipelineTests`. Human compares clipboard and field before/after both takes, checks final space, no pasted leading space and no selection overwrite.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Unreadable field does not justify a leading space. Pure tests cannot prove OS key posting or pasteboard restoration.
