# JevFlow

Personal Mac dictation app. The product name is JevFlow. Open source, local speech, no account, no billing, no website, no cloud speech API. The Swift module and the bundle id stay `local.kept.app`. Takes live in `~/Library/Application Support/Kept`. The Parakeet weights ship inside the app, not in git.

Wispr Flow's cleanup model is the bug. It renumbers lists, swaps rare words for common ones, turns a spoken self-correction into "or", and drops "not" / "never" / "haven't" / "before" / strategic "like". It also drops whole stretches of speech and then cannot recover them, because cleanup runs after a lossy transcript. Turning cleanup off breaks lists. JevFlow does not do that.

## Stack

Locked. Do not reopen it.

macOS 15. No Xcode.app. Command Line Tools only. The default recognizer is NVIDIA Parakeet TDT 0.6B v3, run on this Mac through FluidAudio (CoreML). The weights are CC-BY-4.0 and ship in the app. Launch does not download them. The Hugging Face repo is 3.6 GB because it includes every encoder variant. The app includes the int8 set it runs, about 480 MB. Do not use the tiny whisper test model for real dictation. Do not use a cloud speech API.

A pinned language outside Parakeet's 25 European languages uses Homebrew `whisper-cli`. Auto, English, Portuguese, and the rest of that set do not. Japanese, Korean, and Chinese stay on whisper-cli because v3 romanizes them. Arabic and Hindi stay on whisper-cli because v3 does not support them. The final transcript is a v3 batch. It is not the English-only Parakeet EOU streaming model.

2026 desktop landscape, and why it is not the stack:

- Electron: still the default when a team wants one Chromium everywhere. Wrong here. An always-on dictation utility should not ship a browser.
- Tauri 2: the current small-bundle default (Rust + system WebView). Right for a web UI. Wrong here. The product is a global hotkey, the microphone, and Accessibility insert. Those are AppKit, not a website.
- Velox: alpha Swift port of Tauri. Not production.
- This app: Swift 6 executable from Swift Package Manager, wrapped by a script into a menu-bar `.app` (`LSUIElement` true). Ad-hoc codesign is enough for this Mac. Do not require Xcode.app. Do not add a web frontend.

## What it does

Hold Right Option to talk. A card under the menu-bar icon shows the words as they arrive, aligned to that icon, and names the microphone in use. It does not take keyboard focus. Parakeet v3 is batch. The card updates when a chunk finishes. Release pastes the formatted transcript once, with a trailing space, into the focused field. Click the menu-bar icon for the menu. Open JevFlow for history, dictionary, and settings. Settings chooses the spoken language and the microphone.

The first launch asks which language you speak. Auto detects it. Auto and a pinned European language go to Parakeet. A pinned language outside that set is passed to whisper-cli. Omitting the language flag makes whisper-cli assume English, so the fallback always passes it.

The final text is formatted by Jev. Jev chooses whether the take is prose, a list, or numbered, and which dictionary span you meant. Code applies that and keeps the words. It does not rewrite the sentence. The TypeSafe key is the one saved in Settings, or `TYPESAFE_API_KEY` in the environment. The key is not copied into the repo. If that call fails, the local text is inserted.

A mark sits on the focused app's Accessibility caret while recording and while transcribing. If Accessibility is missing, say so in the menu. Do not use a mark near the mouse instead.

Audio is kept until the user dismisses that take. A short transcript on a long take is a failure, not a successful cleanup.

## Rules the formatter must keep

These are tests, not vibes. The formatter is a pure function. It is not a model.

1. A numbered list keeps the spoken start. "5. alpha / 6. beta" stays 5, 6. Never rewrite it to 1, 2.
2. Do not map uncommon words onto common ones. Seed dictionary includes `auth`. A later whisper prompt may bias the recognizer. The formatter itself must not rewrite `auth` to `off`.
3. A spoken self-correction wins. `I want the color to be orange, err, yellow` becomes `I want the color to be yellow`. `err` / `er` as its own token is the correction mark, not the word `or`. Do not emit `orange or yellow`.
4. Never drop `not`, `never`, `haven't`, `hadn't`, `before`. If the raw transcript has one, the inserted text has it, unless the user corrected that exact word with an `err` mark.
5. Do not strip `like`.
6. Do not euphemize. `pissing` stays `pissing`.
7. Chunk loss is visible. If audio is longer than 20 seconds and the transcript has fewer than one word per four seconds, do not auto-insert. Show the raw text and the duration. The user can still insert raw.
8. A new take inserts one space before its text when the previous insertion does not end in whitespace.
9. Capitalize the start of a finished take. End it with a period when it has no terminal punctuation.

Punctuation and capitalization are allowed only when they do not violate 1–7.

Parakeet word timestamps stay on. The transcript is those words joined with spaces. A newline is a segment break, not a chat send. The whisper-cli fallback also keeps timestamps. `--no-timestamps` drops the tail of a take.

## Insert

Save the pasteboard, paste the accepted text into the focused app with Command-V, restore the pasteboard. Accessibility permission is required. If it is missing, say so in the menu. Do not silently drop the text.

## Layout

- `SPEC.md` this file
- `Package.swift` executable target `Kept` plus a test target
- `Sources/KeptCore/` pure formatter and insert-decision types, no AppKit
- `Sources/Kept/` menu bar app, hotkey, recorder, recognizer
- `scripts/package-app.sh` builds `JevFlow.app` and copies the Parakeet weights into it
- `Tests/KeptCoreTests/` the rules above
- Whisper fallback models, if a pinned language needs them, live in `~/Library/Application Support/Kept/models/`. Never in git.
- Install the built app to `~/Applications/JevFlow.app`. The bundle id stays `local.kept.app`.

## Out of scope

iOS, Windows, accounts, billing, a website, cloud STT, an LLM cleanup pass, a meeting notetaker, rewriting the user's existing Wispr history.
