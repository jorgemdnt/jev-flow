#!/bin/sh
# Read-only. The executable probe reports states only, never secret values.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/../../../.." && pwd)
app="$HOME/Applications/JevFlow.app"
exe="$app/Contents/MacOS/Kept"
built="$root/.build/release/Kept"
signed="$root/dist/JevFlow.app/Contents/MacOS/Kept"
problem=0
if [ ! -x "$exe" ]; then printf 'FAIL installed executable missing: %s\n' "$exe"; exit 1; fi
if codesign --verify --strict "$app" 2>/dev/null; then printf 'OK installed signature\n'; else printf 'FAIL installed signature\n'; problem=1; fi
if [ -x "$built" ] && [ -x "$signed" ]; then
    got=$(shasum -a 256 "$exe" | cut -d ' ' -f 1)
    want=$(shasum -a 256 "$signed" | cut -d ' ' -f 1)
    if [ "$got" = "$want" ]; then printf 'OK installed binary matches signed release artifact: %s\n' "$got"; else printf 'FAIL installed binary differs from signed release artifact (installed %s, signed %s)\n' "$got" "$want"; problem=1; fi
    if [ "$built" -nt "$signed" ]; then printf 'FAIL release build newer than signed artifact; repackage\n'; problem=1; fi
else
    printf 'FAIL release build or signed artifact missing: swift build -c release --product Kept && scripts/package-app.sh\n'; problem=1
fi
running=$(ps -axo pid=,command= | /usr/bin/python3 -c 'import sys; target=sys.argv[1]; print(" ".join(line.strip().split(None, 1)[0] for line in sys.stdin if len(line.strip().split(None, 1)) == 2 and line.strip().split(None, 1)[1] == target))' "$exe")
if [ -n "$running" ]; then printf 'OK running installed executable pid %s\n' "$running"; else printf 'FAIL no running installed executable\n'; problem=1; fi
probe=$("$exe" --verify-doctor) || { printf 'FAIL executable doctor probe\n'; exit 1; }
printf '%s\n' "$probe"
printf '%s\n' "$probe" | /usr/bin/grep -q '^models present$' || problem=1
printf '%s\n' "$probe" | /usr/bin/grep -q '^microphone authorized$' || problem=1
printf '%s\n' "$probe" | /usr/bin/grep -q '^accessibility authorized$' || problem=1
if ! printf '%s\n' "$probe" | /usr/bin/grep -q '^opencode_key present$'; then
    printf 'NOTE OpenCode key absent: edit needs one; dictation does not. No key value was read into evidence.\n'
fi
printf 'NOTE TCC probe runs as an installed executable from this terminal; a live bundle launch may have different privacy attribution. Confirm with a physical hold.\n'
exit "$problem"
