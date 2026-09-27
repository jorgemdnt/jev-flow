# Cancel listening/edit

## Sub-features

- Escape, card click, or status-icon click cancels hold/lock without paste.
- Escape also dismisses a notice.

## How to get to it (user POV)

Start speech or Edit card; separately press Escape, click card body and click menu-bar icon.

## Driving it with verify-jevflow

Run `swift test --filter CaptureGesturesTests` and inspect `notice-light.png`. Human repeats all three paths; compare field/index before/after: no paste/take, card hidden, idle status.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

While a card is up, the icon is Cancel, not Open menu. Never cancel another person's live take.
