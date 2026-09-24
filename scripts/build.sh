#!/bin/bash
# Requires macOS and Xcode or the Xcode Command Line Tools.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$repo_dir/build"
bundle="$build_dir/Codex Weekly.app"
executable_name="CodexWeekly"
sdk_path="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"
minimum_macos="14.0"

mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$repo_dir/Info.plist" "$bundle/Contents/Info.plist"
cp "$repo_dir/LICENSE" "$bundle/Contents/Resources/LICENSE"
/usr/bin/plutil -lint "$bundle/Contents/Info.plist"
for arch in arm64 x86_64; do
    mkdir -p "$build_dir/$arch/module-cache"
    /usr/bin/xcrun swiftc \
        -sdk "$sdk_path" -target "$arch-apple-macosx$minimum_macos" \
        -module-cache-path "$build_dir/$arch/module-cache" \
        -O -framework AppKit "$repo_dir/src/"*.swift \
        -o "$build_dir/$arch/$executable_name"
done
/usr/bin/lipo -create "$build_dir/arm64/$executable_name" "$build_dir/x86_64/$executable_name" \
    -output "$bundle/Contents/MacOS/$executable_name"
# Ad-hoc local signature only. This is not a Developer ID signature or notarization.
/usr/bin/codesign --force --sign - "$bundle"
/usr/bin/codesign --verify --deep --strict "$bundle"
/usr/bin/lipo "$bundle/Contents/MacOS/$executable_name" -verify_arch arm64 x86_64
/usr/bin/file "$bundle/Contents/MacOS/$executable_name"
/usr/bin/xcrun vtool -show-build "$bundle/Contents/MacOS/$executable_name"
printf 'Built universal app: %s\n' "$bundle"
