# Phonon-2 evaluation: keep Parakeet v3

## Decision

Do not migrate English. Keep Parakeet TDT 0.6B v3 for English, Portuguese, Auto, and the other supported European languages. Keep whisper-cli for pinned languages outside that set. No runtime upgrade, language-ID first pass, or second bundled model is warranted by this run.

Phonon-2 was slower on these actual dictation takes and introduced domain-word regressions. An English-only model also cannot safely replace Auto when Portuguese is used. It did fix one `shoot` → `ship` mishearing; that single improvement did not offset the losses.

## Method

Measured on Jorge's Apple M4 Pro, macOS 15.6, Swift Command Line Tools 6.2.3, 2026-10-01. No cloud speech service was used.

- Selected 17 real stored WAVs: 11 English (354.800 seconds), 6 Portuguese (52.696 seconds), including long takes, short commands, domain names, and an older ship/shoot mishearing. The private manifest maps the anonymous labels below to the original takes; no recordings or full personal transcripts are committed.
- Loaded the installed app's exact v3 CoreML directory and the Phonon-2 default sparse/ANE encoder with `AsrModels.loadLocal`. Both use default compute units, the same batch API, fresh `TdtDecoderState` per take, language hints, and word timings joined in timestamp order.
- Phonon-2 CoreML repository revision: `a812a0dfef205660787ef6234317ab79acf4d5d6`. Downloaded only the four default `.mlmodelc` components, vocabulary, and attribution. Verified the sizes and LFS SHA-256 hashes. This evaluation directory is 357,601,312 bytes including its README/license/notice. The advertised 164 MB is the MLX download, not the full CoreML runtime.
- Model-controlled comparison: FluidAudio revision `0b1f46289fe27d95b5e66ad8be46e64f5ee02ae7`, which includes `.phonon2`. Warmed both models, then ran every take three times with alternating model order. Reported per-take medians exclude model load and WAV decoding.
- Current-app baseline: repeated the same WAVs three times using FluidAudio 0.17.2 (`3fc97306612d119337c487ce789c6cd631a7876b`) in a separate release harness. Its texts matched the new-runtime v3 outputs on all 17 takes. Also ran four WAVs through the installed app's `--transcribe`; all succeeded. Separate-process timings are not controlled proof of a runtime regression.
- 153 timed transcriptions collected (17 × 3 × 3 model/runtime combinations). Every model/runtime transcript was stable across its three runs. All 102 transcripts in the model-controlled comparison had word timestamps.

## Warm processing time

Totals are the sum of per-take median processing seconds, not end-to-end key-release-to-paste latency. Jev formatting, microphone startup, insertion, and cold model load are not included.

| Language | Takes | Audio (s) | Current v3, 0.17.2 (s) | v3, Phonon-capable runtime (s) | Phonon-2, same runtime (s) |
|---|---:|---:|---:|---:|---:|
| English | 11 | 354.800 | 2.151 | 3.194 | 4.256 |
| Portuguese | 6 | 52.696 | 0.336 | 0.510 | 0.783 |

Phonon-2 was 33.3% slower than v3 in the same-runtime English comparison (53.4% slower on Portuguese). Compared with the separately measured currently shipped runtime, its English processing total was 97.9% higher.

First load in the new-runtime process: v3 18.880 s; Phonon-2 75.126 s. These include CoreML compilation/cache effects and are not steady-state launch figures. The CoreML card documents a first-load sparse-encoder compile; warm processing above excludes it.

## Per-take table and transcript differences

`Edits` is case/punctuation-normalized word edit distance against the archived **machine-generated** raw transcript. It is not human-verified WER and is biased toward the recognizer that made the archive. Casefold, remove commas inside numbers, tokenize Unicode words/numbers with apostrophes, then Levenshtein distance. Do not report v3's agreement with its own archive as perfect accuracy.

| Take | Audio (s) | Current v3 (s) | New-runtime v3 (s) | Phonon-2 (s) | Edits: v3 / Phonon-2 |
|---|---:|---:|---:|---:|---:|
| EN1 | 89.900 | 0.397 | 0.563 | 0.681 | 0 / 10 |
| EN2 | 13.800 | 0.072 | 0.118 | 0.118 | 0 / 2 |
| EN3 | 12.500 | 0.081 | 0.117 | 0.116 | 0 / 4 |
| EN4 | 16.300 | 0.110 | 0.152 | 0.147 | 0 / 2 |
| EN5 | 36.900 | 0.137 | 0.195 | 0.183 | 0 / 6 |
| EN6 | 8.700 | 0.058 | 0.082 | 0.092 | 0 / 0 |
| EN7 | 19.000 | 0.116 | 0.164 | 0.173 | 0 / 2 |
| EN8 | 13.900 | 0.070 | 0.100 | 0.116 | 0 / 2 |
| EN9 | 13.500 | 0.061 | 0.093 | 0.099 | 0 / 1 |
| EN10 | 125.100 | 1.003 | 1.539 | 2.463 | 0 / 13 |
| EN11 | 5.200 | 0.047 | 0.071 | 0.068 | 0 / 1 |
| PT1 | 8.700 | 0.058 | 0.091 | 0.094 | 0 / 2 |
| PT2 | 4.600 | 0.040 | 0.064 | 0.065 | 0 / 1 |
| PT3 | 27.600 | 0.110 | 0.156 | 0.322 | 0 / 15 |
| PT4 | 3.000 | 0.041 | 0.063 | 0.168 | 0 / 6 |
| PT5 | 4.000 | 0.038 | 0.063 | 0.060 | 0 / 1 |
| PT6 | 4.796 | 0.049 | 0.073 | 0.074 | 1 / 1 |

