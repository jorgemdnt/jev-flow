# Kept

Personal Mac dictation app. Open source, local only, no account, no billing, no website, no cloud speech API, no LLM rewrite pass.

Wispr Flow's cleanup model is the bug. It renumbers lists, swaps rare words for common ones, turns a spoken self-correction into "or", and drops "not" / "never" / "haven't" / "before" / strategic "like". It also drops whole stretches of speech and then cannot recover them, because cleanup runs after a lossy transcript. Turning cleanup off breaks lists. Kept does not do that.

## Stack

Locked. Do not reopen it.

macOS 15.6, Apple M4 Pro, 48 GB. No Xcode.app. Only Command Line Tools (`/Library/Developer/CommandLineTools`, Swift 6.2.3). `whisper-cli` is `/opt/homebrew/bin/whisper-cli`. The only model already on disk is Homebrew's tiny test file. Do not use tiny for real dictation.

2026 desktop landscape, and why it is not the stack:

- Electron: still the default when a team wants one Chromium everywhere. Wrong here. An always-on dictation utility should not ship a browser.
- Tauri 2: the current small-bundle default (Rust + system WebView). Right for a web UI. Wrong here. The product is a global hotkey, the microphone, and Accessibility insert. Those are AppKit, not a website.
- Velox: alpha Swift port of Tauri. Not production.
- This app: Swift 6 executable from Swift Package Manager, wrapped by a script into a menu-bar `.app` (`LSUIElement` true). Ad-hoc codesign is enough for this Mac. Do not require Xcode.app. Do not add a web frontend.

## What it does

Hold Right Option to talk. While held, partial text updates in the focused field. Release replaces that partial with the cleaned transcript. A desktop window shows the takes. Right-click the menu-bar icon for the context menu. Left-click toggles the window and does not activate Kept, so the focused app keeps the caret.

The final text is cleaned by gpt-6-luna at reasoning effort xhigh, using the OpenAI key already in ~/.zshenv. The key is not copied into the repo. The model may clean phrases, adjust words, and format a spoken list as bullets. If that cleanup drops a guard word, rewrites auth to off, turns a correction into or, or renumbers a spoken list, it is thrown out and the local text is inserted instead. Partials stay local. Speech stays on this Mac.

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

Whisper timestamps stay on. `--no-timestamps` drops the tail of a take.

## Insert

Save the pasteboard, paste the accepted text into the focused app with Command-V, restore the pasteboard. Accessibility permission is required. If it is missing, say so in the menu. Do not silently drop the text.

## Layout

- `SPEC.md` this file
- `Package.swift` executable target `Kept` plus a test target
- `Sources/KeptCore/` pure formatter and insert-decision types, no AppKit
- `Sources/Kept/` menu bar app, hotkey, recorder, whisper-cli runner
- `scripts/package-app.sh` builds `Kept.app`
- `Tests/KeptCoreTests/` the rules above
- Models live in `~/Library/Application Support/Kept/models/`, never in git
- Install the built app to `~/Applications/Kept.app`

## Out of scope

iOS, Windows, accounts, billing, a website, cloud STT, an LLM cleanup pass, a meeting notetaker, rewriting the user's existing Wispr history.
