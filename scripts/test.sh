#!/bin/bash
# Offline fixtures only: no Codex account requests or network access.
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_dir="$repo_dir/build/tests"
if [ "$#" -ne 0 ]; then
    printf 'Usage: %s\n' "$0" >&2
    exit 2
fi
mkdir -p "$test_dir/module-cache"

/usr/bin/xcrun swiftc -module-cache-path "$test_dir/module-cache" \
    "$repo_dir/src/UsageModel.swift" \
    "$repo_dir/tests/model/main.swift" -o "$test_dir/weekly-model"
"$test_dir/weekly-model"

# The fixture's main-actor checks use Swift 6 top-level isolation.
/usr/bin/xcrun swiftc -swift-version 6 -module-cache-path "$test_dir/module-cache" \
    "$repo_dir/src/UsageRPC.swift" \
    "$repo_dir/tests/transport/main.swift" -o "$test_dir/weekly-transport"
"$test_dir/weekly-transport"
