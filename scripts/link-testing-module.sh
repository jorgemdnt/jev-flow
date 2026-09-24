#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
modules="$root/.build/arm64-apple-macosx/debug/Modules"
source="/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework/Versions/A/Modules/Testing.swiftmodule"

mkdir -p "$root/Vendor/modules"
ln -sfn "$source" "$root/Vendor/modules/Testing.swiftmodule"
mkdir -p "$(dirname "$modules")"
ln -sfn ../../../Vendor/modules "$modules"
