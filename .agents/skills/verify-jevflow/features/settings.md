# Settings and key health

## Sub-features

- Choose language/input device; save/remove TypeSafe and OpenCode keys.
- Health tags distinguish working/rejected/unreachable/unknown.

## How to get to it (user POV)

Click menu-bar icon → Settings… or Open JevFlow → Settings; use language/mic selectors or secure fields with authorized test key.

## Driving it with verify-jevflow

Run `scripts/test-ui-snapshots.sh "$E/ui"`, inspect `settings-light.png`, `settings-full-dark.png`; run `swift test --filter KeychainQueryTests`. Human checks changed language/mic persisted and health tag after authenticated check.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Doctor checks OpenCode presence, not validity. TypeSafe uses GET /v1/models; OpenCode /models proves nothing, so Settings uses a one-token completion. Never print a production key.