Archived-reference totals: English 43 Phonon edits over 596 reference tokens (v3 0); Portuguese 26 over 88 tokens (v3 1). These are disagreement counts, **not** an independently measured accuracy rate.

Examples that matter to this app's domain:

- EN2: v3 `feature flag`; Phonon-2 `Sherflag`.
- EN8: v3 `spawn Kanban cards`; Phonon-2 `find Camb cards`.
- EN10: v3 `Artemis`; Phonon-2 `Aftomis` / `Atemis`.
- EN11: v3 `shoot RT`; Phonon-2 `ship RT` — a plausible improvement, not ignored in the decision.
- PT4: v3 `Funciona até em português, tá ligado?`; Phonon-2 `I want to take Portuguese, Telegraph` — not a safe Auto replacement.

A true WER comparison requires a human-reviewed reference from the audio. None was available in this headless run; do not synthesize one from guesses or a second recognizer. The directly measured latency loss and observed domain regressions suffice to reject this conditional migration without claiming a formal accuracy win for either model.

## Reproduce

The isolated package at `scripts/asr-benchmark/` pins the Phonon-capable runtime without changing JevFlow's dependency. Its input is a JSON array of objects with `id`, `wavPath`, and `language` (`en` or `pt`). WAVs must be 16 kHz mono. It writes private JSONL with timing, text, and word timestamps. Use the model's pinned revision and verify download hashes before running it.

```sh
swift run --package-path scripts/asr-benchmark -c release SpeechBench \
  "$HOME/Applications/JevFlow.app/Contents/Resources/parakeet-tdt-0.6b-v3-coreml" \
  /absolute/path/to/phonon-2-coreml \
  /absolute/path/to/private-takes.json \
  /absolute/path/to/private-results.jsonl
```

The original local-only evidence is under `~/.hermes/cache/scratch/jevflow/t_108a9c6f/`: pinned model provenance, manifest, harnesses, complete JSONL results, aggregation code, installed-baseline output, and test logs. Those private artifacts are not uploaded or committed. The summary tables above stand alone if scratch is pruned.

## Packaging and verification

No Phonon-2 weights are installed. Parakeet stays bundled; launch still loads locally. The package now includes NVIDIA/FluidInference attribution and the CC-BY-4.0 link in `Resources/SpeechModelAttribution.txt`, also linked from the README. Evaluating Phonon-2 does not make it part of the shipped app; its downloaded LICENSE and NOTICE remain with the local bench model.

Verification: all 136 Swift tests passed both before the changes and on a fresh detached worktree containing only the staged change. `scripts/package-app.sh` completed; `sh -n` and `git diff --check` passed. Release build emitted the existing non-Sendable `RightOptionMonitor` capture warning in `Capture.swift:1081`, not a build failure.

- Stopped only the old installed app (PID 37561); relaunched the newly installed app (PID 29081) through LaunchServices, without opening a main window.
- Doctor: valid signature, installed binary matches the signed release artifact, Microphone/Accessibility authorized, bundled models present. `speech_route_check auto=parakeetV3 en=parakeetV3 pt=parakeetV3` proves the retained routing.
- Installed SHA-256: `5a0e47795bc2ded004d489882190b11f5e858441a1ec83cca523295617a44a7b`, different from the pre-install binary. `strings` found the new `speech_route_check ` literal; the release `main.swift.o` is newer than its edited source.
- All 17 original WAVs succeeded through the newly installed app's `--transcribe` path and matched the pre-change v3 baseline exactly. This is real bundled batch recognition, not a synthetic mic/paste test.
- Bundle before: 494,822,204 bytes (471.899 MiB). After: 494,807,871 bytes (471.886 MiB), 14,333 bytes smaller. Counted regular-file bytes recursively; not compressed download size or allocated disk blocks.
- Bundled attribution matches the source file exactly. No Phonon-2 directory was added. No weights, keys, private manifest, or full transcripts are staged; nothing is pushed.

Manual check (pending): in an expendable focused field, with language set to Auto, hold Right Option and say `Funciona até em português, tá ligado?`, then release. The non-activating card should show Portuguese, and release should paste that Portuguese sentence once with one trailing space. This terminal cannot certify the physical hold, microphone capture, or paste; no synthetic key event is used as proof.

## Sources

- [Phonon-2 CoreML card, files and attribution](https://huggingface.co/FluidInference/phonon-2-coreml/tree/a812a0dfef205660787ef6234317ab79acf4d5d6)
- [Fermion Research Phonon-2](https://huggingface.co/FermionResearch/Phonon-2)
- [FluidAudio Phonon-2 integration](https://github.com/FluidInference/FluidAudio/pull/980)
- [NVIDIA Parakeet v3 and CC-BY-4.0](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
