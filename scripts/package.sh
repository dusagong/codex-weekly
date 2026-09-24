#!/bin/bash
# Build the release ZIP and SHA-256 checksum. Optional argument selects the output directory.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
release_dir="${1:-$repo_dir/build/releases}"
if [ "$#" -gt 1 ]; then
    printf 'Usage: %s [output-directory]\n' "$0" >&2
    exit 2
fi
mkdir -p "$release_dir"
release_dir="$(cd "$release_dir" && pwd)"
"$repo_dir/scripts/test.sh"
"$repo_dir/scripts/build.sh"

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$repo_dir/Info.plist")"
archive="Codex-Weekly-v$version-macOS-universal.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
    "$repo_dir/build/Codex Weekly.app" "$release_dir/$archive"
(cd "$release_dir" && /usr/bin/shasum -a 256 "$archive" > SHA256SUMS)
printf 'Packaged %s\nRelease files: %s\n' "$archive" "$release_dir"
