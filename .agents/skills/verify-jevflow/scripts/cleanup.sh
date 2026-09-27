#!/bin/sh
# Only terminate the PID this run recorded, and only while it is still the app.
set -eu
out=${1:?usage: cleanup.sh <evidence-directory>}
pidfile="$out/owned.pid"
if [ ! -f "$pidfile" ]; then printf 'No owned instance. Evidence retained at %s\n' "$out"; exit 0; fi
pid=$(/usr/bin/python3 -c 'import pathlib,sys; s=pathlib.Path(sys.argv[1]).read_text().strip(); print(s if s.isdecimal() else "")' "$pidfile")
exe="$HOME/Applications/JevFlow.app/Contents/MacOS/Kept"
if [ -n "$pid" ]; then
    command=$(ps -p "$pid" -o command= 2>/dev/null || true)
    if [ "$command" = "$exe" ]; then kill -TERM "$pid"; printf 'Stopped owned pid %s\n' "$pid"; else printf 'Owned pid %s no longer refers to JevFlow; left it alone.\n' "$pid"; fi
fi
rm -f "$pidfile"
printf 'Evidence retained at %s\n' "$out"
