#!/bin/zsh
set -euo pipefail

root_dir=${0:A:h:h}
configuration=${1:-release}
app_dir="$root_dir/.build/coding-agent-percentage.app"
contents="$app_dir/Contents"

cd "$root_dir"
swift build -c "$configuration"
binary_dir=$(swift build -c "$configuration" --show-bin-path)

rm -rf "$app_dir"
mkdir -p "$contents/MacOS"
cp "$binary_dir/coding-agent-percentage" "$contents/MacOS/coding-agent-percentage"
cp "$root_dir/support/Info.plist" "$contents/Info.plist"
codesign --force --sign - "$app_dir"

echo "$app_dir"
