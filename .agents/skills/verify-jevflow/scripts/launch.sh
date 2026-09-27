#!/bin/sh
# Refuse to take ownership of an already-running personal app.
set -eu
out=${1:?usage: launch.sh <evidence-directory>}
mkdir -p "$out"
out=$(CDPATH= cd -- "$out" && pwd)
exe="$HOME/Applications/JevFlow.app/Contents/MacOS/Kept"
test -x "$exe"
existing=$(ps -axo pid=,command= | /usr/bin/python3 -c 'import sys; target=sys.argv[1]; print(" ".join(line.strip().split(None, 1)[0] for line in sys.stdin if len(line.strip().split(None, 1)) == 2 and line.strip().split(None, 1)[1] == target))' "$exe")
if [ -n "$existing" ]; then printf 'Existing user instance pid %s; not owned, not launching another.\n' "$existing"; exit 0; fi
"$exe" > "$out/app.stdout" 2> "$out/app.stderr" &
pid=$!
printf '%s\n' "$pid" > "$out/owned.pid"
# This process may exit on permission or model failure; doctor checks readiness.
kill -0 "$pid" 2>/dev/null || { printf 'Launch exited; see %s/app.stderr\n' "$out" >&2; exit 1; }
printf 'Started installed JevFlow pid %s\n' "$pid"
