#!/bin/sh
# Synthesized audible speech -> actual bundled Parakeet batch -> transcript file.
# No key event, paste, saved take or network call is performed.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../../../.." && pwd)
out=${1:?usage: drive-speech.sh <evidence-directory>}
mkdir -p "$out"
out=$(CDPATH= cd -- "$out" && pwd)
exe="$HOME/Applications/JevFlow.app/Contents/MacOS/Kept"
test -x "$exe"
say -v Samantha -o "$out/spoken.aiff" 'Ship the update on Friday, not Monday.'
afconvert -f WAVE -d LEI16@16000 -c 1 "$out/spoken.aiff" "$out/spoken.wav"
# Bound the model call; a hung CLI must not strand a verification run.
/usr/bin/python3 - "$exe" "$out/spoken.wav" "$out/transcription.txt" "$out/transcription.stderr" <<'PY'
import subprocess
import sys

with open(sys.argv[3], "w") as stdout, open(sys.argv[4], "w") as stderr:
    result = subprocess.run([sys.argv[1], "--transcribe", sys.argv[2]], stdout=stdout, stderr=stderr, timeout=180)
raise SystemExit(result.returncode)
PY
test -s "$out/transcription.txt"
printf 'Real bundled recognizer transcript: %s\n' "$out/transcription.txt"
printf 'Audio: %s\n' "$out/spoken.wav"
