#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"
output=${1:-"${TMPDIR:-/tmp}/jevflow-ui-snapshots"}
mkdir -p "$output"
swift build --product Kept -j 4
bin_dir=$(swift build --product Kept --show-bin-path)
"$bin_dir/Kept" --ui-snapshot "$output"
for appearance in light dark; do
    for view in history history-empty dictionary settings settings-full onboarding listening locked long-speech edit requesting-edit notice; do
        image="$output/$view-$appearance.png"
        test -s "$image"
        /usr/bin/sips -g pixelWidth -g pixelHeight "$image" >/dev/null
    done
done
printf 'UI snapshots verified: %s\n' "$output"
