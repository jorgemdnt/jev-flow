# Long sparse take refusal

## Sub-features

- Over 20s with fewer than one word per four seconds stays saved but not pasted.
- User can Insert raw from History or status menu.

## How to get to it (user POV)

Record a >20s sparse take; then open History or status menu and choose `Insert raw`.

## Driving it with verify-jevflow

Run `swift test --filter InsertDecisionTests` and `swift test --filter InsertPipelineTests`. Human verifies unchanged target field, saved take with raw text/duration, `Kept this take and did not paste it.`, then Insert raw changes the field.

Record the action and observed result in `$E/evidence.md`; explicitly mark unperformed physical-hold checks pending.

## Gotchas

Do not label refusal a paste. Do not dismiss retained take before checking manual recovery.
