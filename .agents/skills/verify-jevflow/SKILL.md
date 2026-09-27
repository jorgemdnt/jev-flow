---
name: verify-jevflow
description: Verify JevFlow's macOS menu-bar dictation, edit chord, windows, and local speech using installed-app diagnostics, real audio, Swift tests, UI PNGs, and human key holds.
---

# Verify JevFlow

The product is JevFlow; its Swift module/executable is `Kept`, bundle id `local.kept.app`. Read `SPEC.md` (product lock), then `features/README.md` for the entire user-facing surface. This is a native Mac app, not a web page. The terminal cannot send a trusted physical Right Option hold (`CGPreflightPostEventAccess` may be false); **do not claim a gesture, actual microphone, Accessibility paste, or edit completed from a unit test or rendered fixture.** Mark those human checks pending in `evidence.md`.

## Launch

From the repo root on macOS 15 with Command Line Tools:

```sh
scripts/link-testing-module.sh && swift test
swift build -c release --product Kept
```

`swift test` runs capture/format/insert behavior. After `swift package clean`, rerun `scripts/link-testing-module.sh` before testing. For a real app, `scripts/package-app.sh` builds release, fetches/copies the bundled int8 Parakeet runtime set, signs and installs `~/Applications/JevFlow.app`. It replaces the user's installed app: first stop only that app, and do not package while another session is using it. The fetch script lists Hugging Face even with a complete cache; on 429, report it rather than quietly pretending installation succeeded (see `scripts/package-app.sh`). Do not use `swift build` alone as proof of install.

Create `E="$HOME/.hermes/cache/scratch/jevflow/<card-id>"` (replace `<card-id>` with the actual task id), then launch with `.agents/skills/verify-jevflow/scripts/launch.sh "$E"`. If it reports an existing instance, that is the user's app: reuse it read-only, never terminate it during cleanup. A new instance writes `owned.pid`. It is ready when `doctor.sh` reports the exact installed executable running and its SHA-256 matches the **signed release artifact** in `dist/` (the raw `.build/release/Kept` hash differs because codesign alters Mach-O bytes). The doctor also checks the release build is not newer than that signed artifact. An installed binary can be older than the current source; rebuild/reinstall and relaunch before claiming live changes. Signing can re-prompt TCC. To prove a new UI literal made the package, compare the release object mtime to source or inspect a long literal in the installed binary; a short Swift string may be encoded inline and not show under `strings`.

## Doctor

Run `.agents/skills/verify-jevflow/scripts/doctor.sh | tee "$E/doctor.txt"` before driving or when an instance seems wrong (use `set -o pipefail` in bash if you need its exit code through `tee`). It checks codesign, signed-artifact/installed binary SHA-256 (plus release build freshness), running PID and exact executable path, installed model runtime directories/vocab, Microphone authorization, Accessibility trust, and OpenCode key **presence only**. Key missing is not a dictation failure; edit needs it. The probe is read-only (`--verify-doctor`), does not request permission, print keys, call a network service, or certify that a key works. A CLI-launched executable may have different TCC attribution than the app launched through Finder: treat a failed TCC result as needing an in-app/human check, and confirm real input/insert with a person. TypeSafe key/HTTP health is shown in Settings; do not dump its contents. Check that a built binary is installed *and* relaunch after package: a PID with the right path is not proof its old in-memory image is new.

## Drive

- Pure behavior: `scripts/link-testing-module.sh && swift test` (test names in `Tests/KeptCoreTests/`; not live key events or paste). Save the test log.
- Real UI drawing: `scripts/test-ui-snapshots.sh "$E/ui"`. It builds debug `Kept`, uses `--ui-snapshot`, verifies 22 light/dark PNGs: History (empty/populated), Dictionary, Settings (short/full), onboarding, listening/locked/long-speech, Edit and notice. The fixtures don't alter the real take store/dictionary or click buttons. Inspect the relevant PNGs, not just exit code. `--render-edit-card <path> [dark] [long]` is a separate view hook.
- Real local model: `.agents/skills/verify-jevflow/scripts/drive-speech.sh "$E"` synthesizes an audible sentence via `say`, converts it to 16 kHz mono PCM WAV, and runs the *installed* app's existing `--transcribe <wav>` path through bundled Parakeet v3. Inspect `spoken.wav`, `transcription.txt` and the exit status. This tests file→batch recognition, **not** microphone capture, Jev formatting, insertion, or real human speech. If Siri voice Samantha is unavailable, choose an installed English voice via `say -v '?'` and note it in evidence.
- Edit model integration (optional and networked): `~/Applications/JevFlow.app/Contents/MacOS/Kept --probe-edit` makes a real OpenCode call with fixed non-personal sample; run only when deliberately testing credentials/network and record status, never a secret. This does not paste a selection.
- Live integration: ask a human to focus an expendable text field, hold Right Option, speak, release; record the field before/action/after, app card/status and `takes/index.json` change. Repeat for gesture variants listed in the feature map. **No automation here can certify physical holds.** Do not fake the event via `CGEvent` or invoke `Session.beginHold()` as proof.

## Evidence

Keep proof at `$HOME/.hermes/cache/scratch/jevflow/<card-id>/`: `evidence.md` (action, pre-state, result, exact gaps), `doctor.txt`, `swift-test.txt`, `ui/`, `spoken.wav`, `transcription.txt`, and optionally a redacted live log. Capture both the action and the resulting state, not a pretty final screenshot alone. `log show --predicate 'subsystem == "local.kept.app"' --info --last 10m` supplies phase/duration/status telemetry; save only reviewed/redacted lines. Stored takes live at `~/Library/Application Support/Kept/takes/index.json` and WAVs: inspect IDs/counts/paths/durations without copying private speech or secrets into shareable proof. Compare before/after for side effects: take retained, index entry and paste destination; a refused take must have no paste. Dismiss only fixtures you created, never someone else's takes. Snapshot fixtures are isolated (`fixture-takes` under the evidence directory); `--transcribe` does not create takes. Networked Jev and OpenCode are production boundaries, not silently mocked here. Tests isolate those boundaries, so tests cannot prove live requests or TCC. Do not treat a dry-run name as a promise: `--probe-edit` calls the network; `scripts/package-app.sh` calls Hugging Face and replaces an installed app. A human check left undone stays explicitly pending in `evidence.md`.

## Cleanup

Run `.agents/skills/verify-jevflow/scripts/cleanup.sh "$E"` after each attempt. It kills only the PID recorded by `launch.sh`, after checking its exact executable path; an existing personal instance is never killed. It retains all evidence. If you packaged/restarted the user's app, arrange with the user whether to leave it running; never kill by process name. Remove disposable `fixture-takes` only after preserving needed PNGs; never delete the user's `~/Library/Application Support/Kept` or bundled model cache. Confirm `test -s "$E/transcription.txt"` and `test -s "$E/ui/listening-light.png"` **after** cleanup. If a run fails, still run cleanup; report what failed, not a fabricated pass.

## Helpers

From repo root, once executable bits are present in git:

```sh
.agents/skills/verify-jevflow/scripts/launch.sh "$E"
.agents/skills/verify-jevflow/scripts/doctor.sh
.agents/skills/verify-jevflow/scripts/drive-speech.sh "$E"
.agents/skills/verify-jevflow/scripts/cleanup.sh "$E"
```

Use the feature map to select *all* entry paths for a feature, not only the easiest fixture or test. `/maintain-verification-skill` keeps this map aligned with product changes.
