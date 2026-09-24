#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

swift build -c release --product Kept

bin_dir=$(swift build -c release --product Kept --show-bin-path)
app="$root/dist/Kept.app"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS"

cp "$bin_dir/Kept" "$app/Contents/MacOS/Kept"
chmod 755 "$app/Contents/MacOS/Kept"

cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Kept</string>
	<key>CFBundleIdentifier</key>
	<string>local.kept.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Kept</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>15.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSMicrophoneUsageDescription</key>
	<string>Kept records while Right Option is held and transcribes that audio on this Mac.</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

printf 'APPL????' > "$app/Contents/PkgInfo"

codesign --force --sign - --identifier local.kept.app \
    -r='designated => identifier "local.kept.app"' \
    "$app"
codesign --verify --strict "$app"

test -x "$app/Contents/MacOS/Kept"
test "$(plutil -extract LSUIElement raw "$app/Contents/Info.plist")" = "true"

# Install for this user only. Never write under /Applications, and never
# touch /Applications/Hermes.app.
hermes="/Applications/Hermes.app"
hermes_stamp=""
if [ -e "$hermes" ]; then
    hermes_stamp=$(stat -f '%i %m %z' "$hermes" "$hermes/Contents/MacOS/Hermes")
fi

install_dir="$HOME/Applications"
case "$install_dir" in
    /Applications|/Applications/*)
        echo "refusing to install into /Applications" >&2
        exit 1
        ;;
esac

mkdir -p "$install_dir"
installed="$install_dir/Kept.app"
if [ -L "$installed" ]; then
    rm -f "$installed"
elif [ -e "$installed" ]; then
    rm -rf "$installed"
fi
ditto "$app" "$installed"
codesign --force --sign - --identifier local.kept.app \
    -r='designated => identifier "local.kept.app"' \
    "$installed"
codesign --verify --strict "$installed"
test -x "$installed/Contents/MacOS/Kept"
test "$(plutil -extract LSUIElement raw "$installed/Contents/Info.plist")" = "true"
test "$(plutil -extract CFBundleIdentifier raw "$installed/Contents/Info.plist")" = "local.kept.app"

if [ -n "$hermes_stamp" ]; then
    hermes_now=$(stat -f '%i %m %z' "$hermes" "$hermes/Contents/MacOS/Hermes")
    test "$hermes_stamp" = "$hermes_now"
fi
