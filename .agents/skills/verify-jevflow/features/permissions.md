# Microphone, Accessibility and caret mark

## Sub-features

- Microphone authorizes recording; Accessibility observes Right Option/caret and sends paste.
- Missing permission surfaces status; caret mark uses AX selection bounds.

## How to get to it (user POV)

Open macOS System Settings → Privacy & Security → Microphone and Accessibility; grant installed JevFlow. Focus a field and hold Right Option.

## Driving it with verify-jevflow

Run `scripts/doctor.sh` for nonprompting TCC status and installed bundle. Human verifies actual mic take and field insertion, no menu warning, caret mark on field; save reviewed/redacted `log show --predicate 'subsystem == "local.kept.app"' --info --last 10m`.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

CLI process privacy attribution can differ from GUI bundle; doctor isn't definitive TCC proof. A mouse-adjacent mark does not prove caret bounds.
