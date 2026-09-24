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

codesign --force --sign - "$app"
codesign --verify --strict "$app"

test -x "$app/Contents/MacOS/Kept"
test "$(plutil -extract LSUIElement raw "$app/Contents/Info.plist")" = "true"
