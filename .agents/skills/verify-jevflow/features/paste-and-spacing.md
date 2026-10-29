# Insertion and spacing

## Sub-features

- Save pasteboard, offer the text lazily (marked transient), Command-V, restore only after the focused app read it, then type one trailing space.
- No read within 2 s: leave the text on the pasteboard, show "Not inserted. Text copied." on the card, do not mark the take inserted, type no trailing space. The edit chord does the same with its replacement.
- No Command-C selection probe at insert: only the Accessibility selection blocks a paste.
- Type leading gap only if caret predecessor is non-whitespace; never dictate over selection.

## How to get to it (user POV)

Dictate twice into a field, including one that trims trailing pasted whitespace; try a selection (routes to Edit).

## Driving it with verify-jevflow

Run `swift test --filter PasteActionsTests` and `swift test --filter InsertPipelineTests`. Live: every insert logs `insert into <bundle id>: pasted|unread|failed after N ms` in category `capture`. Human compares clipboard and field before/after both takes, checks final space, no pasted leading space and no selection overwrite.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Unreadable field does not justify a leading space. Pure tests cannot prove OS key posting, the pasteboard read, or restoration.
